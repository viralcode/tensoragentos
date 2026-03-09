#!/bin/bash
#
# TensorAgent OS — Master Build Script
#
# Builds the entire OS from a Debian Bookworm base:
#   1. Creates rootfs via debootstrap
#   2. Installs system dependencies (Qt6, Node.js, PAM, Wayland)
#   3. Integrates OpenWhale AI platform + WhaleOS shell
#   4. Configures systemd services and boot
#   5. Generates bootable ISO (via xorriso)
#
# Supports:
#   x86_64 (native or cross-compile)
#   aarch64 (cross-compile via qemu-user-static)
#
# Requirements:
#   - Linux x86_64 host (Ubuntu 22.04+ / Debian 12+)
#   - 8GB+ RAM, 20GB+ disk
#   - Build tools: debootstrap, xorriso, mtools, qemu-user-static (for ARM)
#
# Usage: ./scripts/build-iso.sh [--arch=x86_64|aarch64] [--clean] [--skip-chromium]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AINUX_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${AINUX_ROOT}/build"
ROOTFS_DIR="${BUILD_DIR}/rootfs"
ISO_DIR="${BUILD_DIR}/iso"

ARCH="x86_64"
CLEAN=false
SKIP_CHROMIUM=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --arch=*) ARCH="${arg#*=}" ;;
        --clean) CLEAN=true ;;
        --skip-chromium) SKIP_CHROMIUM=true ;;
        --help)
            echo "Usage: $0 [--arch=x86_64|aarch64] [--clean] [--skip-chromium]"
            echo "  --arch=ARCH      Target architecture (default: x86_64)"
            echo "  --clean          Remove build directory and start fresh"
            echo "  --skip-chromium  Use Debian's packaged Chromium instead of building"
            exit 0
            ;;
    esac
done

# Resolve Debian arch name
case "$ARCH" in
    x86_64)  DEB_ARCH="amd64" ; KERNEL_ARCH="amd64" ;;
    aarch64) DEB_ARCH="arm64" ; KERNEL_ARCH="arm64" ;;
    *)       echo "ERROR: Unsupported arch: $ARCH"; exit 1 ;;
esac

echo ""
echo "  🐋 ═══════════════════════════════════════════════════════"
echo "  🐋  TensorAgent OS Build System"
echo "  🐋  Target: ${ARCH} (Debian Bookworm)"
echo "  🐋 ═══════════════════════════════════════════════════════"
echo ""

# ─── Prerequisites Check ────────────────────────────────────────
echo "[1/8] Checking prerequisites..."
REQUIRED_CMDS="debootstrap xorriso mtools mksquashfs"
MISSING=""
for cmd in $REQUIRED_CMDS; do
    if ! command -v "$cmd" &> /dev/null; then
        MISSING="$MISSING $cmd"
    fi
done

if [ -n "$MISSING" ]; then
    echo "Missing tools:$MISSING"
    echo "Install: sudo apt install debootstrap xorriso mtools squashfs-tools"
    exit 1
fi

# Cross-compilation check for aarch64
if [ "$ARCH" = "aarch64" ] && ! command -v qemu-aarch64-static &> /dev/null; then
    echo "ERROR: qemu-user-static needed for aarch64 cross-builds"
    echo "Install: sudo apt install qemu-user-static binfmt-support"
    exit 1
fi

echo "  ✓ Prerequisites OK"

# ─── Clean (optional) ───────────────────────────────────────────
if [ "$CLEAN" = true ]; then
    echo "[*] Cleaning build directory..."
    sudo rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR" "$ISO_DIR"

# ─── Create Rootfs via Debootstrap ──────────────────────────────
echo "[2/8] Creating Debian Bookworm rootfs (${DEB_ARCH})..."
if [ ! -d "$ROOTFS_DIR" ] || [ "$CLEAN" = true ]; then
    sudo debootstrap --arch="$DEB_ARCH" \
        --include=systemd,systemd-sysv,dbus,sudo,bash,curl,wget,git,openssh-server \
        bookworm "$ROOTFS_DIR" http://deb.debian.org/debian
    echo "  ✓ Base rootfs created"
