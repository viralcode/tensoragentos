#!/bin/bash
#
# TensorAgent OS — Fully Automated QEMU Setup
#
# Boots Debian, installs to disk, installs OpenWhale + WhaleOS,
# and configures boot-to-GUI — ALL AUTOMATED.
#
# This script drives QEMU via monitor socket keystrokes.
# It creates a fresh Debian Bookworm VM with TensorAgent OS
# pre-configured and both services enabled on boot.
#

set -euo pipefail

VM_DIR="$(cd "$(dirname "$0")" && pwd)"
DISK="${VM_DIR}/ainux-disk.qcow2"
ISO="${VM_DIR}/alpine.iso"
UEFI_FW="/opt/homebrew/share/qemu/edk2-aarch64-code.fd"
UEFI_VARS="${VM_DIR}/uefi-vars.fd"
MONITOR_SOCK="${VM_DIR}/qemu-monitor.sock"

# ── Clean state ──
rm -f "$UEFI_VARS" "$MONITOR_SOCK"
truncate -s 64M "$UEFI_VARS"
rm -f "$DISK"
qemu-img create -f qcow2 "$DISK" 20G

echo ""
echo "  🐋 TensorAgent OS Auto-Setup — Starting QEMU..."
echo ""

# ── Start QEMU in background ──
qemu-system-aarch64 \
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
    -device virtio-rng-pci \
    -monitor unix:${MONITOR_SOCK},server,nowait &

echo "  🐋 QEMU started (graphical window should be visible)"
echo "  🐋 Waiting 20s for Alpine to boot..."
sleep 20

# ── Helper: send a string as keystrokes via QEMU monitor ──
send_keys() {
    local text="$1"
    for (( i=0; i<${#text}; i++ )); do
        local c="${text:$i:1}"
        local key=""
        case "$c" in
            [a-z]) key="$c" ;;
            [A-Z]) key="shift-$(echo "$c" | tr A-Z a-z)" ;;
            [0-9]) key="$c" ;;
            ' ')   key="spc" ;;
            '/')   key="slash" ;;
            '.')   key="dot" ;;
            '-')   key="minus" ;;
            ':')   key="shift-semicolon" ;;
            '=')   key="equal" ;;
            '_')   key="shift-minus" ;;
            ',')   key="comma" ;;
            ';')   key="semicolon" ;;
            "'")   key="apostrophe" ;;
            '"')   key="shift-apostrophe" ;;
            '!')   key="shift-1" ;;
            '@')   key="shift-2" ;;
            '#')   key="shift-3" ;;
            '$')   key="shift-4" ;;
            '&')   key="shift-7" ;;
            '*')   key="shift-8" ;;
            '(')   key="shift-9" ;;
            ')')   key="shift-0" ;;
            '+')   key="shift-equal" ;;
            '?')   key="shift-slash" ;;
            '\')   key="backslash" ;;
            '|')   key="shift-backslash" ;;
            '[')   key="bracket_left" ;;
            ']')   key="bracket_right" ;;
            '{')   key="shift-bracket_left" ;;
            '}')   key="shift-bracket_right" ;;
            '~')   key="shift-grave_accent" ;;
            '`')   key="grave_accent" ;;
            '<')   key="shift-comma" ;;
            '>')   key="shift-dot" ;;
            '%')   key="shift-5" ;;
            *)     key="spc" ;; # fallback
        esac
        echo "sendkey $key" | socat - UNIX-CONNECT:${MONITOR_SOCK} 2>/dev/null
        sleep 0.05
    done
}

send_enter() {
    echo "sendkey ret" | socat - UNIX-CONNECT:${MONITOR_SOCK} 2>/dev/null
    sleep 0.3
}

send_line() {
    send_keys "$1"
    send_enter
    sleep "${2:-1}"
}

echo "  🐋 Logging in as root..."
send_line "root" 3

echo "  🐋 Running setup-alpine with answerfile..."

# Use setup-alpine in quick mode with environment variables
send_line "export KEYMAPOPTS='us us'" 1
send_line "export HOSTNAMEOPTS='ainux'" 1
send_line "export INTERFACESOPTS='auto lo
auto eth0
iface eth0 inet dhcp'" 1
send_line "export TIMEZONEOPTS='UTC'" 1
send_line "export PROXYOPTS='none'" 1
send_line "export APKREPOSOPTS='-1'" 1
send_line "export SSHDOPTS='openssh'" 1
send_line "export NTPOPTS='chrony'" 1
send_line "export DISKOPTS='-m sys /dev/vda'" 1
send_line "printf 'ainux\nainux\ny\n' | setup-alpine -e" 30

echo "  🐋 Alpine installed to disk. Now setting up TensorAgent OS..."

# Mount installed system and run setup
send_line "mount /dev/vda3 /mnt 2>/dev/null || mount /dev/vda2 /mnt" 2
send_line "mount --bind /proc /mnt/proc" 1
send_line "mount --bind /sys /mnt/sys" 1
send_line "mount --bind /dev /mnt/dev" 1

echo "  🐋 Installing packages inside the new system..."
send_line "chroot /mnt sh -c 'sed -i \"s/#.*community/community/\" /etc/apk/repositories && apk update'" 10
send_line "chroot /mnt apk add --no-cache nodejs npm git chromium cage font-dejavu dbus mesa-dri-gallium eudev bash sudo openssh libpam-dev" 45

