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
        qml6-module-qtquick-window qml6-module-qtquick-templates \
        qml6-module-qtquick-layouts qml6-module-qtwayland-compositor \
        qml6-module-qtqml-workerscript qml6-module-qtqml \
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
        ffmpeg mousepad galculator \
        htop tmux ripgrep jq tree \
        fonts-dejavu fonts-noto fontconfig \
        pipewire pipewire-alsa wireplumber \
        xsel wl-clipboard

    # Office suite & PDF viewer
    apt-get install -y -qq \
        libreoffice-writer libreoffice-calc libreoffice-impress \
        libreoffice-gtk3 \
        evince \
        2>/dev/null || echo "  [SKIP] Some office/PDF packages unavailable"

    # Chromium — package name varies by architecture
    apt-get install -y -qq chromium 2>/dev/null \
        || apt-get install -y -qq chromium-browser 2>/dev/null \
        || echo "  ⚠ Chromium not available for this architecture"

    # Configure Chromium to use Client-Side Decorations (CSD)
    # This makes Chromium show its own minimize/maximize/close buttons
    # just like on Ubuntu/GNOME
    echo "  Configuring Chromium CSD..."

    # Method 1: Chromium flags file (loaded on startup)
    mkdir -p /etc/chromium.d
    cat > /etc/chromium.d/csd.conf << CHROMIUM_CSD
# Enable Client-Side Decorations (CSD) — show min/max/close buttons
export CHROMIUM_FLAGS="\$CHROMIUM_FLAGS --enable-features=UseOzonePlatform,WaylandWindowDecorations"
CHROMIUM_CSD

    # Method 2: Default preferences for the user (custom_chrome_frame = CSD)
    CHROMIUM_PREFS_DIR="/home/ainux/.config/chromium/Default"
    mkdir -p "$CHROMIUM_PREFS_DIR"
    cat > "$CHROMIUM_PREFS_DIR/Preferences" << CHROMIUM_PREFS
{
    "browser": {
        "custom_chrome_frame": true
    }
}
CHROMIUM_PREFS
    chown -R 1000:1000 /home/ainux/.config

    # Verify native app binaries
    echo "  Verifying native app binaries..."
    for bin in chromium mousepad galculator; do
        if which "$bin" 2>/dev/null; then
            echo "    ✓ $bin found: $(which $bin)"
        else
            echo "    ✗ $bin NOT FOUND"
        fi
    done

    # VMware guest tools (for VMware Fusion/Workstation support)
    apt-get install -y -qq open-vm-tools open-vm-tools-desktop 2>/dev/null || true

    # Network management (WiFi + wired)
    apt-get install -y -qq network-manager wpasupplicant wireless-tools iw

    # CRITICAL: NetworkManager ignores interfaces in /etc/network/interfaces
    # Strip it to loopback-only so NM manages everything (ethernet, wifi)
    cat > /etc/network/interfaces << NETIF
# This file is intentionally minimal.
# Network interfaces are managed by NetworkManager.
auto lo
iface lo inet loopback
NETIF

    # Tell NetworkManager to manage all devices (even if in /etc/network/interfaces)
    mkdir -p /etc/NetworkManager/conf.d
    cat > /etc/NetworkManager/conf.d/10-manage-all.conf << NMCONF
[main]
plugins=ifupdown,keyfile

[ifupdown]
managed=true

[device]
wifi.scan-rand-mac-address=no
NMCONF

    systemctl enable NetworkManager 2>/dev/null || true
    # Disable ifupdown networking service so it does not conflict
    systemctl disable networking 2>/dev/null || true

    # Flatpak (dynamic package management) — optional, skip if unavailable
    apt-get install -y -qq flatpak 2>/dev/null || echo "  [SKIP] flatpak not available in repos"
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
        useradd -m -s /bin/bash -G sudo,video,audio,input,render,systemd-journal ainux
        echo "ainux:ainux" | chpasswd
        echo "%sudo ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/nopasswd
        chmod 440 /etc/sudoers.d/nopasswd
    fi
'

echo "  ✓ User created (ainux/ainux)"

# Fix home directory ownership (useradd -m with existing dir leaves root:root)
sudo chroot "$ROOTFS_DIR" /bin/bash -c '
    chown -R ainux:ainux /home/ainux
'
echo "  ✓ Home directory ownership fixed"

# ─── Install Ollama ────────────────────────────────────────────
echo "  → Installing Ollama..."
sudo chroot "$ROOTFS_DIR" /bin/bash -c '
    curl -fsSL https://ollama.com/install.sh | sh 2>&1 | tail -3
'
echo "  ✓ Ollama installed"

# Create Ollama systemd service
sudo tee "${ROOTFS_DIR}/etc/systemd/system/ollama.service" > /dev/null << 'OLLAMA_EOF'
[Unit]
Description=Ollama AI Model Server
After=network.target

