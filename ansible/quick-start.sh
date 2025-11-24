#!/bin/bash

# Quick Start Script for Ansible Setup
# This script helps you get started with the Ansible configuration

set -e

echo "🚀 Ansible Quick Start for Hetzner Bare Metal Fleet"
echo "=================================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if we're in the ansible directory
if [[ ! -f "ansible.cfg" ]]; then
    print_error "Please run this script from the ansible directory"
    print_error "cd ansible && ./quick-start.sh"
    exit 1
fi

# Check if Ansible is installed
print_step "Checking Ansible installation..."
if ! command -v ansible &> /dev/null; then
    print_warning "Ansible not found. Installing via pip..."
    pip install ansible ansible-core
    ansible-galaxy collection install ansible.posix community.general
    print_status "Ansible installed successfully"
else
    print_status "Ansible is already installed: $(ansible --version | head -1)"
fi

# Check inventory file
print_step "Checking inventory configuration..."
if [[ ! -f "inventory/hosts.yml" ]]; then
    print_error "Inventory file not found at inventory/hosts.yml"
    exit 1
fi

# Check SSH key
print_step "Checking SSH key configuration..."
SSH_KEY_PATH="$HOME/.ssh/id_ed25519"
if [[ ! -f "$SSH_KEY_PATH" ]]; then
    print_warning "SSH private key not found at $SSH_KEY_PATH"
    read -p "Enter path to your SSH private key: " SSH_KEY_PATH
    if [[ ! -f "$SSH_KEY_PATH" ]]; then
        print_error "SSH key not found at $SSH_KEY_PATH"
        exit 1
    fi
fi

# Test SSH key permissions
if [[ $(stat -c %a "$SSH_KEY_PATH") != "600" ]]; then
    print_warning "SSH key permissions are not secure. Fixing..."
    chmod 600 "$SSH_KEY_PATH"
    print_status "SSH key permissions fixed"
fi

# Display available operations
echo ""
print_step "Available operations:"
echo "1. Test connectivity (ping all hosts)"
echo "2. Run system update (comprehensive system maintenance)"
echo "3. Run Docker setup (install Docker if missing)"
echo "4. Run SSH security audit and configuration"
echo "5. Check what would be updated (dry run)"
echo "6. Update specific host"
echo "7. Update by server group"
echo "8. Show inventory"
echo "9. Exit"
echo ""

while true; do
    read -p "Select an option [1-9]: " choice
    case $choice in
        1)
            print_step "Testing connectivity to all hosts..."
            if ansible all -m ping; then
                print_status "All reachable hosts are responding!"
            else
                print_warning "Some hosts may not be reachable. Check your SSH configuration."
            fi
            ;;
        2)
            print_step "Running system update on all hosts..."
            ansible-playbook playbooks/system-update.yml
            ;;
        3)
            print_step "Running Docker setup..."
            ansible-playbook playbooks/docker-setup.yml
            ;;
        4)
            print_step "Running SSH security audit..."
            ansible-playbook playbooks/ssh-security.yml
            ;;
        5)
            print_step "Running dry run (check mode)..."
            ansible-playbook playbooks/system-update.yml --check --diff
            ;;
        6)
            print_step "Available hosts:"
            echo "- data-science-staging-1"
            echo "- dragonfly-db-1"
            echo "- github-action-runner-1"
            echo "- milvus-1"
            echo "- postgres-1"
            echo "- sentry-1"
            echo "- storj-interface-1"
            echo "- team-dev-server-1"
            echo "- uptime-monitor-1"
            echo ""
            read -p "Enter hostname to update: " hostname
            if [[ -n "$hostname" ]]; then
                print_step "Updating $hostname..."
                ansible-playbook playbooks/system-update.yml --limit "$hostname"
            else
                print_warning "No hostname provided"
            fi
            ;;
        8)
            print_step "Available server groups:"
            echo "- databases (dragonfly-db-1, postgres-1, milvus-1)"
            echo "- development (data-science-staging-1, team-dev-server-1)"
            echo "- infrastructure (github-action-runner-1, uptime-monitor-1)"
            echo "- applications (sentry-1, storj-interface-1)"
            echo ""
            read -p "Enter group name to update: " group
            if [[ -n "$group" ]]; then
                print_step "Updating $group group..."
                ansible-playbook playbooks/system-update.yml --limit "$group"
            else
                print_warning "No group name provided"
            fi
            ;;
        8)
            print_step "Current inventory:"
            echo "=================="
            cat inventory/hosts.yml
            echo "=================="
            ;;
        9)
            print_status "Goodbye!"
            exit 0
            ;;
        *)
            print_warning "Invalid option. Please select 1-9."
            ;;
    esac
    echo ""
    echo "Press Enter to continue..."
    read
    echo ""
done
