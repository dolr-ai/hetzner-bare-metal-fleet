## Troubleshooting

### "installimage: command not found"

This error means you're not in the rescue system. You must:
1. Activate rescue mode in Hetzner Robot
2. Reboot the server
3. SSH into the rescue system (not the regular OS)

### "Drive /dev/nvme0n1 does not exist"

Check available drives with `lsblk -d` and adjust the `DRIVE_TO_USE` variable accordingly.

### Common Drive Names

- NVMe drives: `nvme0n1`, `nvme1n1`
- SATA drives: `sda`, `sdb`

## One-liner Install (from rescue system)

```bash
IP_ADDRESS="138.201.128.108"
HOSTNAME="airflow-1"
DRIVE="nvme0n1"  # or "sda" for SATA drives
ssh -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" root@$IP_ADDRESS \
  "curl -fsSL https://raw.githubusercontent.com/dolr-ai/hetzner-bare-metal-fleet/refs/heads/main/init.sh | MACHINE_HOSTNAME='$HOSTNAME' DRIVE_TO_USE='$DRIVE' bash && sleep 5 && reboot"
```

# Hetzner Bare Metal Fleet Setup

This repository contains scripts to automate the setup of Hetzner bare metal servers with btrfs and Docker.

## Quick Start (for contributors)

After cloning this repository:
```bash
./setup.sh
```

This one-time setup configures git hooks for automatic secret encryption and checks your environment.

## Prerequisites

1. A Hetzner dedicated server
2. Access to Hetzner Robot panel
3. SSH access
4. Ansible installed locally (for managing the fleet)

## Installation Steps

### 1. Boot into Rescue System

**IMPORTANT:** The `init.sh` script MUST be run from Hetzner's rescue system, not from a running OS.

