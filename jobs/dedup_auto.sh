#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/PulseoSystem"; LOG="$ROOT/logs"; SNAP="$ROOT/Snapshots"
mkdir -p "$LOG" "$SNAP"
ts(){ date -Is; }; say(){ printf "%s %s\n" "$(ts)" "$1" | tee -a "$LOG/dedup_auto.log" >/dev/null; }

KEEP="${SNAP_KEEP:-5}"   # garde 5 snapshots récents par défaut
say "[start] dedup_auto keep=$KEEP"

# 1) Supprimer les doublons exacts (même SHA256) sans options GNU spécifiques
#    On parcourt tous les fichiers et on supprime ceux dont le hash a déjà été vu.
SEEN="$SNAP/.seen_hashes"
: > "$SEEN"
for f in "$SNAP"/*; do
  [ -f "$f" ] || continue
  H=$(sha256sum "$f" | awk "{print \$1}")
  if grep -q "^$H\$" "$SEEN"; then
    say "[rm] duplicate $(basename "$f")"
    rm -f -- "$f" || true
  else
    echo "$H" >> "$SEEN"
  fi
done
rm -f "$SEEN" 2>/dev/null || true

# 2) Garder uniquement les N fichiers les plus récents
#    On trie par date, on supprime au-delà de KEEP.
RECENTS=$(ls -1t "$SNAP" 2>/dev/null | head -n "$KEEP")
for f in "$SNAP"/*; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  echo "$RECENTS" | grep -qx "$base" || { say "[rm] old $base"; rm -f -- "$f" || true; }
done

say "[done] dedup_auto"
