#!/bin/bash
# Baseline Homes - Update Agent Installer
# Run this once on each new Pi to set up automatic updates
# Usage: curl -s https://raw.githubusercontent.com/botbuilder3/baseline-firmware/main/update-agent/install.sh | bash

set -e

echo "=== Baseline Homes Update Agent Installer ==="

# Create directories
mkdir -p /opt/baseline
mkdir -p /opt/baseline/backups

# Download the update script
echo "Downloading update agent..."
curl -s -o /opt/baseline/check-update.sh \
    https://raw.githubusercontent.com/botbuilder3/baseline-firmware/main/update-agent/check-update.sh

chmod +x /opt/baseline/check-update.sh

# Set initial version (will be updated on first check)
echo "1.0.0" > /opt/baseline/current_version

# Install jq if not present (needed for JSON parsing)
if ! command -v jq &> /dev/null; then
    echo "Installing jq..."
    apt-get update && apt-get install -y jq
fi

# Create cron job for nightly updates at 3 AM
echo "Setting up nightly update check..."
cat > /etc/cron.d/baseline-update << 'EOF'
# Baseline Homes - Check for updates at 3 AM
0 3 * * * root /opt/baseline/check-update.sh >> /opt/baseline/update.log 2>&1
EOF

chmod 644 /etc/cron.d/baseline-update

# Run initial check
echo "Running initial update check..."
/opt/baseline/check-update.sh || true

echo ""
echo "=== Installation Complete ==="
echo "Update agent installed to: /opt/baseline/check-update.sh"
echo "Logs will be at: /opt/baseline/update.log"
echo "Updates will check nightly at 3 AM"
echo ""
echo "To manually check for updates:"
echo "  /opt/baseline/check-update.sh"
