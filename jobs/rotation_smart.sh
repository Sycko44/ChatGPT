#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/PulseoSystem"; LOG="$ROOT/logs"; SNAP="$ROOT/Snapshots"
mkdir -p "$LOG" "$SNAP"
ts(){ date -Is; }; say(){ printf "%s %s\n" "$(ts)" "$1" | tee -a "$LOG/rotation_smart.log" >/dev/null; }
say "[start] rotation_smart keep: 7 daily, 4 weekly, 12 monthly"

# Collecte des fichiers snap_YYYYMMDD_HHMMSS.*
mapfile -t FILES < <(ls -1t "$SNAP"/snap_* 2>/dev/null || true)
[ ${#FILES[@]} -gt 0 ] || { say "[info] aucun snapshot"; exit 0; }

KEEP_SET="$(mktemp)"; trap "rm -f $KEEP_SET" EXIT

# 7 derniers quotidiens (par date)
DAILY_DATES=()
for f in "${FILES[@]}"; do
  b=$(basename "$f"); d=${b#snap_}; d=${d%%_*}         # YYYYMMDD
  [[ " ${DAILY_DATES[*]} " =~ " $d " ]] || DAILY_DATES+=("$d")
  [ ${#DAILY_DATES[@]} -ge 7 ] && break
done
for d in "${DAILY_DATES[@]}"; do
  # le plus récent de ce jour
  for f in "${FILES[@]}"; do
    [[ $(basename "$f") == snap_${d}_* ]] && { echo "$(basename "$f")" >> "$KEEP_SET"; break; }
  done
done

# 4 hebdos: on prend le plus récent de chaque semaine (ISO week)
WSEEN=()
for f in "${FILES[@]}"; do
  b=$(basename "$f"); d=${b#snap_}; d=${d%%_*}
  # YYYY-MM-DD depuis YYYYMMDD
  Y=${d:0:4}; M=${d:4:2}; D=${d:6:2}
  week=$(date -d "$Y-$M-$D" +%G-%V 2>/dev/null || date -j -f "%Y-%m-%d" "$Y-$M-$D" "+%G-%V" 2>/dev/null || echo "$Y$M$D")
  if [[ ! " ${WSEEN[*]} " =~ " $week " ]]; then
    echo "$b" >> "$KEEP_SET"
    WSEEN+=("$week")
  fi
  [ ${#WSEEN[@]} -ge 4 ] && break
done

# 12 mensuels: le plus récent de chaque mois
MSEEN=()
for f in "${FILES[@]}"; do
  b=$(basename "$f"); d=${b#snap_}; d=${d%%_*}  # YYYYMMDD
  month=${d:0:6}
  if [[ ! " ${MSEEN[*]} " =~ " $month " ]]; then
    echo "$b" >> "$KEEP_SET"
    MSEEN+=("$month")
  fi
  [ ${#MSEEN[@]} -ge 12 ] && break
done

# Supprime tout ce qui n est pas dans KEEP_SET
for f in "${FILES[@]}"; do
  base=$(basename "$f")
  if ! grep -qx "$base" "$KEEP_SET"; then
    say "[rm] $base"
    rm -f -- "$f" || true
  fi
done
say "[done] rotation_smart"
