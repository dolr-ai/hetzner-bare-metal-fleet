#!/usr/bin/env bash
# Idempotent setup for hetzner-bare-metal-fleet using mise.
# Replaces the old direnv + brew-based setup.
#
# Prerequisites:
#   - mise installed (https://mise.jdx.dev/installing-mise.html)
#     Quick install:  curl https://mise.run | sh
#   - Shell activated:  eval "$(mise activate bash)"   (or zsh/fish)
#
# Usage:
#   ./setup.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

echo "==> [1/3] Installing project tools via mise"
mise install

echo "==> [2/3] Installing Ansible Galaxy collections"
ansible-galaxy collection install -r "$REPO_ROOT/ansible/requirements.yml" \
  --collections-path "$REPO_ROOT/ansible/collections"

echo "==> [3/3] Setting up vault password file"
VAULT_PASS="$REPO_ROOT/ansible/.vault_pass"
if [ ! -f "$VAULT_PASS" ]; then
  echo "REPLACE_WITH_VAULT_PASSWORD" > "$VAULT_PASS"
  chmod 600 "$VAULT_PASS"
  echo "     Created $VAULT_PASS with placeholder — replace with real password"
else
  chmod 600 "$VAULT_PASS"
  echo "     $VAULT_PASS already exists — permissions ensured (600)"
fi

echo ""
echo "Setup complete"
echo "mise:    $(mise --version | head -n1)"
echo "ansible: $(ansible --version 2>/dev/null | head -n1 || echo 'run \"mise install\" then activate mise')"
