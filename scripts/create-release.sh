#!/bin/bash
# Baseline Homes - Create Release Package
# Usage: ./create-release.sh 1.0.1 "Description of changes"

set -e

VERSION=$1
CHANGELOG=$2
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
RELEASES_DIR="$REPO_ROOT/releases"
MANIFEST_FILE="$REPO_ROOT/manifest.json"

# Source files - update this path to your baseline-homes repo
SOURCE_DIR="${BASELINE_HOMES_DIR:-../baseline-homes/ha-config}"

if [ -z "$VERSION" ] || [ -z "$CHANGELOG" ]; then
    echo "Usage: $0 <version> <changelog>"
    echo "Example: $0 1.0.1 'Fixed bathroom duration calculation'"
    exit 1
fi

echo "=== Creating Release $VERSION ==="

# Ensure releases directory exists
mkdir -p "$RELEASES_DIR"

# Create temp directory for packaging
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Copy files to temp directory
echo "Copying configuration files..."
for file in configuration.yaml automations.yaml scripts.yaml customize.yaml; do
    if [ -f "$SOURCE_DIR/$file" ]; then
        cp "$SOURCE_DIR/$file" "$TEMP_DIR/"
        echo "  - $file"
    else
        echo "  WARNING: $file not found in $SOURCE_DIR"
    fi
done

# Create tarball
TARBALL="$RELEASES_DIR/baseline-$VERSION.tar.gz"
echo "Creating tarball..."
tar -czf "$TARBALL" -C "$TEMP_DIR" .

# Calculate checksum
CHECKSUM=$(sha256sum "$TARBALL" | cut -d' ' -f1)
echo "Checksum: $CHECKSUM"

# Update manifest
echo "Updating manifest.json..."
cat > "$MANIFEST_FILE" << EOF
{
  "version": "$VERSION",
  "release_date": "$(date '+%Y-%m-%d')",
  "firmware_url": "https://raw.githubusercontent.com/botbuilder3/baseline-firmware/main/releases/baseline-$VERSION.tar.gz",
  "checksum_sha256": "$CHECKSUM",
  "min_agent_version": "1.0.0",
  "changelog": "$CHANGELOG"
}
EOF

echo ""
echo "=== Release $VERSION Created ==="
echo "Tarball: $TARBALL"
echo "Manifest updated: $MANIFEST_FILE"
echo ""
echo "Next steps:"
echo "  git add ."
echo "  git commit -m 'Release $VERSION: $CHANGELOG'"
echo "  git push"
