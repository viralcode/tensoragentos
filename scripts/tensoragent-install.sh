#!/bin/bash
#
# TensorAgent OS — Enterprise Installer
#
# Installs TensorAgent OS to a target disk with:
#   - LUKS2 full-disk encryption (optional)
#   - Proper partitioning (EFI + root + swap + home)
#   - GRUB bootloader
#   - First-boot wizard setup
#
# Usage:
#   tensoragent-install                — Interactive installer
#   tensoragent-install --target /dev/sda --encrypt  — Automated
#
# WARNING: This will ERASE the target disk!
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

log()  { echo -e "${CYAN}[installer]${NC} $1"; }
ok()   { echo -e "${GREEN}  ✓${NC} $1"; }
err()  { echo -e "${RED}  ✗${NC} $1"; }
warn() { echo -e "${YELLOW}  ⚠${NC} $1"; }

TARGET_DISK=""
ENCRYPT=false
SWAP_SIZE="2G"
HOSTNAME="tensoragent"
TIMEZONE="UTC"

# Parse arguments
for arg in "$@"; do
    case $arg in
        --target=*) TARGET_DISK="${arg#*=}" ;;
        --target) shift; TARGET_DISK="$2" ;;
        --encrypt) ENCRYPT=true ;;
        --no-encrypt) ENCRYPT=false ;;
        --swap=*) SWAP_SIZE="${arg#*=}" ;;
        --hostname=*) HOSTNAME="${arg#*=}" ;;
        --timezone=*) TIMEZONE="${arg#*=}" ;;
        --help)
            echo "TensorAgent OS Installer"
            echo ""
            echo "Usage: tensoragent-install [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --target=DISK    Target disk (e.g., /dev/sda, /dev/nvme0n1)"
            echo "  --encrypt        Enable LUKS2 full-disk encryption"
            echo "  --no-encrypt     Skip disk encryption (default)"
            echo "  --swap=SIZE      Swap partition size (default: 2G)"
            echo "  --hostname=NAME  System hostname (default: tensoragent)"
            echo "  --timezone=TZ    Timezone (default: UTC)"
            exit 0
            ;;
    esac
done

# ─── Banner ───────────────────────────────────────────────────────
clear
echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║                                                          ║"
echo "  ║       🐋  TensorAgent OS — Enterprise Installer          ║"
echo "  ║                                                          ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# ─── Check root ───────────────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    err "This installer must be run as root"
    echo "  Run: sudo tensoragent-install"
    exit 1
fi

# ─── Detect available disks ──────────────────────────────────────
if [ -z "$TARGET_DISK" ]; then
    echo -e "${BOLD}Available Disks:${NC}"
    echo ""
    lsblk -d -o NAME,SIZE,MODEL,TYPE | grep disk | nl
    echo ""
    read -p "  Select target disk (e.g., /dev/sda): " TARGET_DISK
fi

if [ ! -b "$TARGET_DISK" ]; then
    err "Disk not found: ${TARGET_DISK}"
    exit 1
fi

DISK_SIZE=$(lsblk -b -d -o SIZE "$TARGET_DISK" | tail -1 | tr -d ' ')
DISK_SIZE_GB=$((DISK_SIZE / 1073741824))
DISK_MODEL=$(lsblk -d -o MODEL "$TARGET_DISK" | tail -1 | xargs)

echo ""
echo -e "${BOLD}Target Disk:${NC}"
echo "  Device: ${TARGET_DISK}"
echo "  Size:   ${DISK_SIZE_GB} GB"
echo "  Model:  ${DISK_MODEL}"
echo ""

# ─── Encryption option ──────────────────────────────────────────
if [ "$ENCRYPT" = false ]; then
    read -p "  Enable full-disk encryption (LUKS2)? [y/N]: " ENCRYPT_CHOICE
    if [[ "$ENCRYPT_CHOICE" =~ ^[Yy] ]]; then
        ENCRYPT=true
    fi
fi

