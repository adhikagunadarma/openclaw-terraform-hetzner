# OpenClaw 2026.9.2 upgrade

Target release: https://github.com/openclaw/openclaw/releases/tag/v2026.9.2

The repositories are the source of truth. `openclaw-docker-config` pins the
application and plugin versions and owns `config/openclaw.json`.
`openclaw-terraform-hetzner` deploys that image, environment and config. Do not
create a second, untracked configuration by patching `openclaw.json` on the VPS.

## Model policy

| Surface | Model | Thinking |
| --- | --- | --- |
| Main agent | `openai/gpt-5.6-sol` | `low` |
| Main fallback | `openai/gpt-5.6-luna` | `low` |
| Dedicated heartbeat agent | `openai/gpt-5.6-luna` | `low` |
| Stored model-backed cron jobs, enabled and disabled | `openai/gpt-5.6-luna` | `low` |
| Subagents and utility model | `openai/gpt-5.6-luna` | `low` |
| PDF analysis | `openai/gpt-5.6-luna` | configured default `low` |

Astra, Terra and the other configured models remain exposed for manual use.
Image generation stays on GPT Image 2. Codex owns native compaction in this
release, so Doctor removes a separate OpenClaw compaction-model override.

Heartbeat does not have a separate `thinking` property; its dedicated agent
sets `thinkingDefault: low`. Cron stores model and thinking per job, so run
`make set-cron-models` after deployment and after adding model-backed jobs.

## Deployment order

This repository does not have a CI image build. Build and publish `latest`
locally from `openclaw-docker-config` first:

```bash
export GHCR_USERNAME=adhikagunadarma
bash scripts/build-and-push.sh
```

Then run from `openclaw-terraform-hetzner`:

```bash
source config/inputs.sh
make backup-now PRESERVE_BACKUPS=true
make deploy
make push-env
make push-config
make set-cron-models
```

The order is intentional for this schema-changing upgrade. `make deploy`
starts 2026.9.2 against the existing configuration and lets OpenClaw Doctor
migrate persisted state. Only then does `make push-config` activate the
repository's canonical 2026.9.2 config. Pushing that config while 2026.7.1-2 is
still running risks an old process hot-reloading a newer schema.

`make push-env` may be omitted when `secrets/openclaw.env` has not changed. It
is included above when the goal is to reconcile every repository-managed input
with the VPS. Both push commands currently restart the gateway, so expect more
than one restart. A future atomic release target can stage all inputs and
perform one restart without changing the source-of-truth model.

## Verification

```bash
source config/inputs.sh
make status
```

```bash
ssh openclaw@"$SERVER_IP" '
  cd ~/openclaw
  docker compose exec -T openclaw-gateway openclaw --version
  docker compose exec -T openclaw-gateway openclaw config validate --json
  docker compose exec -T openclaw-gateway openclaw health --json
  docker compose exec -T openclaw-gateway openclaw plugins list
'
```

Test Sol, Astra and Luna in separate new sessions, then send a normal Telegram
message and test the owner's `/model` command. Existing conversations may keep
session-level model or thinking overrides. A healthy gateway also does not by
itself prove that the connected OpenAI account is entitled to Astra.
