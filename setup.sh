#!/bin/bash
# First-time repository setup script
# Run this once after cloning: ./setup.sh

set -e

echo "========================================="
echo "Hetzner Bare Metal Fleet - Setup"
echo "========================================="
echo ""

# Check for ansible
if ! command -v ansible &> /dev/null; then
    echo "⚠️  Ansible is not installed"
    echo "Install it with:"
    echo "    Ubuntu/Debian: sudo apt install ansible"
    echo "    macOS: brew install ansible"
    echo "    pip: pip install ansible"
    echo ""
    exit 1
else
    echo "✓ Ansible installed: $(ansible --version | head -n1)"
fi

# Check for vault password
VAULT_PASS_FILE="ansible/.vault_pass"
if [ ! -f "$VAULT_PASS_FILE" ]; then
    echo ""
    echo "⚠️  Vault password file not found"
    echo ""
    echo "Create it with:"
    echo "    echo 'your-vault-password' > $VAULT_PASS_FILE"
    echo "    chmod 600 $VAULT_PASS_FILE"
    echo ""
    echo "Get the vault password from your team lead or password manager."
    exit 1
else
    # Check file permissions
    PERMS=$(stat -c %a "$VAULT_PASS_FILE" 2>/dev/null || stat -f %A "$VAULT_PASS_FILE" 2>/dev/null)
    if [ "$PERMS" != "600" ]; then
        echo "⚠️  Fixing vault password file permissions..."
        chmod 600 "$VAULT_PASS_FILE"
    fi
    echo "✓ Vault password file exists with correct permissions"
fi

# Test vault access
echo ""
echo "Testing vault access..."
if ansible-vault view ansible/group_vars/all/vault.yml > /dev/null 2>&1; then
    echo "✓ Vault password is correct"
else
    echo "❌ Vault password is incorrect or vault file is corrupted"
    exit 1
fi

echo ""
echo "========================================="
echo "Setup complete! 🚀"
echo "========================================="
echo ""
echo "You can now:"
echo "  • Run playbooks locally: cd ansible && ansible-playbook ..."
echo "  • Use the helper script: ./scripts/run-local.sh"
echo "  • Edit vault secrets: ansible-vault edit ansible/group_vars/all/vault.yml"
echo ""
