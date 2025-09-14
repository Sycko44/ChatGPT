#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/PulseoSystem"; LOG="$ROOT/logs"; SNAP="$ROOT/Snapshots"; BUILDS="$ROOT/Builds"; CFG="$ROOT/config"
mkdir -p "$LOG" "$SNAP" "$BUILDS"
ts(){ date -Is; }; say(){ printf "%s %s\n" "$(ts)" "$1" | tee -a "$LOG/snapshot_auto.log" >/dev/null; }
for p in rsync tar xz-utils coreutils openssh; do command -v ${p%% *} >/dev/null 2>&1 || (yes | pkg install -y "$p" >/dev/null 2>&1 || true); done
OVH="$CFG/env.ovh"; if [ -f "$OVH" ]; then . "$OVH"; else OVH_HOST=""; OVH_USER=""; OVH_PATH=""; fi
[ -z "$(ls -A "$BUILDS" 2>/dev/null)" ] && { echo "hello $(date -Is)" > "$BUILDS/test_snapshot.txt"; }
SN="$(date +%Y%m%d_%H%M%S)"; OUT="$SNAP/snap_${SN}.tar.xz"
tar -C "$ROOT" -c "Builds" | xz -z -T0 - > "$OUT"; say "[ok] local $(basename "$OUT")"
if [ -n "${OVH_HOST:-}" ] && [ -n "${OVH_USER:-}" ]; then
  ssh -o StrictHostKeyChecking=accept-new "${OVH_USER}@${OVH_HOST}" "sudo mkdir -p ${OVH_PATH:-/srv/archive} && sudo chown ${OVH_USER}:${OVH_USER} ${OVH_PATH:-/srv/archive}" || true
  rsync -az --partial "$SNAP/" "${OVH_USER}@${OVH_HOST}:${OVH_PATH:-/srv/archive}/" && say "[done] push OVH ok" || { sleep 3; rsync -az --partial "$SNAP/" "${OVH_USER}@${OVH_HOST}:${OVH_PATH:-/srv/archive}/" || say "[warn] push OVH KO"; }
else
  say "[skip] OVH non configuré"
fi
