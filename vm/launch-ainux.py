#!/usr/bin/env python3
"""
AInux — One-Command Custom Linux Distro Builder & Runner
 
Downloads Debian ARM64 generic image, injects cloud-init config
that auto-installs everything, boots in QEMU with HVF acceleration.

First boot: cloud-init runs (~3-5 min), installs OpenWhale, Firefox, Cage
Second boot: boots straight into OpenWhale GUI in Firefox kiosk mode

Usage: python3 vm/launch-ainux.py
"""

import subprocess, os, sys, time, json, shutil, base64

# Force output flushing
sys.stdout.reconfigure(line_buffering=True)

VM_DIR = os.path.dirname(os.path.abspath(__file__))
AINUX_ROOT = os.path.dirname(VM_DIR)

DISK    = os.path.join(VM_DIR, "ainux.qcow2")
BASE    = os.path.join(VM_DIR, "debian-generic.qcow2")
UEFI_FW = "/opt/homebrew/share/qemu/edk2-aarch64-code.fd"
UEFI_VARS = os.path.join(VM_DIR, "efivars.fd")
SEED_IMG = os.path.join(VM_DIR, "seed.img")
CIDATA_DIR = os.path.join(VM_DIR, "cidata")

# Read login page HTML
LOGIN_HTML_PATH = os.path.join(AINUX_ROOT, "packages", "openwhale", "ainux-login.html")
if os.path.exists(LOGIN_HTML_PATH):
    with open(LOGIN_HTML_PATH, "r") as f:
        LOGIN_HTML_B64 = base64.b64encode(f.read().encode()).decode()
    print("    ✓ Login page found")
else:
    LOGIN_HTML_B64 = base64.b64encode(b"<html><body><h1>AInux</h1><a href='/dashboard'>Open Dashboard</a></body></html>").decode()
    print("    ⚠ Login page not found, using fallback")

# Read patch script
PATCH_SCRIPT_PATH = os.path.join(VM_DIR, "patch-openwhale.py")
if os.path.exists(PATCH_SCRIPT_PATH):
    with open(PATCH_SCRIPT_PATH, "r") as f:
        PATCH_SCRIPT_B64 = base64.b64encode(f.read().encode()).decode()
    print("    ✓ Patch script found")
else:
    PATCH_SCRIPT_B64 = base64.b64encode(b"#!/usr/bin/env python3\nprint('No patch script')\n").decode()
    print("    ⚠ Patch script not found")

# Read WhaleOS files (source + assets, recursive)
WHALEOS_DIR = os.path.join(AINUX_ROOT, "packages", "whaleos")
WHALEOS_FILES = {}
WHALEOS_EXTENSIONS = ('.qml', '.js', '.cpp', '.h', '.sh', '.png', '.wav', '.jpg', '.svg', '.ttf', '.otf')

if os.path.isdir(WHALEOS_DIR):
    for dirpath, dirnames, filenames in os.walk(WHALEOS_DIR):
        for fname in filenames:
            fpath = os.path.join(dirpath, fname)
            relpath = os.path.relpath(fpath, WHALEOS_DIR)
            if fname.endswith(WHALEOS_EXTENSIONS):
                with open(fpath, 'rb') as f:
                    WHALEOS_FILES[relpath] = base64.b64encode(f.read()).decode()
    print(f"    ✓ WhaleOS files found ({len(WHALEOS_FILES)} files)")
else:
    print("    ⚠ WhaleOS directory not found")

print("\n  🐋 ═══════════════════════════════════════")
print("  🐋  AInux — Custom Linux Distro Launcher")
print("  🐋 ═══════════════════════════════════════\n")

# ── 1. Create cloud-init data ───────────────────────────────────────────
print("  [1/4] Creating cloud-init configuration...")
os.makedirs(CIDATA_DIR, exist_ok=True)

meta_data = json.dumps({"instance-id": "ainux-001", "local-hostname": "ainux"})

