#!/usr/bin/env bash
# Execute a command remotely on Google Colab via SSH
# Usage: ./run.sh "nvidia-smi" or ./run.sh <hostname> "nvidia-smi"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

# Load config if exists
if [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
fi

SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa}"
COLAB_USER="${COLAB_USER:-root}"
COLAB_HOST="${COLAB_HOST:-}"

# Check dependencies
command -v ssh >/dev/null 2>&1 || { echo "Error: ssh command required"; exit 1; }
command -v cloudflared >/dev/null 2>&1 || {
    echo "Error: cloudflared is required. Run 'make setup-colab' or 'brew install cloudflared'"
    exit 1
}

# Determine host and remote command
if [ "$#" -eq 0 ]; then
    echo "Usage: $0 [hostname] <remote_command>"
    echo "Example: $0 'nvidia-smi'"
    echo "Example: $0 funny-host.trycloudflare.com 'python3 -c \"import torch; print(torch.cuda.is_available())\"'"
    exit 1
fi

TARGET_HOST=""
REMOTE_CMD=""

if [[ "$1" == *".trycloudflare.com"* ]] || [[ "$1" == *"cloudflare"* ]]; then
    TARGET_HOST="$1"
    shift
    REMOTE_CMD="$*"
else
    TARGET_HOST="$COLAB_HOST"
    REMOTE_CMD="$*"
fi

if [ -z "$TARGET_HOST" ]; then
    echo "Error: No Colab host specified. Set COLAB_HOST in .env or pass as first argument."
    exit 1
fi

# Clean host
HOST="$(echo "$TARGET_HOST" | sed -E 's|^[a-zA-Z0-9+.-]+://||' | sed -E 's|/.*$||' | sed -E 's|:[0-9]+$||' | tr -d '[:space:]')"

ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ProxyCommand="cloudflared access ssh --hostname %h" \
    -i "$SSH_KEY" \
    "${COLAB_USER}@${HOST}" \
    "$REMOTE_CMD"
