# Hetzner Bare Metal Fleet

Ansible-based automation for provisioning and managing Hetzner bare metal servers with Ubuntu 24.04, btrfs, Docker, and monitoring.

## Features

- 🚀 Automated bare metal server provisioning from rescue mode
- 🔐 Ansible Vault for secure credential management  
- 🐳 Docker and Docker Compose setup
- 📊 Beszel monitoring agent deployment
- 🔑 SSH access management
- ⚙️ Fleet-wide maintenance automation
- 🌐 Local and GitHub Actions execution

## Quick Start

### For New Contributors

1. Clone and run setup:
```bash
git clone https://github.com/dolr-ai/hetzner-bare-metal-fleet.git
cd hetzner-bare-metal-fleet
./setup.sh
```

2. Get vault password from team lead:
```bash
echo 'your-vault-password' > ansible/.vault_pass
chmod 600 ansible/.vault_pass
```

3. Start using the interactive menu:
```bash
./scripts/run-local.sh
```

## Repository Structure

```
ansible/
├── group_vars/all/
│   ├── vars.yml          # Public variables
│   └── vault.yml         # Encrypted secrets
├── inventory/
│   ├── hosts.yml         # Server inventory  
│   └── host_vars/*/      # Per-host vars & vault files
└── playbooks/            # All automation playbooks

scripts/
└── run-local.sh          # Interactive management tool

.github/workflows/        # GitHub Actions automation
```

## Usage

### Local Execution (Recommended)

**Interactive menu:**
```bash
./scripts/run-local.sh
```

**Direct playbook execution:**
```bash
ansible-playbook ansible/playbooks/bare-metal-provision.yml --limit airflow-1
ansible-playbook ansible/playbooks/docker-setup.yml --limit all
```

### GitHub Actions

**Provision new server:**
Actions → Provision and Configure Bare Metal Server → Run workflow

**Fleet maintenance:**
Actions → Fleet Maintenance → Run workflow (or auto-runs Sundays 2AM UTC)

**Grant temporary SSH access:**
Actions → Grant Temporary SSH Access → Select team member + host

## Key Playbooks

| Playbook | Purpose |
|----------|---------|
| `bare-metal-provision.yml` | Full server provisioning from rescue mode |
| `hetzner-rescue-activate.yml` | Activate Hetzner rescue mode via API |
| `hetzner-ssh-key-grant.yml` | Grant temporary SSH access to team members |
| `ssh-security.yml` | SSH hardening & key deployment |
| `docker-setup.yml` | Install Docker CE |
| `beszel-agent-setup.yml` | Deploy monitoring agent |
| `system-update.yml` | System updates with optional reboot |
| `retry-failed-hosts.yml` | Retry connections to previously failed hosts |

## Retry Failed Hosts

All playbooks now include automatic retry logic for connection failures. When hosts fail to connect:

1. **Automatic retries** - 3 connection attempts with 10-second delays
2. **Retry files** - Automatically saved to `ansible/retry/`
3. **Partial failures** - Up to 50% of hosts can fail without stopping the workflow

### Quick Retry Examples

```bash
# Retry a specific failed host
ansible-playbook ansible/playbooks/system-update.yml --limit offchain-agent-1

# Use auto-generated retry file
ansible-playbook ansible/playbooks/system-update.yml --limit @ansible/retry/system-update.retry

# Or via GitHub Actions - set target_hosts to the failed hostname
```

**📖 Full retry guide:** See [RETRY_GUIDE.md](RETRY_GUIDE.md) for detailed instructions and troubleshooting.

## Vault Management

### Structure

Secrets use a two-file pattern for discoverability:

**vars.yml (plaintext):**
```yaml
hetzner_robot_password: "{{ vault_hetzner_robot_password }}"
```

**vault.yml (encrypted):**
```yaml
vault_hetzner_robot_password: "actual-secret"
```

### Editing Secrets

```bash
# Edit group-wide secrets
ansible-vault edit ansible/group_vars/all/vault.yml

# Edit host-specific secrets
ansible-vault edit ansible/inventory/host_vars/airflow-1/vault.yml

# View without editing
ansible-vault view ansible/group_vars/all/vault.yml
```

### Adding New Secrets

1. Add reference in plaintext `vars.yml`
2. Add encrypted value in `vault.yml` using `ansible-vault edit`

## Troubleshooting

### Vault Issues

```bash
# Verify vault password file
ls -la ansible/.vault_pass  # Should show: -rw------- (600)

# Test vault access
ansible-vault view ansible/group_vars/all/vault.yml
```

### Rescue Mode

**"installimage: command not found"** - Not in rescue mode:
1. Activate rescue mode in Hetzner Robot
2. Hardware reset server
3. Wait 1-2 minutes, then SSH in
4. Verify: `test -f /root/.oldroot/nfs/install/installimage && echo "OK"`

**"Drive not found"** - Check with `lsblk -d`
- NVMe: `nvme0n1`, `nvme1n1`
- SATA: `sda`, `sdb`

### Connectivity

```bash
# Test all hosts
ansible all -m ping --limit hostname

# Verify inventory
ansible-inventory --list
```

## Adding New Servers

1. Add to `ansible/inventory/hosts.yml`:
```yaml
bare_metal:
  hosts:
    new-server:
      ansible_host: 1.2.3.4
```

2. Create host vars:
```bash
mkdir ansible/inventory/host_vars/new-server
# Create vars.yml and vault.yml
```

3. Provision via GitHub Actions or `./scripts/run-local.sh`

## Contributing

- Never commit unencrypted secrets
- Test locally before pushing
- Use vault pattern for all secrets
- Update this README for significant changes

## License

Internal infrastructure - YRAL/DOLR-AI

---

**Quick Reference:**
- Interactive tool: `./scripts/run-local.sh`
- Setup: `./setup.sh`
- Edit secrets: `ansible-vault edit ansible/group_vars/all/vault.yml`
