mdadm --stop /dev/md/*

# for SATA drives:
wipefs -fa /dev/sd*
# for NVMe drives:
wipefs -fa /dev/nvme*n1

installimage -a -n $MACHINE_HOSTNAME -r no -l 0 -p /boot:ext3:1024M,btrfs.1:btrfs:all,btrfs.1:@:/ -d $DRIVE_TO_USE -f yes -t yes -i /root/images/Ubuntu-2404-noble-amd64-base.tar.gz
