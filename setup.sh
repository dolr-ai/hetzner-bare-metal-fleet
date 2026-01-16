#!/bin/bash
# First-time repository setup script
# Run this once after cloning: source ./setup.sh

set -e

echo "========================================="
echo "Hetzner Bare Metal Fleet - Setup"
echo "========================================="
echo ""

# Configure git hooks
if [ -z "$(git config --local core.hooksPath 2>/dev/null)" ]; then
    echo "⚙️  Configuring git hooks for automatic secret encryption..."
    git config core.hooksPath "$(pwd)/hooks"
    echo "✓ Git hooks configured"
else
    echo "✓ Git hooks already configured"
fi

# Check for ansible
if ! command -v ansible-vault &> /dev/null; then
    echo ""
    echo "⚠️  Ansible is not installed"
    echo "Install it with: sudo apt install ansible-core"
    echo ""
else
    echo "✓ Ansible installed"
fi

# Check for vault password
if [ ! -f "ansible/.vault_pass" ]; then
    echo ""
    echo "⚠️  Vault password file not found"
    echo "Create it with:"
    echo "    echo 'your-vault-password' > ansible/.vault_pass"
    echo "    chmod 600 ansible/.vault_pass"
    echo ""
else
    echo "✓ Vault password file exists"
fi

echo ""
echo "========================================="
echo "Setup complete! 🚀"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. Ensure Ansible is installed (if not already)"
echo "  2. Create ansible/.vault_pass with your vault password"
echo "  3. Update host tokens in ansible/inventory/host_vars/"
echo ""
echo "The pre-commit hook will automatically encrypt secrets."
echo ""
