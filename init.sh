#!/bin/bash

set -e

# Check if we're in Hetzner rescue system
# installimage is typically an alias pointing to /root/.oldroot/nfs/install/installimage
# We need to check for the actual file since aliases don't work in non-interactive shells
if [ ! -f /root/.oldroot/nfs/install/installimage ]; then
    echo "ERROR: installimage command not found!"
    echo "This script must be run from Hetzner's rescue system."
    echo ""
    echo "To boot into rescue mode:"
    echo "1. Go to Hetzner Robot panel"
    echo "2. Select your server"
    echo "3. Click 'Rescue' tab"
    echo "4. Activate Linux rescue system"
    echo "5. Reset/reboot your server"
    echo "6. SSH into the rescue system and run this script"
    exit 1
fi

# Validate required environment variables
if [ -z "$MACHINE_HOSTNAME" ]; then
    echo "ERROR: MACHINE_HOSTNAME environment variable is not set"
    exit 1
fi

if [ -z "$DRIVE_TO_USE" ]; then
    echo "ERROR: DRIVE_TO_USE environment variable is not set"
    echo "Example: DRIVE_TO_USE='nvme0n1' or DRIVE_TO_USE='sda'"
    exit 1
fi

# Determine second drive based on first drive
if [[ "$DRIVE_TO_USE" == nvme* ]]; then
    # NVMe: nvme0n1 and nvme1n1
    DRIVE1="nvme0n1"
    DRIVE2="nvme1n1"
elif [[ "$DRIVE_TO_USE" == sd* ]]; then
    # SATA: sda and sdb
    DRIVE1="sda"
    DRIVE2="sdb"
else
    echo "ERROR: Unsupported drive type: $DRIVE_TO_USE"
    echo "Supported: nvme0n1, nvme1n1, sda, sdb"
    exit 1
fi

echo "=========================================="
echo "Hetzner Bare Metal Installation Script"
echo "=========================================="
echo "Hostname: $MACHINE_HOSTNAME"
echo "Drive 1: /dev/$DRIVE1"
echo "Drive 2: /dev/$DRIVE2"
echo "Filesystem: btrfs RAID 0 (full capacity)"
echo "=========================================="

# Stop any existing mdadm arrays if they exist
echo "Stopping existing RAID arrays..."
if ls /dev/md* 2>/dev/null | grep -q .; then
    for md in /dev/md*; do
        if [ -b "$md" ]; then
            mdadm --stop "$md" 2>/dev/null || true
        fi
    done
else
    echo "No mdadm arrays found to stop"
fi

# Wipe filesystems based on drive type
echo "Wiping existing filesystems..."
if [[ "$DRIVE_TO_USE" == nvme* ]]; then
    # For NVMe drives
    if ls /dev/nvme*n1 2>/dev/null | grep -q .; then
        for drive in /dev/nvme*n1; do
            if [ -b "$drive" ]; then
                echo "Wiping $drive"
                wipefs -fa "$drive" 2>/dev/null || true
            fi
        done
    else
        echo "No NVMe drives found"
    fi
else
    # For SATA drives
    if ls /dev/sd* 2>/dev/null | grep -q .; then
        for drive in /dev/sd?; do
            if [ -b "$drive" ]; then
                echo "Wiping $drive"
                wipefs -fa "$drive" 2>/dev/null || true
            fi
        done
    else
        echo "No SATA drives found"
    fi
fi

# Verify both target drives exist
if [ ! -b "/dev/$DRIVE1" ]; then
    echo "ERROR: Drive /dev/$DRIVE1 does not exist!"
    echo "Available drives:"
    lsblk -d -o NAME,SIZE,TYPE | grep disk
    exit 1
fi

if [ ! -b "/dev/$DRIVE2" ]; then
    echo "ERROR: Drive /dev/$DRIVE2 does not exist!"
    echo "Available drives:"
    lsblk -d -o NAME,SIZE,TYPE | grep disk
    exit 1
fi

echo "=========================================="
echo "Starting installimage..."
echo "=========================================="

# Run installimage with full path (alias doesn't work in non-interactive shells)
# Install on first drive only, we'll add the second drive to btrfs afterwards
/root/.oldroot/nfs/install/installimage -a \
    -n "$MACHINE_HOSTNAME" \
    -r no \
    -l 0 \
    -p /:btrfs:all \
    -d "$DRIVE1" \
    -f yes \
    -t yes \
    -i /root/images/Ubuntu-2404-noble-amd64-base.tar.gz

echo "=========================================="
echo "Adding second drive to btrfs RAID 0..."
echo "=========================================="

# Mount the newly installed system
mount /dev/md0 /mnt 2>/dev/null || mount /dev/${DRIVE1}1 /mnt 2>/dev/null || mount /dev/${DRIVE1}p1 /mnt

# Wipe the second drive and add it to btrfs
wipefs -fa "/dev/$DRIVE2" 2>/dev/null || true

# Add second drive to btrfs filesystem with RAID 0 (stripe) profile
btrfs device add -f "/dev/$DRIVE2" /mnt

# Convert to RAID 0 (stripe) for both data and metadata
echo "Converting to RAID 0 profile..."
btrfs balance start -dconvert=raid0 -mconvert=raid0 /mnt

echo "Checking filesystem..."
btrfs filesystem show /mnt
btrfs filesystem usage /mnt

# Unmount
umount /mnt

echo "=========================================="
echo "Installation complete!"
echo "The system will reboot shortly..."
echo "=========================================="

# reboot