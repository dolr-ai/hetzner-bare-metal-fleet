# Ansible Automation for Hetzner Bare Metal Fleet

This directory contains Ansible playbooks and configuration for automating system updates and maintenance on your Hetzner bare metal servers.

## Server Fleet

The fleet consists of 9 servers organized by function:

### Databases
- **dragonfly-db-1** (88.99.58.111) - DragonflyDB instance
- **postgres-1** (94.130.13.115) - PostgreSQL database
- **milvus-1** (88.99.249.91) - Milvus vector database

### Development
- **data-science-staging-1** (88.99.192.144) - Data science staging environment
- **team-dev-server-1** (88.99.61.221) - Development server

### Infrastructure
- **github-action-runner-1** (94.130.14.115) - GitHub Actions runner
- **uptime-monitor-1** (138.201.22.251) - Uptime monitoring

### Applications
- **sentry-1** (88.99.160.251) - Sentry error tracking
- **storj-interface-1** (94.130.128.93) - Storj storage interface

## Directory Structure

```
ansible/
├── ansible.cfg                 # Ansible configuration
├── inventory/
│   └── hosts.yml              # Server inventory (configured)
├── playbooks/
│   └── system-update.yml      # Comprehensive system update
├── quick-start.sh             # Interactive management script
└── README.md                  # This file
```

## Setup

### 1. SSH Key Configuration

The setup uses **ed25519** SSH keys. Ensure you have:
- Private key: `~/.ssh/id_ed25519`
- Public key deployed to all servers

### 2. GitHub Secrets (for CI/CD)

Configure this secret in your GitHub repository:

| Secret Name | Description |
|-------------|-------------|
| `ANSIBLE_SSH_PRIVATE_KEY` | Your ed25519 SSH private key content |

All server IP addresses are configured directly in the inventory file.

## Usage

### Local Execution

1. **Test connectivity:**
```bash
cd ansible
ansible all -m ping
```

2. **Run system update on all servers:**
```bash
ansible-playbook playbooks/system-update.yml
```

3. **Target specific groups:**
```bash
# Update all database servers
ansible-playbook playbooks/system-update.yml --limit databases

# Update development servers
ansible-playbook playbooks/system-update.yml --limit development

# Update infrastructure servers
ansible-playbook playbooks/system-update.yml --limit infrastructure

# Update application servers
ansible-playbook playbooks/system-update.yml --limit applications
```

4. **Target specific servers:**
```bash
ansible-playbook playbooks/system-update.yml --limit dragonfly-db-1
ansible-playbook playbooks/system-update.yml --limit postgres-1
```

5. **Dry run (check mode):**
```bash
ansible-playbook playbooks/system-update.yml --check --diff
```

### Interactive Script

Use the quick-start script for guided operations:
```bash
cd ansible
./quick-start.sh
```

The script provides options to:
- Test connectivity
- Run system updates
- Perform dry runs
- Target specific hosts or groups
- View inventory

### GitHub Actions Workflow

The workflow can be triggered in several ways:

#### 1. Manual Trigger
- Go to Actions tab in GitHub
- Select "System Update via Ansible"
- Click "Run workflow"
- Choose options:
  - **Target hosts:** `all`, `databases`, `development`, `infrastructure`, `applications`, or specific host
  - **Skip reboot:** Prevent automatic reboot even if required
  - **Dry run:** Check what would be updated without making changes

#### 2. Scheduled Execution
- Automatically runs every Sunday at 2 AM UTC
- Updates all servers in the fleet
- Can be customized by editing the cron schedule in `.github/workflows/system-update.yml`

#### 3. Called from Other Workflows
```yaml
jobs:
  update-systems:
    uses: ./.github/workflows/system-update.yml
    with:
      target_hosts: 'databases'
      skip_reboot: true
```

## Playbook Features

### system-update.yml
Comprehensive system maintenance playbook that:
- Updates apt package cache with retries
- Performs full system upgrade
- Removes unnecessary packages (autoremove)
- Cleans apt cache (autoclean)
- Checks for reboot requirements
- Provides detailed upgrade summary
- Includes error handling and connectivity checks
- Supports Debian/Ubuntu systems only

## Server Groups

The inventory organizes servers into logical groups:

### Functional Groups
- **databases**: Database servers (dragonfly-db-1, postgres-1, milvus-1)
- **development**: Development environments (data-science-staging-1, team-dev-server-1)
- **infrastructure**: Infrastructure services (github-action-runner-1, uptime-monitor-1)
- **applications**: Application servers (sentry-1, storj-interface-1)

### Geographic Groups
- **hetzner_nuremberg**: Servers in Nuremberg datacenter
- **hetzner_falkenstein**: Servers in Falkenstein datacenter
- **hetzner_helsinki**: Servers in Helsinki datacenter

## Security Considerations

1. **SSH Keys:** Uses dedicated ed25519 SSH keys for automation
2. **Root Access:** All servers use root user (as per your SSH config)
3. **Network Access:** Ensure GitHub Actions runners can reach your servers
4. **Secrets Management:** SSH key stored securely in GitHub Secrets
5. **Host Verification:** Disabled for automation (StrictHostKeyChecking=no)

## Troubleshooting

### Common Issues

1. **SSH Connection Failed**
   - Verify ed25519 key permissions (`chmod 600 ~/.ssh/id_ed25519`)
   - Check server IP addresses in inventory
   - Ensure SSH service is running on target servers
   - Verify SSH agent is running: `ssh-add -l`

2. **Permission Denied**
   - Verify root user access is configured
   - Ensure SSH key is authorized on target servers
   - Check if key is loaded in SSH agent

3. **Package Lock Issues**
   - Wait for automatic updates to complete
   - Check if other processes are using apt
   - The playbook includes retries for transient failures

### Debug Mode
Run with increased verbosity:
```bash
ansible-playbook playbooks/system-update.yml -vvv
```

### Check Specific Servers
Test individual server connectivity:
```bash
ansible dragonfly-db-1 -m ping
ansible postgres-1 -m setup
```

## Examples

### Update Database Servers Only
```bash
ansible-playbook playbooks/system-update.yml --limit databases
```

### Update with Dry Run
```bash
ansible-playbook playbooks/system-update.yml --check --diff --limit development
```

### Skip Automatic Reboot
```bash
ansible-playbook playbooks/system-update.yml --skip-tags reboot
```

### Update Single Server
```bash
ansible-playbook playbooks/system-update.yml --limit sentry-1
```

### Update by Datacenter
```bash
ansible-playbook playbooks/system-update.yml --limit hetzner_nuremberg
```

## Best Practices

1. **Test First:** Always run in check mode against a subset first
2. **Maintenance Windows:** Schedule database updates during low-traffic periods
3. **Monitoring:** Monitor services after updates, especially databases
4. **Gradual Rollouts:** Update critical services (databases) individually
5. **Documentation:** Keep track of what was updated and when
6. **Backups:** Ensure recent backups before major updates

## Maintenance Schedule Recommendations

- **Development servers:** Can be updated anytime
- **Infrastructure services:** Update during low-usage periods
- **Database servers:** Coordinate updates with application teams
- **Application servers:** Update after verifying dependencies

## Quick Reference

```bash
# Test all servers
ansible all -m ping

# Update everything
ansible-playbook playbooks/system-update.yml

# Update just databases
ansible-playbook playbooks/system-update.yml --limit databases

# Dry run on development servers
ansible-playbook playbooks/system-update.yml --limit development --check

# Interactive management
./quick-start.sh
```
