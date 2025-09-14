#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/PulseoSystem"; LOG="$ROOT/logs"
mkdir -p "$LOG"
ts(){ date -Is; }; say(){ printf "%s %s\n" "$(ts)" "$1" | tee -a "$LOG/clean_auto.log" >/dev/null; }
for p in findutils coreutils; do command -v ${p%% *} >/dev/null 2>&1 || (yes | pkg install -y "$p" >/dev/null 2>&1 || true); done
say "[start] clean_auto"
find "$LOG" -type f -mtime +14 -delete 2>/dev/null || true
find "$HOME" -type d -name "__pycache__" -prune -exec rm -rf {} + 2>/dev/null || true
pkg autoclean >/dev/null 2>&1 || true; pkg clean >/dev/null 2>&1 || true
say "[done] clean_auto"
