#!/bin/bash
# Baseline Homes - Update Agent
# Runs nightly to check for and apply firmware updates
# Location: /opt/baseline/check-update.sh
# Version: 1.0.2

set -e

# Configuration - THIS URL CAN BE CHANGED IN FUTURE RELEASES
MANIFEST_URL="https://firmware.yourbaselinehome.com/manifest.json"

LOCAL_VERSION_FILE="/opt/baseline/current_version"
CONFIG_DIR="/homeassistant"
LOG_FILE="/opt/baseline/update.log"
BACKUP_DIR="/opt/baseline/backups"
MAX_LOG_LINES=1000

# Ensure directories exist
mkdir -p /opt/baseline
mkdir -p "$BACKUP_DIR"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
    echo "$1"
}

# Rotate log if too large
if [ -f "$LOG_FILE" ] && [ $(wc -l < "$LOG_FILE") -gt $MAX_LOG_LINES ]; then
    tail -500 "$LOG_FILE" > "$LOG_FILE.tmp"
    mv "$LOG_FILE.tmp" "$LOG_FILE"
fi

log "=== Starting update check ==="

# Get remote manifest
REMOTE_MANIFEST=$(curl -s --fail --max-time 30 "$MANIFEST_URL") || {
    log "ERROR: Failed to fetch manifest from $MANIFEST_URL"
    exit 1
}

REMOTE_VERSION=$(echo "$REMOTE_MANIFEST" | jq -r '.version')
FIRMWARE_URL=$(echo "$REMOTE_MANIFEST" | jq -r '.firmware_url')
CHECKSUM=$(echo "$REMOTE_MANIFEST" | jq -r '.checksum_sha256')
CHANGELOG=$(echo "$REMOTE_MANIFEST" | jq -r '.changelog')

# Validate manifest
if [ -z "$REMOTE_VERSION" ] || [ "$REMOTE_VERSION" == "null" ]; then
    log "ERROR: Invalid manifest - no version found"
    exit 1
fi

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
log "Downloading update from $FIRMWARE_URL..."
curl -s --fail --max-time 120 -o /tmp/update.tar.gz "$FIRMWARE_URL" || {
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

# Clean old backups (keep last 5)
ls -t "$BACKUP_DIR"/backup-*.tar.gz 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null || true

# Extract update to temp location
log "Extracting update..."
rm -rf /tmp/baseline-update
mkdir -p /tmp/baseline-update
tar -xzf /tmp/update.tar.gz -C /tmp/baseline-update

# Apply update - HA config files (NEVER overwrite secrets.yaml)
log "Applying update..."
for file in configuration.yaml automations.yaml scripts.yaml customize.yaml; do
    if [ -f "/tmp/baseline-update/$file" ]; then
        cp "/tmp/baseline-update/$file" "$CONFIG_DIR/$file"
        log "Updated: $file"
    fi
done

# Update the agent itself if included in release
# THIS ALLOWS CHANGING THE MANIFEST_URL IN FUTURE RELEASES
if [ -f "/tmp/baseline-update/check-update.sh" ]; then
    cp "/tmp/baseline-update/check-update.sh" /opt/baseline/check-update.sh
    chmod +x /opt/baseline/check-update.sh
    log "Updated: check-update.sh (agent updated)"
fi

# Update install script if included
if [ -f "/tmp/baseline-update/install.sh" ]; then
    cp "/tmp/baseline-update/install.sh" /opt/baseline/install.sh
    chmod +x /opt/baseline/install.sh
    log "Updated: install.sh"
fi

# Update version file
echo "$REMOTE_VERSION" > "$LOCAL_VERSION_FILE"

# Cleanup
rm -rf /tmp/update.tar.gz /tmp/baseline-update

log "Update complete: $REMOTE_VERSION"
log "Restarting Home Assistant..."

# Restart Home Assistant (try multiple methods)
if command -v ha &> /dev/null; then
    ha core restart || log "WARNING: ha core restart failed"
else
    # Try via API if ha CLI not available
    curl -s -X POST http://supervisor/core/restart \
        -H "Authorization: Bearer $SUPERVISOR_TOKEN" 2>/dev/null || \
        log "WARNING: API restart failed - manual restart may be needed"
fi

log "=== Update finished ==="