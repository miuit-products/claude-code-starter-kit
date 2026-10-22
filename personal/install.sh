#!/bin/bash
# 個人設定パックを ~/.claude/ に入れる。
#
# 入れるもの:
#   hooks/harness/        介入ログ（Stop hook）と集計スクリプト
#   hooks/company-brain/  Company Brain の hook（SessionStart / UserPromptSubmit / Stop）
#   agents/brain-librarian.md  司書エージェント（Company Brain を読み取り専用で検索）
#
# ~/.claude/settings.json はバックアップを取ってから hook を追記する。
# 同じ command が既に登録されていれば追加しない（何度実行しても重複しない）。
#
# 使い方: ./personal/install.sh [--dry-run]
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS="$DEST/settings.json"
DRY_RUN=false
[ "${1:-}" = "--dry-run" ] && DRY_RUN=true

command -v jq >/dev/null 2>&1 || { echo "jq が必要です（brew install jq）" >&2; exit 1; }

run() { if $DRY_RUN; then echo "[dry-run] $*"; else "$@"; fi; }

# ── 1. ファイルを配置 ─────────────────────────────────────
run mkdir -p "$DEST/hooks/harness" "$DEST/hooks/company-brain" "$DEST/agents"
for f in "$SRC"/hooks/harness/*.sh; do run install -m 755 "$f" "$DEST/hooks/harness/"; done
for f in "$SRC"/hooks/company-brain/*.sh; do run install -m 755 "$f" "$DEST/hooks/company-brain/"; done
run install -m 644 "$SRC/agents/brain-librarian.md" "$DEST/agents/"

# ── 2. settings.json に hook を登録 ─────────────────────────
[ -f "$SETTINGS" ] || { $DRY_RUN || echo '{}' > "$SETTINGS"; }
if ! $DRY_RUN; then
  cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
fi

# event / command / statusMessage（空なら付けない）
HOOKS=$(cat <<EOF
SessionStart	$DEST/hooks/company-brain/session-start.sh	Company Brain
UserPromptSubmit	$DEST/hooks/company-brain/prompt-submit.sh	Company Brain
Stop	$DEST/hooks/company-brain/stop-save-check.sh	Company Brain
Stop	$DEST/hooks/harness/intervention-log.sh
EOF
)

TMP=$(mktemp)
cp "${SETTINGS}" "$TMP" 2>/dev/null || echo '{}' > "$TMP"
while IFS=$'\t' read -r event cmd status; do
  if jq -e --arg e "$event" --arg c "$cmd" \
      '[.hooks[$e][]?.hooks[]?.command] | index($c) != null' "$TMP" >/dev/null; then
    echo "skip（登録済み）: $event $cmd"
    continue
  fi
  jq --arg e "$event" --arg c "$cmd" --arg s "$status" '
    .hooks[$e] = ((.hooks[$e] // []) + [{
      matcher: "",
      hooks: [({type: "command", command: $c, timeout: 5} + (if $s == "" then {} else {statusMessage: $s} end))]
    }])' "$TMP" > "$TMP.next" && mv "$TMP.next" "$TMP"
  echo "登録: $event $cmd"
done <<< "$HOOKS"

if $DRY_RUN; then
  echo "[dry-run] settings.json は変更しません"
  rm -f "$TMP"
else
  mv "$TMP" "$SETTINGS"
fi

echo
echo "完了。Claude Code を再起動すると hook と司書エージェントが有効になります。"
echo "Company Brain の MCP 接続が無い場合、hook は促すだけで何も壊しません。"
