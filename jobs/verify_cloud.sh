#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/PulseoSystem"; LOG="$ROOT/logs"; SNAP="$ROOT/Snapshots"; CFG="$ROOT/config/env.cloud"
mkdir -p "$LOG" "$SNAP"
ts(){ date -Is; }; say(){ printf "%s %s\n" "$(ts)" "$1" | tee -a "$LOG/verify_cloud.log" >/dev/null; }

say "[start] verify_cloud"

if [ ! -f "$CFG" ]; then
  say "[skip] pas de env.cloud"
  exit 0
fi

. "$CFG"

verify_remote(){
  local remote="$1"
  local path="$2"
  [ -n "$remote" ] || return 0

  say "[check] $remote$path"
  TMP_LOCAL=$(mktemp)
  TMP_REMOTE=$(mktemp)
  trap "rm -f $TMP_LOCAL $TMP_REMOTE" EXIT

  # SHA256 local
  (cd "$SNAP" && sha256sum * 2>/dev/null | sort -k2) > "$TMP_LOCAL" || true

  # SHA256 distant (via rclone hashsum)
  rclone hashsum SHA256 "${remote}${path}" --fast-list 2>/dev/null | sort -k2 > "$TMP_REMOTE" || true

  # Compare
  DIFF=$(comm -3 "$TMP_LOCAL" "$TMP_REMOTE" || true)
  if [ -n "$DIFF" ]; then
    say "[warn] différences détectées pour $remote"
    echo "$DIFF" >> "$LOG/verify_cloud_diff.log"
  else
    say "[ok] $remote tous fichiers identiques"
  fi
}

verify_remote "${GDRIVE_REMOTE:-}" "${GDRIVE_PATH:-SpiraTech/ArchiveFinale}"
verify_remote "${ONEDRIVE_REMOTE:-}" "${ONEDRIVE_PATH:-SpiraTechMirror/ArchiveFinale}"

say "[done] verify_cloud"