else
    echo "  ✓ Rootfs already exists, skipping debootstrap"
fi

# ─── Configure Rootfs ──────────────────────────────────────────
echo "[3/8] Configuring rootfs..."

# Mount pseudo-filesystems for chroot
sudo mount --bind /dev  "${ROOTFS_DIR}/dev"  2>/dev/null || true
sudo mount --bind /proc "${ROOTFS_DIR}/proc" 2>/dev/null || true
sudo mount --bind /sys  "${ROOTFS_DIR}/sys"  2>/dev/null || true

# Set hostname
echo "tensoragent" | sudo tee "${ROOTFS_DIR}/etc/hostname" > /dev/null

# Configure apt sources with non-free for firmware
sudo tee "${ROOTFS_DIR}/etc/apt/sources.list" > /dev/null << 'SOURCES'
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
SOURCES

echo "  ✓ Base configuration applied"

# ─── Install System Dependencies ───────────────────────────────
echo "[4/8] Installing system dependencies in chroot..."

sudo chroot "$ROOTFS_DIR" /bin/bash -c '
    export DEBIAN_FRONTEND=noninteractive

    apt-get update -qq

    # Core system + build tools
    apt-get install -y -qq \
        build-essential pkg-config g++ \
        linux-image-'"$KERNEL_ARCH"' grub-efi-'"$DEB_ARCH"' \
        systemd-boot firmware-linux \
        2>/dev/null || apt-get install -y -qq build-essential pkg-config g++ linux-image-'"$KERNEL_ARCH"' grub-efi

    # Graphics & Wayland
    apt-get install -y -qq \
        mesa-utils libgl1-mesa-dri libglx-mesa0 libegl-mesa0 \
        wayland-protocols libwayland-dev weston cage \
        xwayland xdg-utils

    # Qt6 (for WhaleOS shell)
    apt-get install -y -qq \
        qt6-base-dev qt6-declarative-dev \
        qt6-wayland-dev qt6-wayland \
        qml6-module-qtquick qml6-module-qtquick-controls \
        qml6-module-qtquick-layouts qml6-module-qtwayland-compositor \
        libqt6waylandcompositor6 \
        2>/dev/null || echo "  ⚠ Some Qt6 packages unavailable, will build from source"

    # PAM (for secure authentication)
    apt-get install -y -qq libpam0g-dev

    # Node.js 22.x
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt-get install -y -qq nodejs

    # Python & AI tools
    apt-get install -y -qq python3 python3-pip python3-venv sqlite3

    # Multimedia & utilities
    apt-get install -y -qq \
        ffmpeg chromium mousepad galculator \
        htop tmux ripgrep jq tree \
        fonts-dejavu fonts-noto fontconfig \
        pipewire pipewire-alsa wireplumber \
        xsel wl-clipboard

    # VMware guest tools (for VMware Fusion/Workstation support)
    apt-get install -y -qq open-vm-tools open-vm-tools-desktop 2>/dev/null || true

    # Flatpak (dynamic package management)
    apt-get install -y -qq flatpak
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true

    # Clean apt cache
    apt-get clean
    rm -rf /var/lib/apt/lists/*
'

echo "  ✓ Dependencies installed"

# ─── Create User ───────────────────────────────────────────────
echo "[5/8] Creating default user..."

sudo chroot "$ROOTFS_DIR" /bin/bash -c '
    if ! id ainux 2>/dev/null; then
        useradd -m -s /bin/bash -G sudo,video,audio,input,render ainux
        echo "ainux:ainux" | chpasswd
        echo "%sudo ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/nopasswd
        chmod 440 /etc/sudoers.d/nopasswd
    fi
'

echo "  ✓ User created (ainux/ainux)"

# ─── Integrate OpenWhale + WhaleOS ─────────────────────────────
echo "[6/8] Installing OpenWhale + WhaleOS..."

# Build OpenWhale on the HOST (native speed) — TypeScript produces platform-independent JS
echo "  → Building OpenWhale on host..."
cd "${AINUX_ROOT}/packages/openwhale"
npm install 2>/dev/null || true
npm run build 2>/dev/null || true
cd "${AINUX_ROOT}"

# Copy built OpenWhale into rootfs
sudo mkdir -p "${ROOTFS_DIR}/opt/ainux"
sudo cp -r "${AINUX_ROOT}/packages/openwhale" "${ROOTFS_DIR}/opt/ainux/"
sudo cp -r "${AINUX_ROOT}/packages/whaleos"   "${ROOTFS_DIR}/opt/ainux/"

# Install native dependencies inside chroot (for better-sqlite3 etc.)
sudo chroot "$ROOTFS_DIR" /bin/bash -c '
    cd /opt/ainux/openwhale
    npm install --omit=dev 2>/dev/null || true
    npm rebuild better-sqlite3 2>/dev/null || true
'

# Build WhaleOS shell
sudo chroot "$ROOTFS_DIR" /bin/bash -c '
    cd /opt/ainux/whaleos
    bash build.sh
'

echo "  ✓ OpenWhale + WhaleOS installed"

# ─── Configure Systemd Services ───────────────────────────────
echo "[7/8] Configuring systemd services..."

# OpenWhale service
sudo tee "${ROOTFS_DIR}/etc/systemd/system/openwhale.service" > /dev/null << 'OWSERVICE'
[Unit]
Description=OpenWhale AI Platform
After=network.target

[Service]
Type=simple
User=ainux
WorkingDirectory=/opt/ainux/openwhale
ExecStart=/usr/bin/node openwhale.mjs
Environment=NODE_ENV=production PORT=7777 HOME=/home/ainux
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
OWSERVICE

# Hypervisor-aware GUI startup script
sudo tee "${ROOTFS_DIR}/opt/ainux/start-gui.sh" > /dev/null << 'STARTGUI'
#!/bin/bash
# TensorAgent OS — smart display startup
# Detects hypervisor and configures display backend accordingly

export XDG_RUNTIME_DIR=/run/user/1000
export WLR_LIBINPUT_NO_DEVICES=1
export WLR_NO_HARDWARE_CURSORS=1
export QT_QPA_PLATFORM=wayland
export QSG_RENDER_LOOP=basic

# Detect hypervisor
HYPERVISOR=$(systemd-detect-virt 2>/dev/null || echo "none")
echo "[TensorAgent] Detected hypervisor: $HYPERVISOR"

case "$HYPERVISOR" in
    vmware)
        echo "[TensorAgent] VMware detected — using software renderer"
        export WLR_RENDERER=pixman
        export WLR_BACKENDS=drm
        export GALLIUM_DRIVER=llvmpipe
        export LIBGL_ALWAYS_SOFTWARE=1
        # Load VMware GPU module
        modprobe vmwgfx 2>/dev/null || true
        ;;
    qemu|kvm)
        echo "[TensorAgent] QEMU/KVM detected — using virtio-gpu"
        ;;
    *)
        echo "[TensorAgent] Bare metal or unknown — auto-detecting display"
        ;;
esac

# Wait for DRM device (up to 10 seconds)
for i in $(seq 1 20); do
    if ls /dev/dri/card* 2>/dev/null; then
        echo "[TensorAgent] DRM device found"
        break
    fi
    echo "[TensorAgent] Waiting for DRM device... ($i/20)"
    sleep 0.5
done

# If no DRM device, force headless + VNC fallback
if ! ls /dev/dri/card* 2>/dev/null; then
    echo "[TensorAgent] No DRM device — using headless backend with VNC"
    export WLR_BACKENDS=headless
    export WLR_RENDERER=pixman
fi

exec /usr/bin/cage -- /opt/ainux/whaleos/whaleos
STARTGUI
sudo chmod +x "${ROOTFS_DIR}/opt/ainux/start-gui.sh"

# WhaleOS GUI service (Cage compositor running WhaleOS)
sudo tee "${ROOTFS_DIR}/etc/systemd/system/ainux-gui.service" > /dev/null << 'GUISERVICE'
[Unit]
Description=TensorAgent OS Desktop Shell
After=openwhale.service
Wants=openwhale.service

[Service]
Type=simple
User=ainux
PAMName=login
ExecStartPre=/bin/sleep 3
ExecStart=/opt/ainux/start-gui.sh
Restart=on-failure
RestartSec=3

[Install]
WantedBy=graphical.target
GUISERVICE

# Enable services
sudo chroot "$ROOTFS_DIR" /bin/bash -c '
    systemctl enable openwhale.service
    systemctl enable ainux-gui.service
    systemctl set-default graphical.target
    # Enable loginctl for multi-seat support
    systemctl enable systemd-logind
'

# Auto-login on tty1
sudo mkdir -p "${ROOTFS_DIR}/etc/systemd/system/getty@tty1.service.d"
sudo tee "${ROOTFS_DIR}/etc/systemd/system/getty@tty1.service.d/autologin.conf" > /dev/null << 'AUTOLOGIN'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ainux --noclear %I $TERM
AUTOLOGIN

echo "  ✓ Services configured"

# ─── Generate Bootable ISO ────────────────────────────────────
echo "[8/8] Generating bootable ISO..."

# Install live-boot in chroot (required for boot=live kernel parameter)
sudo chroot "$ROOTFS_DIR" /bin/bash -c '
    apt-get update -qq 2>/dev/null
    apt-get install -y -qq live-boot 2>/dev/null || true
    apt-get clean
'

# Create squashfs from rootfs
sudo umount "${ROOTFS_DIR}/dev"  2>/dev/null || true
sudo umount "${ROOTFS_DIR}/proc" 2>/dev/null || true
sudo umount "${ROOTFS_DIR}/sys"  2>/dev/null || true

if [ "$ARCH" = "x86_64" ]; then
    sudo mksquashfs "$ROOTFS_DIR" "${ISO_DIR}/live/filesystem.squashfs" \
        -comp xz -Xbcj x86 -b 1M -no-exports -noappend 2>/dev/null || \
    sudo mksquashfs "$ROOTFS_DIR" "${ISO_DIR}/live/filesystem.squashfs" \
        -comp gzip -b 1M -no-exports -noappend
else
    sudo mkdir -p "${ISO_DIR}/live"
    sudo mksquashfs "$ROOTFS_DIR" "${ISO_DIR}/live/filesystem.squashfs" \
        -comp gzip -b 1M -no-exports -noappend
fi

# Copy kernel and initrd for live boot
sudo mkdir -p "${ISO_DIR}/live"
sudo cp "${ROOTFS_DIR}/boot/vmlinuz-"*  "${ISO_DIR}/live/vmlinuz"  2>/dev/null || true
sudo cp "${ROOTFS_DIR}/boot/initrd.img-"* "${ISO_DIR}/live/initrd"  2>/dev/null || true

# Create GRUB config
sudo mkdir -p "${ISO_DIR}/boot/grub"
sudo tee "${ISO_DIR}/boot/grub/grub.cfg" > /dev/null << 'GRUB'
set timeout=3
set default=0

menuentry "TensorAgent OS" {
    linux /live/vmlinuz boot=live quiet splash
    initrd /live/initrd
}

menuentry "TensorAgent OS (Safe Mode)" {
    linux /live/vmlinuz boot=live nomodeset
    initrd /live/initrd
}
GRUB

# Create architecture-specific EFI boot image
echo "  → Creating EFI boot image for ${ARCH}..."
EFI_IMG="${ISO_DIR}/boot/grub/efi.img"
sudo mkdir -p "${ISO_DIR}/EFI/BOOT"

if [ "$ARCH" = "x86_64" ]; then
    GRUB_TARGET="x86_64-efi"
    EFI_BINARY="BOOTX64.EFI"
    GRUB_PREFIX="/usr/lib/grub/x86_64-efi"
else
    GRUB_TARGET="arm64-efi"
    EFI_BINARY="BOOTAA64.EFI"
    GRUB_PREFIX="/usr/lib/grub/arm64-efi"
fi

# Build standalone GRUB EFI binary
if [ "$ARCH" = "x86_64" ]; then
    # x86_64: build on host (grub-efi-amd64-bin is installed)
    grub-mkstandalone \
        --format="${GRUB_TARGET}" \
        --output="${ISO_DIR}/EFI/BOOT/${EFI_BINARY}" \
        --locales="" \
        --fonts="" \
        "boot/grub/grub.cfg=${ISO_DIR}/boot/grub/grub.cfg"
else
    # aarch64: build inside chroot (host doesn't have arm64 grub modules)
    sudo cp "${ISO_DIR}/boot/grub/grub.cfg" "${ROOTFS_DIR}/tmp/grub.cfg"
    sudo chroot "$ROOTFS_DIR" /bin/bash -c '
        grub-mkstandalone \
            --format=arm64-efi \
            --output=/tmp/BOOTAA64.EFI \
            --locales="" \
            --fonts="" \
            "boot/grub/grub.cfg=/tmp/grub.cfg"
    '
    sudo cp "${ROOTFS_DIR}/tmp/BOOTAA64.EFI" "${ISO_DIR}/EFI/BOOT/BOOTAA64.EFI"
fi

# Create FAT EFI partition image
dd if=/dev/zero of="${EFI_IMG}" bs=1M count=8
mkfs.vfat "${EFI_IMG}"
mmd -i "${EFI_IMG}" ::/EFI ::/EFI/BOOT
mcopy -i "${EFI_IMG}" "${ISO_DIR}/EFI/BOOT/${EFI_BINARY}" "::/EFI/BOOT/${EFI_BINARY}"

# Build ISO with xorriso
FINAL_ISO="${AINUX_ROOT}/tensoragent-os-${ARCH}.iso"

if [ "$ARCH" = "x86_64" ]; then
    # x86_64: hybrid BIOS + EFI boot
    xorriso -as mkisofs \
        -iso-level 3 \
        -o "$FINAL_ISO" \
        -full-iso9660-filenames \
        -volid "TENSORAGENT" \
        --grub2-boot-info \
        --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
        -eltorito-boot boot/grub/efi.img \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        --eltorito-catalog boot/grub/boot.cat \
        -append_partition 2 0xef "${EFI_IMG}" \
        "$ISO_DIR" 2>/dev/null || \
    xorriso -as mkisofs -o "$FINAL_ISO" -J -R -V "TENSORAGENT" \
        -append_partition 2 0xef "${EFI_IMG}" \
        "$ISO_DIR"
else
    # aarch64: EFI-only boot
    xorriso -as mkisofs \
        -iso-level 3 \
        -o "$FINAL_ISO" \
        -full-iso9660-filenames \
        -volid "TENSORAGENT" \
        -eltorito-boot boot/grub/efi.img \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        --eltorito-catalog boot/grub/boot.cat \
        -append_partition 2 0xef "${EFI_IMG}" \
        "$ISO_DIR" 2>/dev/null || \
    xorriso -as mkisofs -o "$FINAL_ISO" -J -R -V "TENSORAGENT" \
        -append_partition 2 0xef "${EFI_IMG}" \
        "$ISO_DIR"
fi

SIZE=$(du -h "$FINAL_ISO" | cut -f1)
echo ""
echo "  🐋 ═══════════════════════════════════════════════════════"
echo "  🐋  BUILD COMPLETE!"
echo "  🐋  ISO: ${FINAL_ISO} (${SIZE})"
echo "  🐋  Arch: ${ARCH}"
echo "  🐋"
echo "  🐋  Test with QEMU:"
echo "  🐋    ./scripts/run-qemu.sh"
echo "  🐋"
echo "  🐋  Flash to USB:"
echo "  🐋    sudo dd if=${FINAL_ISO} of=/dev/sdX bs=4M status=progress"
echo "  🐋 ═══════════════════════════════════════════════════════"
echo ""

