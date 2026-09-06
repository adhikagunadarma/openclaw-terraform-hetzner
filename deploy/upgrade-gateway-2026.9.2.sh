#!/usr/bin/env bash
# Run ON the VPS from a unique upgrade directory containing backup.sh and
# upgrade-2026.9.2-models.jq. No credentials are printed or replaced.
set -euo pipefail
umask 077
upgrade_dir="$(cd "$(dirname "$0")" && pwd)"
candidate='ghcr.io/adhikagunadarma/openclaw-docker-config/openclaw-gateway:upgrade-2026.9.2-20260906'
image_ref='ghcr.io/adhikagunadarma/openclaw-docker-config/openclaw-gateway:latest'
cd /home/openclaw/openclaw
test -f "$upgrade_dir/backup.sh"
test -f "$upgrade_dir/upgrade-2026.9.2-models.jq"
if compgen -G "$upgrade_dir/openclaw_backup_*.tar.gz" >/dev/null; then
    echo "Refusing to reuse an upgrade directory that already contains a snapshot."
    exit 1
fi
docker image inspect "$candidate" >/dev/null
old_id="$(docker inspect --format '{{.Image}}' openclaw-openclaw-gateway-1)"
rollback_tag="openclaw-rollback:$(basename "$upgrade_dir")"
docker tag "$old_id" "$rollback_tag"
printf '%s\n' "$rollback_tag" > "$upgrade_dir/rollback-image.txt"
cp -p docker-compose.yml "$upgrade_dir/docker-compose.yml"
cp -p .env "$upgrade_dir/compose.env"
phase=backup
rollback() {
    result=$?
    trap - EXIT
    if [[ $result -ne 0 ]]; then
        echo "Upgrade failed during $phase. Restoring the previous deployment."
        docker compose stop openclaw-gateway </dev/null || true
        if [[ "$phase" != backup ]]; then
            # Preserve failed state for diagnosis; never merge new DB files into
            # the old database or delete the user's backup.
            mv /home/openclaw/.openclaw "$upgrade_dir/failed-upgrade-state"
            tar -xzf "$snapshot" -C /home/openclaw
        fi
        docker tag "$rollback_tag" "$image_ref"
        docker compose up -d --no-deps --pull never openclaw-gateway </dev/null || true
        echo "Rollback requested. Backup and logs remain in $upgrade_dir."
    fi
    exit "$result"
}
trap rollback EXIT
trap 'exit 143' TERM
trap 'exit 130' INT
trap 'exit 129' HUP
docker compose stop openclaw-gateway </dev/null
bash "$upgrade_dir/backup.sh" true "$upgrade_dir"
snapshots=("$upgrade_dir"/openclaw_backup_*.tar.gz)
[[ ${#snapshots[@]} -eq 1 && -f "${snapshots[0]}" ]]
snapshot="${snapshots[0]}"
phase=migration
jq -f "$upgrade_dir/upgrade-2026.9.2-models.jq" /home/openclaw/.openclaw/openclaw.json > "$upgrade_dir/candidate-config.json"
jq -e '.agents.defaults.model.primary == "openai/gpt-6-astra"' "$upgrade_dir/candidate-config.json" >/dev/null
cp "$upgrade_dir/candidate-config.json" /home/openclaw/.openclaw/openclaw.json
chmod 600 /home/openclaw/.openclaw/openclaw.json
docker tag "$candidate" "$image_ref"
docker compose up -d --no-deps --pull never openclaw-gateway </dev/null
phase=readiness
deadline=$((SECONDS + 600))
while (( SECONDS < deadline )); do
    if timeout 15s docker compose exec -T openclaw-gateway openclaw health </dev/null > "$upgrade_dir/health.log" 2>&1; then
        echo "Gateway is healthy. Backup: $snapshot"
        trap - EXIT
        exit 0
    fi
    echo "Waiting for gateway migration/startup..."
    sleep 10
done
docker compose logs --tail 150 --no-color openclaw-gateway > "$upgrade_dir/startup-failure.log" 2>&1
echo "Gateway failed its bounded readiness check; logs saved privately."
exit 1
