# Baseline Homes - Firmware Update System

**Last Updated:** January 11, 2026

## Overview

The firmware update system allows remote, automatic updates to all deployed Raspberry Pi devices running Home Assistant. Updates are checked nightly and applied automatically without customer intervention.

**Hosting:** Self-hosted at `https://firmware.yourbaselinehome.com/` via Cloudflare tunnel.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  Self-Hosted Server (LXC 101)               │
│                                                              │
│  nginx :8084 → /opt/firmware/                               │
│  ┌─────────────┐  ┌──────────────────────────────────────┐  │
│  │manifest.json│  │ releases/                            │  │
│  │             │  │   baseline-1.7.0.tar.gz              │  │
│  │ - version   │  │   ...                                │  │
│  │ - checksum  │  │                                      │  │
│  │ - url       │  │                                      │  │
│  └─────────────┘  └──────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
              Cloudflare Tunnel (firmware.yourbaselinehome.com)
                              │
                              │ HTTPS (nightly at 3 AM)
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Customer Raspberry Pi                     │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ /opt/baseline/                                      │    │
│  │   check-update.sh    <- Update agent                │    │
│  │   current_version    <- Tracks installed version    │    │
│  │   update.log         <- Activity log                │    │
│  │   backups/           <- Config backups              │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ /homeassistant/                                     │    │
│  │   configuration.yaml  <- Updated by system          │    │
│  │   automations.yaml    <- Updated by system          │    │
│  │   scripts.yaml        <- Updated by system          │    │
│  │   customize.yaml      <- Updated by system          │    │
│  │   secrets.yaml        <- NEVER TOUCHED              │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

---

## Components

### 1. manifest.json

The manifest file tells devices what version is available and where to download it.

**Location:** `/opt/firmware/manifest.json` on server

**Structure:**
```json
{
  "version": "1.7.0",
  "release_date": "2026-01-11",
  "firmware_url": "https://firmware.yourbaselinehome.com/releases/baseline-1.7.0.tar.gz",
  "checksum_sha256": "13ec3b4ccec89f5992da88ab26ff3b054e66d760deb645105d10ba4db74c3035",
  "min_agent_version": "1.0.0",
  "changelog": "v1.7: Dumb pipe - removed all alert logic from HA"
}
```

| Field | Description |
|-------|-------------|
| version | Semantic version (X.Y.Z) |
| release_date | When released (YYYY-MM-DD) |
| firmware_url | Direct download URL for the release package |
| checksum_sha256 | SHA256 hash for verification |
| min_agent_version | Minimum agent version required (for future use) |
| changelog | Human-readable description of changes |

---

### 2. Release Packages

Tar.gz archives containing the updated configuration files.

**Location:** `/opt/firmware/releases/baseline-X.X.X.tar.gz` on server

**Contents:**
```
baseline-1.7.0.tar.gz
├── configuration.yaml
├── automations.yaml
├── scripts.yaml
├── customize.yaml
└── check-update.sh      <- Updates the agent itself
```

**Important:** Never include `secrets.yaml` in releases - it contains customer-specific data.

---

### 3. Update Agent (check-update.sh)

The script that runs on each Pi to check for and apply updates.

**Location on Pi:** `/opt/baseline/check-update.sh`

**Key Configuration:**
```bash
MANIFEST_URL="https://firmware.yourbaselinehome.com/manifest.json"
CONFIG_DIR="/homeassistant"
```

**Features:**
- Nightly version check against manifest
- SHA256 checksum verification
- Automatic backup before updates
- Self-updating capability
- Log rotation (keeps last 1000 lines)
- Backup cleanup (keeps last 5)
- Multiple restart methods (CLI and API)

**Cron Schedule:** 3:00 AM daily

---

## Update Flow

```
┌──────────────────┐
│ Cron triggers    │
│ at 3 AM          │
└────────┬─────────┘
         ▼
┌──────────────────┐
│ Fetch manifest   │
│ from server      │
└────────┬─────────┘
         ▼
┌──────────────────┐     ┌─────────────────┐
│ Compare versions │────►│ Same? Exit.     │
└────────┬─────────┘     └─────────────────┘
         ▼ Different
┌──────────────────┐
│ Download release │
│ package          │
└────────┬─────────┘
         ▼
┌──────────────────┐     ┌─────────────────┐
│ Verify checksum  │────►│ Mismatch? Abort │
└────────┬─────────┘     └─────────────────┘
         ▼ Valid
┌──────────────────┐
│ Backup current   │
│ config files     │
└────────┬─────────┘
         ▼
┌──────────────────┐
│ Extract & apply  │
│ new files        │
└────────┬─────────┘
         ▼
┌──────────────────┐
│ Update agent     │
│ (if included)    │
└────────┬─────────┘
         ▼
┌──────────────────┐
│ Update version   │
│ file             │
└────────┬─────────┘
         ▼
┌──────────────────┐
│ Restart Home     │
│ Assistant        │
└──────────────────┘
```

---

## Files Updated vs Protected

| File | Updated | Notes |
|------|---------|-------|
| configuration.yaml | ✅ Yes | Core HA config, hardcoded webhook URLs |
| automations.yaml | ✅ Yes | Event logging (dumb pipe) |
| scripts.yaml | ✅ Yes | Helper scripts |
| customize.yaml | ✅ Yes | Entity customization |
| check-update.sh | ✅ Yes | Self-updating agent |
| secrets.yaml | ❌ NEVER | Customer-specific data |

