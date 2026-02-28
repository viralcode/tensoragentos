#!/bin/bash
#
# AInux QEMU Test Runner
#
# Boots the AInux ISO in a QEMU virtual machine for testing.
# Requires: qemu-system-x86_64 (with KVM if on Linux)
#
# Usage: ./scripts/run-qemu.sh [--no-kvm] [--vnc]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AINUX_ROOT="$(dirname "$SCRIPT_DIR")"
ISO="${AINUX_ROOT}/ainux.iso"
DISK="${AINUX_ROOT}/build/ainux-disk.qcow2"

KVM=""
DISPLAY_OPT="-display gtk,gl=on"
EXTRA_ARGS=""

# Detect KVM support
if [ -e /dev/kvm ]; then
    KVM="-enable-kvm -cpu host"
    echo "[qemu] KVM acceleration enabled"
else
    KVM="-cpu qemu64"
    echo "[qemu] No KVM, using software emulation (slower)"
fi

# Parse arguments
for arg in "$@"; do
    case $arg in
        --no-kvm) KVM="-cpu qemu64" ;;
        --vnc) DISPLAY_OPT="-vnc :0" ;;
        --headless) DISPLAY_OPT="-display none -daemonize" ;;
    esac
done

# Check for ISO
if [ ! -f "$ISO" ]; then
    echo "ERROR: AInux ISO not found at $ISO"
    echo "Build it first: ./scripts/build-iso.sh"
    exit 1
fi

# Create persistent disk if it doesn't exist
if [ ! -f "$DISK" ]; then
    echo "[qemu] Creating 20GB persistent disk..."
    qemu-img create -f qcow2 "$DISK" 20G
fi

echo ""
echo "  🐋 AInux QEMU VM"
echo "  ISO: ${ISO}"
echo "  Disk: ${DISK}"
echo "  RAM: 8GB | CPUs: 4"
echo "  Forwarded: localhost:7777 → :7777 (OpenWhale)"
echo "  Forwarded: localhost:2222 → :22 (SSH)"
echo ""

exec qemu-system-x86_64 \
    $KVM \
    -m 8G \
    -smp 4 \
    -drive file="$ISO",format=raw,media=cdrom,readonly=on \
    -drive file="$DISK",format=qcow2 \
    -boot d \
    -device virtio-vga-gl \
    $DISPLAY_OPT \
    -device virtio-net,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::7777-:7777,hostfwd=tcp::2222-:22 \
    -device virtio-balloon \
    -device virtio-keyboard \
    -device virtio-mouse \
    -device intel-hda \
    -device hda-duplex \
    -usb \
    -device usb-tablet \
    $EXTRA_ARGS
