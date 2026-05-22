#!/bin/bash
# =============================================================================
# OpenClaw Setup Codex Auth Script
# =============================================================================
# Purpose: Authenticate OpenAI Codex (ChatGPT Plus) via OAuth
# Usage: ./scripts/setup-codex-auth.sh [VPS_IP]
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

VPS_USER="openclaw"
SSH_OPTS="-o StrictHostKeyChecking=accept-new"
[[ -n "${SSH_KEY:-}" ]] && SSH_OPTS+=" -i $SSH_KEY"
TERRAFORM_DIR="infra/terraform/envs/prod"

# -----------------------------------------------------------------------------
# Source environment variables if files exist
# -----------------------------------------------------------------------------
if [ -f "config/inputs.sh" ]; then
    source "config/inputs.sh"
fi

if [ -f "secrets/openclaw.env" ]; then
    # Automatically export variables from .env file
    set -a
    source "secrets/openclaw.env"
    set +a
fi

# -----------------------------------------------------------------------------
# Get VPS IP
# -----------------------------------------------------------------------------

if [[ -n "${1:-}" ]]; then
    VPS_IP="$1"
elif [[ -n "${SERVER_IP:-}" ]]; then
    VPS_IP="$SERVER_IP"
else
    if command -v terraform &> /dev/null && [[ -d "$TERRAFORM_DIR/.terraform" ]]; then
        VPS_IP=$(cd "$TERRAFORM_DIR" && terraform output -raw server_ip 2>/dev/null) || {
            echo "Error: Could not get VPS IP from terraform output."
            echo "Usage: $0 <VPS_IP>"
            exit 1
        }
    else
        echo "Error: No VPS IP provided and terraform not available."
        echo "Usage: $0 <VPS_IP>"
        exit 1
    fi
fi

echo "=== OpenClaw Setup Codex Auth ==="
echo "VPS IP: $VPS_IP"
echo ""

# -----------------------------------------------------------------------------
# Trigger OAuth Flow
# -----------------------------------------------------------------------------

echo "[...] Triggering interactive OAuth flow..."
echo "You will be given a URL to open in your browser."
echo "Please follow the instructions on screen."
echo ""
echo "NOTE: If the browser redirects to http://localhost/?state=..., you will need to"
echo "manually 'curl' that URL on the VPS just like you did for GOG."
echo ""

# We use -t to force pseudo-terminal allocation for interactive auth
ssh -t $SSH_OPTS "$VPS_USER@$VPS_IP" \
    "cd ~/openclaw && docker compose exec openclaw-gateway openclaw models auth login --provider openai-codex" || {
    echo ""
    echo "[WARNING] Authentication command failed or returned non-zero."
    echo "If the command is incorrect, you may need to run it manually."
    exit 1
}

echo ""
echo "=== Done ==="
echo ""
echo "Your Codex integration should now be authenticated."