---

## Installation on New Devices

### Option 1: Pre-installed on Master Image (Recommended)

The update agent should be baked into the master Raspberry Pi image so all new devices have it from the start.

### Option 2: Manual Installation

SSH into the Pi and run:

```bash
curl -s https://firmware.yourbaselinehome.com/update-agent/install.sh | bash
```

This will:
1. Create `/opt/baseline/` directory
2. Download `check-update.sh`
3. Install `jq` if needed
4. Set up the cron job
5. Run an initial update check

---

## Creating a New Release

### Steps

1. Update the HA config files in `baseline-home-v3/ha-config/`

2. Create temp folder and copy files:

```bash
mkdir -p temp-release
cp ../baseline-home-v3/ha-config/configuration.yaml temp-release/
cp ../baseline-home-v3/ha-config/automations.yaml temp-release/
cp ../baseline-home-v3/ha-config/scripts.yaml temp-release/
cp ../baseline-home-v3/ha-config/customize.yaml temp-release/
cp update-agent/check-update.sh temp-release/
```

3. Create tarball and get checksum:

```bash
cd temp-release && tar -czf ../releases/baseline-X.X.X.tar.gz . && cd ..
sha256sum releases/baseline-X.X.X.tar.gz
rm -rf temp-release
```

4. Update `manifest.json` with new version, URL, and checksum

5. Copy to server:

```bash
cat releases/baseline-X.X.X.tar.gz | ssh root@192.168.1.104 "pct exec 101 -- tee /opt/firmware/releases/baseline-X.X.X.tar.gz > /dev/null"
cat manifest.json | ssh root@192.168.1.104 "pct exec 101 -- tee /opt/firmware/manifest.json > /dev/null"
```

6. Commit and push to GitHub (as backup)

---

## Server Setup

### nginx Configuration

File: `/etc/nginx/sites-available/firmware`

```nginx
server {
    listen 8084;
    server_name _;
    root /opt/firmware;

    location / {
        autoindex off;
        try_files $uri =404;
    }

    location = /manifest.json {
        add_header Cache-Control "no-cache";
    }

    location /releases/ {
        add_header Cache-Control "public, max-age=86400";
    }
}
```

### Cloudflare Tunnel

In `/etc/cloudflared/config.yml`:

```yaml
ingress:
  - hostname: firmware.yourbaselinehome.com
    service: http://localhost:8084
```

### Directory Structure

```
/opt/firmware/
├── manifest.json
├── releases/
│   ├── baseline-1.0.0.tar.gz
│   ├── baseline-1.6.0.tar.gz
│   └── baseline-1.7.0.tar.gz
└── update-agent/
    ├── check-update.sh
    └── install.sh
```

---

## Monitoring & Troubleshooting

### View Update Logs

SSH into the Pi:

```bash
cat /opt/baseline/update.log
```

### Check Current Version

```bash
cat /opt/baseline/current_version
```

### Manual Update Check

```bash
/opt/baseline/check-update.sh
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "Failed to fetch manifest" | No internet / server down | Check network, verify server is up |
| "Checksum mismatch" | Corrupted download | Will auto-retry next night |
| "ha core restart failed" | HA supervisor issue | Manual restart via UI |
| Updates not applying | Cron not running | Check `/etc/cron.d/baseline-update` |

### View Backups

```bash
ls -la /opt/baseline/backups/
```

### Manual Rollback

```bash
cd /homeassistant
tar -xzf /opt/baseline/backups/backup-X.X.X-YYYYMMDD-HHMMSS.tar.gz
ha core restart
```

---

## Security Considerations

| Risk | Mitigation |
|------|------------|
| Man-in-the-middle | HTTPS via Cloudflare |
| Tampered firmware | SHA256 checksum verification |
| DDoS attacks | Cloudflare protection |
| Failed updates | Automatic backups, keeps previous 5 |
| Bricked devices | HA restarts gracefully, manual recovery possible |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-01-09 | Initial release - pet-aware sleep detection, humidity logging |
| 1.6.0 | 2026-01-11 | Hardcoded webhook URLs (fixes bad installs), battery reporting |
| 1.7.0 | 2026-01-11 | Dumb pipe architecture - all alert logic moved to n8n Rule Engine |

---

## File Locations Summary

### On Server (LXC 101)

```
/opt/firmware/
├── manifest.json                 # Version info - devices check this
├── releases/
│   └── baseline-X.X.X.tar.gz    # Release packages
└── update-agent/
    ├── check-update.sh          # The update script
    └── install.sh               # Bootstrap installer
```

### On Each Raspberry Pi

```
/opt/baseline/
├── check-update.sh              # Update agent
├── current_version              # Installed version (e.g., "1.7.0")
├── update.log                   # Activity log
└── backups/
    └── backup-X.X.X-*.tar.gz   # Config backups (last 5)

/homeassistant/
├── configuration.yaml           # HA config (updated by system)
├── automations.yaml             # Automations (updated by system)
├── scripts.yaml                 # Scripts (updated by system)
├── customize.yaml               # Customizations (updated by system)
└── secrets.yaml                 # Customer secrets (NEVER touched)

/etc/cron.d/
└── baseline-update              # Cron job (3 AM daily)
```

---

## Support

**Logs location:** `/opt/baseline/update.log`

**Manual check:** `/opt/baseline/check-update.sh`

**Server files:** `/opt/firmware/` on LXC 101

**Public URL:** https://firmware.yourbaselinehome.com/
