#!/usr/bin/env bash
# Opt-in rclone Google Drive setup/teardown for Colab SSH (disabled by default; requires explicit user permission)
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: colab-rclone.sh [options]

Optional helper to configure or disable rclone Google Drive access on an active
Colab SSH runtime without repeating browser OAuth on every new VM.

Security & Opt-In Policy:
  - DISABLED by default.
  - Requires explicit user permission (--enable or ENABLE_COLAB_RCLONE=1) AND
    interactive confirmation before copying ~/.config/rclone/rclone.conf to Colab.
  - Can be disabled at any time with --disable (removes remote config & unmount).

Options:
  --enable              Enable rclone on the Colab runtime (requires confirmation)
  --disable             Disable rclone on the Colab runtime (removes remote rclone.conf & unmounts)
  --mount               Also mount <remote>: at /content/drive via rclone mount (with --enable)
  --status              Check whether rclone and rclone.conf are present on Colab
  -s, --session <host>  SSH host alias or target (default: colab)
  -r, --remote <name>   rclone remote name to mount (default: gdrive)
  -c, --config <path>   Local rclone.conf path (default: auto-detected via `rclone config file`)
  -h, --help            Show this help message
EOF
}

ACTION=""
DO_MOUNT="0"
SSH_HOST="${COLAB_SSH_HOST:-colab}"
REMOTE_NAME="${RCLONE_REMOTE:-gdrive}"
LOCAL_CONF=""
OPT_IN="${ENABLE_COLAB_RCLONE:-0}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --enable) ACTION="enable"; OPT_IN="1"; shift ;;
    --disable) ACTION="disable"; shift ;;
    --mount) DO_MOUNT="1"; shift ;;
    --status) ACTION="status"; shift ;;
    -s|--session) SSH_HOST="$2"; shift 2 ;;
    -r|--remote) REMOTE_NAME="$2"; shift 2 ;;
    -c|--config) LOCAL_CONF="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

for dep in ssh scp; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    echo "Error: '$dep' is required but not found in PATH." >&2
    exit 1
  fi
done

if [[ -z "$ACTION" ]]; then
  if [[ "$OPT_IN" == "1" ]]; then
    ACTION="enable"
  else
    echo "rclone Colab integration is disabled by default."
    echo "Pass --enable (or set ENABLE_COLAB_RCLONE=1) to opt in, or --disable to remove it from Colab."
    usage
    exit 0
  fi
fi

SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=15 -o ServerAliveInterval=30 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)

if [[ "$ACTION" == "status" ]]; then
  ssh "${SSH_OPTS[@]}" "$SSH_HOST" '
    echo "rclone binary: $(command -v rclone || echo "not installed")"
    if [ -f /root/.config/rclone/rclone.conf ]; then
      echo "rclone.conf:   PRESENT (/root/.config/rclone/rclone.conf)"
    else
      echo "rclone.conf:   absent (disabled)"
    fi
    if mountpoint -q /content/drive 2>/dev/null; then
      echo "mountpoint:    /content/drive is mounted"
    else
      echo "mountpoint:    /content/drive is not mounted"
    fi
  '
  exit 0
fi

if [[ "$ACTION" == "disable" ]]; then
  echo "Disabling rclone on Colab host '$SSH_HOST'..."
  ssh "${SSH_OPTS[@]}" "$SSH_HOST" '
    fusermount -u /content/drive 2>/dev/null || umount /content/drive 2>/dev/null || true
    rm -f /root/.config/rclone/rclone.conf
    echo "Removed /root/.config/rclone/rclone.conf and unmounted /content/drive (if mounted)."
  '
  exit 0
fi

# ACTION == "enable"
if [[ "$OPT_IN" != "1" ]]; then
  echo "Error: rclone Colab integration is disabled (ENABLE_COLAB_RCLONE=$OPT_IN)." >&2
  exit 1
fi

if ! command -v rclone >/dev/null 2>&1; then
  echo "Error: 'rclone' is not installed locally. Install it and run 'rclone config' first." >&2
  exit 1
fi

if [[ -z "$LOCAL_CONF" ]]; then
  LOCAL_CONF="$(rclone config file 2>/dev/null | tail -n 1 | tr -d '\r')"
fi

if [[ -z "$LOCAL_CONF" || ! -f "$LOCAL_CONF" ]]; then
  echo "Error: Local rclone config not found at '${LOCAL_CONF:-<unknown>}'." >&2
  echo "Run 'rclone config' locally to create a Google Drive remote first." >&2
  exit 1
fi

echo "WARNING: This will copy your local rclone config ($LOCAL_CONF), which contains"
echo "         an OAuth refresh token for your Google Drive, onto the ephemeral Colab VM ('$SSH_HOST')."
echo "         You can revoke/remove it from the VM at any time with: $0 --disable -s $SSH_HOST"
echo ""
read -r -p "Exclusive user permission required. Type 'YES' to continue: " CONFIRM
if [[ "$CONFIRM" != "YES" ]]; then
  echo "Aborted. No credentials were copied."
  exit 1
fi

echo "Installing rclone on Colab (if missing) and preparing config directory..."
ssh "${SSH_OPTS[@]}" "$SSH_HOST" '
  if ! command -v rclone >/dev/null 2>&1; then
    curl -fsSL https://rclone.org/install.sh | bash
  fi
  mkdir -p /root/.config/rclone
  chmod 700 /root/.config/rclone
'

scp -q "${SSH_OPTS[@]}" "$LOCAL_CONF" "${SSH_HOST}:/root/.config/rclone/rclone.conf"
ssh "${SSH_OPTS[@]}" "$SSH_HOST" 'chmod 600 /root/.config/rclone/rclone.conf'
echo "rclone.conf copied to ${SSH_HOST}:/root/.config/rclone/rclone.conf."

if [[ "$DO_MOUNT" == "1" ]]; then
  echo "Mounting '${REMOTE_NAME}:' at /content/drive on '$SSH_HOST'..."
  ssh "${SSH_OPTS[@]}" "$SSH_HOST" "
    mkdir -p /content/drive
    nohup rclone mount '${REMOTE_NAME}:' /content/drive --vfs-cache-mode writes --daemon >/tmp/rclone-mount.log 2>&1 || true
    sleep 2
    if mountpoint -q /content/drive 2>/dev/null; then
      echo 'Mounted ${REMOTE_NAME}: at /content/drive (Note: Colab native UI uses /content/drive/MyDrive; rclone mounts root directly at /content/drive).'
    else
      echo 'Mount did not become active; check /tmp/rclone-mount.log on Colab. You can still use rclone copy/move directly.'
    fi
  "
fi

echo "Done. Example: ssh $SSH_HOST \"rclone lsd ${REMOTE_NAME}:\""
