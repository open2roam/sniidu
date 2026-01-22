#!/usr/bin/env bash
# Generate secrets files for NixOS deployment
# This script is called by nixos-anywhere with extra_environment variables
# Files created here are copied to the target system's root filesystem

set -euo pipefail

# Create secrets directory (will be /var/lib/secrets on target)
mkdir -p var/lib/secrets

# Storage box credentials for WebDAV/DuckLake
cat > var/lib/secrets/storagebox.env << EOF
STORAGEBOX_SERVER=${STORAGEBOX_SERVER}
STORAGEBOX_PASSWORD=${STORAGEBOX_PASSWORD}
STORAGEBOX_ID=${STORAGEBOX_ID}
STORAGEBOX_WEBDAV_URL=https://${STORAGEBOX_SERVER}.your-storagebox.de
EOF

# Restrict permissions
chmod 600 var/lib/secrets/storagebox.env

echo "Generated storage box secrets"
