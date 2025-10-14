# installimage with swraid 0 and btrfs for the root

```bash
PART btrfs.1    btrfs       all
SUBVOL btrfs.1  @           /
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
fdisk -l /dev/sda /dev/sdb;
cat /proc/mdstat;
btrfs filesystem show;
# If previously mdadm was used, stop and remove arrays
mdadm --stop /dev/md0 /dev/md1 /dev/md2
mdadm --zero-superblock /dev/sdb1 /dev/sdb2 /dev/sdb3;
# blkdiscard /dev/sdb -f;
# dd if=/dev/zero of=/dev/sda bs=1M status=progress;
wipefs -a /dev/sdb;
lsblk /dev/sdb;
wipefs -a /dev/sdb2;
parted /dev/sdb mklabel gpt;
lsblk /dev/sdb;
btrfs device add -f /dev/sdb /;
btrfs filesystem show;
btrfs balance start / --full-balance;
btrfs filesystem show;
df -h /;
btrfs filesystem usage /;
lsblk -f;
```

# Docker install script

```bash
apt update -y;
apt full-upgrade -y;
apt autoremove -y;
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
useradd -m --shell /bin/bash --groups sudo,docker <username>;
passwd <username>;
```

# Turn off password authentication

```bash
nano /etc/ssh/sshd_config
# Change PasswordAuthentication to no
service ssh restart
```

# fail2ban setup

```bash
apt install fail2ban -y;
```

# Setup SSH

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