if [ "$ENCRYPT" = true ]; then
    echo ""
    log "Disk encryption enabled (LUKS2 with AES-256-XTS)"
    while true; do
        read -sp "  Enter encryption passphrase: " LUKS_PASS
        echo ""
        read -sp "  Confirm passphrase: " LUKS_PASS_CONFIRM
        echo ""
        if [ "$LUKS_PASS" = "$LUKS_PASS_CONFIRM" ]; then
            if [ ${#LUKS_PASS} -lt 8 ]; then
                err "Passphrase must be at least 8 characters"
                continue
            fi
            break
        else
            err "Passphrases do not match"
        fi
    done
fi

# ─── Confirm ─────────────────────────────────────────────────────
echo ""
echo -e "${RED}${BOLD}  ⚠ WARNING: ALL DATA ON ${TARGET_DISK} WILL BE ERASED!${NC}"
echo ""
read -p "  Type 'yes' to continue: " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    log "Installation cancelled"
    exit 0
fi

# ─── Partitioning ────────────────────────────────────────────────
log "Partitioning ${TARGET_DISK}..."

# Determine partition naming (sda1 vs nvme0n1p1)
if [[ "$TARGET_DISK" == *nvme* ]] || [[ "$TARGET_DISK" == *mmcblk* ]]; then
    PART_PREFIX="${TARGET_DISK}p"
else
    PART_PREFIX="${TARGET_DISK}"
fi

# Wipe existing partitions
wipefs -af "$TARGET_DISK" 2>/dev/null || true
sgdisk -Z "$TARGET_DISK" 2>/dev/null || true

# Create GPT partition table
sgdisk -og "$TARGET_DISK"

# Partition layout:
#   1: EFI System Partition (512MB, FAT32)
#   2: Root partition (remaining - swap)
#   3: Swap partition
sgdisk -n 1:0:+512M -t 1:EF00 -c 1:"EFI" "$TARGET_DISK"
sgdisk -n 3:0:+${SWAP_SIZE} -t 3:8200 -c 3:"swap" "$TARGET_DISK"
sgdisk -n 2:0:0 -t 2:8300 -c 2:"root" "$TARGET_DISK"

partprobe "$TARGET_DISK" 2>/dev/null || true
sleep 2

EFI_PART="${PART_PREFIX}1"
ROOT_PART="${PART_PREFIX}2"
SWAP_PART="${PART_PREFIX}3"

ok "Partitions created: EFI(${EFI_PART}) Root(${ROOT_PART}) Swap(${SWAP_PART})"

# ─── Encryption (optional) ──────────────────────────────────────
if [ "$ENCRYPT" = true ]; then
    log "Encrypting root partition with LUKS2..."
    echo -n "$LUKS_PASS" | cryptsetup luksFormat --type luks2 \
        --cipher aes-xts-plain64 \
        --key-size 512 \
        --hash sha512 \
        --iter-time 5000 \
        --pbkdf argon2id \
        "$ROOT_PART" -

    echo -n "$LUKS_PASS" | cryptsetup luksOpen "$ROOT_PART" cryptroot -

    ROOT_DEV="/dev/mapper/cryptroot"
    ok "LUKS2 encryption configured"
else
    ROOT_DEV="$ROOT_PART"
fi

# ─── Format Partitions ──────────────────────────────────────────
log "Formatting partitions..."
mkfs.fat -F32 "$EFI_PART"
mkfs.ext4 -L "tensoragent-root" "$ROOT_DEV"
mkswap -L "tensoragent-swap" "$SWAP_PART"
ok "Filesystems created"

# ─── Mount ───────────────────────────────────────────────────────
log "Mounting filesystems..."
INSTALL_ROOT="/mnt/tensoragent"
mkdir -p "$INSTALL_ROOT"
mount "$ROOT_DEV" "$INSTALL_ROOT"
mkdir -p "$INSTALL_ROOT/boot/efi"
mount "$EFI_PART" "$INSTALL_ROOT/boot/efi"
swapon "$SWAP_PART"
ok "Filesystems mounted at ${INSTALL_ROOT}"

# ─── Copy System ─────────────────────────────────────────────────
log "Installing TensorAgent OS (this may take several minutes)..."

# If running from live ISO, copy the running system
if [ -d "/run/live/rootfs" ]; then
    # Live ISO — copy squashfs contents
    rsync -aAXH --progress \
        --exclude='/dev/*' \
        --exclude='/proc/*' \
        --exclude='/sys/*' \
        --exclude='/tmp/*' \
        --exclude='/run/*' \
        --exclude='/mnt/*' \
        --exclude='/media/*' \
        --exclude='/lost+found' \
        / "$INSTALL_ROOT/"
else
    # Direct copy from running system
    rsync -aAXH --progress \
        --exclude='/dev/*' \
        --exclude='/proc/*' \
        --exclude='/sys/*' \
        --exclude='/tmp/*' \
        --exclude='/run/*' \
        --exclude='/mnt/*' \
        --exclude='/media/*' \
        --exclude='/lost+found' \
        --exclude='/swap*' \
        / "$INSTALL_ROOT/"
fi
ok "System files installed"

# ─── Configure fstab ─────────────────────────────────────────────
log "Configuring fstab..."
ROOT_UUID=$(blkid -s UUID -o value "$ROOT_DEV")
EFI_UUID=$(blkid -s UUID -o value "$EFI_PART")
SWAP_UUID=$(blkid -s UUID -o value "$SWAP_PART")

cat > "$INSTALL_ROOT/etc/fstab" << FSTAB
# TensorAgent OS — Filesystem Table
# <device>                                <mount>      <type>  <options>                    <dump> <pass>
UUID=${ROOT_UUID}  /            ext4    errors=remount-ro,noatime    0      1
UUID=${EFI_UUID}   /boot/efi    vfat    umask=0077                   0      1
UUID=${SWAP_UUID}  none         swap    sw                           0      0
FSTAB

# Add crypttab if encrypted
if [ "$ENCRYPT" = true ]; then
    ROOT_PART_UUID=$(blkid -s UUID -o value "$ROOT_PART")
    echo "cryptroot UUID=${ROOT_PART_UUID} none luks,discard" > "$INSTALL_ROOT/etc/crypttab"
    ok "Crypttab configured"
fi

ok "fstab configured"

# ─── Install GRUB ────────────────────────────────────────────────
log "Installing GRUB bootloader..."

mount --bind /dev  "$INSTALL_ROOT/dev"
mount --bind /proc "$INSTALL_ROOT/proc"
mount --bind /sys  "$INSTALL_ROOT/sys"

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  GRUB_TARGET="x86_64-efi" ;;
    aarch64) GRUB_TARGET="arm64-efi" ;;
    *)       err "Unsupported architecture: $ARCH"; exit 1 ;;
