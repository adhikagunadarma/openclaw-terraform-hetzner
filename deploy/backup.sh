#!/bin/bash
# =============================================================================
# OpenClaw Backup Script
# =============================================================================
# Purpose: Creates a backup of ~/.openclaw directory.
# Usage: Run on the VPS directly, or called by systemd timer.
#
# This script:
#   1. Creates a timestamped tar.gz of ~/.openclaw
#   2. Stores it in ~/backups/
#   3. Removes backups older than 7 days before creating a new archive
#   4. Validates the archive before publishing it under its final name
#
# Note: This script is meant to run ON the VPS, not from your laptop.
#       For remote backup, use: ssh openclaw@VPS ./deploy/backup.sh
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

BACKUP_DIR="${2:-$HOME/backups}"
SOURCE_DIR="$HOME/.openclaw"
RETENTION_DAYS=7
PRESERVE_BACKUPS="${1:-false}"
BACKUP_MODE="${3:-live}"
COMPOSE_DIR="$HOME/openclaw"
PARTIAL_FILE=""
GATEWAY_WAS_RUNNING=false

if [[ "$BACKUP_MODE" != "live" && "$BACKUP_MODE" != "consistent" ]]; then
    echo "Error: backup mode must be 'live' or 'consistent'" >&2
    exit 2
fi

cleanup() {
    local exit_code=$?

    if [[ -n "$PARTIAL_FILE" && -f "$PARTIAL_FILE" ]]; then
        rm -f -- "$PARTIAL_FILE"
    fi

    if [[ "$GATEWAY_WAS_RUNNING" == "true" ]]; then
        echo "[...] Restarting OpenClaw gateway..."
        if (cd "$COMPOSE_DIR" && docker compose up -d openclaw-gateway); then
            echo "[OK] Gateway restarted"
        else
            echo "[ERROR] Gateway could not be restarted" >&2
            [[ $exit_code -ne 0 ]] || exit_code=1
        fi
    fi

    trap - EXIT
    exit "$exit_code"
}
trap cleanup EXIT

# -----------------------------------------------------------------------------
# Create backup directory
# -----------------------------------------------------------------------------

mkdir -p "$BACKUP_DIR"

# Remove hidden temporary archives left by an interrupted backup.
find "$BACKUP_DIR" -maxdepth 1 -name '.openclaw_backup_*' -type f -delete

# -----------------------------------------------------------------------------
# Check if source exists
# -----------------------------------------------------------------------------

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Warning: Source directory $SOURCE_DIR does not exist"
    echo "Nothing to backup"
    exit 0
fi

# -----------------------------------------------------------------------------
# Retention and capacity preflight
# -----------------------------------------------------------------------------

echo "=== OpenClaw Backup ==="

if [[ "$PRESERVE_BACKUPS" == "true" ]]; then
    echo "[OK] Retention cleanup disabled; preserving all existing backups."
else
    echo "[...] Cleaning up backups older than $RETENTION_DAYS days..."
    OLD_COUNT=$(find "$BACKUP_DIR" -maxdepth 1 -name "openclaw_backup_*.tar.gz" -type f -mtime +$RETENTION_DAYS | wc -l)
    if [[ $OLD_COUNT -gt 0 ]]; then
        find "$BACKUP_DIR" -maxdepth 1 -name "openclaw_backup_*.tar.gz" -type f -mtime +$RETENTION_DAYS -delete
        echo "[OK] Deleted $OLD_COUNT old backup(s)"
    else
        echo "[OK] No old backups to delete"
    fi
fi

SOURCE_KB=$(du -sk "$SOURCE_DIR" | awk '{print $1}')
AVAILABLE_KB=$(df -Pk "$BACKUP_DIR" | awk 'NR == 2 {print $4}')
REQUIRED_KB=$((SOURCE_KB + 524288))

if (( AVAILABLE_KB < REQUIRED_KB )); then
    echo "Error: insufficient free space for a safe backup." >&2
    echo "Required: at least $((REQUIRED_KB / 1024)) MiB; available: $((AVAILABLE_KB / 1024)) MiB." >&2
    exit 1
fi

# -----------------------------------------------------------------------------
# Optionally pause the gateway for a migration-safe snapshot
# -----------------------------------------------------------------------------

if [[ "$BACKUP_MODE" == "consistent" ]]; then
    if [[ ! -f "$COMPOSE_DIR/docker-compose.yml" ]]; then
        echo "Error: $COMPOSE_DIR/docker-compose.yml not found" >&2
        exit 1
    fi

    if (cd "$COMPOSE_DIR" && docker compose ps --status running --services | grep -qx openclaw-gateway); then
        GATEWAY_WAS_RUNNING=true
        echo "[...] Stopping OpenClaw gateway for a consistent backup..."
        (cd "$COMPOSE_DIR" && docker compose stop openclaw-gateway)
        echo "[OK] Gateway stopped"
    else
        echo "[INFO] Gateway is already stopped"
    fi
fi

# -----------------------------------------------------------------------------
# Create backup
# -----------------------------------------------------------------------------

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
PARTIAL_FILE=$(mktemp "$BACKUP_DIR/.openclaw_backup_${TIMESTAMP}_XXXXXX")
PARTIAL_NAME=$(basename "$PARTIAL_FILE")
BACKUP_FILE="$BACKUP_DIR/${PARTIAL_NAME#.}.tar.gz"

echo "Source: $SOURCE_DIR"
echo "Destination: $BACKUP_FILE"
echo "Mode: $BACKUP_MODE"
echo ""

echo "[...] Creating backup..."

# Live scheduled backups tolerate files changing while they are being read. The
# consistent pre-upgrade mode stops the gateway and uses strict tar behavior.
if [[ "$BACKUP_MODE" == "consistent" ]]; then
    tar -czf "$PARTIAL_FILE" -C "$HOME" ".openclaw"
else
    tar --ignore-failed-read --warning=no-file-changed -czf "$PARTIAL_FILE" -C "$HOME" ".openclaw"
fi
gzip -t "$PARTIAL_FILE"
tar -tzf "$PARTIAL_FILE" >/dev/null
mv -- "$PARTIAL_FILE" "$BACKUP_FILE"
PARTIAL_FILE=""

# Get backup size
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)

echo "[OK] Backup created: $BACKUP_FILE ($BACKUP_SIZE)"

# -----------------------------------------------------------------------------
# List current backups
# -----------------------------------------------------------------------------

echo ""
echo "=== Current Backups ==="
ls -lh "$BACKUP_DIR"/openclaw_backup_*.tar.gz 2>/dev/null || echo "No backups found"

echo ""
echo "=== Backup Complete ==="