[Service]
Type=simple
User=ainux
ExecStart=/usr/local/bin/ollama serve
Environment=HOME=/home/ainux OLLAMA_HOST=0.0.0.0
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
OLLAMA_EOF

sudo chroot "$ROOTFS_DIR" /bin/bash -c '
    systemctl enable ollama 2>/dev/null || true
'
echo "  ✓ Ollama service enabled"

# ─── Integrate OpenWhale + WhaleOS ─────────────────────────────
echo "[6/8] Installing OpenWhale + WhaleOS..."

# Copy source into rootfs first (before building)
sudo mkdir -p "${ROOTFS_DIR}/opt/ainux"
sudo cp -r "${AINUX_ROOT}/packages/openwhale" "${ROOTFS_DIR}/opt/ainux/"
sudo cp -r "${AINUX_ROOT}/packages/whaleos"   "${ROOTFS_DIR}/opt/ainux/"

# Build OpenWhale inside chroot where Node.js is available
echo "  → Building OpenWhale in chroot..."
sudo chroot "$ROOTFS_DIR" /bin/bash -c '
    cd /opt/ainux/openwhale
    echo "    Installing dependencies..."
    npm install 2>&1 | tail -5
    echo "    Building TypeScript..."
    if npx tsc --version 2>/dev/null; then
        npm run build 2>&1 | tail -10
        if [ -f dist/index.js ]; then
            echo "    ✓ TypeScript compiled — dist/index.js exists"
            # Clean devDependencies to save space
            npm prune --production 2>/dev/null || true
        else
            echo "    ⚠ tsc build failed — keeping tsx for runtime"
        fi
    else
        echo "    ⚠ tsc not found — keeping tsx for runtime"
    fi
    # Ensure tsx is available as runtime fallback
    npm list tsx 2>/dev/null || npm install tsx 2>&1 | tail -3
    # Rebuild native modules for ARM64
    npm rebuild better-sqlite3 2>/dev/null || true
    # Create data directory and fix ownership so ainux user can write
    mkdir -p /opt/ainux/openwhale/data
    chown -R 1000:1000 /opt/ainux/openwhale
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

# WhaleOS helper service (port 7778 — system exec for QML)
sudo tee "${ROOTFS_DIR}/etc/systemd/system/whaleos-helper.service" > /dev/null << 'HELPERSERVICE'
[Unit]
Description=WhaleOS System Helper
After=network.target

[Service]
Type=simple
User=ainux
WorkingDirectory=/opt/ainux/whaleos
ExecStart=/usr/bin/node /opt/ainux/whaleos/whaleos-helper.mjs
Environment=NODE_ENV=production HOME=/home/ainux
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
HELPERSERVICE

sudo chroot "$ROOTFS_DIR" systemctl enable whaleos-helper 2>/dev/null || true
echo "  ✓ WhaleOS helper service enabled (port 7778)"

# Hypervisor-aware GUI startup script
sudo tee "${ROOTFS_DIR}/opt/ainux/start-gui.sh" > /dev/null << 'STARTGUI'
#!/bin/bash
# TensorAgent OS — smart display startup
# WhaleOS IS a Wayland compositor — no need for Cage.
# Runs directly on the framebuffer via EGLFS.

LOGFILE=/tmp/tensoragent-gui.log

# Simple logging — no process substitution pipes that block VT
log() { echo "[TensorAgent] $*" | tee -a "$LOGFILE"; }
log "=== TensorAgent GUI starting at $(date) ==="

# Create XDG_RUNTIME_DIR if it doesn't exist
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
if [ ! -d "$XDG_RUNTIME_DIR" ]; then
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 0700 "$XDG_RUNTIME_DIR"
fi

# Qt rendering config — software rendering for VM compatibility
export QT_QPA_PLATFORM=eglfs
export QSG_RENDER_LOOP=basic
export QT_QUICK_BACKEND=software
export QML2_IMPORT_PATH=/usr/lib/aarch64-linux-gnu/qt6/qml:/usr/lib/qt6/qml

# EGLFS config — use linuxfb fallback if no working EGL
export QT_QPA_EGLFS_INTEGRATION=eglfs_kms
export QT_QPA_EGLFS_ALWAYS_SET_MODE=1
export LIBGL_ALWAYS_SOFTWARE=1

# Disable GTK client-side decorations — WhaleOS provides server-side title bars
export GTK_CSD=0
export XDG_CURRENT_DESKTOP=WhaleOS

# Detect hypervisor
HYPERVISOR=$(systemd-detect-virt 2>/dev/null || echo "none")
log "Detected hypervisor: $HYPERVISOR"

