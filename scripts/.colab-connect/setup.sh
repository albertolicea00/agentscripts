#!/usr/bin/env bash
# Setup local environment and SSH keys for Google Colab connection
# Usage: ./setup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
EXAMPLE_FILE="${SCRIPT_DIR}/.env.example"
SSH_DIR="${HOME}/.ssh"
DEFAULT_KEY="${SSH_DIR}/id_rsa"
PUB_KEY="${DEFAULT_KEY}.pub"

echo "=== Colab Connect Setup ==="

# 1. Check or install cloudflared
if ! command -v cloudflared >/dev/null 2>&1; then
    echo "cloudflared is not installed."
    if command -v brew >/dev/null 2>&1; then
        echo "Installing cloudflared via Homebrew..."
        brew install cloudflared
    else
        echo "Error: Homebrew not found. Please install cloudflared manually: https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/"
        exit 1
    fi
else
    echo "✓ cloudflared is installed: $(which cloudflared)"
fi

# 2. Check SSH key pair
if [ ! -f "$PUB_KEY" ]; then
    echo "No SSH key found at $PUB_KEY"
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    echo "Generating new Ed25519/RSA SSH key pair..."
    ssh-keygen -t rsa -b 4096 -f "$DEFAULT_KEY" -N "" -C "colab-connect@local"
    echo "✓ Generated new SSH key at $DEFAULT_KEY"
else
    echo "✓ SSH public key found at: $PUB_KEY"
fi

# Copy public key to clipboard if on macOS
if command -v pbcopy >/dev/null 2>&1; then
    pbcopy < "$PUB_KEY"
    echo "📋 Public key has been copied to your macOS clipboard!"
fi

echo ""
echo "--- YOUR PUBLIC SSH KEY (Paste into Colab notebook widget) ---"
cat "$PUB_KEY"
echo "-------------------------------------------------------------"
echo ""

# 3. Create .env from template
if [ -f "$ENV_FILE" ]; then
    echo "✓ .env already exists at $ENV_FILE"
else
    cp "$EXAMPLE_FILE" "$ENV_FILE"
    echo "✓ Created $ENV_FILE from template."
fi

# Make companion scripts executable
chmod +x "${SCRIPT_DIR}/connect.sh" 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/run.sh" 2>/dev/null || true

echo "Setup complete! Now open the Colab notebook, paste your public key, and run it."
