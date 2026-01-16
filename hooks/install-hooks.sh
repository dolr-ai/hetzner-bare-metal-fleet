#!/bin/bash
# Script to configure git to use hooks from the tracked hooks/ directory

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Configuring git hooks..."

# Configure git to use the hooks/ directory
git config core.hooksPath "$REPO_ROOT/hooks"

echo "✓ Git configured to use hooks from hooks/ directory"
echo ""
echo "Git hooks setup complete!"
echo ""
echo "The pre-commit hook will automatically encrypt host_vars/*.yml files"
echo "before committing to ensure secrets are never committed unencrypted."
echo ""
echo "Hooks will be automatically available after git checkout/clone."
