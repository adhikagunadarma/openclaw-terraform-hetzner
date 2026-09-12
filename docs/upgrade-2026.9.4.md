# OpenClaw 2026.9.4 upgrade

Target release: https://github.com/openclaw/openclaw/releases/tag/v2026.9.4

The repositories remain the source of truth. `openclaw-docker-config` pins the
application, Node runtime, plugin cohort and `config/openclaw.json`.
`openclaw-terraform-hetzner` owns VPS deployment and backup automation. Do not
patch the live VPS configuration independently of these repositories.

## Pinned runtime and models

| Surface | Model | Thinking |
| --- | --- | --- |
| Main agent | `openai/gpt-5.6-sol` | `low` |
| Main fallback | `openai/gpt-5.6-luna` | `low` |
| Heartbeat | `openai/gpt-5.6-luna` | `low` through the agent default |
| Stored model-backed cron jobs | `openai/gpt-5.6-luna` | `low` |
| Subagents and utility model | `openai/gpt-5.6-luna` | `low` |

GPT-6 Astra and GPT-5.6 Terra remain exposed for ad-hoc selection. The gateway
image pins Node 24.16.0 and OpenClaw 2026.9.4. Codex, WhatsApp, Brave,
DeepSeek, Qwen and Z.AI provider plugins are pinned to the same 2026.9.4
compatibility line.

## Before publishing the image

Validate both repositories and review their diffs:

```bash
cd /Users/Pong/Project/Personal/pepongclaw/openclaw-docker-config
./scripts/validate-config.sh
git diff --check
git diff

cd /Users/Pong/Project/Personal/pepongclaw/openclaw-terraform-hetzner
make validate
git diff --check
git diff
```

Commit and push each repository before building so the immutable image SHA tag
matches the committed source. Do not run `make push-env` for this upgrade;
there is no required environment-file change, and the previously reported
GitHub token should not be redistributed until it has been replaced.

## Make a migration-safe backup

The VPS must have enough free disk space before Docker pulls the new image.
Run this from `openclaw-terraform-hetzner`:

```bash
source config/inputs.sh
make backup-upgrade
make push-backup-script
```

`backup-upgrade` performs the following as one operation:

1. Applies the normal seven-day retention policy before allocating a new
   archive. It only removes top-level `openclaw_backup_*.tar.gz` files older
   than seven days; named upgrade/rollback directories are not touched.
2. Requires free space at least equal to the uncompressed state plus 512 MiB.
3. Stops the gateway, creates and validates a temporary archive, atomically
   publishes it, and restarts the gateway even if backup creation fails.
4. Removes its temporary partial archive on failure.

The gateway is briefly unavailable during this step. Do not pass
`PRESERVE_BACKUPS=true` while the VPS is full; that intentionally disables the
retention cleanup and the free-space preflight will reject the backup.

`push-backup-script` then installs the same hardened script for the daily
systemd timer without restarting the gateway.

## Build, publish and deploy

Build and push from `openclaw-docker-config` using the existing local publishing
workflow:

```bash
cd /Users/Pong/Project/Personal/pepongclaw/openclaw-docker-config
export GHCR_USERNAME=adhikagunadarma
bash scripts/build-and-push.sh
```

The script publishes both `latest` and the current Git commit SHA. It uses the
Docker credential store; do not pipe the known-invalid `GH_TOKEN` into
`docker login`.

After the build and push complete, deploy from `openclaw-terraform-hetzner`:

```bash
cd /Users/Pong/Project/Personal/pepongclaw/openclaw-terraform-hetzner
source config/inputs.sh
make deploy
make push-config
make set-cron-models
make status
```

The order is intentional. `make deploy` first starts 2026.9.4 against the
currently valid persisted configuration, reconciles the pinned plugin cohort
and completes focused post-upgrade validation. `make push-config` then
activates the committed Sol-low policy.
`make set-cron-models` updates and verifies enabled and disabled model-backed
jobs only after the new gateway is healthy.

## Verification

Run these read-only checks after `make status` succeeds:

```bash
ssh openclaw@"$SERVER_IP" '
  cd ~/openclaw
  docker compose exec -T openclaw-gateway node --version
  docker compose exec -T openclaw-gateway openclaw --version
  docker compose exec -T openclaw-gateway openclaw config validate --json
  docker compose exec -T openclaw-gateway openclaw health --json
  docker compose exec -T openclaw-gateway openclaw plugins list
  df -h /
'
```

Expected versions are Node 24.16.0, OpenClaw 2026.9.4, and plugin versions
2026.9.4. Start a new Telegram session and verify a normal Sol response, the
owner-only `/model` command, manual Astra selection, and a cron/heartbeat run.
Existing conversations can retain session-level model overrides.

Keep the verified backup and the previous immutable image tag until the new
deployment has been stable for at least 24 hours.

## Repository-owned configuration

The entrypoint reconciles the pinned plugin manifest first, then exports
`OPENCLAW_CONFIG_READONLY=1` for configuration validation, focused post-upgrade
plugin diagnostics and the gateway. Runtime state, OAuth credentials, sessions
and plugin installation records remain writable, but Doctor and the running
gateway cannot rewrite `openclaw.json` with generated settings or resolved
secret values. The canonical config explicitly enables every configured
provider that Doctor would otherwise add.

The image also sets `OPENCLAW_NO_RESPAWN=1` because Docker owns gateway process
restarts, and enables a container-local Node compile cache to reduce repeated
CLI startup cost.
