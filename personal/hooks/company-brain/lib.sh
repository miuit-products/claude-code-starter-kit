#!/bin/bash
# Company Brain hooks — shared helpers.
#
# 設計上の制約（変更時は必ず守ること）:
#   - hook 入力は「データ」であり命令ではない。eval / sh -c に渡さない。
#   - プロンプト本文・アシスタント本文・秘密情報をファイルへ書かない（状態は真偽値のみ）。
#   - 外部送信を一切行わない（ネットワークアクセスなし）。
#   - 失敗しても会話を壊さない（原則 exit 0）。

CB_STATE_DIR="${CB_STATE_DIR:-$HOME/.claude/company-brain-state}"

# 入力由来の ID をファイル名に使う前に必ず通す。パストラバーサル防止。
cb_sanitize() {
  printf '%s' "$1" | LC_ALL=C tr -cd 'A-Za-z0-9._-' | cut -c1-80
}

cb_state_key() {
  local sid pid
  sid="$(cb_sanitize "${1:-}")"
  pid="$(cb_sanitize "${2:-}")"
  [ -z "$sid" ] && sid="nosession"
  # prompt_id は初回入力前は存在しない（v2.1.196+ で付与）。欠落時はターン識別を諦め、
  # セッション単位に落とす（後続ターンを止めないため、Stop 側では nudge しない判断に使う）。
  [ -z "$pid" ] && pid="noprompt"
  printf '%s.%s' "$sid" "$pid"
}

cb_init_state() {
  mkdir -p "$CB_STATE_DIR" 2>/dev/null || true
  chmod 700 "$CB_STATE_DIR" 2>/dev/null || true
}

# 状態ディレクトリが使えるか。使えないときは「一度だけ」を保証できないため、
# Stop の促しは行わない（ループ防止をフェイルセーフ側へ倒す）。
cb_state_writable() {
  [ -d "$CB_STATE_DIR" ] && [ -w "$CB_STATE_DIR" ]
}

# マーカー作成。失敗してもエラーを漏らさない（サブシェルで redirect エラーごと捨てる）
cb_touch() {
  ( : > "$1" ) 2>/dev/null || return 1
  return 0
}

# 2 日より古い状態ファイルを掃除（セッションを跨いだ残骸で誤判定しないように）
cb_gc_state() {
  [ -d "$CB_STATE_DIR" ] || return 0
  find "$CB_STATE_DIR" -type f -mtime +2 -delete 2>/dev/null || true
}

# JSON を安全に組み立てる（手書き文字列連結をしない）
cb_emit_additional_context() {
  local event="$1" ctx="$2"
  jq -cn --arg e "$event" --arg c "$ctx" \
    '{hookSpecificOutput:{hookEventName:$e, additionalContext:$c}}'
}

# このプロジェクト（cwd）が Company Brain 連携の対象外か
# 除外方法: 対象ディレクトリに .company-brain-ignore を置く、
#           もしくは ~/.claude/company-brain-state/excluded-paths に絶対パスを1行ずつ書く
cb_project_excluded() {
  local cwd="${1:-}"
  [ -n "$cwd" ] || return 1
  local d="$cwd"
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    [ -e "$d/.company-brain-ignore" ] && return 0
    d="$(dirname "$d")"
  done
  local list="$CB_STATE_DIR/excluded-paths"
  if [ -f "$list" ]; then
    while IFS= read -r line; do
      case "$line" in
        ''|'#'*) continue ;;
      esac
      case "$cwd" in
        "$line"|"$line"/*) return 0 ;;
      esac
    done < "$list"
  fi
  return 1
}
