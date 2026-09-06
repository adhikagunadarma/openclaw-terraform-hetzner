# OpenClaw 2026.9.2 upgrade

Target release: https://github.com/openclaw/openclaw/releases/tag/v2026.9.2

This is a fresh release, not a guarantee of production stability. Validate the
actual gateway, plugin migrations, channel routing and account model access.
Node 22.23.1 satisfies this release's supported Node range. The Docker build
pins core, Codex, WhatsApp and Brave to 2026.9.2 together.

## Model policy

| Surface | Model | Thinking |
| --- | --- | --- |
| Main agent | `openai/gpt-6-astra` | `low` |
| Main fallback | `openai/gpt-5.6-luna` | `low` |
| Dedicated heartbeat agent | `openai/gpt-5.6-luna` | `low` |
| Stored model-backed cron jobs, enabled and disabled | `openai/gpt-5.6-luna` | `low` |
| Subagents and utility model | `openai/gpt-5.6-luna` | `low` |
| PDF analysis | `openai/gpt-5.6-luna` | configured default `low` |

Sol, Terra and the other manually selectable models remain exposed. Image
generation stays on GPT Image 2; Luna is not an image-generation replacement.
Codex owns native compaction: Doctor removes OpenClaw's separate compaction
model override, so compaction cannot be promised to run on Luna.

Heartbeat has no separate `thinking` property; the dedicated heartbeat agent
sets `thinkingDefault: low`. Cron stores `payload.model` and `payload.thinking`
per job. In 2026.9.2 isolated cron also considers the configured subagent model,
but explicit payload/session/hook overrides can take precedence. Specify Luna
and low when creating new jobs; rerun `make set-cron-models` to enforce the
policy across all existing jobs. This does not change their schedules or
enabled flags.

## Backup and deployment

Run commands from `openclaw-terraform-hetzner`:

```bash
source config/inputs.sh
make backup-now PRESERVE_BACKUPS=true
```

Ordinary live backups may include changing databases. For this upgrade,
`deploy/upgrade-gateway-2026.9.2.sh` stops the gateway before the snapshot,
verifies the archive, applies the scoped JQ migration to the existing live
config, and starts the staged image. It automatically restores the original
state/image on startup/readiness failure, preserving the failed state for
diagnosis. It must run from a NEW private directory on the VPS containing
`backup.sh`, the upgrade script and `upgrade-2026.9.2-models.jq`. It is a
version-specific maintenance script, not a generic replacement for deploy.

The September 6 preparation was cancelled at the user's request. The original
deployment was restored from its snapshot; the candidate state was preserved
separately for diagnosis. Do not reuse that directory for another upgrade.
Its directory is:
`/home/openclaw/backups/upgrade-2026.9.2-ET3GMGQK`.
The snapshot filename is
`openclaw_backup_20260906_105558_kBgX2s.tar.gz`.
The directory also holds the original Compose file/environment and rollback
image tag. Do not commit its contents: they contain credentials and user data.
No existing backup is overwritten or removed by this upgrade.

The candidate is staged under the separate image tag
`upgrade-2026.9.2-20260906`; the normal `latest` tag should only be promoted
after production validation. Do not run an ordinary `make deploy` during that
validation window, because it pulls the previously published `latest` image.

## Post-upgrade checks

```bash
source config/inputs.sh
make status
make set-cron-models
```

Check `openclaw --version`, `openclaw config validate --json`,
`openclaw plugins list`, `openclaw health`, and the account-discovered model
catalog inside the gateway container. Test Astra and Luna in separate
non-delivering sessions; a healthy gateway alone does not prove model access.
Finally send a normal Telegram message and test the owner's `/model` command.
Existing conversations may retain session-level model/thinking overrides.

The local template uses canonical `agents.entries`, explicit channel bindings,
`mediaModels.image`, and omits retired tuning/logging fields. For upgrades,
patch the existing live config instead of `make push-config`, which replaces
it and can discard customizations made through OpenClaw.
