#!/usr/bin/env bash
# postCreate.sh - Idempotent dev-container setup for hetzner-bare-metal-fleet.
# Safe to re-run at any time; every step checks before acting.
#
# Python library deps (passlib, jmespath, netaddr) are injected into Ansible's
# pipx virtualenv via the devcontainer feature - no pip/PEP-668 concerns here.
set -euo pipefail

# Ensure pipx and user-installed binaries are on PATH (non-interactive shells may not source profile)
export PATH="$HOME/.local/bin:$PATH"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANSIBLE_DIR="$REPO_ROOT/ansible"

echo "==> [1/4] Installing ansible-lint (isolated pipx env)"
pipx install ansible-lint --quiet 2>/dev/null || pipx upgrade ansible-lint --quiet

echo "==> [2/4] Installing Ansible collections"
# requirements.yml may be added later; guard against absence
REQUIREMENTS="$ANSIBLE_DIR/requirements.yml"
if [ -f "$REQUIREMENTS" ]; then
  ansible-galaxy collection install -r "$REQUIREMENTS" --collections-path "$ANSIBLE_DIR/collections"
else
  echo "     No $REQUIREMENTS found - skipping collection install"
fi

echo "==> [3/4] Creating vault password placeholder (if absent)"
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

echo "==> [4/4] Extracting Ansible SSH key (if vault is unlocked)"
VAULT_CONTENT=$(cat "$VAULT_PASS" 2>/dev/null || true)
if [ "$VAULT_CONTENT" = "REPLACE_WITH_VAULT_PASSWORD" ] || [ -z "$VAULT_CONTENT" ]; then
  echo "     Vault password not set — skipping SSH key extraction"
else
  mkdir -p ~/.ssh
  if ansible-vault view "$ANSIBLE_DIR/inventory/group_vars/all/vault.yml" \
      --vault-password-file="$VAULT_PASS" 2>/dev/null \
      | awk '/vault_github_actions_ssh_private_key:/,/-----END OPENSSH PRIVATE KEY-----/' \
      | tail -n +2 | sed 's/^  //' > ~/.ssh/ansible_hetzner_fleet \
    && [ -s ~/.ssh/ansible_hetzner_fleet ]; then
    chmod 600 ~/.ssh/ansible_hetzner_fleet
    echo "     SSH key written to ~/.ssh/ansible_hetzner_fleet"
  else
    rm -f ~/.ssh/ansible_hetzner_fleet
    echo "     WARNING: Failed to extract SSH key from vault — check vault password"
  fi
fi

echo "==> Verifying toolchain"
echo "     ansible      : $(ansible --version | head -n1)"
echo "     ansible-lint : $(ansible-lint --version 2>&1 | head -n1)"
echo "     gh           : $(gh --version | head -n1)"

echo ""
echo "Dev container ready."
echo "Set the vault password in $VAULT_PASS before running playbooks."
