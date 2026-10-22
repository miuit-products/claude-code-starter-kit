#!/bin/bash
# chat-preview hub を開く/前面化する。
# すでに Chrome に hub.html のタブがあればそれを再利用してキー(#key)へジャンプし、
# 無ければ新規タブを1つだけ開く。AppleScript が使えない/許可されない環境では
# 素直に `open` にフォールバックする（その場合のみ新規タブが増える）。
# 成功/失敗どちらのパスでも最後に HUB_URL を1行 stdout に出す
# （呼び出し側は自動オープンが効かなかった場合の手動リンクとして必ず使う）。
set -euo pipefail

KEY="${1:-}"
if [[ ! "$KEY" =~ ^[a-z0-9-]+$ ]]; then
  echo "usage: open-hub.sh <key>  (key must match [a-z0-9-]+)" >&2
  exit 1
fi

HUB_PATH="${CHAT_PREVIEW_BASE:-$HOME/.claude/chat-preview}/hub.html"
HUB_BASE="file://${HUB_PATH}"
HUB_URL="${HUB_BASE}#${KEY}"

if ! command -v osascript >/dev/null 2>&1; then
  open "$HUB_URL"
  echo "$HUB_URL"
  exit 0
fi

if osascript <<OSA
set hubBase to "${HUB_BASE}"
set targetURL to "${HUB_URL}"
tell application "Google Chrome"
  if not running then
    open location targetURL
    activate
    return
  end if
  set foundIt to false
  set dupeTabs to {}
  repeat with w in windows
    set i to 0
    repeat with t in tabs of w
      set i to i + 1
      try
        if (URL of t) starts with hubBase then
          if foundIt then
            set end of dupeTabs to t
          else
            set URL of t to targetURL
            set active tab index of w to i
            set index of w to 1
            set foundIt to true
          end if
        end if
      end try
    end repeat
  end repeat
  -- 過去の権限エラー等で溜まった重複ハブタブは、見つけたついでに畳んでおく
  -- （古いバックグラウンドウィンドウに埋もれて「開いたのに見えない」原因になっていた）
  repeat with dt in dupeTabs
    try
      close dt
    end try
  end repeat
  if not foundIt then
    open location targetURL
  end if
  activate
end tell
OSA
then
  echo "$HUB_URL"
  exit 0
else
  # Automation 権限が未許可、または Chrome を操作できなかった場合のフォールバック。
  # このパスでは新規タブが開く（従来動作と同じ）。
  open "$HUB_URL"
  echo "$HUB_URL"
fi
