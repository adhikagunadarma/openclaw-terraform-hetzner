#!/usr/bin/env bash
set -euo pipefail

if [[ -f "config/inputs.sh" ]]; then
  source "config/inputs.sh"
fi

VPS_USER="${VPS_USER:-openclaw}"
SSH_OPTS=(-o StrictHostKeyChecking=accept-new)
if [[ -n "${SSH_KEY:-}" ]]; then
  SSH_OPTS+=(-i "$SSH_KEY")
fi
TERRAFORM_DIR="${TERRAFORM_DIR:-infra/terraform/envs/prod}"

if [[ -n "${1:-}" ]]; then
  VPS_IP="$1"
elif [[ -n "${SERVER_IP:-}" ]]; then
  VPS_IP="$SERVER_IP"
elif command -v terraform >/dev/null 2>&1 && [[ -d "$TERRAFORM_DIR/.terraform" ]]; then
  VPS_IP="$(terraform -chdir="$TERRAFORM_DIR" output -raw server_ip)"
else
  echo "Error: server IP not provided. Pass it as an argument or set SERVER_IP." >&2
  exit 1
fi

POLLYREACH_AGENT_NAME="${POLLYREACH_AGENT_NAME:-PepongClaw}"

echo "Checking PollyReach on $VPS_IP"

ssh "${SSH_OPTS[@]}" "$VPS_USER@$VPS_IP" \
  "cd ~/openclaw && docker compose exec -T openclaw-gateway bash -s -- $(printf '%q' "$POLLYREACH_AGENT_NAME")" <<'CONTAINER_SCRIPT'
set -euo pipefail

agent_name="$1"
credential_dir="$HOME/.openclaw/.config/PollyReach"
credential_file="$credential_dir/key.json"
legacy_credential_file="$credential_dir/credentials.json"
skill_root="$HOME/.openclaw/workspace/skills"
skill_dir="$skill_root/pollyreach"
if [[ -d "$skill_root/@pollyreach/pollyreach" ]]; then
  skill_dir="$skill_root/@pollyreach/pollyreach"
fi

umask 077
mkdir -p "$credential_dir"
chmod 700 "$credential_dir"

if [[ ! -f "$credential_file" && -f "$legacy_credential_file" ]]; then
  mv "$legacy_credential_file" "$credential_file"
  echo "Migrated PollyReach credentials to key.json."
fi

if [[ -f "$credential_file" ]]; then
  chmod 600 "$credential_file"
  token="$(jq -er '.token | select(type == "string" and length > 0)' "$credential_file")" || {
    echo "Error: PollyReach credential file exists but has no valid token." >&2
    echo "Refusing to register again. Repair or remove it manually after taking a backup." >&2
    exit 1
  }

  activation_script="$skill_dir/scripts/activation.sh"
  if [[ ! -f "$activation_script" && -f "$skill_dir/activation.sh" ]]; then
    activation_script="$skill_dir/activation.sh"
  fi
  if [[ ! -f "$activation_script" ]]; then
    echo "Error: PollyReach is not installed at $skill_dir." >&2
    echo "Deploy the gateway image first, then rerun this command." >&2
    exit 1
  fi

  echo "Existing PollyReach credentials found; checking activation."
  bash "$activation_script"
  exit 0
fi

echo "No PollyReach credentials found; registering $agent_name."
response="$(
  curl --fail-with-body --silent --show-error \
    -X POST "https://api.pollyreach.ai/platform/v1/auths/signin/device" \
    -H "Content-Type: application/json" \
    --data "$(jq -nc \
      --arg name "$agent_name" \
      --arg source "openclaw" \
      --arg description "Personal OpenClaw assistant" \
      '{name: $name, source: $source, description: $description}')"
)"

token="$(jq -er '.agent.token | select(type == "string" and length > 0)' <<<"$response")" || {
  echo "Error: PollyReach registration did not return a token." >&2
  exit 1
}
activation_url="$(jq -er '.agent.activation_url | select(type == "string" and length > 0)' <<<"$response")" || {
  echo "Error: PollyReach registration did not return an activation link." >&2
  exit 1
}

temporary_file="$(mktemp "$credential_dir/key.json.tmp.XXXXXX")"
jq -n --arg token "$token" --arg agent_name "$agent_name" \
  '{token: $token, agent_name: $agent_name}' >"$temporary_file"
chmod 600 "$temporary_file"
mv "$temporary_file" "$credential_file"

echo "PollyReach credentials saved in persistent OpenClaw state."
echo "Open this activation link and sign in:"
printf '%s\n' "$activation_url"
echo "After activation, rerun this command to verify the assigned number."
CONTAINER_SCRIPT