esac

chroot "$INSTALL_ROOT" /bin/bash -c "
    grub-install --target=${GRUB_TARGET} --efi-directory=/boot/efi --bootloader-id=TensorAgent --recheck 2>&1
    
    # Configure GRUB
    cat > /etc/default/grub << 'GRUBCONF'
GRUB_DEFAULT=0
GRUB_TIMEOUT=3
GRUB_DISTRIBUTOR=\"TensorAgent OS\"
GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash\"
GRUB_CMDLINE_LINUX=\"\"
GRUBCONF
"

# Add LUKS to GRUB if encrypted
if [ "$ENCRYPT" = true ]; then
    ROOT_PART_UUID=$(blkid -s UUID -o value "$ROOT_PART")
    chroot "$INSTALL_ROOT" /bin/bash -c "
        sed -i 's|GRUB_CMDLINE_LINUX=\"\"|GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${ROOT_PART_UUID}:cryptroot root=/dev/mapper/cryptroot\"|' /etc/default/grub
        echo 'GRUB_ENABLE_CRYPTODISK=y' >> /etc/default/grub
    "
fi

chroot "$INSTALL_ROOT" update-grub 2>&1
ok "GRUB installed"

# ─── Configure for installed system ─────────────────────────────
log "Finalizing installation..."

# Set hostname
echo "$HOSTNAME" > "$INSTALL_ROOT/etc/hostname"

# Ensure first-boot wizard runs
rm -f "$INSTALL_ROOT/etc/ainux/.first-boot-complete"
chroot "$INSTALL_ROOT" systemctl enable ainux-first-boot.service 2>/dev/null || true

# Generate initramfs (especially important for LUKS)
chroot "$INSTALL_ROOT" update-initramfs -u -k all 2>&1

# Clean up
umount "$INSTALL_ROOT/dev" 2>/dev/null || true
umount "$INSTALL_ROOT/proc" 2>/dev/null || true
umount "$INSTALL_ROOT/sys" 2>/dev/null || true
umount "$INSTALL_ROOT/boot/efi" 2>/dev/null || true
umount "$INSTALL_ROOT" 2>/dev/null || true

if [ "$ENCRYPT" = true ]; then
    cryptsetup luksClose cryptroot 2>/dev/null || true
fi

swapoff "$SWAP_PART" 2>/dev/null || true

echo ""
echo -e "${GREEN}  ╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}  ║                                                          ║${NC}"
echo -e "${GREEN}  ║     ✓  TensorAgent OS installed successfully!            ║${NC}"
echo -e "${GREEN}  ║                                                          ║${NC}"
if [ "$ENCRYPT" = true ]; then
echo -e "${GREEN}  ║     🔒 Full-disk encryption: ENABLED (LUKS2)             ║${NC}"
else
echo -e "${GREEN}  ║     🔓 Full-disk encryption: disabled                    ║${NC}"
fi
echo -e "${GREEN}  ║                                                          ║${NC}"
echo -e "${GREEN}  ║     Remove installation media and reboot.                ║${NC}"
echo -e "${GREEN}  ║     The first-boot wizard will guide you through         ║${NC}"
echo -e "${GREEN}  ║     creating your admin account.                         ║${NC}"
echo -e "${GREEN}  ║                                                          ║${NC}"
echo -e "${GREEN}  ╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
