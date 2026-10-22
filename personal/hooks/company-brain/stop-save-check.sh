#!/bin/bash
# Stop hook — 未処理の業務知見について、保存要否の判定・保存を「1ターンにつき1回だけ」促す。
#
# 入力(stdin): 共通フィールド + stop_hook_active, last_assistant_message,
#              background_tasks[], session_crons[]
# 出力: 促すとき {"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"..."}}
#       それ以外は何も出さない（= 通常どおり停止）
#
# ループ防止（多重）:
#   1) stop_hook_active が true なら即終了（Claude Code 側は 8 連続で打ち切るが、それに頼らない）
#   2) <sid>.<pid>.nudged マーカーで同一ターン 1 回に限定（出力前に作成）
#   3) prompt_id が無いターンでは促さない（ターン境界を識別できないため）
#   4) background_tasks / session_crons が残っているときは「完了」ではないので促さない
#
# このフックは保存を実行しない。保存は AI が既存の認証済み MCP 経由で行う。
# hook の成功は保存成功を意味しない。

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
. "$HOOK_DIR/lib.sh"

INPUT="$(cat 2>/dev/null || true)"
cb_init_state

ACTIVE="$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)"
[ "$ACTIVE" = "true" ] && exit 0

SID="$(printf '%s' "$INPUT"  | jq -r '.session_id // empty' 2>/dev/null || true)"
PID="$(printf '%s' "$INPUT"  | jq -r '.prompt_id  // empty' 2>/dev/null || true)"
CWD="$(printf '%s' "$INPUT"  | jq -r '.cwd        // empty' 2>/dev/null || true)"
MSG="$(printf '%s' "$INPUT"  | jq -r '.last_assistant_message // empty' 2>/dev/null || true)"
NTASK="$(printf '%s' "$INPUT" | jq -r '(.background_tasks // []) | length' 2>/dev/null || echo 0)"
NCRON="$(printf '%s' "$INPUT" | jq -r '(.session_crons   // []) | length' 2>/dev/null || echo 0)"

# ターン境界を識別できないなら促さない（後続ターンや別セッションを妨げないため）
[ -z "$PID" ] && exit 0
[ -z "$MSG" ] && exit 0

# セッションが「完了」ではなく「バックグラウンド待ち」のときは促さない
[ "$NTASK" != "0" ] && exit 0
[ "$NCRON" != "0" ] && exit 0

KEY="$(cb_state_key "$SID" "$PID")"
SIDS="$(cb_sanitize "$SID")"; [ -z "$SIDS" ] && SIDS="nosession"

# 状態を書けない環境では「1ターン1回」を保証できない。促さずに終了する（ループ防止優先）。
cb_state_writable || exit 0

[ -f "$CB_STATE_DIR/$KEY.nudged" ] && exit 0
[ -f "$CB_STATE_DIR/$SIDS.optout" ] && exit 0
cb_project_excluded "$CWD" && exit 0

# --- 促さないケース ---------------------------------------------------------
# 1) ユーザーの回答待ち（質問で終わっている / 選択を求めている）
TAIL="$(printf '%s' "$MSG" | tail -c 400)"
if printf '%s' "$TAIL" | grep -qE '[？?][[:space:]]*$|(どちら|いずれ|どれ)に(しますか|しましょう)|教えてください[[:space:]]*$|ご確認ください[[:space:]]*$|進めてよいですか|よろしいでしょうか'; then
  exit 0
fi

# 2) 認証待ち / 接続不能 / 権限不足（保存を促しても失敗するだけ）
if printf '%s' "$MSG" | grep -qiE '認証(が必要|してください|待ち)|ログインしてください|再ログイン|permission_denied|unauthorized|forbidden|401|403|接続(に失敗|できません|エラー)|not connected|failed to connect|MCP.*(失敗|未接続)'; then
  exit 0
fi

# 3) 明示的に保存不要・私的と述べている
if printf '%s' "$MSG" | grep -qiE '保存(は)?(不要|しません|見送)|記録(は)?(不要|しません)|私的|雑談'; then
  exit 0
fi

# 4) 既にこのターンで保存済みと述べている（重複保存を促さない）
if printf '%s' "$MSG" | grep -qiE 'company.?brain.*(へ|に).*(保存|記録)しました|put_page.*成功|workspace-[a-z-]+.*(へ|に).*保存しました'; then
  exit 0
fi

# --- 促す条件 ---------------------------------------------------------------
LEN="$(printf '%s' "$MSG" | wc -c | tr -d ' ')"

# 下限: 短すぎる回答には保存すべき知見が無い（会社関連ターンでも促さない）
[ "${LEN:-0}" -lt 200 ] && exit 0

# (A) UserPromptSubmit が会社関連と判定したターン、または
# (B) 実質的な成果が出たターン（十分な長さ + 決定/実装/調査の語彙）
WORTH=0
[ -f "$CB_STATE_DIR/$KEY.company" ] && WORTH=1

if [ "$WORTH" -eq 0 ]; then
  if [ "${LEN:-0}" -ge 600 ] && printf '%s' "$MSG" | grep -qiE '決定|方針|採用しました|却下|設計|移行|原因は|修正しました|実装しました|結論|比較した|検証結果|トレードオフ'; then
    WORTH=1
  fi
fi

[ "$WORTH" -eq 0 ] && exit 0

# 出力の前にマーカーを作る（出力後に落ちても二重に促さない）
cb_touch "$CB_STATE_DIR/$KEY.nudged" || true

read -r -d '' CTX <<'CBEOF' || true
Company Brain 保存チェック（このターンで 1 回だけ）。判定基準は ~/.claude/CLAUDE.md の
「Company Brain 運用ルール」に従う（保存先は本人の workspace のみ。秘密・個人情報・顧客の
限定公開情報は保存しない）。

最後に次のどちらかを 1 行だけ書いて終了する。
- 保存しない場合: 「Company Brain: 保存なし」
- 保存した場合:   「Company Brain: 保存 → <workspace>/<slug>」（put_page の成功応答を確認してから書く）

失敗・権限不足は隠さずそのまま報告し、無限に再試行しない。
CBEOF

cb_emit_additional_context "Stop" "$CTX"
exit 0
