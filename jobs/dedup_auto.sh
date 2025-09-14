#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/PulseoSystem"; LOG="$ROOT/logs"; SNAP="$ROOT/Snapshots"
mkdir -p "$LOG" "$SNAP"
ts(){ date -Is; }; say(){ printf "%s %s\n" "$(ts)" "$1" | tee -a "$LOG/dedup_auto.log" >/dev/null; }
say "[start] dedup_auto"
# Supprimer doublons exacts
find "$SNAP" -type f -name "*.tar.*" -exec sha256sum {} + | sort | uniq -w64 -dD | awk "{print \$2}" | xargs -r rm -f
# Garder seulement les 5 plus récents
ls -1t "$SNAP"/snap_* 2>/dev/null | tail -n +6 | xargs -r rm -f
say "[done] dedup_auto"
