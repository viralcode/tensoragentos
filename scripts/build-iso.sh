#!/bin/bash
#
# AInux Master Build Script
#
# Builds the entire AInux OS from source:
# 1. Clones/updates Buildroot
# 2. Applies AInux configuration
# 3. Builds Linux kernel, rootfs, Chromium, OpenWhale
# 4. Generates bootable ISO
#
# Requirements:
#   - Linux x86_64 host (Ubuntu 22.04+ recommended)
#   - 16GB+ RAM, 150GB+ disk space
#   - Build tools: gcc, g++, make, git, python3, pkg-config
#
# Usage: ./scripts/build-iso.sh [--clean] [--skip-chromium]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AINUX_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="${AINUX_ROOT}/build"
BUILDROOT_VERSION="2024.11"
BUILDROOT_DIR="${BUILD_DIR}/buildroot"
OUTPUT_DIR="${BUILD_DIR}/output"

CLEAN=false
SKIP_CHROMIUM=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --clean) CLEAN=true ;;
        --skip-chromium) SKIP_CHROMIUM=true ;;
        --help)
            echo "Usage: $0 [--clean] [--skip-chromium]"
            echo "  --clean          Remove build directory and start fresh"
            echo "  --skip-chromium  Skip Chromium build (use pre-built binary)"
            exit 0
            ;;
    esac
done

echo ""
echo "  🐋 ═══════════════════════════════════════════════════════"
echo "  🐋  AInux Build System"
echo "  🐋  Building AI Agentic Operating System..."
echo "  🐋 ═══════════════════════════════════════════════════════"
echo ""

# ─── Prerequisites Check ────────────────────────────────────────────────────

echo "[1/7] Checking prerequisites..."
REQUIRED_CMDS="gcc g++ make git python3 wget curl tar xz patch"
for cmd in $REQUIRED_CMDS; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "ERROR: Required command '$cmd' not found."
        echo "Install build essentials: sudo apt install build-essential git python3 wget curl xz-utils"
        exit 1
    fi
done

# Check disk space (need at least 50GB)
AVAILABLE_SPACE=$(df -BG "${AINUX_ROOT}" | tail -1 | awk '{print $4}' | tr -d 'G')
if [ "${AVAILABLE_SPACE}" -lt 50 ]; then
    echo "WARNING: Only ${AVAILABLE_SPACE}GB available. AInux build needs ~100-150GB."
fi

echo "  ✓ Prerequisites OK"

# ─── Clean (optional) ───────────────────────────────────────────────────────

if [ "$CLEAN" = true ]; then
    echo "[*] Cleaning build directory..."
    rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"

# ─── Clone/Update Buildroot ─────────────────────────────────────────────────

echo "[2/7] Setting up Buildroot ${BUILDROOT_VERSION}..."
if [ ! -d "$BUILDROOT_DIR" ]; then
    echo "  Cloning Buildroot..."
    git clone --depth 1 --branch "${BUILDROOT_VERSION}" \
        https://github.com/buildroot/buildroot.git "$BUILDROOT_DIR"
else
    echo "  Buildroot already present, updating..."
    cd "$BUILDROOT_DIR" && git fetch && git checkout "${BUILDROOT_VERSION}" 2>/dev/null || true
fi

echo "  ✓ Buildroot ready"

# ─── Apply AInux Configuration ──────────────────────────────────────────────

echo "[3/7] Applying AInux configuration..."
cd "$BUILDROOT_DIR"

# Set external tree
export BR2_EXTERNAL="${AINUX_ROOT}/buildroot-external"

# Copy our defconfig
cp "${AINUX_ROOT}/configs/ainux_defconfig" \
   "${BUILDROOT_DIR}/configs/ainux_defconfig"

# Load the configuration
make ainux_defconfig O="${OUTPUT_DIR}"

echo "  ✓ Configuration applied"

# ─── Chromium Build (optional) ──────────────────────────────────────────────

