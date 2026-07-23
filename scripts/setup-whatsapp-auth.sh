#!/bin/bash
# =============================================================================
# OpenClaw Setup WhatsApp Auth Script
# =============================================================================
# Purpose: Link or repair the default OpenClaw WhatsApp Web session.
# Usage: ./scripts/setup-whatsapp-auth.sh [VPS_IP]
# =============================================================================

set -euo pipefail

VPS_USER="openclaw"
SSH_OPTS="-o StrictHostKeyChecking=accept-new"
[[ -n "${SSH_KEY:-}" ]] && SSH_OPTS+=" -i $SSH_KEY"
TERRAFORM_DIR="infra/terraform/envs/prod"

if [ -f "config/inputs.sh" ]; then
    source "config/inputs.sh"
fi

if [[ -n "${1:-}" ]]; then
    VPS_IP="$1"
elif [[ -n "${SERVER_IP:-}" ]]; then
    VPS_IP="$SERVER_IP"
elif command -v terraform >/dev/null 2>&1 && [[ -d "$TERRAFORM_DIR/.terraform" ]]; then
    VPS_IP=$(cd "$TERRAFORM_DIR" && terraform output -raw server_ip 2>/dev/null) || {
        echo "Error: Could not get server IP from Terraform output."
        echo "Usage: $0 <VPS_IP>"
        exit 1
    }
else
    echo "Error: No server IP provided and Terraform output is unavailable."
    echo "Usage: $0 <VPS_IP>"
    exit 1
fi

echo "=== OpenClaw Setup WhatsApp Auth ==="
echo "VPS IP: $VPS_IP"
echo ""
echo "[INFO] The QR will be rendered only in this terminal."
echo "[INFO] Do not copy it into Telegram, logs, screenshots, or agent messages."
echo ""

REMOTE_STATUS='cd ~/openclaw && docker compose exec -T openclaw-gateway openclaw channels status --channel whatsapp --probe --json'

echo "[...] Checking the default WhatsApp listener..."
STATUS=$(ssh $SSH_OPTS "$VPS_USER@$VPS_IP" "$REMOTE_STATUS" 2>&1 || true)
printf '%s\n' "$STATUS"

if printf '%s\n' "$STATUS" | grep -Eq '"connected"[[:space:]]*:[[:space:]]*true' \
    && printf '%s\n' "$STATUS" | grep -Eq '"running"[[:space:]]*:[[:space:]]*true'; then
    echo ""
    echo "[OK] WhatsApp is already connected and running; no auth state was changed."
    exit 0
fi

echo ""
echo "[...] Restarting the gateway once before changing auth state..."
STATUS=$(ssh $SSH_OPTS "$VPS_USER@$VPS_IP" \
    "cd ~/openclaw && docker compose restart openclaw-gateway >/dev/null && sleep 10 && docker compose exec -T openclaw-gateway openclaw channels status --channel whatsapp --probe --json" \
    2>&1 || true)
printf '%s\n' "$STATUS"

if printf '%s\n' "$STATUS" | grep -Eq '"connected"[[:space:]]*:[[:space:]]*true' \
    && printf '%s\n' "$STATUS" | grep -Eq '"running"[[:space:]]*:[[:space:]]*true'; then
    echo ""
    echo "[OK] WhatsApp recovered after the gateway restart; auth state was preserved."
    exit 0
fi

echo ""
echo "[WARN] WhatsApp is not healthy. A 401 status means the linked session was logged out."
echo "[WARN] If WhatsApp shows a pairing cooldown, stop here with Ctrl+C and wait for it to expire."
echo "[WARN] This command performs one login attempt and never retries automatically."
echo ""
read -r -p "Press Enter to clear the stale session and show a new QR, or Ctrl+C to cancel... "

ssh $SSH_OPTS "$VPS_USER@$VPS_IP" \
    "cd ~/openclaw && docker compose exec -T openclaw-gateway openclaw channels logout --channel whatsapp --account default" \
    >/dev/null 2>&1 || true

echo ""
echo "[...] Starting interactive WhatsApp login..."
echo "Open WhatsApp on the assistant phone, then use Linked devices > Link a device."
echo ""

ssh -tt $SSH_OPTS "$VPS_USER@$VPS_IP" \
    "cd ~/openclaw && docker compose exec openclaw-gateway openclaw channels login --channel whatsapp --account default"

echo ""
echo "[...] Restarting the gateway and verifying the linked session..."
ssh $SSH_OPTS "$VPS_USER@$VPS_IP" \
    "cd ~/openclaw && docker compose restart openclaw-gateway >/dev/null && sleep 10 && docker compose exec -T openclaw-gateway openclaw channels status --channel whatsapp --probe --json"

echo ""
echo "=== Done ==="
echo "Confirm that the final status reports connected=true and running=true."
