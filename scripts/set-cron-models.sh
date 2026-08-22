#!/usr/bin/env bash
set -euo pipefail

VPS_USER="openclaw"
TERRAFORM_DIR="infra/terraform/envs/prod"

if [[ -f "config/inputs.sh" ]]; then
    source "config/inputs.sh"
fi

SSH_OPTS="-o StrictHostKeyChecking=accept-new"
[[ -n "${SSH_KEY:-}" ]] && SSH_OPTS+=" -i $SSH_KEY"

if [[ -n "${1:-}" ]]; then
    VPS_IP="$1"
elif [[ -n "${SERVER_IP:-}" ]]; then
    VPS_IP="$SERVER_IP"
elif command -v terraform >/dev/null 2>&1 && [[ -d "$TERRAFORM_DIR/.terraform" ]]; then
    VPS_IP=$(cd "$TERRAFORM_DIR" && terraform output -raw server_ip)
else
    echo "Error: No VPS IP provided."
    echo "Usage: $0 <VPS_IP>"
    exit 1
fi

MODEL="openai/gpt-5.6-luna"
THINKING="low"

echo "Setting every model-backed cron job to $MODEL with $THINKING thinking..."

remote_compose='cd "$HOME/openclaw" && docker compose exec -T openclaw-gateway'
jobs_json=$(ssh -n $SSH_OPTS "$VPS_USER@$VPS_IP" \
    "$remote_compose openclaw cron list --json")

if ! jq -e '.jobs | type == "array"' >/dev/null <<<"$jobs_json"; then
    echo "Error: Gateway did not return valid cron JSON." >&2
    exit 1
fi

job_count=$(jq '[.jobs[] | select(.payload.kind == "agentTurn")] | length' \
    <<<"$jobs_json")
if [[ "$job_count" -eq 0 ]]; then
    echo "No model-backed cron jobs found."
    exit 0
fi

while IFS= read -r row; do
    IFS=$'\t' read -r job_id job_name <<<"$row"
    if [[ ! "$job_id" =~ ^[0-9a-fA-F-]{36}$ ]]; then
        echo "Error: Refusing invalid cron job id: $job_id" >&2
        exit 1
    fi
    echo "Updating $job_name ($job_id)..."
    ssh -n $SSH_OPTS "$VPS_USER@$VPS_IP" \
        "$remote_compose openclaw cron edit '$job_id' --model '$MODEL' --thinking '$THINKING'"
done < <(
    jq -r '.jobs[] | select(.payload.kind == "agentTurn") | [.id, .name] | @tsv' \
        <<<"$jobs_json"
)

echo "Updated $job_count model-backed cron job(s)."
ssh -n $SSH_OPTS "$VPS_USER@$VPS_IP" \
    "$remote_compose openclaw cron list --json" \
    | jq '{jobs: [.jobs[] | {id, name, kind: .payload.kind, model: .payload.model, thinking: .payload.thinking}]}'
