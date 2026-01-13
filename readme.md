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
ssh -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" root@$IP_ADDRESS \
  "MACHINE_HOSTNAME='kubernetes-host-1' DRIVE_TO_USE='nvme0n1' bash -c 'curl -fsSL https://raw.githubusercontent.com/dolr-ai/hetzner-bare-metal-fleet/refs/heads/main/init.sh | bash'; sleep 10; reboot;"
```

# Hetzner Bare Metal Fleet Setup

This repository contains scripts to automate the setup of Hetzner bare metal servers with btrfs and Docker.

## Prerequisites

1. A Hetzner dedicated server
2. Access to Hetzner Robot panel
3. SSH access

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
HOSTNAME="kubernetes-host-1"
DRIVE="nvme0n1"  # or "sda" for SATA drives

ssh -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" root@$IP_ADDRESS \
  "MACHINE_HOSTNAME='$HOSTNAME' DRIVE_TO_USE='$DRIVE' bash -c 'curl -fsSL https://raw.githubusercontent.com/dolr-ai/hetzner-bare-metal-fleet/refs/heads/main/init.sh | bash'; sleep 10; reboot;"
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
