#!/usr/bin/env bash
set -e

# -------- sécurité / compat Termux --------
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
if ! printf "%s" "$PREFIX" | grep -q "com.termux"; then
  echo "[WARN] Ce script est pensé pour Termux. PREFIX=$PREFIX"
fi

# -------- variables --------
REPO_URL="${REPO_URL:-https://github.com/Sycko44/ChatGPT.git}"
ROOT="$HOME/PulseoSystem"
BIN="$ROOT/bin"; CFG="$ROOT/config"; LOG="$ROOT/logs"; ST="$ROOT/status"; JOBS="$ROOT/jobs"; REPO="$ROOT/repo"

mkdir -p "$BIN" "$CFG" "$LOG" "$ST" "$JOBS" "$REPO"

# -------- dépendances --------
yes | pkg update -y >/dev/null 2>&1 || true
for p in coreutils findutils git rsync jq openssh xz-utils; do
  command -v ${p%% *} >/dev/null 2>&1 || yes | pkg install -y "$p" >/dev/null 2>&1 || true
done

# -------- agent.env --------
AG="$CFG/agent.env"
if [ ! -f "$AG" ]; then
  cat > "$AG" <<EOF
REMOTE_KIND=git
GIT_URL=$REPO_URL
GIT_BRANCH=main
INTERVAL_SEC=90
APPROVAL=auto
SAFE_ROOT=$ROOT
EOF
fi
[ -f "$CFG/github.env" ] || printf "GITHUB_USER=\nGITHUB_TOKEN=\n" > "$CFG/github.env"

# -------- agent netd.sh --------
if [ ! -x "$BIN/netd.sh" ]; then
  cat > "$BIN/netd.sh" <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$HOME/PulseoSystem"; CFG="$ROOT/config"; LOG="$ROOT/logs"; ST="$ROOT/status"; JOBS="$ROOT/jobs"; REPO="$ROOT/repo"
AG="$CFG/agent.env"; GH="$CFG/github.env"
mkdir -p "$LOG" "$ST" "$JOBS" "$REPO"
[ -f "$AG" ] && . "$AG"; [ -f "$GH" ] && . "$GH"
ts(){ date -Is; }
log(){ printf "%s %s\n" "$(ts)" "$1" | tee -a "$LOG/netd.log" >/dev/null; }
need(){ command -v "$1" >/dev/null 2>&1 || { yes | pkg install -y "$1" >/dev/null 2>&1 || true; }; }

pull_git(){
  need git rsync
  [ -z "${GIT_URL:-}" ] && { log "[info] GIT_URL vide"; return 0; }
  url="$GIT_URL"
  if [ -n "${GITHUB_USER:-}" ] && [ -n "${GITHUB_TOKEN:-}" ] && printf "%s" "$url" | grep -q "^https://"; then
    url="https://${GITHUB_USER}:${GITHUB_TOKEN}@${url#https://}"
  fi
  if [ ! -d "$REPO/.git" ]; then
    rm -rf "$REPO"
    git clone --depth 1 "$url" "$REPO" >> "$LOG/netd_git.log" 2>&1 || { log "[err] clone"; return 1; }
  else
    ( cd "$REPO" \
      && git fetch --all -p >> "$LOG/netd_git.log" 2>&1 \
      && git checkout "${GIT_BRANCH:-main}" >> "$LOG/netd_git.log" 2>&1 \
      && git pull --ff-only >> "$LOG/netd_git.log" 2>&1 ) || { log "[warn] pull KO"; return 1; }
  fi
  rsync -a --delete "$REPO/jobs/" "$JOBS/" >> "$LOG/netd_git.log" 2>&1 || true
}

discover(){ find "$JOBS" -type f \( -name "*.sh" -o -name "*.bash" \) 2>/dev/null; }
approve(){ [ "${APPROVAL:-manual}" = "auto" ] || [ -f "$ST/APPROVE" ]; }
run_job(){ j="$1"; chmod +x "$j" 2>/dev/null || true; log "[run] ${j#$ROOT/}"; bash "$j" >> "$LOG/job_$(basename "${j%.*}")_$(date +%Y%m%d_%H%M%S).log" 2>&1 || log "[warn] job failed"; }

cycle(){
  need coreutils; need findutils
  [ "${REMOTE_KIND:-git}" = "git" ] && pull_git || true
  if approve; then
    for j in $(discover); do run_job "$j"; done
    rm -f "$ST/APPROVE" 2>/dev/null || true
  else
    log "[hold] attente approbation (touch $ST/APPROVE)"
  fi
  log "[done] cycle"
}

case "${1:-loop}" in
  once) cycle ;;
  loop) while true; do cycle; sleep "${INTERVAL_SEC:-90}"; done ;;
  start) nohup "$0" loop >/dev/null 2>&1 & echo $! > "$ST/netd.pid"; log "[start] netd" ;;
  stop) pkill -f "PulseoSystem/bin/netd.sh loop" 2>/dev/null || true; rm -f "$ST/netd.pid"; log "[stop] netd" ;;
  status) pgrep -f "PulseoSystem/bin/netd.sh loop" >/dev/null && echo "netd: running" || echo "netd: stopped" ;;
esac
BASH
  chmod +x "$BIN/netd.sh"
fi

# -------- job de test si aucun présent --------
if [ -z "$(find "$JOBS" -maxdepth 1 -type f -name '*.sh' 2>/dev/null)" ]; then
  printf "%s\n" '#!/usr/bin/env bash' 'set -e' 'echo "[hello] $(date -Is) OK"' > "$JOBS/hello.sh"
  chmod +x "$JOBS/hello.sh"
fi

# -------- run + start --------
touch "$ST/APPROVE"
"$BIN/netd.sh" once
pgrep -f "PulseoSystem/bin/netd.sh loop" >/dev/null 2>&1 || "$BIN/netd.sh" start || true

echo "✅ Install OK.\nJobs:   $JOBS\nLogs:   $LOG/netd.log\nConfig: $CFG/agent.env\nAstuce: tail -n 80 $LOG/netd.log"