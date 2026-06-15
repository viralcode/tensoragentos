#!/bin/bash
#
# TensorAgent OS — VMware Fusion Launcher
# Creates a VMware VM bundle from the qcow2 disk and boots it.
#
# Usage:
#   ./scripts/launch-vmware.sh
#

set -euo pipefail

AINUX_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VMWARE_DIR="${AINUX_ROOT}/vmware_build"
VMX_FILE="${VMWARE_DIR}/TensorAgentOS.vmx"
VMDK_FILE="${VMWARE_DIR}/ainux.vmdk"
QCOW2_FILE="${AINUX_ROOT}/vm/ainux.qcow2"

echo ""
echo "  🐋 TensorAgent OS — VMware Fusion Launcher"
echo "  ════════════════════════════════════════════"
echo ""

# Check VMware Fusion
if ! command -v vmrun &>/dev/null; then
    echo "  ✗ VMware Fusion not found"
    echo "    Install VMware Fusion from https://www.vmware.com/products/desktop-hypervisor"
    exit 1
fi
echo "  ✓ VMware Fusion found"

# Check QCOW2
if [ ! -f "$QCOW2_FILE" ]; then
    echo "  ✗ No QCOW2 disk image found at $QCOW2_FILE"
    echo "    Run: python3 vm/launch-ainux.py to create one first"
    exit 1
fi

# Convert if VMDK doesn't exist or is older than QCOW2
if [ ! -f "$VMDK_FILE" ] || [ "$QCOW2_FILE" -nt "$VMDK_FILE" ]; then
    echo "  → Converting QCOW2 → VMDK (this takes a few minutes)..."
    mkdir -p "$VMWARE_DIR"
    qemu-img convert -p -f qcow2 -O vmdk "$QCOW2_FILE" "$VMDK_FILE"
    echo "  ✓ Conversion complete"
else
    echo "  ✓ VMDK is up to date"
fi

# Ensure VMX exists
if [ ! -f "$VMX_FILE" ]; then
    echo "  ✗ VMX configuration not found"
    exit 1
fi

# Check if VM is already running
if vmrun list 2>/dev/null | grep -q "TensorAgentOS"; then
    echo "  ⚠ VM is already running"
    echo ""
    echo "  Dashboard: http://localhost:7777/dashboard"
    echo "  SSH:       ssh ainux@<vm-ip> -p 22"
    exit 0
fi

echo "  → Starting TensorAgent OS in VMware Fusion..."
echo ""

# Start the VM
vmrun start "$VMX_FILE" gui 2>/dev/null || {
    # If vmrun fails, try opening directly
    open "$VMX_FILE"
}

echo "  ✓ VM started!"
echo ""
echo "  ┌─────────────────────────────────────────────┐"
echo "  │ TensorAgent OS is booting in VMware Fusion   │"
echo "  │                                              │"
echo "  │ First boot takes ~5 minutes for setup.       │"
echo "  │                                              │"
echo "  │ After boot:                                  │"
echo "  │   Dashboard: http://<vm-ip>:7777/dashboard   │"
echo "  │   SSH:       ssh ainux@<vm-ip>               │"
echo "  │                                              │"
echo "  │ Get VM IP:                                   │"
echo "  │   vmrun getGuestIPAddress \"$VMX_FILE\"        │"
echo "  └─────────────────────────────────────────────┘"
echo ""