case "$HYPERVISOR" in
    vmware)
        log "VMware detected — using software renderer with linuxfb fallback"
        export GALLIUM_DRIVER=llvmpipe
        modprobe vmwgfx 2>/dev/null || true
        # Try eglfs first, fall back to linuxfb if it fails
        export QT_QPA_EGLFS_KMS_CONFIG=""
        ;;
    qemu|kvm)
        log "QEMU/KVM detected — using virtio-gpu"
        ;;
    *)
        log "Bare metal or unknown — auto-detecting display"
        ;;
esac

# Wait for DRM device (up to 10 seconds)
for i in $(seq 1 20); do
    if ls /dev/dri/card* 2>/dev/null; then
        log "DRM device found"
        ls /dev/dri/ >> "$LOGFILE" 2>&1
        break
    fi
    log "Waiting for DRM device... ($i/20)"
    sleep 0.5
done

# If no DRM device, fall back to linuxfb
if ! ls /dev/dri/card* 2>/dev/null; then
    log "No DRM device — falling back to linuxfb"
    export QT_QPA_PLATFORM=linuxfb
fi

# Pre-flight checks
log "Checking WhaleOS binary..."
if [ ! -x /opt/ainux/whaleos/whaleos ]; then
    log "ERROR: WhaleOS binary not found or not executable"
    ls -la /opt/ainux/whaleos/ >> "$LOGFILE" 2>&1 || echo "  whaleos directory missing" >> "$LOGFILE"
    exit 1
fi

log "Checking main.qml..."
if [ ! -f /opt/ainux/whaleos/main.qml ]; then
    log "ERROR: main.qml not found"
    exit 1
fi

log "Environment:"
log "  QT_QPA_PLATFORM=$QT_QPA_PLATFORM"
log "  QT_QUICK_BACKEND=$QT_QUICK_BACKEND"
log "  QSG_RENDER_LOOP=$QSG_RENDER_LOOP"
log "  XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"

# Launch WhaleOS directly — it IS a Wayland compositor
# No Cage needed. WhaleOS renders via EGLFS to the DRM device.
log "Starting WhaleOS compositor directly..."

# Refresh apt cache in background so Package Store works immediately
apt-get update -qq &>/dev/null &

exec /opt/ainux/whaleos/whaleos >> "$LOGFILE" 2>&1
STARTGUI
sudo chmod +x "${ROOTFS_DIR}/opt/ainux/start-gui.sh"

# ── GUI Launch via Getty Autologin (Kiosk Mode) ──
# Standard Cage kiosk setup: getty autologin → PAM session → logind seat → Cage gets DRM
# This gives Cage proper seat access that a standalone systemd service cannot provide.

# Auto-login on tty1
sudo mkdir -p "${ROOTFS_DIR}/etc/systemd/system/getty@tty1.service.d"
sudo tee "${ROOTFS_DIR}/etc/systemd/system/getty@tty1.service.d/autologin.conf" > /dev/null << 'AUTOLOGIN'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ainux --noclear %I $TERM
AUTOLOGIN

# Launch GUI from .bash_profile on tty1 (only runs on console login, not SSH)
sudo tee "${ROOTFS_DIR}/home/ainux/.bash_profile" > /dev/null << 'BASHPROFILE'
# TensorAgent OS — Auto-launch GUI on tty1
if [ "$(tty)" = "/dev/tty1" ] && [ -z "$WAYLAND_DISPLAY" ]; then
    echo "[TensorAgent] Starting desktop environment..."
    exec /opt/ainux/start-gui.sh
fi

# Normal shell for other TTYs and SSH
[ -f ~/.bashrc ] && source ~/.bashrc
BASHPROFILE
sudo chown 1000:1000 "${ROOTFS_DIR}/home/ainux/.bash_profile"

# Keep OpenWhale as a service (backend)
# Enable services
sudo chroot "$ROOTFS_DIR" /bin/bash -c '
    systemctl enable openwhale.service
    systemctl set-default graphical.target
    systemctl enable systemd-logind
'

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

sudo mkdir -p "${ISO_DIR}/live"

if [ "$ARCH" = "x86_64" ]; then
    sudo mksquashfs "$ROOTFS_DIR" "${ISO_DIR}/live/filesystem.squashfs" \
        -comp xz -Xbcj x86 -b 1M -no-exports -noappend 2>/dev/null || \
    sudo mksquashfs "$ROOTFS_DIR" "${ISO_DIR}/live/filesystem.squashfs" \
        -comp gzip -b 1M -no-exports -noappend
else
    sudo mksquashfs "$ROOTFS_DIR" "${ISO_DIR}/live/filesystem.squashfs" \
        -comp gzip -b 1M -no-exports -noappend
fi

# Copy kernel and initrd for live boot
sudo mkdir -p "${ISO_DIR}/live"

