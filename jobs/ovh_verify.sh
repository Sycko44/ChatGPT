#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/PulseoSystem"; LOG="$ROOT/logs"; SNAP="$ROOT/Snapshots"; CFG="$ROOT/config/env.ovh"
mkdir -p "$LOG" "$SNAP"
ts(){ date -Is; }; say(){ printf "%s %s\n" "$(ts)" "$1" | tee -a "$LOG/ovh_verify.log" >/dev/null; }
say "[start] ovh_verify"
[ -f "$CFG" ] || { say "[skip] pas de env.ovh"; exit 0; }
. "$CFG"
[ -n "${OVH_HOST:-}" ] && [ -n "${OVH_USER:-}" ] || { say "[skip] ovh mal configuré"; exit 0; }

# Local hash list
TMP_L=$(mktemp); trap "rm -f $TMP_L $TMP_R" EXIT
(cd "$SNAP" && sha256sum * 2>/dev/null | sort -k2) > "$TMP_L" || true

# Distant hash list (essaie sha256sum, sinon openssl)
HASH_CMD="(command -v sha256sum >/dev/null && sha256sum) || (command -v openssl >/dev/null && xargs -I{} sh -c 'openssl dgst -sha256 "{}" | awk '\{print \$2\"  \"\$3}'\ )"
TMP_R=$(mktemp)
ssh -o StrictHostKeyChecking=accept-new "${OVH_USER}@${OVH_HOST}" "cd ${OVH_PATH:-/srv/archive} && ls -1 * 2>/dev/null | $HASH_CMD | sort -k2" > "$TMP_R" 2>/dev/null || true

DIFF=$(comm -3 "$TMP_L" "$TMP_R" || true)
if [ -n "$DIFF" ]; then
  say "[warn] différences détectées (voir ovh_verify_diff.log)"
  printf "%s\n" "$DIFF" >> "$LOG/ovh_verify_diff.log"
else
  say "[ok] OVH vs local identiques"
fi
say "[done] ovh_verify"
