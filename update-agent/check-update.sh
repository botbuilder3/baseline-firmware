#!/bin/bash
# Baseline Homes - Update Agent
# Runs nightly to check for and apply firmware updates
# Location: /opt/baseline/check-update.sh

set -e

# Configuration
MANIFEST_URL="https://raw.githubusercontent.com/botbuilder3/baseline-firmware/main/manifest.json"
LOCAL_VERSION_FILE="/opt/baseline/current_version"
CONFIG_DIR="/config"
LOG_FILE="/opt/baseline/update.log"
BACKUP_DIR="/opt/baseline/backups"

# Ensure directories exist
mkdir -p /opt/baseline
mkdir -p "$BACKUP_DIR"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
    echo "$1"
}

log "=== Starting update check ==="

# Get remote manifest
REMOTE_MANIFEST=$(curl -s --fail "$MANIFEST_URL") || {
    log "ERROR: Failed to fetch manifest"
    exit 1
}

REMOTE_VERSION=$(echo "$REMOTE_MANIFEST" | jq -r '.version')
FIRMWARE_URL=$(echo "$REMOTE_MANIFEST" | jq -r '.firmware_url')
CHECKSUM=$(echo "$REMOTE_MANIFEST" | jq -r '.checksum_sha256')
CHANGELOG=$(echo "$REMOTE_MANIFEST" | jq -r '.changelog')

# Get local version
LOCAL_VERSION=$(cat "$LOCAL_VERSION_FILE" 2>/dev/null || echo "0.0.0")

log "Local version: $LOCAL_VERSION"
log "Remote version: $REMOTE_VERSION"

# Compare versions
if [ "$REMOTE_VERSION" == "$LOCAL_VERSION" ]; then
    log "Already up to date"
    exit 0
fi

log "Update available: $LOCAL_VERSION -> $REMOTE_VERSION"
log "Changelog: $CHANGELOG"

# Download update
log "Downloading update..."
curl -s --fail -o /tmp/update.tar.gz "$FIRMWARE_URL" || {
    log "ERROR: Failed to download firmware"
    exit 1
}

# Verify checksum (skip if empty)
if [ -n "$CHECKSUM" ] && [ "$CHECKSUM" != "null" ] && [ "$CHECKSUM" != "" ]; then
    ACTUAL_CHECKSUM=$(sha256sum /tmp/update.tar.gz | cut -d' ' -f1)
    if [ "$ACTUAL_CHECKSUM" != "$CHECKSUM" ]; then
        log "ERROR: Checksum mismatch!"
        log "Expected: $CHECKSUM"
        log "Actual: $ACTUAL_CHECKSUM"
        rm /tmp/update.tar.gz
        exit 1
    fi
    log "Checksum verified"
else
    log "WARNING: No checksum provided, skipping verification"
fi

# Backup current config (excluding secrets.yaml)
log "Backing up current configuration..."
BACKUP_FILE="$BACKUP_DIR/backup-$LOCAL_VERSION-$(date '+%Y%m%d-%H%M%S').tar.gz"
tar -czf "$BACKUP_FILE" \
    --exclude='secrets.yaml' \
    -C "$CONFIG_DIR" \
    configuration.yaml automations.yaml scripts.yaml customize.yaml 2>/dev/null || true

# Extract update to temp location
log "Extracting update..."
rm -rf /tmp/baseline-update
mkdir -p /tmp/baseline-update
tar -xzf /tmp/update.tar.gz -C /tmp/baseline-update

# Apply update (copy files, but NEVER overwrite secrets.yaml)
log "Applying update..."
for file in configuration.yaml automations.yaml scripts.yaml customize.yaml; do
    if [ -f "/tmp/baseline-update/$file" ]; then
        cp "/tmp/baseline-update/$file" "$CONFIG_DIR/$file"
        log "Updated: $file"
    fi
done

# Update version file
echo "$REMOTE_VERSION" > "$LOCAL_VERSION_FILE"

# Cleanup
rm -rf /tmp/update.tar.gz /tmp/baseline-update

log "Update complete: $REMOTE_VERSION"
log "Restarting Home Assistant..."

# Restart Home Assistant
ha core restart || {
    log "WARNING: Failed to restart HA via CLI, trying API..."
    curl -X POST http://supervisor/core/restart -H "Authorization: Bearer $SUPERVISOR_TOKEN" || true
}

log "=== Update finished ==="