# Find and copy kernel
KERNEL=$(find "${ROOTFS_DIR}/boot" -name "vmlinuz-*" -type f 2>/dev/null | sort -V | tail -1)
if [ -z "$KERNEL" ]; then
    # Try symlink
    KERNEL="${ROOTFS_DIR}/boot/vmlinuz"
fi
if [ -f "$KERNEL" ]; then
    sudo cp "$KERNEL" "${ISO_DIR}/live/vmlinuz"
    echo "  ✓ Kernel: $(basename $KERNEL)"
else
    echo "  ✗ ERROR: No kernel found in ${ROOTFS_DIR}/boot/"
    ls -la "${ROOTFS_DIR}/boot/" || true
fi

# Find and copy initrd
INITRD=$(find "${ROOTFS_DIR}/boot" -name "initrd.img-*" -type f 2>/dev/null | sort -V | tail -1)
if [ -z "$INITRD" ]; then
    INITRD="${ROOTFS_DIR}/boot/initrd.img"
fi
if [ -f "$INITRD" ]; then
    sudo cp "$INITRD" "${ISO_DIR}/live/initrd"
    echo "  ✓ Initrd: $(basename $INITRD)"
else
    echo "  ✗ ERROR: No initrd found in ${ROOTFS_DIR}/boot/"
    ls -la "${ROOTFS_DIR}/boot/" || true
fi

# Verify both files exist before proceeding
if [ ! -f "${ISO_DIR}/live/vmlinuz" ] || [ ! -f "${ISO_DIR}/live/initrd" ]; then
    echo "FATAL: Kernel or initrd missing from ISO live directory!"
    echo "Contents of ${ISO_DIR}/live/:"
    ls -la "${ISO_DIR}/live/" || true
fi

# Create GRUB config
sudo mkdir -p "${ISO_DIR}/boot/grub"
sudo tee "${ISO_DIR}/boot/grub/grub.cfg" > /dev/null << 'GRUB'
insmod all_video
insmod gzio
insmod part_gpt
insmod part_msdos
insmod iso9660
insmod search_label

search --no-floppy --set=root --label TENSORAGENT

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
    # x86_64: EFI-only boot (removes legacy BIOS flags that corrupted efi.img)
    xorriso -as mkisofs \
        -iso-level 3 \
        -o "$FINAL_ISO" \
        -full-iso9660-filenames \
        -volid "TENSORAGENT" \
        -e boot/grub/efi.img \
        -no-emul-boot \
        -append_partition 2 0xef "${EFI_IMG}" \
        "$ISO_DIR" 2>/dev/null || \
    xorriso -as mkisofs -o "$FINAL_ISO" -J -R -V "TENSORAGENT" \
        -e boot/grub/efi.img -no-emul-boot \
        -append_partition 2 0xef "${EFI_IMG}" \
        "$ISO_DIR"
else
    # aarch64: EFI-only boot (no -boot-info-table, it corrupts EFI image)
    xorriso -as mkisofs \
        -iso-level 3 \
        -o "$FINAL_ISO" \
        -full-iso9660-filenames \
        -volid "TENSORAGENT" \
        -e boot/grub/efi.img \
        -no-emul-boot \
        -append_partition 2 0xef "${EFI_IMG}" \
        "$ISO_DIR" 2>/dev/null || \
    xorriso -as mkisofs -o "$FINAL_ISO" -J -R -V "TENSORAGENT" \
        -e boot/grub/efi.img -no-emul-boot \
        -append_partition 2 0xef "${EFI_IMG}" \
        "$ISO_DIR"
fi

# ─── Copy ISO to canonical output location ────────────────────
if [ "$ARCH" = "x86_64" ]; then
    ISO_OUTPUT_DIR="${AINUX_ROOT}/build/iso/x86"
else
    ISO_OUTPUT_DIR="${AINUX_ROOT}/build/iso/arm"
fi
mkdir -p "$ISO_OUTPUT_DIR"
cp -v "$FINAL_ISO" "$ISO_OUTPUT_DIR/"
CANONICAL_ISO="${ISO_OUTPUT_DIR}/$(basename "$FINAL_ISO")"

SIZE=$(du -h "$CANONICAL_ISO" | cut -f1)
echo ""
echo "  🐋 ═══════════════════════════════════════════════════════"
echo "  🐋  BUILD COMPLETE!"
echo "  🐋  ISO: ${CANONICAL_ISO} (${SIZE})"
echo "  🐋  Arch: ${ARCH}"
echo "  🐋"
echo "  🐋  Test with QEMU:"
echo "  🐋    ./scripts/run-qemu.sh"
echo "  🐋"
echo "  🐋  Flash to USB:"
echo "  🐋    sudo dd if=${CANONICAL_ISO} of=/dev/sdX bs=4M status=progress"
echo "  🐋 ═══════════════════════════════════════════════════════"
echo ""

