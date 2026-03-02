#!/usr/bin/env bash
# postCreate.sh - Idempotent dev-container setup for hetzner-bare-metal-fleet.
# Safe to re-run at any time; every step checks before acting.
#
# Python library deps (passlib, jmespath, netaddr) are injected into Ansible's
# pipx virtualenv via the devcontainer feature - no pip/PEP-668 concerns here.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANSIBLE_DIR="$REPO_ROOT/ansible"

echo "==> [1/3] Installing ansible-lint (isolated pipx env)"
pipx install ansible-lint --quiet 2>/dev/null || pipx upgrade ansible-lint --quiet

echo "==> [2/3] Installing Ansible collections"
# requirements.yml may be added later; guard against absence
REQUIREMENTS="$ANSIBLE_DIR/requirements.yml"
if [ -f "$REQUIREMENTS" ]; then
  ansible-galaxy collection install -r "$REQUIREMENTS" --collections-path "$ANSIBLE_DIR/collections"
else
  echo "     No $REQUIREMENTS found - skipping collection install"
fi

echo "==> [3/3] Creating vault password placeholder (if absent)"
VAULT_PASS="$ANSIBLE_DIR/.vault_pass"
if [ ! -f "$VAULT_PASS" ]; then
  echo "REPLACE_WITH_VAULT_PASSWORD" > "$VAULT_PASS"
  chmod 600 "$VAULT_PASS"
  echo "     Created $VAULT_PASS with placeholder - replace with real password"
else
  # Fix permissions silently if wrong
  chmod 600 "$VAULT_PASS"
  echo "     $VAULT_PASS already exists - permissions ensured (600)"
fi

echo "==> Verifying toolchain"
echo "     ansible      : $(ansible --version | head -n1)"
echo "     ansible-lint : $(ansible-lint --version 2>&1 | head -n1)"
echo "     gh           : $(gh --version | head -n1)"

echo ""
echo "Dev container ready."
echo "Set the vault password in $VAULT_PASS before running playbooks."
