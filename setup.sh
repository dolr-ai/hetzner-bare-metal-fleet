#!/usr/bin/env bash
# Idempotent setup for hetzner-bare-metal-fleet on macOS.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> [1/4] Installing Ansible"
brew install ansible

echo "==> [2/4] Installing Python dependencies (pyproject.toml)"
"$(brew --prefix ansible)/libexec/bin/python3" -m pip install --quiet "$REPO_ROOT"

echo "==> [3/4] Installing Ansible collections (ansible/requirements.yml)"
ansible-galaxy collection install -r "$REPO_ROOT/ansible/requirements.yml" \
  --collections-path "$REPO_ROOT/ansible/collections"

echo "==> [4/4] Setting up vault password file"
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
echo "ansible: $(ansible --version | head -n1)"
