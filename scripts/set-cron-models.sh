#!/usr/bin/env bash
set -euo pipefail

VPS_USER="openclaw"
SSH_OPTS="-o StrictHostKeyChecking=accept-new"
[[ -n "${SSH_KEY:-}" ]] && SSH_OPTS+=" -i $SSH_KEY"
TERRAFORM_DIR="infra/terraform/envs/prod"

if [[ -f "config/inputs.sh" ]]; then
    source "config/inputs.sh"
fi

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

ssh $SSH_OPTS "$VPS_USER@$VPS_IP" bash -s -- "$MODEL" "$THINKING" <<'REMOTE_SCRIPT'
set -euo pipefail

model="$1"
thinking="$2"
cd "$HOME/openclaw"

jobs_json=$(docker compose exec -T openclaw-gateway openclaw cron list --json)
mapfile -t job_rows < <(
    jq -r '.jobs[] | select(.payload.kind == "agentTurn") | [.id, .name] | @tsv' <<<"$jobs_json"
)

if [[ ${#job_rows[@]} -eq 0 ]]; then
    echo "No model-backed cron jobs found."
    exit 0
fi

for row in "${job_rows[@]}"; do
    IFS=$'\t' read -r job_id job_name <<<"$row"
    echo "Updating $job_name ($job_id)..."
    docker compose exec -T openclaw-gateway \
        openclaw cron edit "$job_id" --model "$model" --thinking "$thinking"
done

echo "Updated ${#job_rows[@]} model-backed cron job(s)."
docker compose exec -T openclaw-gateway openclaw cron list --json \
    | jq '{jobs: [.jobs[] | {id, name, kind: .payload.kind, model: .payload.model, thinking: .payload.thinking}]}'
REMOTE_SCRIPT
