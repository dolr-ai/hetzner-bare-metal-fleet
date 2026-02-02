#!/usr/bin/env bash
set -euo pipefail

# Hetzner Bare Metal Fleet - Local Deployment Script
# This script helps run Ansible playbooks locally with vault support

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"
VAULT_PASS_FILE="$ANSIBLE_DIR/.vault_pass"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check for vault password file
check_vault_password() {
    if [ ! -f "$VAULT_PASS_FILE" ]; then
        print_error "Vault password file not found: $VAULT_PASS_FILE"
        echo ""
        echo "To set up vault access:"
        echo "  1. Get the vault password from your team lead"
        echo "  2. Create the password file: echo 'password' > $VAULT_PASS_FILE"
        echo "  3. Secure the file: chmod 600 $VAULT_PASS_FILE"
        echo ""
        exit 1
    fi
    
    # Check file permissions
    PERMS=$(stat -c %a "$VAULT_PASS_FILE" 2>/dev/null || stat -f %A "$VAULT_PASS_FILE" 2>/dev/null)
    if [ "$PERMS" != "600" ]; then
        print_warning "Vault password file has incorrect permissions: $PERMS"
        print_info "Fixing permissions..."
        chmod 600 "$VAULT_PASS_FILE"
    fi
    
    print_success "Vault password file found"
}

# Run ansible playbook
run_playbook() {
    local playbook=$1
    local extra_args="${2:-}"
    
    print_info "Running playbook: $playbook"
    
    cd "$ANSIBLE_DIR"
    
    if [ -n "$extra_args" ]; then
        ansible-playbook -i inventory/hosts.yml "playbooks/$playbook" $extra_args
    else
        ansible-playbook -i inventory/hosts.yml "playbooks/$playbook"
    fi
}

# Display menu
show_menu() {
    echo ""
    echo "=========================================="
    echo "  Hetzner Bare Metal Fleet"
    echo "  Local Management Menu"
    echo "=========================================="
    echo ""
    echo "Provisioning & Configuration:"
    echo "  1) Provision New Server (from rescue mode)"
    echo "  2) Configure SSH Security"
    echo "  3) Install/Update Docker"
    echo "  4) Deploy Beszel Monitoring Agent"
    echo "  5) Run System Updates"
    echo ""
    echo "Access Management:"
    echo "  6) Grant Temporary SSH Access"
    echo "  7) Activate Rescue Mode"
    echo ""
    echo "Vault Management:"
    echo "  8) View Vault (group_vars/all/vault.yml)"
    echo "  9) Edit Vault"
    echo "  10) Encrypt All Host Vault Files"
    echo ""
    echo "Utilities:"
    echo "  11) Test Connectivity (ping all hosts)"
    echo "  12) List All Hosts"
    echo ""
    echo "  0) Exit"
    echo ""
}

# Get host input
get_host_input() {
    local prompt="${1:-Enter hostname or group (or 'all' for all hosts)}"
    read -p "$prompt: " host_input
    if [ -z "$host_input" ]; then
        print_error "No host specified"
        return 1
    fi
    echo "$host_input"
}

# Encrypt all host vault files
encrypt_all_host_vaults() {
    print_info "Encrypting all host vault files..."
    cd "$ANSIBLE_DIR"
    
    local count=0
    for dir in inventory/host_vars/*/; do
        if [ -d "$dir" ]; then
            vault_file="${dir}vault.yml"
            if [ -f "$vault_file" ]; then
                # Check if already encrypted
                if head -n1 "$vault_file" | grep -q "ANSIBLE_VAULT"; then
                    print_info "$(basename $dir): already encrypted"
                else
                    ansible-vault encrypt "$vault_file"
                    print_success "$(basename $dir): encrypted"
                    ((count++))
                fi
            fi
        fi
    done
    
    echo ""
    print_success "Encrypted $count host vault file(s)"
}

# Main script
main() {
    echo "=========================================="
    echo " Hetzner Bare Metal Fleet"
    echo " Local Management Tool"
    echo "=========================================="
    echo ""
    
    # Check for vault password
    check_vault_password
    
    # Check for ansible
    if ! command -v ansible-playbook &> /dev/null; then
        print_error "Ansible not found. Please install Ansible first."
        echo "  Ubuntu/Debian: sudo apt install ansible"
        echo "  macOS: brew install ansible"
        echo "  pip: pip install ansible"
        exit 1
    fi
    
    print_success "Ansible found: $(ansible-playbook --version | head -n1)"
    
    # Interactive menu or direct playbook
    if [ $# -eq 0 ]; then
        while true; do
            show_menu
            read -p "Select option: " choice
            
            case $choice in
                1)
                    host=$(get_host_input "Enter hostname to provision") || continue
                    read -p "Force provision? (yes/no) [no]: " force
                    force_flag=""
                    if [ "$force" = "yes" ]; then
                        force_flag="--extra-vars force_provision=true"
                    fi
                    run_playbook "bare-metal-provision.yml" "--limit $host $force_flag"
                    ;;
                2)
                    host=$(get_host_input) || continue
                    run_playbook "ssh-security.yml" "--limit $host"
                    ;;
                3)
                    host=$(get_host_input) || continue
                    run_playbook "docker-setup.yml" "--limit $host"
                    ;;
                4)
                    host=$(get_host_input) || continue
                    run_playbook "beszel-agent-setup.yml" "--limit $host"
                    ;;
                5)
                    host=$(get_host_input) || continue
                    read -p "Allow automatic reboot? (yes/no) [no]: " reboot
                    reboot_flag=""
                    if [ "$reboot" = "yes" ]; then
                        reboot_flag="--extra-vars enable_reboot=true"
                    fi
                    run_playbook "system-update.yml" "--limit $host $reboot_flag"
                    ;;
                6)
                    host=$(get_host_input) || continue
                    echo "Available team members: jay, joel, kevin, naitik, ravi"
                    read -p "Enter team member name: " member
                    if [ -z "$member" ]; then
                        print_error "No team member specified"
                        continue
                    fi
                    run_playbook "hetzner-ssh-key-grant.yml" "--limit $host --extra-vars team_member_name=$member"
                    ;;
                7)
                    host=$(get_host_input "Enter hostname to activate rescue mode for") || continue
                    run_playbook "hetzner-rescue-activate.yml" "--limit $host"
                    ;;
                8)
                    print_info "Viewing vault contents..."
                    cd "$ANSIBLE_DIR"
                    ansible-vault view group_vars/all/vault.yml
                    ;;
                9)
                    print_info "Opening vault for editing..."
                    cd "$ANSIBLE_DIR"
                    ansible-vault edit group_vars/all/vault.yml
                    ;;
                10)
                    encrypt_all_host_vaults
                    ;;
                11)
                    print_info "Testing connectivity to all hosts..."
                    cd "$ANSIBLE_DIR"
                    ansible all -i inventory/hosts.yml -m ping
                    ;;
                12)
                    print_info "Listing all hosts in inventory..."
                    cd "$ANSIBLE_DIR"
                    ansible-inventory -i inventory/hosts.yml --list
                    ;;
                0)
                    print_info "Exiting..."
                    exit 0
                    ;;
                *)
                    print_error "Invalid option: $choice"
                    ;;
            esac
            
            echo ""
            read -p "Press Enter to continue..."
        done
    else
        # Direct playbook execution
        run_playbook "$1" "${2:-}"
    fi
}

main "$@"
