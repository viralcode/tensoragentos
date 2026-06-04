#!/bin/bash
#
# TensorAgent OS — VMware Fusion Builder (macOS ARM64)
#
# Converts the QEMU-based AInux disk image into a ready-to-boot
# VMware Fusion virtual machine bundle (.vmwarevm).
#
# Prerequisites:
#   - qemu-img (brew install qemu)
#   - VMware Fusion installed at /Applications/VMware Fusion.app
#   - A working AInux qcow2 disk image (from launch-ainux.py)
#
# Usage:
#   ./scripts/build-vmware.sh                  # Uses existing ainux.qcow2
#   ./scripts/build-vmware.sh --fresh          # Build from base image first
#   ./scripts/build-vmware.sh --open           # Build and open in VMware Fusion
#
# Output:
#   build/vmware/AInux.vmwarevm/               # VMware Fusion bundle
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AINUX_ROOT="$(dirname "$SCRIPT_DIR")"
VM_DIR="${AINUX_ROOT}/vm"
BUILD_DIR="${AINUX_ROOT}/build/vmware"
BUNDLE_DIR="${BUILD_DIR}/AInux.vmwarevm"

QCOW2_DISK="${VM_DIR}/ainux.qcow2"
BASE_DISK="${VM_DIR}/ubuntu-server.qcow2"
VMDK_DISK="${BUNDLE_DIR}/ainux.vmdk"
VMX_FILE="${BUNDLE_DIR}/AInux.vmx"

VMWARE_VDISK="/Applications/VMware Fusion.app/Contents/Library/vmware-vdiskmanager"
VMWARE_APP="/Applications/VMware Fusion.app"

OPEN_AFTER=false
FRESH_BUILD=false

# ── Parse arguments ─────────────────────────────────────────────
for arg in "$@"; do
    case $arg in
        --open)  OPEN_AFTER=true ;;
        --fresh) FRESH_BUILD=true ;;
        --help)
            echo "Usage: $0 [--fresh] [--open]"
            echo "  --fresh   Build from base Ubuntu image (runs cloud-init)"
            echo "  --open    Open in VMware Fusion after building"
            exit 0
            ;;
    esac
done

echo ""
echo "  🐋 ═══════════════════════════════════════════════════════"
echo "  🐋  TensorAgent OS — VMware Fusion Builder"
echo "  🐋  Target: ARM64 (Apple Silicon)"
echo "  🐋 ═══════════════════════════════════════════════════════"
echo ""

# ── 1. Prerequisites ────────────────────────────────────────────
echo "[1/4] Checking prerequisites..."

if ! command -v qemu-img &>/dev/null; then
    echo "  ✗ qemu-img not found. Install with: brew install qemu"
    exit 1
fi
echo "  ✓ qemu-img found"

if [ ! -d "$VMWARE_APP" ]; then
    echo "  ✗ VMware Fusion not found at $VMWARE_APP"
    exit 1
fi
echo "  ✓ VMware Fusion found"

# ── 2. Prepare source disk ─────────────────────────────────────
echo "[2/4] Preparing source disk image..."

if [ "$FRESH_BUILD" = true ] || [ ! -f "$QCOW2_DISK" ]; then
    if [ ! -f "$BASE_DISK" ]; then
        echo "  ✗ No base image found at $BASE_DISK"
        echo "    Download with:"
        echo '    curl -L -o vm/ubuntu-server.qcow2 "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-arm64.img"'
        exit 1
    fi
    echo "  → Copying base image and resizing to 20GB..."
    cp "$BASE_DISK" "$QCOW2_DISK"
    qemu-img resize "$QCOW2_DISK" 20G
    echo "  ✓ Fresh 20GB disk ready (cloud-init will run on first VMware boot)"
else
    echo "  ✓ Using existing ainux.qcow2 ($(du -h "$QCOW2_DISK" | cut -f1))"
fi

# ── 3. Convert to VMDK and create VMware bundle ────────────────
echo "[3/4] Building VMware Fusion bundle..."

# Clean previous build
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR"

# Convert qcow2 → VMDK (VMware compatible)
echo "  → Converting qcow2 → VMDK (this may take a minute)..."
qemu-img convert -f qcow2 -O vmdk -o subformat=monolithicSparse "$QCOW2_DISK" "$VMDK_DISK"
echo "  ✓ VMDK created ($(du -h "$VMDK_DISK" | cut -f1))"

# Also convert the cloud-init seed image if it exists
SEED_IMG="${VM_DIR}/seed.img"
SEED_VMDK="${BUNDLE_DIR}/seed.vmdk"
if [ -f "$SEED_IMG" ]; then
    echo "  → Converting seed.img → VMDK..."
    qemu-img convert -f raw -O vmdk "$SEED_IMG" "$SEED_VMDK"
    echo "  ✓ Seed VMDK created"
    HAS_SEED=true
else
    HAS_SEED=false
    echo "  ⚠ No seed.img found — cloud-init won't run unless you run launch-ainux.py first"
fi

# Create UEFI firmware copy for VMware (it needs its own vars file)
UEFI_VARS="${BUNDLE_DIR}/efivars.vmdk"
echo "  → Creating EFI vars disk..."
# Create a small 64MB disk for EFI variables
dd if=/dev/zero of="${BUNDLE_DIR}/efivars.raw" bs=1M count=64 2>/dev/null
qemu-img convert -f raw -O vmdk "${BUNDLE_DIR}/efivars.raw" "$UEFI_VARS" 2>/dev/null || true
rm -f "${BUNDLE_DIR}/efivars.raw"

# ── Create VMX configuration ───────────────────────────────────
echo "  → Generating VMX configuration..."

