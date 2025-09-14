#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/PulseoSystem"; LOG="$ROOT/logs"; JOBS="$ROOT/jobs"
mkdir -p "$LOG"
ts(){ date -Is; }
say(){ printf "%s %s\n" "$(ts)" "$1" | tee -a "$LOG/orchestrator.log" >/dev/null; }

run_with_retry(){
  local job="$1"; local max="${2:-3}"
  local cnt=0
  if [ ! -x "$JOBS/$job" ]; then
    say "[skip] $job absent"
    return 0
  fi
  while :; do
    cnt=$((cnt+1))
    say "[run] $job (try $cnt/$max)"
    if bash "$JOBS/$job" >> "$LOG/job_${job%.*}_$(date +%Y%m%d_%H%M%S).log" 2>&1; then
      say "[ok]  $job"
      return 0
    fi
    say "[warn] $job failed (try $cnt)"
    [ "$cnt" -lt "$max" ] || { say "[fail] $job after $max tries"; return 1; }
    sleep $((cnt*5))
  done
}

# Ordre AutoGPT: clean -> snapshot -> dedup -> sync -> verify
ORDER=( "clean_auto.sh" "snapshot_auto.sh" "dedup_auto.sh" "sync_cloud.sh" "verify_cloud.sh" )
say "[start] orchestrator"
for j in "${ORDER[@]}"; do run_with_retry "$j" 3 || true; done
say "[done] orchestrator"
