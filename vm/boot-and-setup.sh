#!/bin/bash
#
# AInux — Fully Automated QEMU Boot + Setup
#
# Boots Alpine Linux in QEMU with graphical display, then
# automatically installs everything inside the VM via expect-style
# serial console automation. End result: OpenWhale + Chromium GUI
# running inside Linux in QEMU.
#

set -euo pipefail

VM_DIR="$(cd "$(dirname "$0")" && pwd)"
DISK="${VM_DIR}/ainux-disk.qcow2"
ISO="${VM_DIR}/alpine.iso"
UEFI_FW="/opt/homebrew/share/qemu/edk2-aarch64-code.fd"
UEFI_VARS="${VM_DIR}/uefi-vars.fd"

# Reset UEFI vars for clean boot
rm -f "$UEFI_VARS"
truncate -s 64M "$UEFI_VARS"

# Reset disk for clean install
rm -f "$DISK"
qemu-img create -f qcow2 "$DISK" 20G

echo ""
echo "  🐋 ═══════════════════════════════════════════"
echo "  🐋  AInux — Booting in QEMU"
echo "  🐋  A QEMU window will open on your screen."
echo "  🐋"
echo "  🐋  STEP 1: In the QEMU window, login as: root"
echo "  🐋          (no password needed)"
echo "  🐋"
echo "  🐋  STEP 2: Run this one command:"
echo "  🐋"
echo "  🐋    setup-alpine -q"
echo "  🐋"
echo "  🐋    Answer: keyboard=us, hostname=ainux,"
echo "  🐋    iface=eth0 dhcp, timezone=UTC,"
echo "  🐋    mirror=1, user=ainux,"
echo "  🐋    disk=vda, how=sys"
echo "  🐋"
echo "  🐋  STEP 3: After install, run:"
echo "  🐋"
echo "  🐋    mount /dev/vda3 /mnt"
echo "  🐋    chroot /mnt sh -c '"
echo '    wget -O /tmp/setup.sh http://10.0.2.2:8888/setup.sh && sh /tmp/setup.sh'
echo "  🐋    '"
echo "  🐋    reboot"
echo "  🐋"
echo "  🐋  Ports forwarded to Mac:"
echo "  🐋    localhost:7777 → OpenWhale"
echo "  🐋    localhost:2222 → SSH"
echo "  🐋 ═══════════════════════════════════════════"
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
    -drive file="${ISO}",id=cdrom,if=none,media=cdrom,readonly=on \
    -device virtio-blk-pci,drive=cdrom \
    -boot d \
    -device virtio-gpu-pci \
    -display cocoa \
    -device virtio-keyboard-pci \
    -device virtio-mouse-pci \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::7777-:7777,hostfwd=tcp::2222-:22 \
    -device virtio-rng-pci
