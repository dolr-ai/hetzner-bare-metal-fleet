# installimage with swraid 0 and btrfs for the root

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

# 1 liner install

```bash
IP_ADDRESS="" ssh -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" root@$IP_ADDRESS "MACHINE_HOSTNAME='kubernetes-host-1' DRIVE_TO_USE='nvme0n1' bash -c 'curl -fsSL https://raw.githubusercontent.com/dolr-ai/hetzner-bare-metal-fleet/refs/heads/main/init.sh | bash'; sleep 10; reboot;"
```
