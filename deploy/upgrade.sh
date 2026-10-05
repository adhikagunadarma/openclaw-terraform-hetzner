#!/usr/bin/env bash
set -euo pipefail

server=${1:?Server required}
config_dir=${2:?CONFIG_DIR required; source config/inputs.sh}
registry_user=${3:?GHCR_USERNAME required; source config/inputs.sh}
version=${4:-2026.9.8}
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid version" >&2; exit 1; }
[[ "$registry_user" =~ ^[a-z0-9][a-z0-9_-]*$ ]] || { echo "Invalid registry username" >&2; exit 1; }
repo_root=$(cd "$(dirname "$0")/.." && pwd)
ssh_opts=(-o StrictHostKeyChecking=accept-new)
[[ -z "${SSH_KEY:-}" ]] || ssh_opts+=(-i "$SSH_KEY")
image="ghcr.io/$registry_user/openclaw-docker-config/openclaw-gateway:$version"
bash "$config_dir/scripts/validate-config.sh"

stage=$(ssh "${ssh_opts[@]}" "openclaw@$server" 'mktemp -d /home/openclaw/openclaw-upgrade.XXXXXXXX')
[[ "$stage" =~ ^/home/openclaw/openclaw-upgrade\.[a-zA-Z0-9]+$ ]] || exit 1
scp "${ssh_opts[@]}" "$config_dir/config/openclaw.json" "openclaw@$server:$stage/openclaw.json"
scp "${ssh_opts[@]}" "$repo_root/deploy/backup.sh" "openclaw@$server:$stage/backup.sh"

ssh "${ssh_opts[@]}" "openclaw@$server" bash -s -- "$image" "$version" "$stage" <<'REMOTE'
set -euo pipefail
umask 077
image=$1
version=$2
stage=$3
cd "$HOME/openclaw"
[[ -f docker-compose.yml ]] || { echo "Missing Compose file" >&2; exit 1; }
if [[ -f docker-compose.override.yml ]] && ! head -1 docker-compose.override.yml | grep -qx '# Managed by deploy/upgrade.sh'; then
    echo "Existing custom Compose override requires manual review." >&2
    exit 1
fi
docker pull "$image"
reported=$(docker run --rm --entrypoint openclaw "$image" --version)
[[ "$reported" == *"$version"* ]] || { echo "Image version mismatch: $reported" >&2; exit 1; }

# Match backup.sh's capacity check before stopping a healthy gateway.
mkdir -p "$HOME/backups"
source_kb=$(du -sk "$HOME/.openclaw" | awk '{print $1}')
available_kb=$(df -Pk "$HOME/backups" | awk 'NR == 2 {print $4}')
required_kb=$((source_kb + 524288))
if (( available_kb < required_kb )); then
    echo "Insufficient backup space: need $((required_kb / 1024)) MiB; available $((available_kb / 1024)) MiB. Gateway remains running." >&2
    exit 1
fi

stamp=$(date +%Y%m%d_%H%M%S)
recovery="$HOME/backups/upgrade-$stamp"
mkdir -p "$recovery"
cp docker-compose.yml "$recovery/"
if [[ -f docker-compose.override.yml ]]; then cp docker-compose.override.yml "$recovery/"; fi
container=$(docker compose ps -aq openclaw-gateway)
[[ -n "$container" ]] || { echo "No existing gateway to preserve" >&2; exit 1; }
old_image=$(docker inspect --format '{{.Image}}' "$container")
docker tag "$old_image" "openclaw-gateway:pre-upgrade-$stamp"
printf '%s\n' "$old_image" > "$recovery/image-id.txt"
printf 'services:\n  openclaw-gateway:\n    image: openclaw-gateway:pre-upgrade-%s\n' "$stamp" > "$recovery/rollback-image.yml"

echo "Stopping services. Recovery files: $recovery"
docker compose --profile sync stop
trap 'docker compose --profile sync stop || true; echo "Upgrade failed. Services were stopped; recovery files are in $recovery. Do not start the old image on migrated state." >&2' ERR
# The backup script sees an already stopped gateway and leaves it stopped.
bash "$stage/backup.sh" true "$HOME/backups" consistent | tee "$recovery/backup.log"

install -m 600 "$stage/openclaw.json" "$HOME/.openclaw/openclaw.json"
printf '# Managed by deploy/upgrade.sh\nservices:\n  openclaw-gateway:\n    image: %s\n' "$image" > docker-compose.override.yml
docker compose run --rm --no-deps -e OPENCLAW_UPGRADE_REPAIR=1 openclaw-gateway true
docker compose up -d openclaw-gateway
ready=false
deadline=$((SECONDS + 300))
while (( SECONDS < deadline )); do
    if timeout 15s docker compose exec -T openclaw-gateway openclaw health >/dev/null 2>&1; then
        ready=true
        break
    fi
    sleep 5
done
if [[ "$ready" != true ]]; then
    docker compose logs --tail 120 openclaw-gateway
    docker compose stop openclaw-gateway
    echo "Gateway health check failed" >&2
    exit 1
fi
if grep -qE '^GIT_WORKSPACE_(REPO|REMOTE)(_[A-Z]+)?=.+' .env; then
    docker compose --profile sync up -d
fi
docker compose exec -T openclaw-gateway openclaw --version
docker compose exec -T openclaw-gateway openclaw config validate --json
echo "Upgrade complete. Recovery files: $recovery"
echo "Doctor may have migrated config; review changes before the next make push-config."
rm -f "$stage/openclaw.json" "$stage/backup.sh"
rmdir "$stage"
REMOTE
