#!/bin/bash
# Helper script to encrypt beszel agent tokens for all hosts
# Usage: ./encrypt-beszel-tokens.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_VARS_DIR="$SCRIPT_DIR/ansible/inventory/host_vars"

# List of all hosts
HOSTS=(
    "airflow-1"
    "clickhouse-keeper-1"
    "clickhouse-keeper-2"
    "clickhouse-keeper-3"
    "clickhouse-replica-1"
    "clickhouse-replica-2"
    "data-science-staging-1"
    "dragonfly-db-1"
    "github-action-runner-1"
    "low-traffic-1"
    "milvus-1"
    "sentry-1"
    "storj-interface-1"
    "team-dev-server-1"
    "uptime-monitor-1"
)

echo "========================================="
echo "Beszel Agent Token Encryption Helper"
echo "========================================="
echo ""
echo "This script will help you set and encrypt beszel agent tokens for all hosts."
echo ""
echo "Prerequisites:"
echo "1. You have created ansible/.vault_pass with your vault password"
echo "2. You have obtained tokens from your beszel hub at https://beszel.yral.com"
echo ""
read -p "Do you want to continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Check if vault password file exists
if [ ! -f "$SCRIPT_DIR/ansible/.vault_pass" ]; then
    echo "ERROR: ansible/.vault_pass not found!"
    echo "Please create it first: echo 'your-password' > ansible/.vault_pass"
    exit 1
fi

echo ""
echo "You can either:"
echo "  1. Edit each host file manually with: ansible-vault edit <hostname>.yml"
echo "  2. Use this script to encrypt all files at once"
echo ""
read -p "Choose option (1 for manual, 2 for batch): " -n 1 -r OPTION
echo

if [ "$OPTION" == "1" ]; then
    echo ""
    echo "Edit each host file manually:"
    for host in "${HOSTS[@]}"; do
        echo "  cd $HOST_VARS_DIR && ansible-vault edit ${host}.yml"
    done
    echo ""
    echo "Replace PLACEHOLDER_TOKEN_HERE with actual tokens from beszel hub."
    exit 0
fi

if [ "$OPTION" == "2" ]; then
    echo ""
    echo "WARNING: This will encrypt all host_vars files using the vault password."
    echo "Make sure you have replaced PLACEHOLDER_TOKEN_HERE with actual tokens first!"
    echo ""
    read -p "Have you updated all tokens? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Please update tokens first, then run this script again."
        exit 0
    fi
    
    echo ""
    echo "Encrypting all host_vars files..."
    cd "$HOST_VARS_DIR"
    
    for host in "${HOSTS[@]}"; do
        if [ -f "${host}.yml" ]; then
            if ansible-vault view "${host}.yml" &>/dev/null; then
                echo "  ✓ ${host}.yml is already encrypted"
            else
                ansible-vault encrypt "${host}.yml"
                echo "  ✓ Encrypted ${host}.yml"
            fi
        else
            echo "  ✗ ${host}.yml not found"
        fi
    done
    
    echo ""
    echo "Done! All files have been encrypted."
    echo ""
    echo "To edit a file: ansible-vault edit <hostname>.yml"
    echo "To decrypt a file: ansible-vault decrypt <hostname>.yml"
    echo "To view a file: ansible-vault view <hostname>.yml"
fi