1. Log into [Hetzner Robot](https://robot.hetzner.com/)
2. Select your server
3. Go to the "Rescue" tab
4. Activate the Linux rescue system (64-bit)
5. Note the root password provided
6. Go to the "Reset" tab and trigger a hardware reset (or use the "Send CTRL+ALT+DEL" option)
7. Wait 1-2 minutes for the server to boot into rescue mode

### 2. Run the Installation Script

```bash
IP_ADDRESS="138.201.128.108"
HOSTNAME="airflow-1"
DRIVE="nvme0n1"  # or "sda" for SATA drives
ssh -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" root@$IP_ADDRESS \
  "curl -fsSL https://raw.githubusercontent.com/dolr-ai/hetzner-bare-metal-fleet/refs/heads/main/init.sh | MACHINE_HOSTNAME='$HOSTNAME' DRIVE_TO_USE='$DRIVE' bash && sleep 5 && reboot"
```

**Note:** Use the rescue system password when prompted.

### 3. Wait for Reboot

After the script completes, the server will reboot into the newly installed Ubuntu system. Wait 2-3 minutes before attempting to SSH again.

## What the Installation Script Does

- Stops existing RAID arrays
- Wipes filesystem signatures from drives
- Installs Ubuntu 24.04 with:
  - No software RAID (RAID 0)
  - Single btrfs partition with @ subvolume for root
  - 1GB /boot partition (ext3)

### installimage Configuration

```bash
PART btrfs.1 btrfs all
SUBVOL btrfs.1 @ /
```

# update the system

```bash
# export DEBIAN_FRONTEND=noninteractive;
apt update -y;
apt full-upgrade -y;
apt autoremove -y;
```

# btrfs setup script

```bash
lsblk -f;
df -h;
fdisk -l;
cat /proc/mdstat;
btrfs filesystem show;
# If previously mdadm was used, stop and remove arrays
mdadm --stop /dev/md0 /dev/md1 /dev/md2
mdadm --zero-superblock /dev/sdb1 /dev/sdb2 /dev/sdb3;
# blkdiscard /dev/sda -f;
# dd if=/dev/zero of=/dev/sda bs=1M status=progress;

# For SATA
wipefs -a /dev/sdb;
parted /dev/sdb mklabel gpt;
btrfs device add -f /dev/sdb /;
btrfs filesystem show;
btrfs balance start / --full-balance;
btrfs filesystem show;
df -h /;
btrfs filesystem usage /;
lsblk -f;

# For NVMe
wipefs -a /dev/nvme1n1;
parted /dev/nvme1n1 mklabel gpt;
btrfs device add -f /dev/nvme1n1 /;
btrfs filesystem show;
btrfs balance start / --full-balance;
btrfs filesystem show;
df -h /;
btrfs filesystem usage /;
lsblk -f;
```

# Docker install script

```bash
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do apt-get remove $pkg; done
# Add Docker's official GPG key:
apt-get update
apt-get install ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin;
apt autoremove -y;
```

# Unattended upgrades

```bash
apt install unattended-upgrades;
dpkg-reconfigure unattended-upgrades;
```

# User Setup

```bash
useradd -m --shell /bin/bash --groups sudo,docker,systemd-journal <username>;
passwd <username>;
```

# Turn off password authentication

```bash
nano /etc/ssh/sshd_config
# Change PasswordAuthentication to no
systemctl restart ssh
```

# Setup user account

- `su` into user

```bash
mkdir -p ~/.ssh;
sudo cp /root/.ssh/authorized_keys ~/.ssh/;
sudo chown -R $USER:$USER ~/.ssh;
```

## Passwordless sudo for special cases

```bash
visudo
# Add the following line at the end of the file
<username> ALL=(ALL) NOPASSWD:ALL
```

## Change Hostname

```bash
hostnamectl set-hostname <new-hostname>
```

## GitHub Actions Workflows

This repository uses GitHub Actions for automated server provisioning and fleet maintenance.

### Provision and Configure (New Servers)

**Workflow:** `provision-and-configure.yml`

Provisions a new bare metal server from scratch. This workflow:
1. Activates Hetzner rescue mode via API
2. Reboots the server into rescue mode
3. Installs Ubuntu 24.04 with btrfs RAID0
4. Configures SSH security, Docker, and Beszel monitoring

**Prerequisites:**
1. Server must be added to `ansible/inventory/hosts.yml`
2. Beszel agent token must be encrypted in `ansible/inventory/host_vars/{hostname}.yml`
3. Required GitHub secrets must be configured:
   - `HETZNER_ROBOT_USER` - Hetzner Robot API username
   - `HETZNER_ROBOT_PASSWORD` - Hetzner Robot API password
   - `HETZNER_BARE_METAL_GITHUB_ACTIONS_SSH_PRIVATE_KEY` - SSH private key
   - `ANSIBLE_VAULT_PASSWORD` - Ansible vault password

**Triggering via GitHub UI:**
1. Go to **Actions** → **Provision and Configure Bare Metal Server**
2. Click **"Run workflow"**
3. Fill in:
   - **target_host**: Single hostname (e.g., `airflow-1`)
   - **additional_ssh_keys**: Optional team member SSH keys
   - **auto_configure**: Enable post-provision configuration (default: true)
4. Click **"Run workflow"**

**Triggering via GitHub CLI:**
```bash
# Provision a single server
gh workflow run "Provision and Configure Bare Metal Server" \
  -f target_host="airflow-1" \
  -f auto_configure=true

# With additional SSH keys
gh workflow run "Provision and Configure Bare Metal Server" \
  -f target_host="vault-1" \
  -f additional_ssh_keys="all"
```

**Important Notes:**
- Disk auto-detection: Automatically selects the first available disk (nvme0n1 or sda)
- Servers have 2 identical disks: first for OS, second added to btrfs RAID0
- RAID0 provides combined capacity but **no redundancy** (data loss if either disk fails)

### Fleet Maintenance (Ongoing Management)

**Workflow:** `fleet-maintenance.yml`

Manages ongoing server maintenance across the fleet. Runs weekly on Sundays at 2 AM UTC, or can be triggered manually.

**What it does:**
- System updates and upgrades
- SSH security audits and configuration
- Docker installation (if missing)
- Beszel agent setup/updates

**Triggering via GitHub UI:**
1. Go to **Actions** → **Fleet Maintenance**
2. Click **"Run workflow"**
3. Fill in:
   - **target_hosts**: `all` or specific hostname(s)
   - **run_ssh_security**: Enable SSH security playbook (default: true)
   - **run_docker_setup**: Enable Docker setup playbook (default: true)
   - **run_system_update**: Enable system updates (default: true)
   - **run_beszel_agent**: Enable Beszel agent setup (default: true)
   - **enable_reboot**: Allow automatic reboot if required (default: false)
4. Click **"Run workflow"**

**Triggering via GitHub CLI:**
```bash
# Run all maintenance on all servers
gh workflow run "Fleet Maintenance" \
  -f target_hosts="all"

# Run only system updates on specific hosts
gh workflow run "Fleet Maintenance" \
  -f target_hosts="vault-1,vault-2" \
  -f run_ssh_security=false \
  -f run_docker_setup=false \
  -f run_beszel_agent=false \
  -f run_system_update=true \
  -f enable_reboot=true
```

### Monitoring Workflow Progress

1. Go to the **Actions** tab
2. Click on the running workflow
3. View real-time logs in the job details
4. Check the **Summary** tab for status and logs

## Ansible Playbooks

This repository includes Ansible playbooks for managing the fleet:

- `playbooks/system-update.yml` - System updates and upgrades
- `playbooks/ssh-security.yml` - SSH security audit and configuration
- `playbooks/docker-setup.yml` - Docker installation
- `playbooks/beszel-agent-setup.yml` - Beszel monitoring agent setup

### Ansible Vault Setup

The Beszel agent playbook uses Ansible vault to securely store per-host agent tokens.

#### Local Setup

**After cloning, run the setup script once:**
```bash
./setup.sh
```

This configures git hooks automatically. Then:

1. Create the vault password file:
```bash
cd ansible
echo "your-vault-password-here" > .vault_pass
chmod 600 .vault_pass
```

2. Edit host-specific tokens (obtain tokens from your Beszel hub at https://beszel.yral.com):
```bash
# Edit each host's token file (unencrypted initially)
cd inventory/host_vars
# Edit the file with your favorite editor
nano airflow-1.yml
# Replace PLACEHOLDER_TOKEN_HERE with the actual token from beszel hub
# Repeat for all 16 hosts
```

**Note:** You can edit the files in plain text. When you commit, the pre-commit hook will automatically encrypt them.

3. Run the playbook:
```bash
cd ansible
ansible-playbook playbooks/beszel-agent-setup.yml
```

#### GitHub Actions Setup

The GitHub Actions workflow automatically uses the vault password from GitHub secrets:

1. Add the vault password as a secret named `ANSIBLE_VAULT_PASSWORD` in your repository settings
2. The workflow will automatically decrypt the tokens when running

#### Encrypting New Tokens

The pre-commit hook handles encryption automatically, but if you need to manually encrypt:

```bash
cd ansible/inventory/host_vars
# Create a new file with the token
echo 'beszel_agent_token: "your-token-here"' > new-host.yml
# Encrypt it manually (or let the pre-commit hook do it)
ansible-vault encrypt new-host.yml
```

To edit already encrypted files:

```bash
# Decrypt, edit, and the pre-commit hook will re-encrypt on commit
ansible-vault decrypt airflow-1.yml
nano airflow-1.yml
git add airflow-1.yml
git commit -m "Update token"  # Hook encrypts automatically

# Or use ansible-vault edit (encrypts after editing)
ansible-vault edit airflow-1.yml
```

Or use encrypt_string for inline encryption:

```bash
ansible-vault encrypt_string 'your-token-here' --name 'beszel_agent_token'
```
