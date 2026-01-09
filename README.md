# Baseline Homes - Firmware Updates

This repo manages OTA (over-the-air) updates for Baseline Homes Raspberry Pi devices.

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
2. Script fetches `manifest.json` from this repo
3. Compares remote version to local version
4. If newer, downloads and applies the update
5. Restarts Home Assistant

## Files Updated (NEVER touches secrets.yaml)

- `configuration.yaml`
- `automations.yaml`
- `scripts.yaml`
- `customize.yaml`

## Installing on a New Pi

SSH into the Pi and run:

```bash
curl -s https://raw.githubusercontent.com/botbuilder3/baseline-firmware/main/update-agent/install.sh | bash
```

## Creating a New Release

1. Update the HA config files in `baseline-homes` repo
2. Run the release script:

```bash
./scripts/create-release.sh 1.0.1 "Fixed bathroom duration calculation"
```

3. Commit and push

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
cd /config
tar -xzf /opt/baseline/backups/backup-X.X.X-YYYYMMDD-HHMMSS.tar.gz
ha core restart
```

## Security

- HTTPS for all downloads
- SHA256 checksum verification
- secrets.yaml is NEVER overwritten
- Automatic backups before updates