user_data = """#cloud-config
hostname: ainux
manage_etc_hosts: true
locale: en_US.UTF-8
timezone: UTC

datasource_list: [NoCloud]
datasource:
  NoCloud:
    seedfrom: /

users:
  - name: ainux
    gecos: AInux User
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: false
    plain_text_passwd: ainux
    groups: [sudo, video, audio, input, render, shadow]

ssh_pwauth: true

package_update: true
package_upgrade: false

packages:
  - git
  - curl
  - wget
  - bash
  - sudo
  - openssh-server
  - build-essential
  - python3
  - g++
  - pkg-config
  - cage
  - xwayland
  - xdotool
  - seatd
  - fonts-dejavu
  - dbus
  - dbus-x11
  - mesa-utils
  - libgl1-mesa-dri
  - pipewire
  - pipewire-alsa
  - wireplumber
  - htop
  - procps
  - qt6-base-dev
  - qt6-declarative-dev
  - qml6-module-qtquick
  - qml6-module-qtquick-controls
  - qml6-module-qtquick-layouts
  - qml6-module-qtquick-window
  - qt6-wayland
  - qml6-module-qtqml-workerscript
  - qml6-module-qtquick-templates
  - qml6-module-qtqml
  - qml6-module-qtqml-models
  - qml6-module-qtcore
  - libqt6opengl6-dev
  - galculator
  - mousepad
  - chromium
  - qt6-wayland-dev
  - qml6-module-qtwayland-compositor
  - wl-clipboard
  - xclip
  - xsel
  - autocutsel
  - wlr-randr
  - open-vm-tools
  - net-tools
  - network-manager
  - isc-dhcp-client

write_files:
  - path: /opt/ainux/ainux-login.b64
    content: """ + LOGIN_HTML_B64 + """
    permissions: '0644'
  - path: /opt/ainux/patch-openwhale.py
    permissions: '0755'
    encoding: b64
    content: """ + PATCH_SCRIPT_B64 + """
""" + ''.join([
    f"""  - path: /opt/ainux/whaleos/{fname}
    permissions: '0644'
    encoding: b64
    content: {content}
""" for fname, content in WHALEOS_FILES.items()]) + """

bootcmd:
  # ── Restrict cloud-init datasources IMMEDIATELY to avoid 120s EC2/OpenStack probe timeouts ──
  # Without this, cloud-init tries AWS/OpenStack/VMware on every boot (all unreachable in QEMU)
  - mkdir -p /etc/cloud/cloud.cfg.d
  - 'echo "datasource_list: [NoCloud, None]" > /etc/cloud/cloud.cfg.d/99-datasource.cfg'
  # Enable VGA console output so QEMU window shows boot
  - 'sed -i "s/console=ttyAMA0/console=tty0 console=ttyAMA0/" /etc/default/grub 2>/dev/null || true'
  - 'update-grub 2>/dev/null || true'

runcmd:
  # Set password via chpasswd as backup
  - 'echo ainux:ainux | chpasswd'
  - 'echo root:ainux | chpasswd'
  
  # Enable seatd and add user to required groups
  - systemctl enable seatd
  - systemctl start seatd
  - adduser ainux seat 2>/dev/null || true
  - adduser ainux render 2>/dev/null || true
  - adduser ainux video 2>/dev/null || true
  - adduser ainux input 2>/dev/null || true

  # ── Fix boot speed: disable wait-online (QEMU network is always up via DHCP) ──
  # Without this, systemd waits 90s+ for network before starting SSH / other services
  - systemctl disable systemd-networkd-wait-online.service 2>/dev/null || true
  - systemctl mask systemd-networkd-wait-online.service 2>/dev/null || true
  # Also reduce cloud-init datasource probe list to avoid VMware/OVF probing on QEMU
  - |-
    cat > /etc/cloud/cloud.cfg.d/99-datasource.cfg << 'DSEOF'
    datasource_list: [NoCloud, None]
    DSEOF
  
  # Fix GRUB console for VGA output
  - 'sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\\"console=tty0\\"/" /etc/default/grub'
  - update-grub 2>/dev/null || true
  
  # ── Network: Universal DHCP for QEMU / UTM / VMware / VirtualBox ──
  # Covers all common VM network interface names automatically
  - |
    cat > /etc/netplan/01-all-ifaces.yaml << 'NETEOF'
    network:
      version: 2
      renderer: networkd
      ethernets:
        any-eth:
          match:
            name: "e*"
          dhcp4: true
          dhcp6: false
          optional: true
          nameservers:
            addresses: [8.8.8.8, 1.1.1.1, 8.8.4.4]
    NETEOF
  - chmod 600 /etc/netplan/01-all-ifaces.yaml
  - netplan generate 2>/dev/null || true
  - netplan apply 2>/dev/null || true

  # ── Wait for network to be ready ──
  - systemctl enable systemd-networkd-wait-online.service 2>/dev/null || true
  - sleep 5
  - dhclient 2>/dev/null || true

  # ── Install Node.js 22.x ──
  - curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  - apt-get install -y nodejs
  
  # Install global node tools  
  - npm install -g pnpm tsx @anthropic-ai/chrome-devtools-mcp 2>/dev/null || npm install -g pnpm tsx
  
  # Clone and install OpenWhale
  - mkdir -p /opt/ainux
  - git clone https://github.com/viralcode/openwhale.git /opt/ainux/openwhale
  - cd /opt/ainux/openwhale && npm install --legacy-peer-deps 2>/dev/null || true
  
  # Rebuild native modules for Node.js 22
  - cd /opt/ainux/openwhale && npm rebuild better-sqlite3 2>/dev/null || true
  
  # Inject AInux login page into OpenWhale
  - base64 -d /opt/ainux/ainux-login.b64 > /opt/ainux/openwhale/src/dashboard/ainux-login.html
  - rm -f /opt/ainux/ainux-login.b64
  # Patch OpenWhale to serve login page at root /
  - python3 /opt/ainux/patch-openwhale.py
  
  # Build WhaleOS native desktop
  - mkdir -p /opt/ainux/whaleos
  - cd /opt/ainux/whaleos && bash build.sh 2>/dev/null || echo 'WhaleOS build failed'
  - chmod +x /opt/ainux/whaleos/whaleos 2>/dev/null || true
  - rm -f /opt/ainux/patch-openwhale.py
  
  # Create OpenWhale .env
  - |
    cat > /opt/ainux/openwhale/.env << 'ENVEOF'
    PORT=7777
    NODE_ENV=production
    AINUX_MODE=true
    AINUX_VERSION=0.1.0
    ENVEOF
  
  # Set ownership
  - chown -R ainux:ainux /opt/ainux
  - chown -R ainux:ainux /home/ainux
  
  # Create OpenWhale memory context
  - mkdir -p /home/ainux/.openwhale/memory
  - mkdir -p /home/ainux/.openwhale/skills/ainux-system
  - |
    cat > /home/ainux/.openwhale/memory/MEMORY.md << 'MEMEOF'
    ## AInux OS Context
    I am running on AInux, a custom AI-native Linux operating system.
    I am the entire user interface — there is no other desktop.
    I control the hardware via system tools.
    MEMEOF
  - |
    cat > /home/ainux/.openwhale/skills/ainux-system/SKILL.md << 'SKILLEOF'
    ---
    name: ainux-system
    description: AInux OS integration
    ---
    # AInux System
    You are the OS. The user has no other UI. Use system commands to manage hardware, services, and settings.
    SKILLEOF
  - chown -R ainux:ainux /home/ainux/.openwhale
  
  # Create OpenWhale systemd service
  - |
    cat > /etc/systemd/system/openwhale.service << 'OWEOF'
    [Unit]
    Description=OpenWhale AI Platform
    After=network-online.target
    Wants=network-online.target
    
    [Service]
    Type=simple
    User=ainux
    WorkingDirectory=/opt/ainux/openwhale
    ExecStart=/usr/bin/node /opt/ainux/openwhale/openwhale.mjs
    Environment=HOME=/home/ainux
    Environment=PORT=7777
    Environment=NODE_ENV=production
    Restart=always
    RestartSec=5
    
    [Install]
    WantedBy=multi-user.target
    OWEOF
  
  # ── GUI: Use getty autologin + .bash_profile to launch Cage ──
  # This is the CORRECT approach for a kiosk Wayland compositor.
  # A proper agetty login gives Cage a real VT session so seatd can
  # grant access to /dev/input/* devices. Without this, Cage runs
  # without VT ownership and ALL input (mouse/keyboard) is dead.
  - |
    mkdir -p /etc/systemd/system/getty@tty1.service.d
    cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << 'AEOF'
    [Service]
    ExecStart=
    ExecStart=-/sbin/agetty --autologin ainux --noclear %I $TERM
    AEOF
  - |
    cat > /home/ainux/.bash_profile << 'BPEOF'
    # Auto-start WhaleOS GUI on virtual console login
    if [[ -t 0 ]] && [[ -z "$DISPLAY" ]] && [[ -z "$WAYLAND_DISPLAY" ]]; then
        mkdir -p /run/user/1000
        chown ainux:ainux /run/user/1000
        chmod 700 /run/user/1000
        export HOME=/home/ainux
        export XDG_RUNTIME_DIR=/run/user/1000
        export XDG_SESSION_TYPE=wayland
        export WLR_RENDERER=pixman
        export WLR_NO_HARDWARE_CURSORS=1
        export WLR_DRM_NO_ATOMIC=1
        export QT_QPA_PLATFORM=wayland
        export QT_QUICK_BACKEND=software
        export QSG_RENDER_LOOP=basic
        export LIBGL_ALWAYS_SOFTWARE=1
        exec /usr/bin/cage -- /opt/ainux/whaleos/whaleos
    fi
    BPEOF
  - chown ainux:ainux /home/ainux/.bash_profile
  
  # Create OpenWhale systemd service (standalone, no GUI dep)
  - |
    cat > /etc/systemd/system/openwhale.service << 'OWEOF'
    [Unit]
    Description=OpenWhale AI Platform
    After=network-online.target
    Wants=network-online.target
    
    [Service]
    Type=simple
    User=ainux
    WorkingDirectory=/opt/ainux/openwhale
    ExecStart=/usr/bin/node /opt/ainux/openwhale/openwhale.mjs
    Environment=HOME=/home/ainux
    Environment=PORT=7777
    Environment=NODE_ENV=production
    Restart=always
    RestartSec=5
    
    [Install]
    WantedBy=multi-user.target
    OWEOF
  
  # Enable services
  - systemctl daemon-reload
  - systemctl enable openwhale.service
  - systemctl enable getty@tty1.service
  - systemctl set-default multi-user.target
  
  # Set MOTD
  - |
    cat > /etc/motd << 'MOTDEOF'
    
    🐋 AInux v0.1.0 — AI Agentic Operating System
    
       OpenWhale:  http://localhost:7777/dashboard
       SSH:        ssh ainux@<ip> (password: ainux)
    
    MOTDEOF
  
  # ── Install Google Chrome (official .deb) + Chromium fallback ──
  # Try Google Chrome first, fall back to chromium from apt
  - |
    set -e
    # Add Google Chrome apt repo
    wget -q -O /tmp/google-chrome.gpg https://dl.google.com/linux/linux_signing_key.pub 2>/dev/null || true
    if [ -f /tmp/google-chrome.gpg ]; then
      gpg --dearmor < /tmp/google-chrome.gpg > /usr/share/keyrings/google-chrome.gpg 2>/dev/null || true
      echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main' > /etc/apt/sources.list.d/google-chrome.list || true
      apt-get update -qq 2>/dev/null || true
      apt-get install -y google-chrome-stable 2>/dev/null && ln -sf /usr/bin/google-chrome-stable /usr/local/bin/chromium 2>/dev/null || true
    fi
    # Ensure chromium binary exists (use chromium package as fallback)
    if ! which chromium &>/dev/null && ! which chromium-browser &>/dev/null; then
      apt-get install -y chromium 2>/dev/null || true
    fi
    # Create universal chromium wrapper script
    CHROME_BIN=$(which google-chrome-stable 2>/dev/null || which chromium-browser 2>/dev/null || which chromium 2>/dev/null || echo "/usr/bin/chromium")
    cat > /usr/local/bin/chromium << CHREOF
    #!/bin/bash
    export DISPLAY=:0
    export XAUTHORITY=/home/ainux/.Xauthority
    export XDG_RUNTIME_DIR=/run/user/1000
    exec $CHROME_BIN --no-sandbox --disable-gpu --disable-software-rasterizer --disable-dev-shm-usage "$@"
    CHREOF
    chmod +x /usr/local/bin/chromium

  # Install Ollama (local AI)
  - curl -fsSL https://ollama.com/install.sh | sh
  - systemctl enable ollama.service
  
  # Create display modes script
  - |
    cat > /opt/ainux/whaleos/add-display-modes.sh << 'DMEOF'
    #!/bin/bash
    sleep 4
    export DISPLAY=:0
    xrandr --newmode "1920x1080_60.00" 173.00 1920 2048 2248 2576 1080 1083 1088 1120 -hsync +vsync 2>/dev/null
    xrandr --addmode XWAYLAND0 "1920x1080_60.00" 2>/dev/null
    xrandr --newmode "1600x900_60.00" 118.25 1600 1696 1856 2112 900 903 908 934 -hsync +vsync 2>/dev/null
    xrandr --addmode XWAYLAND0 "1600x900_60.00" 2>/dev/null
    xrandr --newmode "1440x900_60.00" 106.50 1440 1528 1672 1904 900 903 909 934 -hsync +vsync 2>/dev/null
    xrandr --addmode XWAYLAND0 "1440x900_60.00" 2>/dev/null
    xrandr --newmode "1366x768_60.00" 85.25 1366 1440 1576 1784 768 771 781 798 -hsync +vsync 2>/dev/null
    xrandr --addmode XWAYLAND0 "1366x768_60.00" 2>/dev/null
    xrandr --newmode "1024x768_60.00" 63.50 1024 1072 1176 1328 768 771 775 798 -hsync +vsync 2>/dev/null
    xrandr --addmode XWAYLAND0 "1024x768_60.00" 2>/dev/null
    DMEOF
  - chmod +x /opt/ainux/whaleos/add-display-modes.sh
  
  # Create clipboard bridge script (X11 <-> Wayland)
  - |
    cat > /opt/ainux/whaleos/clipboard-sync.sh << 'CBEOF'
    #!/bin/bash
    export DISPLAY=:0
    export WAYLAND_DISPLAY=wayland-0
    export XDG_RUNTIME_DIR=/run/user/1000
    # Start autocutsel to persist X11 clipboard when apps close
    autocutsel -s CLIPBOARD -fork 2>/dev/null
    autocutsel -fork 2>/dev/null
    LAST_X11=""
    LAST_WL=""
    while true; do
        X11_CLIP=$(xclip -selection clipboard -o 2>/dev/null) || X11_CLIP=""
        WL_CLIP=$(wl-paste --no-newline 2>/dev/null) || WL_CLIP=""
        if [ -n "$X11_CLIP" ] && [ "$X11_CLIP" != "$LAST_X11" ] && [ "$X11_CLIP" != "$WL_CLIP" ]; then
            printf '%s' "$X11_CLIP" | wl-copy 2>/dev/null
            LAST_X11="$X11_CLIP"; LAST_WL="$X11_CLIP"
        fi
        if [ -n "$WL_CLIP" ] && [ "$WL_CLIP" != "$LAST_WL" ] && [ "$WL_CLIP" != "$X11_CLIP" ]; then
            printf '%s' "$WL_CLIP" | xclip -selection clipboard 2>/dev/null
            LAST_WL="$WL_CLIP"; LAST_X11="$WL_CLIP"
        fi
        sleep 0.5
    done
    CBEOF
  - chmod +x /opt/ainux/whaleos/clipboard-sync.sh
  - |
    cat > /etc/systemd/system/clipboard-sync.service << 'CSEOF'
    [Unit]
    Description=Clipboard Bridge (X11 <-> Wayland)
    After=ainux-gui.service
    [Service]
    Type=simple
    User=ainux
    ExecStartPre=/bin/sleep 5
    ExecStart=/opt/ainux/whaleos/clipboard-sync.sh
    Restart=always
    RestartSec=3
    [Install]
    WantedBy=multi-user.target
    CSEOF
  - systemctl enable clipboard-sync.service
  
  # Signal completion
  - echo "AINUX_SETUP_COMPLETE" > /var/log/ainux-setup.log
  - systemctl start openwhale.service
  - systemctl start ollama.service

  # ── Disable cloud-init after first-boot setup is done ──
  # Prevents cloud-init from running on every subsequent boot and probing
  # unreachable cloud metadata endpoints (AWS/OpenStack/VMware) with 120s timeouts
  - touch /etc/cloud/cloud-init.disabled
  - echo "cloud-init disabled after first-boot setup" >> /var/log/ainux-setup.log

final_message: "🐋 AInux setup complete! Rebooting into GUI..."

power_state:
  mode: reboot
  message: "AInux setup complete, rebooting into GUI mode"
  timeout: 30
"""

