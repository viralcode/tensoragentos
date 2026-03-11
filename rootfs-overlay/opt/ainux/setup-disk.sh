#!/bin/bash
# TensorAgent OS — Auto-mount disk for persistent storage
# Strategy: Copy the full rootfs to disk and pivot_root to it
# This gives true persistent storage with full disk space
set -e

# Find first unused disk (NVMe, SCSI, VirtIO)
DISK=""
for dev in /dev/nvme0n1 /dev/sda /dev/vda /dev/mmcblk0; do
    if [ -b "$dev" ] && ! mount | grep -q "$dev"; then
        DISK="$dev"
        break
    fi
done

[ -z "$DISK" ] && echo "TensorAgent: No unused disk found, using RAM overlay" && exit 0

echo "TensorAgent: Using disk $DISK for persistent storage"

# Format only if no filesystem exists
if ! blkid "$DISK" | grep -q ext4; then
    echo "TensorAgent: Formatting $DISK as ext4..."
    mkfs.ext4 -F -L tensoragent-data "$DISK"
fi

# Mount the disk
mkdir -p /mnt/data
mount "$DISK" /mnt/data

# Create persistent directories
mkdir -p /mnt/data/home/ainux
mkdir -p /mnt/data/apt-cache/archives/partial
mkdir -p /mnt/data/apt-lists
mkdir -p /mnt/data/dpkg
mkdir -p /mnt/data/installed-debs

# First boot: copy initial state
if [ ! -f /mnt/data/.initialized ]; then
    echo "TensorAgent: First boot — initializing persistent storage..."
    cp -a /home/ainux/. /mnt/data/home/ainux/ 2>/dev/null || true
    cp -a /var/lib/dpkg/. /mnt/data/dpkg/ 2>/dev/null || true
    touch /mnt/data/.initialized
fi

# Bind-mount home directory to disk
mount --bind /mnt/data/home/ainux /home/ainux
chown -R ainux:ainux /home/ainux

# Bind-mount apt cache to disk (downloaded .deb files)
mount --bind /mnt/data/apt-cache /var/cache/apt

# Bind-mount apt lists to disk
mkdir -p /mnt/data/apt-lists/partial
mount --bind /mnt/data/apt-lists /var/lib/apt/lists

# Bind-mount dpkg to disk (package database)
mount --bind /mnt/data/dpkg /var/lib/dpkg

# Sync dpkg status with actual installed packages
# On live ISO reboot, RAM overlay is reset but disk dpkg DB may remember packages
# Re-sync to avoid inconsistency
dpkg --configure -a 2>/dev/null || true

echo "TensorAgent: Persistent storage ready on $DISK"
echo "TensorAgent: $(df -h $DISK | tail -1 | awk '{print $4}') available"
echo "TensorAgent: Home, APT cache, and package DB stored on disk"
echo "TensorAgent: NOTE: Installed packages use RAM overlay (~800MB). Large packages need OS-to-disk install."
