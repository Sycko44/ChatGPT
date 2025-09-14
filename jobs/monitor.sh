#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/PulseoSystem"; LOG="$ROOT/logs"; CFG="$ROOT/config/env.monitor"
mkdir -p "$LOG"
ts(){ date -Is; }; say(){ printf "%s %s\n" "$(ts)" "$1" | tee -a "$LOG/monitor.log" >/dev/null; }
say "[start] monitor"

WEBHOOK=""
if [ -f "$CFG" ]; then
  . "$CFG"
  WEBHOOK="${MONITOR_WEBHOOK_URL:-}"
fi

# Agrège les erreurs récentes
TMP=$(mktemp); trap "rm -f $TMP" EXIT
grep -E "\[warn\]|\[fail\]" -h "$LOG"/*.log 2>/dev/null | tail -n 100 > "$TMP" || true

if [ -s "$TMP" ]; then
  say "[alert] anomalies détectées"
  if [ -n "$WEBHOOK" ]; then
    # Discord/Slack-compatible (content / text)
    PAYLOAD=$(jq -Rs . < "$TMP" 2>/dev/null || python - <<PY
import sys, json
print(json.dumps(sys.stdin.read()))
PY
)
    curl -m 10 -sS -X POST -H "Content-Type: application/json" \
      -d "{\"content\": \"PulseoSystem alert:\\n\" , \"embeds\": [{\"description\": $PAYLOAD}]}" \
      "$WEBHOOK" >/dev/null 2>&1 || true
  fi
else
  say "[ok] pas d anomalies"
fi
say "[done] monitor"
