#!/usr/bin/env bash
# Connect to active Google Colab runtime via SSH and Cloudflare Tunnel
# Usage: ./connect.sh [hostname_or_url]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

# Load config if exists
if [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC1090
    source "$ENV_FILE"
fi

# Config defaults
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa}"
COLAB_USER="${COLAB_USER:-root}"
RAW_INPUT="${1:-${COLAB_HOST:-}}"

# 1. Check dependencies
command -v ssh >/dev/null 2>&1 || { echo "Error: ssh command required"; exit 1; }
command -v cloudflared >/dev/null 2>&1 || {
    echo "Error: cloudflared is required. Run 'make setup-colab' or 'brew install cloudflared'"
    exit 1
}

if [ ! -f "$SSH_KEY" ]; then
    echo "Error: SSH private key not found at $SSH_KEY"
    echo "Run './setup.sh' to initialize SSH keys."
    exit 1
fi

# 2. Prompt if no host provided
if [ -z "$RAW_INPUT" ]; then
    echo "Enter the Cloudflare Tunnel hostname or URL from Google Colab:"
    read -r -p "Hostname / URL: " RAW_INPUT
fi

if [ -z "$RAW_INPUT" ]; then
    echo "Error: Hostname cannot be empty."
    exit 1
fi

# 3. Clean up input (strip protocol, slashes, port)
HOST="$(echo "$RAW_INPUT" | sed -E 's|^[a-zA-Z0-9+.-]+://||' | sed -E 's|/.*$||' | sed -E 's|:[0-9]+$||' | tr -d '[:space:]')"

echo "Connecting to Google Colab instance at: ${HOST} (user: ${COLAB_USER})..."
echo "To exit SSH session, type 'exit' or press Ctrl+D."
echo ""

# 4. Connect via SSH over Cloudflare Tunnel
exec ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ProxyCommand="cloudflared access ssh --hostname %h" \
    -i "$SSH_KEY" \
    "${COLAB_USER}@${HOST}"
