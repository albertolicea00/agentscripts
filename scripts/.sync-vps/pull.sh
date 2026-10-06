#!/usr/bin/env bash
# Pull scripts from VPS into local scripts/ via rsync over SSH
# Usage: ./pull.sh  (or: make pull-vps from scripts/ or repo root)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

ENV_FILE="$SCRIPT_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  set +a
fi

: "${VPS_HOST:?Set VPS_HOST in .sync-vps/.env}"
: "${VPS_USER:?Set VPS_USER in .sync-vps/.env}"
: "${VPS_PORT:=22}"
: "${VPS_SCRIPTS_PATH:?Set VPS_SCRIPTS_PATH in .sync-vps/.env}"
: "${SSH_KEY:=$HOME/.ssh/id_rsa}"

echo "[pull-vps] $VPS_USER@$VPS_HOST:$VPS_SCRIPTS_PATH → scripts/"

rsync -avz --progress \
  -e "ssh -p $VPS_PORT -i $SSH_KEY" \
  "$VPS_USER@$VPS_HOST:$VPS_SCRIPTS_PATH/" \
  "$ROOT_DIR/scripts/"

echo "Done."
