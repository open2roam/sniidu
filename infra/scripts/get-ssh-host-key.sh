#!/usr/bin/env bash
# Extracts SSH host keys from SOPS and storage box credentials
# Called by nixos-anywhere during deployment
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# SSH host keys from SOPS
secret_file="$SCRIPT_DIR/../../secrets/hosts/$NIXOS_SYSTEM_NAME.yaml"

if [ -f "$secret_file" ]; then
  mkdir -p "./etc/ssh"

  for keyname in ssh_host_ed25519_key ssh_host_ed25519_key.pub; do
    if [[ $keyname == *.pub ]]; then
      umask 0133
    else
      umask 0177
    fi
    sops --extract '["'"$keyname"'"]' -d "$secret_file" >"./etc/ssh/$keyname"
  done
  echo "Extracted SSH host keys"
else
  echo "Warning: No SSH host key file at $secret_file, will generate new keys"
fi

# Storage box credentials
if [ -n "${STORAGEBOX_SERVER:-}" ]; then
  mkdir -p "./var/lib/secrets"

  cat >./var/lib/secrets/storagebox.env <<EOF
STORAGEBOX_SERVER=${STORAGEBOX_SERVER}
STORAGEBOX_PASSWORD=${STORAGEBOX_PASSWORD}
STORAGEBOX_ID=${STORAGEBOX_ID}
STORAGEBOX_WEBDAV_URL=https://${STORAGEBOX_SERVER}
EOF

  chmod 600 ./var/lib/secrets/storagebox.env
  echo "Generated storage box credentials"
fi