echo "  🐋 Cloning OpenWhale..."
send_line "chroot /mnt sh -c 'mkdir -p /opt/ainux && git clone https://github.com/viralcode/openwhale.git /opt/ainux/openwhale'" 30
send_line "chroot /mnt sh -c 'cd /opt/ainux/openwhale && npm install --legacy-peer-deps 2>/dev/null'" 60

echo "  🐋 Creating ainux user..."
send_line "chroot /mnt adduser -D -s /bin/bash ainux" 2
send_line "printf 'ainux\nainux\n' | chroot /mnt passwd ainux" 2
send_line "chroot /mnt addgroup ainux wheel 2>/dev/null" 1
send_line "chroot /mnt addgroup ainux video 2>/dev/null" 1
send_line "chroot /mnt addgroup ainux input 2>/dev/null" 1
send_line "chroot /mnt sh -c 'echo \"%wheel ALL=(ALL) NOPASSWD: ALL\" >> /etc/sudoers'" 1

echo "  🐋 Setting up OpenWhale .env..."
send_line "cat > /mnt/opt/ainux/openwhale/.env << 'EOF'
PORT=7777
NODE_ENV=production
AINUX_MODE=true
AINUX_VERSION=0.2.0
EOF" 1

echo "  🐋 Creating services..."

# ── OpenWhale service (OpenRC) ──
send_line "cat > /mnt/etc/init.d/openwhale << 'SVCEOF'
#!/sbin/openrc-run
name=\"OpenWhale AI Platform\"
command=\"/usr/bin/node\"
command_args=\"/opt/ainux/openwhale/openwhale.mjs\"
command_user=\"ainux\"
command_background=true
pidfile=\"/run/openwhale.pid\"
directory=\"/opt/ainux/openwhale\"
start_stop_daemon_args=\"--env HOME=/home/ainux --env NODE_ENV=production --env PORT=7777\"
output_log=\"/var/log/openwhale.log\"
error_log=\"/var/log/openwhale.err\"
depend() { need net; }
SVCEOF" 1
send_line "chmod +x /mnt/etc/init.d/openwhale" 1

# ── WhaleOS GUI service (OpenRC) ──
send_line "cat > /mnt/etc/init.d/ainux-gui << 'SVCEOF'
#!/sbin/openrc-run
name=\"TensorAgent OS Desktop Shell\"
command=\"/usr/bin/cage\"
command_args=\"-- /usr/bin/su -s /bin/bash -c /opt/ainux/whaleos/whaleos ainux\"
command_background=true
pidfile=\"/run/ainux-gui.pid\"
start_stop_daemon_args=\"--env HOME=/home/ainux --env XDG_RUNTIME_DIR=/tmp/ainux-xdg --env WLR_LIBINPUT_NO_DEVICES=1 --env WLR_NO_HARDWARE_CURSORS=1 --env QT_QPA_PLATFORM=wayland --env QSG_RENDER_LOOP=basic\"
output_log=\"/var/log/ainux-gui.log\"
error_log=\"/var/log/ainux-gui.err\"
depend() { need openwhale dbus; }
start_pre() {
    mkdir -p /tmp/ainux-xdg && chown ainux /tmp/ainux-xdg && chmod 700 /tmp/ainux-xdg
    local i=0
    while [ \$i -lt 15 ]; do
        if wget -q -O /dev/null http://localhost:7777/health 2>/dev/null; then break; fi
        sleep 1; i=\$((i + 1))
    done
}
SVCEOF" 1
send_line "chmod +x /mnt/etc/init.d/ainux-gui" 1

# ── ENABLE BOTH SERVICES ON BOOT ──
echo "  🐋 Enabling services on boot..."
send_line "chroot /mnt rc-update add dbus default" 1
send_line "chroot /mnt rc-update add openwhale default" 1
send_line "chroot /mnt rc-update add ainux-gui default" 1
send_line "chroot /mnt rc-update add openssh default" 1

# Set hostname
send_line "echo 'ainux' > /mnt/etc/hostname" 1

# Set MOTD
send_line "echo '🐋 TensorAgent OS v0.2.0 — AI-Native Operating System' > /mnt/etc/motd" 1

# Chown to ainux
send_line "chroot /mnt chown -R ainux:ainux /opt/ainux" 2
send_line "chroot /mnt mkdir -p /home/ainux/.openwhale/memory" 1
send_line "echo 'I am running on TensorAgent OS.' > /mnt/home/ainux/.openwhale/memory/MEMORY.md" 1
send_line "chroot /mnt chown -R ainux:ainux /home/ainux" 1

# ── Auto-login on tty1 ──
send_line "sed -i 's|^tty1::.*|tty1::respawn:/bin/login -f ainux|' /mnt/etc/inittab 2>/dev/null" 1

echo ""
echo "  🐋 ═══════════════════════════════════════════"
echo "  🐋  Setup complete! Rebooting into TensorAgent OS..."
echo "  🐋 ═══════════════════════════════════════════"
echo ""

# Unmount and reboot
send_line "umount /mnt/dev /mnt/proc /mnt/sys 2>/dev/null" 1
send_line "umount /mnt" 1
send_line "reboot" 5

echo "  🐋 TensorAgent OS is rebooting from disk."
echo "  🐋 OpenWhale will auto-start on :7777"
echo "  🐋 Desktop shell will auto-launch in QEMU."
echo "  🐋 SSH: ssh ainux@localhost -p 2222 (password: ainux)"
echo ""