with open(os.path.join(CIDATA_DIR, "meta-data"), "w") as f:
    f.write(meta_data)
with open(os.path.join(CIDATA_DIR, "user-data"), "w") as f:
    f.write(user_data)

print("    ✓ Cloud-init config created")

# ── 2. Create seed image (FAT filesystem with cloud-init data) ──────────
print("  [2/4] Creating cloud-init seed image...")

# Use hdiutil on macOS to create a FAT image
dmg = os.path.join(VM_DIR, "seed.dmg")
subprocess.run(["rm", "-f", SEED_IMG, dmg], check=False)
subprocess.run(["hdiutil", "create", "-size", "16m", "-fs", "MS-DOS FAT16",
                 "-volname", "cidata", dmg], check=True,
                capture_output=True)
# Attach 
result = subprocess.run(["hdiutil", "attach", dmg, "-nobrowse"],
                        capture_output=True, text=True, check=True)
mount_point = None
for line in result.stdout.strip().split("\n"):
    parts = line.strip().split("\t")
    if len(parts) >= 3:
        mount_point = parts[-1].strip()
        
if mount_point and os.path.isdir(mount_point):
    shutil.copy(os.path.join(CIDATA_DIR, "meta-data"), mount_point)
    shutil.copy(os.path.join(CIDATA_DIR, "user-data"), mount_point)
    subprocess.run(["hdiutil", "detach", mount_point], capture_output=True)
