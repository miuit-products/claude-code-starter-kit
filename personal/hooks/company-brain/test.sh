#!/bin/bash
# Company Brain hooks — 検証スイート
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

HERE="$(pwd)"
export CB_STATE_DIR="$HERE/.test-state"
rm -rf "$CB_STATE_DIR"
mkdir -p "$CB_STATE_DIR"

PASS=0; FAIL=0
S="11111111-aaaa-bbbb-cccc-222222222222"
P1="33333333-dddd-eeee-ffff-444444444444"
P2="55555555-dddd-eeee-ffff-666666666666"

j() { jq -cn "$@"; }

check() { # check <name> <expect: empty|nonempty> <actual>
  local name="$1" expect="$2" actual="$3"
  if [ "$expect" = "empty" ] && [ -z "$actual" ]; then
    echo "  PASS  $name"; PASS=$((PASS+1))
  elif [ "$expect" = "nonempty" ] && [ -n "$actual" ]; then
    echo "  PASS  $name"; PASS=$((PASS+1))
  else
    echo "  FAIL  $name (expected $expect, got: ${actual:0:120})"; FAIL=$((FAIL+1))
  fi
}

valid_json() { # valid_json <name> <string>
  if [ -z "$2" ]; then echo "  FAIL  $1 (no output)"; FAIL=$((FAIL+1)); return; fi
  if printf '%s' "$2" | jq -e . >/dev/null 2>&1; then
    echo "  PASS  $1 (valid JSON)"; PASS=$((PASS+1))
  else
    echo "  FAIL  $1 (invalid JSON: ${2:0:120})"; FAIL=$((FAIL+1))
  fi
}

ups() { # ups <prompt> [prompt_id] [cwd]
  j --arg s "$S" --arg p "${2:-$P1}" --arg t "$1" --arg c "${3:-/Users/yasuikaito/proj}" \
    '{session_id:$s,prompt_id:$p,cwd:$c,hook_event_name:"UserPromptSubmit",prompt:$t}' \
    | ./prompt-submit.sh
}

stp() { # stp <msg> [prompt_id] [stop_hook_active] [ntasks] [cwd]
  j --arg s "$S" --arg p "${2:-$P1}" --arg m "$1" \
    --argjson a "${3:-false}" --argjson n "${4:-0}" --arg c "${5:-/Users/yasuikaito/proj}" \
    '{session_id:$s,prompt_id:$p,cwd:$c,hook_event_name:"Stop",stop_hook_active:$a,
      last_assistant_message:$m,
      background_tasks:[range($n)|{id:"t",type:"shell",status:"running",description:"x"}],
      session_crons:[]}' \
    | ./stop-save-check.sh
}

echo "== SessionStart =="
OUT=$(j --arg s "$S" --arg c "/Users/yasuikaito/proj" '{session_id:$s,cwd:$c,hook_event_name:"SessionStart",reason:"startup"}' | ./session-start.sh)
valid_json "SessionStart emits JSON" "$OUT"
check "SessionStart hookEventName" nonempty "$(printf '%s' "$OUT" | jq -r 'select(.hookSpecificOutput.hookEventName=="SessionStart")|"y"')"
check "SessionStart has additionalContext" nonempty "$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext // empty')"