if [ "$SKIP_CHROMIUM" = false ]; then
    echo "[4/7] Building Chromium from source (this takes 6-8 hours)..."
    echo "  This is the longest step. Go get coffee ☕"
    
    CHROMIUM_BUILD="${BUILD_DIR}/chromium"
    mkdir -p "$CHROMIUM_BUILD"
    
    # Download depot_tools
    if [ ! -d "${BUILD_DIR}/depot_tools" ]; then
        git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git \
            "${BUILD_DIR}/depot_tools"
    fi
    export PATH="${BUILD_DIR}/depot_tools:$PATH"
    
    # Fetch Chromium source
    if [ ! -d "${CHROMIUM_BUILD}/src" ]; then
        cd "$CHROMIUM_BUILD"
        fetch --nohooks chromium
        cd src
        gclient runhooks
    fi
    
    cd "${CHROMIUM_BUILD}/src"
    
    # Apply AInux patches
    echo "  Applying AInux patches..."
    for patch in "${AINUX_ROOT}/packages/chromium/patches/"*.patch; do
        if [ -f "$patch" ]; then
            echo "    Applying $(basename "$patch")..."
            git apply "$patch" 2>/dev/null || patch -p1 < "$patch" || true
        fi
    done
    
    # Generate build files
    echo "  Generating build files..."
    gn gen out/AInux --args='
        is_debug = false
        is_official_build = true
        is_component_build = false
        enable_nacl = false
        use_ozone = true
        ozone_platform = "wayland"
        ozone_auto_platforms = false
        ozone_platform_wayland = true
        ozone_platform_x11 = false
        enable_experimental_web_platform_features = true
        proprietary_codecs = true
        ffmpeg_branding = "Chrome"
        use_vaapi = true
        use_pulseaudio = false
        use_pipewire = true
        rtc_use_pipewire = true
        chrome_pgo_phase = 0
        symbol_level = 0
        blink_symbol_level = 0
        v8_symbol_level = 0
    '
    
    # Build
    echo "  Building Chromium (this will take a while)..."
    ninja -j$(nproc) -C out/AInux chrome
    
    echo "  ✓ Chromium built successfully"
else
    echo "[4/7] Skipping Chromium build (--skip-chromium)"
fi

# ─── Build Rootfs ───────────────────────────────────────────────────────────

echo "[5/7] Building Linux kernel and root filesystem..."
cd "$BUILDROOT_DIR"
make O="${OUTPUT_DIR}" -j$(nproc)

echo "  ✓ Root filesystem built"

# ─── Integrate Chromium ─────────────────────────────────────────────────────

echo "[6/7] Integrating Chromium into rootfs..."
if [ "$SKIP_CHROMIUM" = false ] && [ -f "${CHROMIUM_BUILD}/src/out/AInux/chrome" ]; then
    ROOTFS_DIR="${OUTPUT_DIR}/target"
    mkdir -p "${ROOTFS_DIR}/opt/ainux/chromium"
    cp "${CHROMIUM_BUILD}/src/out/AInux/chrome" "${ROOTFS_DIR}/opt/ainux/chromium/"
    cp "${CHROMIUM_BUILD}/src/out/AInux/"*.pak "${ROOTFS_DIR}/opt/ainux/chromium/" 2>/dev/null || true
    cp "${CHROMIUM_BUILD}/src/out/AInux/"*.dat "${ROOTFS_DIR}/opt/ainux/chromium/" 2>/dev/null || true
    cp "${CHROMIUM_BUILD}/src/out/AInux/"*.bin "${ROOTFS_DIR}/opt/ainux/chromium/" 2>/dev/null || true
    cp -r "${CHROMIUM_BUILD}/src/out/AInux/locales" "${ROOTFS_DIR}/opt/ainux/chromium/" 2>/dev/null || true
    echo "  ✓ Chromium integrated"
else
    echo "  ⚠ No Chromium build found, image will use system Chromium"
fi

# ─── Generate ISO ───────────────────────────────────────────────────────────

echo "[7/7] Generating bootable ISO..."
cd "$BUILDROOT_DIR"
make O="${OUTPUT_DIR}" -j$(nproc)

ISO_PATH="${OUTPUT_DIR}/images/rootfs.iso9660"
if [ -f "$ISO_PATH" ]; then
    FINAL_ISO="${AINUX_ROOT}/ainux.iso"
    cp "$ISO_PATH" "$FINAL_ISO"
    
    SIZE=$(du -h "$FINAL_ISO" | cut -f1)
    echo ""
    echo "  🐋 ═══════════════════════════════════════════════════════"
    echo "  🐋  BUILD COMPLETE!"
    echo "  🐋  ISO: ${FINAL_ISO} (${SIZE})"
    echo "  🐋"
    echo "  🐋  Test with QEMU:"
    echo "  🐋    ./scripts/run-qemu.sh"
    echo "  🐋"
    echo "  🐋  Flash to USB:"
    echo "  🐋    sudo dd if=ainux.iso of=/dev/sdX bs=4M status=progress"
    echo "  🐋 ═══════════════════════════════════════════════════════"
    echo ""
else
    echo "ERROR: ISO generation failed. Check build logs."
    exit 1
fi
