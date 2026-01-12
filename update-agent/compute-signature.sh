#!/bin/bash
# Baseline Homes - Webhook Signature Generator
# Computes HMAC-SHA256 signature for webhook authentication
# Location: /opt/baseline/compute-signature.sh

# Usage: compute-signature.sh "<payload_json>" "<webhook_secret>"
# Output: signature|timestamp (pipe-separated)

PAYLOAD="$1"
SECRET="$2"

# Validate inputs
if [ -z "$PAYLOAD" ] || [ -z "$SECRET" ]; then
    echo "error|0"
    exit 1
fi

# Get current Unix timestamp
TIMESTAMP=$(date +%s)

# Create signing string: timestamp.payload
SIGNING_STRING="${TIMESTAMP}.${PAYLOAD}"

# Compute HMAC-SHA256 (hex output, lowercase)
SIGNATURE=$(echo -n "$SIGNING_STRING" | openssl dgst -sha256 -hmac "$SECRET" 2>/dev/null | awk '{print $2}')

# Validate signature was generated
if [ -z "$SIGNATURE" ] || [ ${#SIGNATURE} -ne 64 ]; then
    echo "error|0"
    exit 1
fi

# Output: signature|timestamp
echo "${SIGNATURE}|${TIMESTAMP}"
