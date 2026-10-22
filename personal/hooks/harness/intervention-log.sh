#!/bin/bash
# Stop hook — worker（Codex / Sonnet subagent / クラウド）の成果物を Fable が受入したターンで、
# 介入ログ（1行 JSONL）の追記を「1ターンにつき1回だけ」促す。
#
# 目的: Harness Optimization Loop の分母・分子を作る。
#   介入率 = intervened:true の件数 / 受入件数。kind 別に数えて「毎回同じところで人が手を出している」を見つける。
#
# 入力(stdin): 共通フィールド + stop_hook_active, last_assistant_message, background_tasks[], session_crons[]
# 出力: 促すとき {"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"..."}}
#       それ以外は何も出さない
#
# ループ防止は company-brain/stop-save-check.sh と同じ:
#   1) stop_hook_active が true なら即終了
#   2) <sid>.<pid>.intervention マーカーで同一ターン 1 回に限定（出力前に作成）
#   3) prompt_id が無いターンでは促さない
#   4) background_tasks / session_crons が残っているときは促さない
#
# このフックはログを書かない。書くのは AI（Fable）で、形式は下記の CTX に従う。

set -uo pipefail

LOG_DIR="${HARNESS_LOG_DIR:-$HOME/.claude/harness-log}"
LOG_FILE="$LOG_DIR/interventions.jsonl"
STATE_DIR="$HOME/.claude/company-brain-state"   # 既存の状態ディレクトリを共用（真偽値の空ファイルのみ）

INPUT="$(cat 2>/dev/null || true)"

ACTIVE="$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)"
[ "$ACTIVE" = "true" ] && exit 0

SID="$(printf '%s' "$INPUT"  | jq -r '.session_id // empty' 2>/dev/null || true)"
PID="$(printf '%s' "$INPUT"  | jq -r '.prompt_id  // empty' 2>/dev/null || true)"
CWD="$(printf '%s' "$INPUT"  | jq -r '.cwd        // empty' 2>/dev/null || true)"
MSG="$(printf '%s' "$INPUT"  | jq -r '.last_assistant_message // empty' 2>/dev/null || true)"
NTASK="$(printf '%s' "$INPUT" | jq -r '(.background_tasks // []) | length' 2>/dev/null || echo 0)"
NCRON="$(printf '%s' "$INPUT" | jq -r '(.session_crons   // []) | length' 2>/dev/null || echo 0)"

[ -z "$PID" ] && exit 0
[ -z "$MSG" ] && exit 0
[ "$NTASK" != "0" ] && exit 0
[ "$NCRON" != "0" ] && exit 0

mkdir -p "$STATE_DIR" "$LOG_DIR" 2>/dev/null || exit 0
SAFE_SID="$(printf '%s' "$SID" | tr -c 'A-Za-z0-9_-' '_' )"; [ -z "$SAFE_SID" ] && SAFE_SID="nosession"
SAFE_PID="$(printf '%s' "$PID" | tr -c 'A-Za-z0-9_-' '_' )"
MARK="$STATE_DIR/$SAFE_SID.$SAFE_PID.intervention"
[ -f "$MARK" ] && exit 0

# --- 受入ターンの判定 -------------------------------------------------------
# worker の成果物を受け取った・検証した・マージした、という語彙が本文にあるときだけ。
# 通常の会話・調査・自分で実装しただけのターンでは促さない。
# 過去形の「実際にやった」表現だけに絞る（「受入手順を書いた」「受入ログを作った」等の説明文で誤発火しないため。2026-10-17 初回誤発火で修正）
if ! printf '%s' "$MSG" | grep -qE '\[DONE\].*(受入|検証|確認)しました|(受入|受け入れ)(しました|完了|済み)|差し戻しました|(PR|プルリク).*(マージしました|merge しました)|worker の(成果物|PR|diff)を(確認|検証|レビュー)しました|subagent の(成果|結果|出力)を(確認|検証|レビュー)しました'; then
  exit 0
fi

# 既にこのターンで記録済みと述べている
if printf '%s' "$MSG" | grep -qiE 'interventions\.jsonl|介入ログ(に|へ)(追記|記録)しました'; then
  exit 0
fi

# ユーザーの回答待ちで終わっているターンは促さない（受入が完了していない）
TAIL="$(printf '%s' "$MSG" | tail -c 300)"
if printf '%s' "$TAIL" | grep -qE '[？?][[:space:]]*$|進めてよいですか|よろしいでしょうか'; then
  exit 0
fi

touch "$MARK" 2>/dev/null || exit 0

REPO="$(basename "${CWD:-unknown}")"
TS="$(date +%Y-%m-%dT%H:%M:%S%z)"

read -r -d '' CTX <<CBEOF || true
介入ログ（このターンで 1 回だけ）。worker の成果物を受入したので、次の 1 行を ${LOG_FILE} に追記する（Bash の echo >> で可。既存行は変更しない）。

{"ts":"${TS}","repo":"${REPO}","task":"<短い要約>","worker":"codex|sonnet|claude-cloud|fable","intervened":true|false,"kind":"tenant-guard|test-missing|design-token|spec-gap|layer-violation|flake|security|none|other","fix_layer":"type|ci|rule|prompt|manual|none","notes":"<1行。何を直したか / 直さなかった理由>"}

ルール:
- intervened は「受入で人（Fable 含む）が直した・差し戻した」なら true。そのまま通したら false で kind:"none", fix_layer:"none"。
- kind は介入の原因の種類。fix_layer は「同じ介入を次回なくすなら、どの層で防ぐべきか」（pstack の優先順位: type > ci > rule > prompt > manual）。
- 秘密値・個人情報・顧客名は書かない。
- 追記したら本文の最後に「介入ログ: 追記済み（kind=…, fix_layer=…）」と 1 行書く。
CBEOF

jq -nc --arg ctx "$CTX" '{hookSpecificOutput:{hookEventName:"Stop",additionalContext:$ctx}}'
exit 0
