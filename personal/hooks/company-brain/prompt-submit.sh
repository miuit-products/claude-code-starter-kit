#!/bin/bash
# UserPromptSubmit hook — 会社関連の質問で、回答前の Company Brain 検索を促す。
#
# 入力(stdin): 共通フィールド + .prompt（ユーザーが送信したテキスト）
#   ※ このイベントの本文フィールドは `prompt`。`user_input` というフィールドは存在しない。
# 出力: {"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"..."}}
#       会社関連でなければ何も出さない（プロンプトは常に通す。block は一切しない）
#
# 副作用: このターンの判定結果を状態ファイルへ残す（真偽値のみ。本文は書かない）
#   <sid>.<pid>.company : 会社関連ターン
#   <sid>.optout        : このセッションでは保存を促さない（保存拒否 / 私的会話宣言）

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$HOOK_DIR/lib.sh"

INPUT="$(cat 2>/dev/null || true)"
cb_init_state

SID="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)"
PID="$(printf '%s' "$INPUT" | jq -r '.prompt_id  // empty' 2>/dev/null || true)"
CWD="$(printf '%s' "$INPUT" | jq -r '.cwd        // empty' 2>/dev/null || true)"
PROMPT="$(printf '%s' "$INPUT" | jq -r '
  if (.prompt | type) == "string" then .prompt
  elif (.prompt | type) == "object" then (.prompt.content // empty)
  else empty end' 2>/dev/null || true)"

[ -z "$PROMPT" ] && exit 0

# 2026-10-22（ハーネス #5 テストで判明）: subagent の返答やバックグラウンド完了通知も
# UserPromptSubmit として届き、本文の語（料金・顧客など）で誤発火して「司書を呼べ」が毎回注入されていた。
# 通知ブロックを取り除き、残ったユーザー自身の文だけで判定する（混在メッセージでもユーザー部分は判定される）。
PROMPT="$(printf '%s' "$PROMPT" | perl -0pe '
  s{<task-notification>.*?</task-notification>}{}gs;
  s{<agent-message\b[^>]*>.*?</agent-message>}{}gs;
  s{<system-reminder>.*?</system-reminder>}{}gs;
  s{^Another Claude session sent a message:\s*$}{}gm;
  s{^That "other Claude session" is an agent working inside this same session.*?(?:\n\n|\z)}{}gms;
' 2>/dev/null || printf '%s' "$PROMPT")"
[ -z "$(printf '%s' "$PROMPT" | tr -d '[:space:]')" ] && exit 0

KEY="$(cb_state_key "$SID" "$PID")"
SIDS="$(cb_sanitize "$SID")"; [ -z "$SIDS" ] && SIDS="nosession"

# --- プロジェクト除外 -------------------------------------------------------
if cb_project_excluded "$CWD"; then
  cb_touch "$CB_STATE_DIR/$SIDS.optout" || true
  exit 0
fi

# --- 明示的な保存拒否 / 私的会話宣言（セッション単位で以後の促しを止める）----
if printf '%s' "$PROMPT" | grep -qiE '保存しないで|記録しないで|残さないで|ブレインに入れないで|brain(に|へ)(は)?(入れ|保存|記録)しないで|company.?brain.*(使わないで|オフ|無効)|オフレコ|この話は(内緒|秘密)|do ?not (save|record|store)|dont save this'; then
  cb_touch "$CB_STATE_DIR/$SIDS.optout" || true
  exit 0
fi

# --- 私的・非業務の文脈は発火させない ---------------------------------------
if printf '%s' "$PROMPT" | grep -qiE '雑談|世間話|プライベート|私事|私用|家族|恋愛|体調|健康診断|通院|給与明細|年収|転職したい|愚痴'; then
  exit 0
fi

CATEGORY=""

# (A) 会社固有の強いシグナル（単独で発火してよい語）
if printf '%s' "$PROMPT" | grep -qiE '会社の方針|社内(方針|ルール|規程|制度|共有)|全社|うちの会社|自社|Octty|オクティー|Miuit|ミューイット|料金(表|体系|プラン)?|価格(表|改定)?|見積|商談|受注|失注|顧客|取引先|クライアント|営業(先|資料|状況)?|契約(書|条件)?|請求|決算|ISMS|競合|導入事例|テナント'; then
  CATEGORY="company"
fi

# (B) 過去の判断・実装の参照（文脈パターン。単語一致ではなく句で判定）
if [ -z "$CATEGORY" ] && printf '%s' "$PROMPT" | grep -qiE '前に(決め|話し|検討|実装|調べ)|以前(の|に).{0,6}(判断|決定|実装|調査|方針)|過去に.{0,8}(決|判断|実装|調査)|どう(決めた|判断した)|なぜ.{0,12}(決めた|採用|選んだ|却下)|(決定|判断)の経緯|前回の.{0,8}(実装|判断|方針|調査)|似た(事例|ケース)|調査メモ|previously (decided|discussed|implemented)|what did we (decide|choose)|past decision'; then
  CATEGORY="recall"
fi

# (C) 弱いシグナルは 2 つ以上そろったときだけ（単語一致だけで決めない）
if [ -z "$CATEGORY" ]; then
  WEAK=0
  for pat in '方針' '判断' '設計|アーキテクチャ' '調査|リサーチ' '事例' '運用(ルール|フロー)' '比較検討|技術選定'; do
    if printf '%s' "$PROMPT" | grep -qiE "$pat"; then WEAK=$((WEAK+1)); fi
  done
  if [ "$WEAK" -ge 2 ]; then CATEGORY="weak"; fi
fi

[ -z "$CATEGORY" ] && exit 0

cb_touch "$CB_STATE_DIR/$KEY.company" || true

# 2026-10-18（ハーネス #5）: 本体が MCP を直接叩く手順から「司書 subagent を 1 回呼ぶ」に変更。
# 理由: 本体（Fable）のコンテキストに検索結果の生データを入れない／検索回数を司書側で上限管理する。
# 2026-10-18: GBrain は廃止（Company Brain へ完全移行）。brain-first-check.sh は settings.json から外した。
read -r -d '' CTX <<'CBEOF' || true
Company Brain-First: 会社に関わる問い合わせを検出しました。回答を書き始める前に、司書 subagent を 1 回だけ呼んで関連記録を取り寄せてください。

Agent(subagent_type: "brain-librarian", prompt: "question: <ユーザーの質問をそのまま>\nscope: company\nhints: <検索語 2〜3 個>")

・GBrain（個人ブレイン）は廃止済み。検索しない。
・司書レポートの「状態」を見て、接続エラーと「該当なし（0件）」を区別して伝える。未確認の社内方針を断定しない。
・回答には司書が実際に取得した slug とタイトルだけを出典として添える。
・司書が接続エラーを返したら、その旨を述べて一般知識で補う（自分で MCP を叩き直して無限に再試行しない）。
CBEOF

cb_emit_additional_context "UserPromptSubmit" "$CTX"
exit 0
