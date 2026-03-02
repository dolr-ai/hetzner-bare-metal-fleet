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
    
    if [ -n "$extra_args" ]; then
        ansible-playbook "$ANSIBLE_DIR/playbooks/$playbook" $extra_args
    else
        ansible-playbook "$ANSIBLE_DIR/playbooks/$playbook"
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
    echo "Primary Playbooks:"
    echo "  1) Provision new server           (provision.yml)"
    echo "  2) Weekly maintenance update      (weekly-update.yml)"
    echo "  3) Grant temporary SSH access     (ssh-access.yml)"
    echo ""
    echo "Individual Role Playbooks:"
    echo "  4) System update only             (system-update.yml)"
    echo "  5) SSH security / reset keys only (ssh-security.yml)"
    echo "  6) Docker install/verify only     (docker-setup.yml)"
    echo "  7) Beszel agent deploy only       (beszel-agent-setup.yml)"
    echo "  8) Activate rescue mode           (hetzner-rescue-activate.yml)"
    echo ""
    echo "Vault Management:"
    echo "  9) View Vault (group_vars/all/vault.yml)"
    echo "  10) Edit Vault"
    echo "  11) Encrypt All Host Vault Files"
    echo ""
    echo "Utilities:"
    echo "  12) Test Connectivity (ping all hosts)"
    echo "  13) List All Hosts"
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
    
    local count=0
    for dir in "$ANSIBLE_DIR"/inventory/host_vars/*/; do
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
                    read -p "Skip rescue activation? (yes/no) [no]: " skip_rescue
                    read -p "Force re-provision? (yes/no) [no]: " force
                    extra_flags=""
                    [ "$skip_rescue" = "yes" ] && extra_flags="$extra_flags --extra-vars skip_rescue_activation=true"
                    [ "$force" = "yes" ]       && extra_flags="$extra_flags --extra-vars force_provision=true"
                    run_playbook "provision.yml" "--limit $host $extra_flags"
                    ;;
                2)
                    host=$(get_host_input "Enter hostname/group or 'all' for all hosts") || continue
                    read -p "Allow automatic reboot? (yes/no) [no]: " reboot
                    reboot_flag=""
                    [ "$reboot" = "yes" ] && reboot_flag="--extra-vars enable_reboot=true"
                    run_playbook "weekly-update.yml" "--limit $host $reboot_flag"
                    ;;
                3)
                    host=$(get_host_input) || continue
                    echo "Available team members: jay, joel, kevin, mayank, naitik, ravi, samarth, sarvesh, shivam"
                    read -p "Enter team member name: " member
                    if [ -z "$member" ]; then
                        print_error "No team member specified"
                        continue
                    fi
                    run_playbook "ssh-access.yml" "--limit $host --extra-vars team_member_name=$member"
                    ;;
                4)
                    host=$(get_host_input) || continue
                    read -p "Allow automatic reboot? (yes/no) [no]: " reboot
                    reboot_flag=""
                    [ "$reboot" = "yes" ] && reboot_flag="--extra-vars enable_reboot=true"
                    run_playbook "system-update.yml" "--limit $host $reboot_flag"
                    ;;
                5)
                    host=$(get_host_input) || continue
                    run_playbook "ssh-security.yml" "--limit $host"
                    ;;
                6)
                    host=$(get_host_input) || continue
                    run_playbook "docker-setup.yml" "--limit $host"
                    ;;
                7)
                    host=$(get_host_input) || continue
                    run_playbook "beszel-agent-setup.yml" "--limit $host"
                    ;;
                8)
                    host=$(get_host_input "Enter hostname to activate rescue mode for") || continue
                    run_playbook "hetzner-rescue-activate.yml" "--limit $host"
                    ;;
                9)
                    print_info "Viewing vault contents..."
                    ansible-vault view "$ANSIBLE_DIR/inventory/group_vars/all/vault.yml"
                    ;;
                10)
                    print_info "Opening vault for editing..."
                    ansible-vault edit "$ANSIBLE_DIR/inventory/group_vars/all/vault.yml"
                    ;;
                11)
                    encrypt_all_host_vaults
                    ;;
                12)
                    print_info "Testing connectivity to all hosts..."
                    ansible all -m ping
                    ;;
                13)
                    print_info "Listing all hosts in inventory..."
                    ansible-inventory --list
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
