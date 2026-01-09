# Baseline Homes - Firmware Update System

**Last Updated:** January 9, 2026

## Overview

The firmware update system allows remote, automatic updates to all deployed Raspberry Pi devices running Home Assistant. Updates are checked nightly and applied automatically without customer intervention.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Repository                         │
│              botbuilder3/baseline-firmware                   │
│                                                              │
│  ┌─────────────┐  ┌──────────────────────────────────────┐  │
│  │manifest.json│  │ releases/                            │  │
│  │             │  │   baseline-1.0.0.tar.gz              │  │
│  │ - version   │  │   baseline-1.0.1.tar.gz              │  │
│  │ - checksum  │  │   ...                                │  │
│  │ - url       │  │                                      │  │
│  └─────────────┘  └──────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
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
│  │ /config/                                            │    │
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

**Location:** Repository root

**Structure:**
```json
{
  "version": "1.0.0",
  "release_date": "2026-01-09",
  "firmware_url": "https://raw.githubusercontent.com/botbuilder3/baseline-firmware/main/releases/baseline-1.0.0.tar.gz",
  "checksum_sha256": "2d243150cc55aa85f2acb3eb3b8758588114b6fc9cf311e39a21e721a574bec4",
  "min_agent_version": "1.0.0",
  "changelog": "Initial release - pet-aware sleep detection"
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

**Location:** `releases/baseline-X.X.X.tar.gz`

**Contents:**
```
baseline-1.0.0.tar.gz
├── configuration.yaml
├── automations.yaml
├── scripts.yaml
├── customize.yaml
└── check-update.sh      <- Optional: updates the agent itself
```

**Important:** Never include `secrets.yaml` in releases - it contains customer-specific data.

---

### 3. Update Agent (check-update.sh)

The script that runs on each Pi to check for and apply updates.

**Location on Pi:** `/opt/baseline/check-update.sh`

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
│ from GitHub      │
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
| configuration.yaml | ✅ Yes | Core HA config |
| automations.yaml | ✅ Yes | Alert logic |
| scripts.yaml | ✅ Yes | Helper scripts |
| customize.yaml | ✅ Yes | Entity customization |
| secrets.yaml | ❌ NEVER | Customer-specific data |
| check-update.sh | ✅ Yes | If included in release |

---

## Installation on New Devices

### Option 1: Pre-installed on Master Image (Recommended)

The update agent should be baked into the master Raspberry Pi image so all new devices have it from the start.

### Option 2: Manual Installation

SSH into the Pi and run:

```bash
curl -s https://raw.githubusercontent.com/botbuilder3/baseline-firmware/main/update-agent/install.sh | bash
```

This will:
1. Create `/opt/baseline/` directory
2. Download `check-update.sh`
3. Install `jq` if needed
4. Set up the cron job
5. Run an initial update check

---

## Creating a New Release

### Prerequisites

- Updated config files in `baseline-homes/ha-config/`
- Access to `baseline-firmware` repository

### Steps (Windows PowerShell)

```powershell
# 1. Navigate to firmware repo
cd C:\baseline-homes\baseline-firmware

# 2. Create temp folder and copy files
mkdir temp-release -Force
copy ..\baseline-homes\ha-config\configuration.yaml temp-release\
copy ..\baseline-homes\ha-config\automations.yaml temp-release\
copy ..\baseline-homes\ha-config\scripts.yaml temp-release\
copy ..\baseline-homes\ha-config\customize.yaml temp-release\

# 3. Include updated agent if needed
copy update-agent\check-update.sh temp-release\

# 4. Create the release package
tar -czvf releases\baseline-X.X.X.tar.gz -C temp-release .

# 5. Get the checksum
certutil -hashfile releases\baseline-X.X.X.tar.gz SHA256

# 6. Clean up
Remove-Item temp-release -Recurse

# 7. Update manifest.json with new version and checksum
notepad manifest.json

# 8. Commit and push
git add .
git commit -m "Release X.X.X: Description of changes"
git push
```

### Manifest Update Template

```json
{
  "version": "X.X.X",
  "release_date": "YYYY-MM-DD",
  "firmware_url": "https://raw.githubusercontent.com/botbuilder3/baseline-firmware/main/releases/baseline-X.X.X.tar.gz",
  "checksum_sha256": "PASTE_CHECKSUM_HERE",
  "min_agent_version": "1.0.0",
  "changelog": "Description of what changed"
}
```

---

## Monitoring & Troubleshooting

### View Update Logs

SSH into the Pi:

```bash
cat /opt/baseline/update.log
```

Or tail for live updates:

```bash
tail -f /opt/baseline/update.log
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
| "Failed to fetch manifest" | No internet / GitHub down | Check network, retry later |
| "Checksum mismatch" | Corrupted download | Will auto-retry next night |
| "ha core restart failed" | HA supervisor issue | Manual restart via UI |
| Updates not applying | Cron not running | Check `/etc/cron.d/baseline-update` |

### View Backups

```bash
ls -la /opt/baseline/backups/
```

### Manual Rollback

```bash
cd /config
tar -xzf /opt/baseline/backups/backup-X.X.X-YYYYMMDD-HHMMSS.tar.gz
ha core restart
```

---

## Changing the Update Source

To migrate devices to a new repository or URL:

1. Edit `check-update.sh` - change `MANIFEST_URL` at the top
2. Include the updated `check-update.sh` in your next release
3. Push to the CURRENT repository
4. Devices will download from old repo, get new script
5. Next update check will use the new URL

**Example migration:**

```bash
# In check-update.sh, change:
MANIFEST_URL="https://raw.githubusercontent.com/botbuilder3/baseline-firmware/main/manifest.json"

# To:
MANIFEST_URL="https://your-new-server.com/firmware/manifest.json"
```

---

## Security Considerations

| Risk | Mitigation |
|------|------------|
| Man-in-the-middle | HTTPS for all downloads |
| Tampered firmware | SHA256 checksum verification |
| Unauthorized access | Private GitHub repo |
| Failed updates | Automatic backups, keeps previous 5 |
| Bricked devices | HA restarts gracefully, manual recovery possible |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-01-09 | Initial release - pet-aware sleep detection, humidity logging |
| 1.0.1 | 2026-01-09 | Agent self-update capability, log rotation, better error handling |

---

## File Locations Summary

### On GitHub (baseline-firmware repo)

```
baseline-firmware/
├── manifest.json                 # Version info - devices check this
├── README.md                     # Repo readme
├── releases/
│   └── baseline-X.X.X.tar.gz    # Release packages
├── scripts/
│   └── create-release.sh        # Release helper (Linux/Mac)
└── update-agent/
    ├── check-update.sh          # The update script
    └── install.sh               # Bootstrap installer
```

### On Each Raspberry Pi

```
/opt/baseline/
├── check-update.sh              # Update agent
├── current_version              # Installed version (e.g., "1.0.0")
├── update.log                   # Activity log
├── install.sh                   # Installer (if updated)
└── backups/
    └── backup-X.X.X-*.tar.gz   # Config backups (last 5)

/config/
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

**Repository:** https://github.com/botbuilder3/baseline-firmware
