# Ubuntu Mechanism:
- installimage with swraid 0 and btrfs for the root
```bash
PART btrfs.1    btrfs       all
SUBVOL btrfs.1  @           /
```
- reboot into system
```bash
export DEBIAN_FRONTEND=noninteractive;
lsblk -f;
df -h;
fdisk -l /dev/sda /dev/sdb;
cat /proc/mdstat;
btrfs filesystem show;
# If previously mdadm was used, stop and remove arrays
mdadm --stop /dev/md0 /dev/md1 /dev/md2
mdadm --zero-superblock /dev/sdb1 /dev/sdb2 /dev/sdb3;
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
apt install unattended-upgrades;
dpkg-reconfigure unattended-upgrades;
```


# Bootc Mechanism:
- activate rescue system
```bash
export DEBIAN_FRONTEND=noninteractive;
# update
apt update -y;
apt full-upgrade -y;
# podman
apt install podman -y;

# Remove prior partition table
wipefs /dev/sda -a;
wipefs /dev/sdb -a;

# Install bootc with btrfs
podman run --rm --privileged --pid=host --network=host \
  -v /var/lib/containers:/var/lib/containers \
  -v /dev:/dev \
  -v ~/.ssh/authorized_keys:/authorized_keys:ro \
  --security-opt label=type:unconfined_t \
  quay.io/fedora/fedora-bootc:latest \
  bootc install to-disk --wipe --filesystem=btrfs \
  --root-ssh-authorized-keys /authorized_keys /dev/sda;

# Create unified RAID0 btrfs storage
mkdir -p /mnt/root;
mount /dev/sda3 /mnt/root;
btrfs device add --force /dev/sdb /mnt/root;
btrfs balance start --force -dconvert=raid0 -mconvert=raid0 /mnt/root;
umount /mnt/root;
reboot;

```
