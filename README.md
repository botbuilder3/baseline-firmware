# Baseline Homes - Firmware Updates

This repo manages OTA (over-the-air) updates for Baseline Homes Raspberry Pi devices.

## Hosting

Firmware is self-hosted at `https://firmware.yourbaselinehome.com/` via Cloudflare tunnel.

**Current Version:** 1.7.0

## Architecture

```
baseline-firmware/
├── manifest.json              # Version info - Pis check this nightly
├── releases/
│   └── baseline-X.X.X.tar.gz  # Firmware packages
├── update-agent/
│   ├── check-update.sh        # Script that runs on each Pi
│   └── install.sh             # Bootstrap script for new Pis
└── scripts/
    └── create-release.sh      # Helper to package new releases
```

## How It Works

1. Each Pi runs `check-update.sh` nightly at 3 AM
2. Script fetches `manifest.json` from `firmware.yourbaselinehome.com`
3. Compares remote version to local version
4. If newer, downloads and applies the update
5. Restarts Home Assistant

## Files Updated (NEVER touches secrets.yaml)

- `configuration.yaml`
- `automations.yaml`
- `scripts.yaml`
- `customize.yaml`
- `check-update.sh` (self-updating)

## Config Directory

Home Assistant OS uses `/homeassistant/` for config files (not `/config/`).

## Installing on a New Pi

SSH into the Pi and run:

```bash
curl -s https://firmware.yourbaselinehome.com/update-agent/install.sh | bash
```

Or from GitHub (if repo is public):

```bash
curl -s https://raw.githubusercontent.com/botbuilder3/baseline-firmware/main/update-agent/install.sh | bash
```

## Creating a New Release

1. Update the HA config files in `baseline-home-v3/ha-config/`
2. Create temp folder and copy files:

```bash
mkdir temp-release
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
```

4. Update `manifest.json` with new version, URL, and checksum

5. Copy to server:

```bash
cat releases/baseline-X.X.X.tar.gz | ssh root@192.168.1.104 "pct exec 101 -- tee /opt/firmware/releases/baseline-X.X.X.tar.gz > /dev/null"
cat manifest.json | ssh root@192.168.1.104 "pct exec 101 -- tee /opt/firmware/manifest.json > /dev/null"
```

6. Commit and push to GitHub (as backup)

## Manual Update Check

On any Pi:

```bash
/opt/baseline/check-update.sh
```

## Viewing Logs

```bash
cat /opt/baseline/update.log
```

## Rollback

Backups are stored at `/opt/baseline/backups/` on each Pi.

To rollback:
```bash
cd /homeassistant
tar -xzf /opt/baseline/backups/backup-X.X.X-YYYYMMDD-HHMMSS.tar.gz
ha core restart
```

## Server Setup

Firmware is served from LXC 101:
- nginx on port 8084 serves `/opt/firmware/`
- Cloudflare tunnel routes `firmware.yourbaselinehome.com` to localhost:8084

## Security

- HTTPS via Cloudflare
- SHA256 checksum verification
- secrets.yaml is NEVER overwritten
- Automatic backups before updates

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-01-09 | Initial release |
| 1.6.0 | 2026-01-11 | Hardcoded webhook URLs, battery reporting |
| 1.7.0 | 2026-01-11 | Dumb pipe - removed alert logic from HA, n8n Rule Engine handles all alerts |
