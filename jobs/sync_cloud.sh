#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/PulseoSystem"; LOG="$ROOT/logs"; SNAP="$ROOT/Snapshots"; CFG="$ROOT/config/env.cloud"
mkdir -p "$LOG" "$SNAP"
ts(){ date -Is; }; say(){ printf "%s %s\n" "$(ts)" "$1" | tee -a "$LOG/sync_cloud.log" >/dev/null; }
say "[start] sync_cloud"
if [ -f "$CFG" ]; then
  . "$CFG"
  [ -n "${GDRIVE_REMOTE:-}" ] && rclone sync "$SNAP" "${GDRIVE_REMOTE}${GDRIVE_PATH:-SpiraTech/ArchiveFinale}" --create-empty-src-dirs --transfers=4 --checkers=8 --fast-list && say "[done] gdrive ok" || say "[skip] gdrive"
  [ -n "${ONEDRIVE_REMOTE:-}" ] && rclone sync "$SNAP" "${ONEDRIVE_REMOTE}${ONEDRIVE_PATH:-SpiraTechMirror/ArchiveFinale}" --create-empty-src-dirs --transfers=4 --checkers=8 --fast-list && say "[done] onedrive ok" || say "[skip] onedrive"
else
  say "[skip] env.cloud absent"
fi
say "[done] sync_cloud"
