#!/bin/bash
# 介入ログの週次集計。Harness Optimization Loop の「毎回同じところで人が手を出している」を見つける。
#
# 使い方:
#   summarize.sh            # 直近 14 日
#   summarize.sh 28         # 直近 28 日
#   summarize.sh 14 --json  # 機械可読（週次ハーネス改善ジョブ #7 が読む）
#
# 出力: 受入件数・介入件数・介入率、kind 別件数（多い順）、fix_layer 別件数、
#       「同じ kind が 3 回以上」の候補（= ハーネス変更候補）

set -uo pipefail
DAYS="${1:-14}"
MODE="${2:-}"
LOG_FILE="${HARNESS_LOG_DIR:-$HOME/.claude/harness-log}/interventions.jsonl"

[ -f "$LOG_FILE" ] || { echo "no log: $LOG_FILE"; exit 0; }

SINCE="$(date -v-"${DAYS}"d +%Y-%m-%dT00:00:00 2>/dev/null || date -d "-${DAYS} days" +%Y-%m-%dT00:00:00)"

# 不正行（JSON でない）は数えずに件数だけ報告する
VALID="$(jq -c 'select(type=="object")' "$LOG_FILE" 2>/dev/null)"
BAD=$(( $(wc -l < "$LOG_FILE") - $(printf '%s\n' "$VALID" | grep -c . ) ))

WINDOW="$(printf '%s\n' "$VALID" | jq -c --arg s "$SINCE" 'select(.ts >= $s)')"

if [ "$MODE" = "--json" ]; then
  printf '%s\n' "$WINDOW" | jq -s --arg since "$SINCE" --argjson bad "$BAD" '
    {since:$since, bad_lines:$bad,
     accepted: length,
     intervened: (map(select(.intervened==true)) | length),
     rate: (if length>0 then ((map(select(.intervened==true))|length) / length) else null end),
     by_kind: (map(select(.intervened==true)) | group_by(.kind) | map({kind:.[0].kind, n:length}) | sort_by(-.n)),
     by_fix_layer: (map(select(.intervened==true)) | group_by(.fix_layer) | map({fix_layer:.[0].fix_layer, n:length}) | sort_by(-.n)),
     by_worker: (group_by(.worker) | map({worker:.[0].worker, accepted:length, intervened:(map(select(.intervened==true))|length)})),
     candidates: (map(select(.intervened==true)) | group_by(.kind) | map(select(length>=3)) | map({kind:.[0].kind, n:length, fix_layers:(map(.fix_layer)|unique), notes:(map(.notes)|.[0:3])}))
    }'
  exit 0
fi

echo "介入ログ集計: 直近 ${DAYS} 日（${SINCE} 以降）  不正行: ${BAD}"
printf '%s\n' "$WINDOW" | jq -s -r '
  "受入 \(length) 件 / 介入 \(map(select(.intervened==true))|length) 件 / 介入率 \(if length>0 then (((map(select(.intervened==true))|length)*100/length)|floor) else 0 end)%",
  "",
  "kind 別（介入のみ）:",
  (map(select(.intervened==true)) | group_by(.kind) | map("  \(length)  \(.[0].kind)") | sort | reverse | .[]),
  "",
  "fix_layer 別（介入のみ）:",
  (map(select(.intervened==true)) | group_by(.fix_layer) | map("  \(length)  \(.[0].fix_layer)") | sort | reverse | .[]),
  "",
  "worker 別:",
  (group_by(.worker) | map("  \(.[0].worker): 受入 \(length) / 介入 \(map(select(.intervened==true))|length)") | .[]),
  "",
  "ハーネス変更候補（同じ kind が 3 回以上）:",
  ((map(select(.intervened==true)) | group_by(.kind) | map(select(length>=3)) | map("  \(.[0].kind) ×\(length)  → 防ぐ層の候補: \(map(.fix_layer)|unique|join(", "))") | if length==0 then ["  なし"] else . end) | .[])
'