else:
    print(f"    ⚠ Mount point issue: {result.stdout}")
    sys.exit(1)

# Convert DMG to raw image
subprocess.run(["hdiutil", "convert", dmg, "-format", "UDRW", "-o", SEED_IMG],
               capture_output=True, check=True)
# hdiutil adds .dmg extension to output
if os.path.exists(SEED_IMG + ".dmg"):
    os.rename(SEED_IMG + ".dmg", SEED_IMG)
os.remove(dmg)
print("    ✓ Seed image created")

# ── 3. Prepare disk image ───────────────────────────────────────────────
print("  [3/4] Preparing AInux disk image...")

if not os.path.exists(BASE):
    print("    ✗ No base image! Download with:")
    print('    curl -L -o vm/debian-generic.qcow2 "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-arm64.qcow2"')
    sys.exit(1)

# Copy base image and resize 
subprocess.run(["rm", "-f", DISK], check=False) 
subprocess.run(["cp", BASE, DISK], check=True)
subprocess.run(["qemu-img", "resize", DISK, "20G"], check=True, capture_output=True)

# Create UEFI vars
subprocess.run(["rm", "-f", UEFI_VARS], check=False)
subprocess.run(["truncate", "-s", "64M", UEFI_VARS], check=True, capture_output=True)
print("    ✓ 20GB disk ready")