# Seed disk entry (conditional)
SEED_VMX_ENTRY=""
if [ "$HAS_SEED" = true ]; then
    SEED_VMX_ENTRY='
# Cloud-init seed disk
nvme0:1.present = "TRUE"
nvme0:1.fileName = "seed.vmdk"
nvme0:1.deviceType = "disk"'
fi

cat > "$VMX_FILE" << VMXEOF
.encoding = "UTF-8"
displayName = "AInux - TensorAgent OS"

# ── Virtual Hardware ──────────────────────────────────────────
config.version = "8"
virtualHW.version = "21"
guestOS = "arm-ubuntu-64"

# PCIe Root Ports (needed for VMware Fusion ARM64 to attach PCIe devices)
pciBridge0.present = "TRUE"
pciBridge4.present = "TRUE"
pciBridge4.virtualDev = "pcieRootPort"
pciBridge4.functions = "8"
pciBridge5.present = "TRUE"
pciBridge5.virtualDev = "pcieRootPort"
pciBridge5.functions = "8"
pciBridge6.present = "TRUE"
pciBridge6.virtualDev = "pcieRootPort"
pciBridge6.functions = "8"
pciBridge7.present = "TRUE"
pciBridge7.virtualDev = "pcieRootPort"
pciBridge7.functions = "8"

# ── CPU & Memory ─────────────────────────────────────────────
numvcpus = "4"
cpuid.coresPerSocket = "4"
memsize = "6144"

# ── Firmware (UEFI for ARM64) ────────────────────────────────
firmware = "efi"
uefi.secureBoot.enabled = "FALSE"

# ── Display ──────────────────────────────────────────────────
svga.autodetect = "TRUE"
svga.vramSize = "268435456"
mks.enable3d = "TRUE"

# ── Main Boot Disk (NVMe) ───────────────────────────────────
nvme0.present = "TRUE"
nvme0:0.present = "TRUE"
nvme0:0.fileName = "ainux.vmdk"
nvme0:0.deviceType = "disk"
${SEED_VMX_ENTRY}

# ── Networking (NAT — auto DHCP) ────────────────────────────
ethernet0.present = "TRUE"
ethernet0.connectionType = "nat"
ethernet0.virtualDev = "vmxnet3"
ethernet0.addressType = "generated"
ethernet0.wakeOnPcktRcv = "FALSE"

# ── USB ─────────────────────────────────────────────────────
usb.present = "TRUE"
usb_xhci.present = "TRUE"
usb.generic.autoconnect = "TRUE"

# ── Sound ───────────────────────────────────────────────────
sound.present = "TRUE"
sound.autodetect = "TRUE"
sound.virtualDev = "hdaudio"

# ── Serial (for debug console) ──────────────────────────────
serial0.present = "TRUE"
serial0.fileType = "file"
serial0.fileName = "serial.log"

# ── Misc ────────────────────────────────────────────────────
tools.syncTime = "TRUE"
tools.upgrade.policy = "manual"
powerType.powerOff = "soft"
powerType.suspend = "soft"
powerType.reset = "soft"
msg.autoAnswer = "TRUE"
uuid.action = "create"

# ── Shared Folders (optional) ───────────────────────────────
sharedFolder0.present = "FALSE"
isolation.tools.hgfs.disable = "FALSE"

# ── Performance ─────────────────────────────────────────────
sched.cpu.units = "mhz"
sched.cpu.affinity = "all"
VMXEOF

echo "  ✓ VMX configuration created"

# ── 4. Final summary ──────────────────────────────────────────
echo "[4/4] Finalizing..."

# Create a convenience launch script
cat > "${BUILD_DIR}/launch-vmware.sh" << 'LAUNCHEOF'
#!/bin/bash
# Quick launcher for AInux in VMware Fusion
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLE="${SCRIPT_DIR}/AInux.vmwarevm"
VMX="${BUNDLE}/AInux.vmx"

if [ ! -f "$VMX" ]; then
    echo "✗ VM not found. Run: ./scripts/build-vmware.sh"
    exit 1
fi

echo "🐋 Starting AInux in VMware Fusion..."
open -a "VMware Fusion" "$VMX"
LAUNCHEOF
chmod +x "${BUILD_DIR}/launch-vmware.sh"

# Calculate sizes
BUNDLE_SIZE=$(du -sh "$BUNDLE_DIR" | cut -f1)

echo ""
echo "  🐋 ═══════════════════════════════════════════════════════"
echo "  🐋  BUILD COMPLETE!"
echo "  🐋"
echo "  🐋  Bundle:  ${BUNDLE_DIR}/"
echo "  🐋  Size:    ${BUNDLE_SIZE}"
echo "  🐋"
echo "  🐋  To launch:"
echo "  🐋    open -a 'VMware Fusion' '${VMX_FILE}'"
echo "  🐋    — or —"
echo "  🐋    ./build/vmware/launch-vmware.sh"
echo "  🐋"
echo "  🐋  Credentials:"
echo "  🐋    User: ainux  |  Password: ainux"
echo "  🐋    SSH:  ssh ainux@<vm-ip> (password: ainux)"
echo "  🐋    Web:  http://<vm-ip>:7777/ (OpenWhale)"
echo "  🐋"
if [ "$HAS_SEED" = false ]; then
    echo "  🐋  ⚠ NOTE: No seed.img found. For first-time setup,"
    echo "  🐋    run 'python3 vm/launch-ainux.py' in QEMU first,"
    echo "  🐋    then re-run this script to package for VMware."
fi
echo "  🐋 ═══════════════════════════════════════════════════════"
echo ""

# Open in VMware if requested
if [ "$OPEN_AFTER" = true ]; then
    echo "  → Opening in VMware Fusion..."
    open -a "VMware Fusion" "$VMX_FILE"
fi