echo
echo "== UserPromptSubmit: 発火すべきケース =="
for t in "Octtyの料金プランってどうなってる？" "この機能、前に決めた方針ある？" "競合のダトラと比較したい" "顧客への見積の出し方"; do
  rm -f "$CB_STATE_DIR"/*.company 2>/dev/null
  O=$(ups "$t"); check "fires: $t" nonempty "$O"
done

echo
echo "== UserPromptSubmit: 発火すべきでないケース =="
rm -f "$CB_STATE_DIR"/*.optout
for t in "このESLintエラー直して" "git statusして" "型エラーを修正" "こんにちは"; do
  O=$(ups "$t"); check "silent: $t" empty "$O"
done

echo
echo "== UserPromptSubmit: subagent の返答・タスク通知は発火しない =="
rm -f "$CB_STATE_DIR"/*.company 2>/dev/null
O=$(ups "Another Claude session sent a message:
<agent-message from=\"abc\">
  ## 司書レポート
  Octty の料金プランの決定ページ …
</agent-message>"); check "silent: agent-message hand-back" empty "$O"
O=$(ups "<task-notification>
<task-id>abc</task-id>
<summary>Agent \"司書テスト2: 料金プラン\" finished</summary>
</task-notification>"); check "silent: task-notification" empty "$O"
O=$(ups "Octtyの料金で、<agent-message> というタグの意味は？"); check "fires: user text mentioning the tag inline" nonempty "$O"
O=$(ups "<task-notification>
<summary>Agent finished</summary>
</task-notification>
ところでOcttyの料金プランってどうなってる？"); check "fires: user question after a notification" nonempty "$O"

echo
echo "== UserPromptSubmit: 私的会話・保存拒否 =="
O=$(ups "家族との予定を整理したい、これはプライベートな話"); check "private conversation silent" empty "$O"
rm -f "$CB_STATE_DIR/$S.optout"
O=$(ups "Octtyの料金の話だけどCompany Brainには保存しないで"); check "save-refusal silent" empty "$O"
if [ -f "$CB_STATE_DIR/$S.optout" ]; then echo "  PASS  save-refusal sets optout"; PASS=$((PASS+1)); else echo "  FAIL  optout not set"; FAIL=$((FAIL+1)); fi
O=$(stp "Octtyの料金について決定しました。理由は……$(head -c 700 /dev/zero | tr '\0' 'あ')"); check "Stop suppressed by optout" empty "$O"
rm -f "$CB_STATE_DIR/$S.optout"

echo
echo "== Stop: ループ防止 =="
LONG="方針を決定しました。採用した案と却下した案、制約、検証結果は次のとおりです。$(head -c 700 /dev/zero | tr '\0' 'あ')"
rm -f "$CB_STATE_DIR"/*.nudged
O1=$(stp "$LONG" "$P1"); check "Stop nudges once" nonempty "$O1"
valid_json "Stop output is JSON" "$O1"
O2=$(stp "$LONG" "$P1"); check "Stop 2nd call same turn silent" empty "$O2"
O3=$(stp "$LONG" "$P1" true); check "stop_hook_active=true silent" empty "$O3"
O4=$(stp "$LONG" "$P2"); check "next turn (new prompt_id) can nudge" nonempty "$O4"

echo
echo "== Stop: 促さないケース =="
rm -f "$CB_STATE_DIR"/*.nudged
check "background task pending" empty "$(stp "$LONG" "$P1" false 1)"
rm -f "$CB_STATE_DIR"/*.nudged
check "awaiting user answer (?)" empty "$(stp "どちらの方式にしますか？")"
rm -f "$CB_STATE_DIR"/*.nudged
check "auth/MCP failure" empty "$(stp "company-brain へ接続に失敗しました。permission_denied が返っています。$LONG")"
rm -f "$CB_STATE_DIR"/*.nudged
check "already saved" empty "$(stp "workspace-yasui に保存しました。slug は test です。$LONG")"
rm -f "$CB_STATE_DIR"/*.nudged
check "trivial short turn" empty "$(stp "完了しました。")"
rm -f "$CB_STATE_DIR"/*.nudged
check "missing prompt_id -> no nudge" empty "$(j --arg s "$S" --arg m "$LONG" '{session_id:$s,hook_event_name:"Stop",stop_hook_active:false,last_assistant_message:$m,background_tasks:[],session_crons:[]}' | ./stop-save-check.sh)"

echo
echo "== プロジェクト除外 =="
EX="$HERE/.test-excluded"; mkdir -p "$EX"; touch "$EX/.company-brain-ignore"
rm -f "$CB_STATE_DIR"/*.nudged "$CB_STATE_DIR"/*.optout
check "excluded project: UserPromptSubmit silent" empty "$(ups "Octtyの料金は？" "$P1" "$EX")"
rm -f "$CB_STATE_DIR"/*.nudged "$CB_STATE_DIR"/*.optout
check "excluded project: Stop silent" empty "$(stp "$LONG" "$P1" false 0 "$EX")"

echo
echo "== 堅牢性: 不正入力・インジェクション =="
check "empty stdin (UPS)" empty "$(printf '' | ./prompt-submit.sh)"
check "empty stdin (Stop)" empty "$(printf '' | ./stop-save-check.sh)"
check "malformed JSON (UPS)" empty "$(printf 'not json' | ./prompt-submit.sh)"
check "malformed JSON (Stop)" empty "$(printf 'not json' | ./stop-save-check.sh)"
valid_json "SessionStart w/ empty stdin" "$(printf '' | ./session-start.sh)"
# パストラバーサル: session_id に ../ を仕込む
rm -rf "$CB_STATE_DIR/evil"
j --arg s "../../evil" --arg p "$P1" --arg t "Octtyの料金" '{session_id:$s,prompt_id:$p,cwd:"/tmp",hook_event_name:"UserPromptSubmit",prompt:$t}' | ./prompt-submit.sh >/dev/null
if [ -z "$(find "$CB_STATE_DIR/.." -maxdepth 1 -name 'evil*' 2>/dev/null)" ]; then
  echo "  PASS  path traversal sanitized"; PASS=$((PASS+1))
else echo "  FAIL  path traversal escaped"; FAIL=$((FAIL+1)); fi
# 命令インジェクション: プロンプトにコマンドを仕込んでも実行されない
PWNED="$HERE/.cb-pwned"
rm -f "$PWNED"
O=$(ups '$(touch '"$PWNED"') `touch '"$PWNED"'` Octtyの料金')
if [ ! -f "$PWNED" ]; then echo "  PASS  no command injection"; PASS=$((PASS+1));
else echo "  FAIL  command injection!"; FAIL=$((FAIL+1)); rm -f "$PWNED"; fi

echo
echo "== 機密保護: 状態ファイルに本文を書かない =="
rm -f "$CB_STATE_DIR"/*
ups "Octtyの料金は SECRETVALUE123 です" >/dev/null
stp "料金を決定しました SECRETVALUE123 $LONG" >/dev/null
if grep -rq "SECRETVALUE123" "$CB_STATE_DIR" 2>/dev/null; then
  echo "  FAIL  prompt text leaked into state"; FAIL=$((FAIL+1))
else echo "  PASS  no prompt/assistant text in state files"; PASS=$((PASS+1)); fi
echo "  state files: $(ls "$CB_STATE_DIR" | tr '\n' ' ')"
echo "  sizes: $(find "$CB_STATE_DIR" -type f -size +0c | wc -l | tr -d ' ') non-empty files (expect 0)"

echo
echo "== 実行時間 =="
T0=$(python3 -c 'import time;print(time.time())')
for i in 1 2 3 4 5; do ups "Octtyの料金は？" >/dev/null; done
T1=$(python3 -c 'import time;print(time.time())')
python3 -c "print('  5 runs: %.0f ms total (%.0f ms each)' % (($T1-$T0)*1000, ($T1-$T0)*200))"

echo
echo "================================"
echo "PASS=$PASS  FAIL=$FAIL"
[ "$FAIL" -eq 0 ] && echo "ALL GREEN" || echo "FAILURES PRESENT"
rm -rf "$CB_STATE_DIR"
exit "$FAIL"
