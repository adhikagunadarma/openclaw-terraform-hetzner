#!/bin/bash
# =============================================================================
# OpenClaw Setup GOG Auth Script
# =============================================================================
# Purpose: Push Google OAuth client_secret.json to the VPS and authenticate.
# Usage: ./scripts/setup-gog-auth.sh [VPS_IP]
#
# This script:
#   1. Reads GOG_CLIENT_ID, GOG_PROJECT_ID, and GOG_CLIENT_SECRET from the env
#   2. Writes client_secret_desktop.json directly to the VPS host volume
#   3. Registers the OAuth client in the persistent gog config path
#   4. Reuses an existing token when present, or triggers interactive auth
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

GOG_CLIENT_ID="${GOG_CLIENT_ID:-}"
GOG_PROJECT_ID="${GOG_PROJECT_ID:-pepongclaw}"
GOG_CLIENT_SECRET="${GOG_CLIENT_SECRET:-}"
GOG_ACCOUNT="${GOG_ACCOUNT:-pepperwhiskey29@gmail.com}"



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

echo "=== OpenClaw Setup GOG Auth ==="
echo "VPS IP: $VPS_IP"
echo ""

# -----------------------------------------------------------------------------
# Validate environment variables
# -----------------------------------------------------------------------------

if [[ -z "$GOG_CLIENT_ID" || -z "$GOG_CLIENT_SECRET" ]]; then
    echo "Error: GOG_CLIENT_ID or GOG_CLIENT_SECRET not set"
    echo ""
    echo "Please configure your GOG auth variables:"
    echo "  1. Add them to your config/inputs.sh or secrets file"
    echo "  2. Source the file (e.g., source config/inputs.sh)"
    echo "  3. Run this script again."
    exit 1
fi

# -----------------------------------------------------------------------------
# Push client_secret_desktop.json to VPS
# -----------------------------------------------------------------------------

AUTH_DIR="\$HOME/.openclaw"
AUTH_FILE="\$HOME/.openclaw/client_secret_desktop.json"

echo "[...] Writing client_secret_desktop.json to VPS..."

echo "[INFO] Constructing client_secret_desktop.json from environment variables..."
ssh $SSH_OPTS "$VPS_USER@$VPS_IP" bash -s <<REMOTE_SCRIPT
set -euo pipefail
mkdir -p "$AUTH_DIR/.config/gogcli" "$AUTH_DIR/.local/share"
cat > "$AUTH_FILE" << 'AUTHEOF'
{
  "installed": {
    "client_id": "$GOG_CLIENT_ID",
    "project_id": "$GOG_PROJECT_ID",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_secret": "$GOG_CLIENT_SECRET",
    "redirect_uris": ["http://localhost"]
  }
}
AUTHEOF
chmod 600 "$AUTH_FILE"
echo "[OK] GOG auth profile written to $AUTH_FILE"
REMOTE_SCRIPT

# -----------------------------------------------------------------------------
# Register credentials and reuse existing OAuth token when possible
# -----------------------------------------------------------------------------

echo ""
echo "[...] Registering GOG credentials in persistent config..."
echo ""

GOG_DOCKER_ENV="-e XDG_CONFIG_HOME=/home/node/.openclaw/.config -e XDG_DATA_HOME=/home/node/.openclaw/.local/share -e GOG_KEYRING_BACKEND=file"

ssh $SSH_OPTS "$VPS_USER@$VPS_IP" \
    "cd ~/openclaw && \
    docker compose exec -T $GOG_DOCKER_ENV openclaw-gateway gog auth credentials /home/node/.openclaw/client_secret_desktop.json" || {
    echo ""
    echo "[WARNING] Failed to register GOG OAuth client credentials."
    exit 1
}

echo "[...] Checking whether $GOG_ACCOUNT is already authenticated..."

if ssh $SSH_OPTS "$VPS_USER@$VPS_IP" \
    "cd ~/openclaw && \
    docker compose exec -T $GOG_DOCKER_ENV openclaw-gateway gog auth list --json --no-input | grep -F '\"$GOG_ACCOUNT\"' >/dev/null"; then
    echo "[OK] $GOG_ACCOUNT is already authenticated; skipping OAuth browser flow."
else
    echo ""
    echo "[...] Triggering interactive OAuth flow..."
    echo "You will likely be given a URL to open in your browser."
    echo "Please follow the instructions on screen."
    echo ""

    # We use -t to force pseudo-terminal allocation for interactive auth.
    ssh -t $SSH_OPTS "$VPS_USER@$VPS_IP" \
        "cd ~/openclaw && \
        docker compose exec $GOG_DOCKER_ENV openclaw-gateway gog auth add \"$GOG_ACCOUNT\" --services gmail,calendar,drive,contacts,sheets,docs" || {
    echo ""
    echo "[WARNING] Authentication command failed or returned non-zero."
    echo "If the command is incorrect, you may need to run it manually."
    exit 1
}
fi

echo ""
echo "=== Done ==="
echo ""
echo "Your GOG integration should now be authenticated."
echo "GOG config and file-keyring state should persist under ~/.openclaw across redeploys."