# ── 4. Boot QEMU ────────────────────────────────────────────────────────
print("  [4/4] Booting AInux in QEMU...")
print("")
print("  🐋 ═══════════════════════════════════════════════")
print("  🐋  FIRST BOOT — cloud-init will install everything")
print("  🐋  This takes ~3-5 minutes. Watch the QEMU window.")
print("  🐋")
print("  🐋  What happens automatically:")
print("  🐋   • Node.js 22.x + tsx installed")
print("  🐋   • OpenWhale cloned & npm installed")
print("  🐋   • Qt6 QML + Cage (Wayland compositor) installed")
print("  🐋   • WhaleOS native desktop shell compiled")
print("  🐋   • AInux OS Login Screen injected")
print("  🐋   • systemd services created & enabled")
print("  🐋   • Auto-reboot into native GUI")
print("  🐋")
print("  🐋  After reboot, WhaleOS desktop appears in QEMU.")
print("  🐋  SSH:     ssh ainux@localhost -p 2222  (pass: ainux)")
print("  🐋  Web:     http://localhost:7777/ (OpenWhale API)")
print("  🐋 ═══════════════════════════════════════════════")
print("")

os.execvp("qemu-system-aarch64", [
    "qemu-system-aarch64",
    "-machine", "virt",
    "-accel", "hvf",
    "-cpu", "host",
    "-m", "4G",
    "-smp", "4",
    "-drive", f"if=pflash,format=raw,file={UEFI_FW},readonly=on",
    "-drive", f"if=pflash,format=raw,file={UEFI_VARS}",
    "-drive", f"file={DISK},if=virtio,format=qcow2",
    "-drive", f"file={SEED_IMG},if=virtio,format=raw",
    "-device", "virtio-gpu-pci",
    "-display", "cocoa,show-cursor=on",
    "-device", "virtio-keyboard-pci",
    "-device", "qemu-xhci",
    "-device", "usb-tablet",
    "-device", "virtio-net-pci,netdev=net0",
    "-netdev", "user,id=net0,hostfwd=tcp::7777-:7777,hostfwd=tcp::2222-:22,hostfwd=tcp::9222-:9222",
    "-device", "virtio-rng-pci",
    "-serial", "mon:stdio",
])
