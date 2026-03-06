#!/bin/bash
#
# AInux QEMU Boot Script — Apple Silicon (ARM64 + HVF)
#
# Boots AInux (Alpine Linux base) with hardware-accelerated
# virtualization in a graphical QEMU window.
#
# First boot: boots from Alpine ISO for installation
# Subsequent boots: boots from the installed disk
#
# Usage:
#   ./vm/boot-ainux.sh              — Normal boot (from disk)
#   ./vm/boot-ainux.sh --install    — First install (from ISO)
#

set -euo pipefail

VM_DIR="$(cd "$(dirname "$0")" && pwd)"
DISK="${VM_DIR}/ainux.qcow2"
ISO="${VM_DIR}/alpine.iso"
UEFI_FW="/opt/homebrew/share/qemu/edk2-aarch64-code.fd"
UEFI_VARS="${VM_DIR}/uefi-vars.fd"

INSTALL_MODE=false
for arg in "$@"; do
    case $arg in
        --install) INSTALL_MODE=true ;;
    esac
done

# Create UEFI vars only if missing — never wipe, it stores GRUB's boot entry
if [ ! -f "$UEFI_VARS" ]; then
    truncate -s 64M "$UEFI_VARS"
fi
# startup.nsh is baked into the disk's EFI partition (FS0) so UEFI shell
# auto-boots BOOTAA64.EFI even when NVRAM is blank

echo ""
echo "  🐋 ═══════════════════════════════════════"
echo "  🐋  AInux — AI Agentic Operating System"
echo "  🐋  Booting in QEMU (ARM64 + HVF)..."
echo "  🐋 ═══════════════════════════════════════"

if [ "$INSTALL_MODE" = true ]; then
    echo "  🐋  MODE: Installation (booting from ISO)"
    echo "  🐋"
    echo "  🐋  After Alpine boots, run:"
    echo "  🐋    setup-alpine"
    echo "  🐋    (use 'sys' disk mode, select vda)"
    echo "  🐋  Then run the AInux setup:"
    echo "  🐋    wget -O- http://10.0.2.2:8888/setup.sh | sh"
    echo ""

    CDROM="-drive file=${ISO},id=cdrom,if=none,media=cdrom,readonly=on -device virtio-blk-pci,drive=cdrom"
    BOOT_ORDER="-boot d"
else
    echo "  🐋  MODE: Normal boot (from disk)"
    CDROM=""
    BOOT_ORDER="-boot c"
fi

echo "  🐋  Forwarded ports:"
echo "  🐋    localhost:7777 → OpenWhale"
echo "  🐋    localhost:2222 → SSH"
echo "  🐋 ═══════════════════════════════════════"
echo ""

exec qemu-system-aarch64 \
    -machine virt \
    -accel hvf \
    -cpu host \
    -m 4G \
    -smp 4 \
    -drive if=pflash,format=raw,file="${UEFI_FW}",readonly=on \
    -drive if=pflash,format=raw,file="${UEFI_VARS}" \
    -drive file="${DISK}",if=none,id=hd0,format=qcow2 \
    -device virtio-blk-pci,drive=hd0 \
    ${CDROM} \
    ${BOOT_ORDER} \
    -device virtio-gpu-pci \
    -display cocoa \
    -device virtio-keyboard-pci \
    -device qemu-xhci \
    -device usb-tablet \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::7777-:7777,hostfwd=tcp::2222-:22 \
    -device virtio-rng-pci \
    -serial mon:stdio
