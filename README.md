<p align="center">
  <img src="packages/whaleos/whale_logo.png" alt="TensorAgent OS Logo" width="120" />
</p>

<h1 align="center">TensorAgent OS</h1>

<p align="center">
  <strong>The World's First AI-Native Operating System</strong><br/>
  A fully bootable OS where an AI agent <em>is</em> the entire user interface.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-0.1.0-blue" alt="Version" />
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License" />
  <img src="https://img.shields.io/badge/arch-x86__64%20%7C%20ARM64-orange" alt="Architecture" />
  <img src="https://img.shields.io/badge/powered_by-OpenWhale-blueviolet" alt="Powered By" />
</p>

---

## What is TensorAgent OS?

TensorAgent OS is an **AI-native operating system** — not a Linux distro with an AI chatbot bolted on, but a ground-up rethinking of the desktop where an **AI agent is the primary interface**. There is no file manager, no taskbar, no traditional app launcher — just you and an AI that has deep, native access to the kernel, hardware, services, and every layer of the operating system.

Think of it like Android: it uses a Linux kernel under the hood, but it's its own thing.

| Component | Technology |
|-----------|------------|
| **AI Brain** | [OpenWhale](https://github.com/viralcode/openwhale) — multi-agent AI platform |
| **Desktop Shell** | WhaleOS — custom Qt6 QML native desktop |
| **Wayland Compositor** | Cage (kiosk compositor) |
| **Linux Base** | Buildroot (x86_64) / Debian Bookworm (ARM64) |
| **Init System** | systemd |
| **Audio** | PipeWire + WirePlumber |
| **Graphics** | Mesa (OpenGL/Vulkan) → DRM/KMS → Wayland |
| **Runtime** | Node.js 22.x, Python 3, SQLite |

---

## Table of Contents

- [🚀 Quick Start — UTM (Recommended for macOS)](#-quick-start--utm-recommended-for-macos)
- [🖥 Quick Start — QEMU (macOS ARM64)](#-quick-start--qemu-macos-arm64)
- [🐧 Quick Start — QEMU (Linux x86_64)](#-quick-start--qemu-linux-x86_64)
- [🔨 Building from Source (Full ISO)](#-building-from-source-full-iso)
- [💽 Building a UTM Bundle (macOS)](#-building-a-utm-bundle-macos)
- [🔩 Bare Metal Installation](#-bare-metal-installation)
- [📱 iOS / Remote Access](#-ios--remote-access)
- [📁 Project Structure](#-project-structure)
- [🖥 WhaleOS Desktop Shell](#-whaleos-desktop-shell)
- [⚙️ System Administration](#%EF%B8%8F-system-administration)
- [🔄 Updating TensorAgent OS](#-updating-tensoragent-os)
- [🐛 Troubleshooting](#-troubleshooting)
- [🏗 Architecture Overview](#-architecture-overview)
- [🤝 Contributing](#-contributing)
- [📄 License](#-license)

---

## 🚀 Quick Start — UTM (Recommended for macOS)

> **Best for:** Apple Silicon Macs (M1/M2/M3/M4). Zero setup, double-click to boot. ~30 seconds to desktop.

### Option A: Pre-Built UTM Bundle (Fastest)

A ready-to-run UTM virtual machine is included in the repository at `utm_build/TensorAgentOS.utm`.

1. **Install UTM** (if not already installed):
   - Download from [https://mac.getutm.app](https://mac.getutm.app) or install via Homebrew:
     ```bash
     brew install --cask utm
     ```

2. **Open the VM:**
   ```bash
   open utm_build/TensorAgentOS.utm
   ```
   Or simply **double-click** `utm_build/TensorAgentOS.utm` in Finder.

3. **Start the VM** in UTM and wait for it to boot to the login screen.

4. **Sign in** with credentials below and start using the AI.

**Pre-built VM Specs:**
| Setting | Value |
|---------|-------|
| **Architecture** | ARM64 (aarch64) |
| **RAM** | 6 GB |
| **CPU Cores** | 6 |
| **Disk** | 20 GB (QCOW2) |
| **Display** | virtio-ramfb |
| **Network** | Emulated (NAT with port forwarding) |

**Port Forwarding (pre-configured):**

| Host Port | Guest Port | Service |
|-----------|------------|---------|
| 7777 | 7777 | OpenWhale API / Dashboard |
| 2222 | 22 | SSH |

### Option B: Build UTM from QEMU (Manual)

If you want to build the UTM bundle yourself from the QEMU disk image:

1. **Run the QEMU Quick Start** first (see next section) to create `vm/ainux.qcow2`.
2. See [Building a UTM Bundle](#-building-a-utm-bundle-macos) below for conversion steps.

---

## 🖥 Quick Start — QEMU (macOS ARM64)

> **Best for:** Apple Silicon Macs. Uses HVF hardware acceleration for native performance. ~5 min first-boot setup.

### Prerequisites

1. **Install QEMU** (with EFI firmware):
   ```bash
   brew install qemu
   ```

2. **Verify the UEFI firmware exists:**
   ```bash
   ls /opt/homebrew/share/qemu/edk2-aarch64-code.fd
   ```

3. **Download the Debian ARM64 cloud image:**
   ```bash
   curl -L -o vm/debian-generic.qcow2 \
     "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-arm64.qcow2"
   ```

### Launch

```bash
python3 vm/launch-ainux.py
```

That's it. The script will:

1. Create a cloud-init seed image with all TensorAgent OS configuration
2. Copy the base Debian image and resize it to 20GB
3. Boot QEMU with HVF acceleration (native speed)
4. Cloud-init auto-installs everything on first boot (~3–5 min):
   - Node.js 22.x + npm + pnpm
   - OpenWhale AI platform (cloned from GitHub)
   - Qt6 QML + Cage Wayland compositor
   - WhaleOS native desktop shell (compiled from `packages/whaleos/`)
   - systemd services for auto-start
5. Auto-reboots into the WhaleOS GUI

### After First Boot

| Service | Access |
|---------|--------|
| **WhaleOS Desktop** | Visible in the QEMU window |
| **OpenWhale API** | [http://localhost:7777](http://localhost:7777) |
| **OpenWhale Dashboard** | [http://localhost:7777/dashboard](http://localhost:7777/dashboard) |
| **SSH** | `ssh ainux@localhost -p 2222` (password: `ainux`) |

### Subsequent Boots

After the first boot, just re-run the same command. Cloud-init won't re-execute — it boots straight into the desktop:

```bash
python3 vm/launch-ainux.py
```

### QEMU Configuration Details

| Setting | Value |
|---------|-------|
| **Machine** | `virt` with HVF acceleration |
| **CPU** | `host` (native Apple Silicon) |
| **RAM** | 4 GB, 4 cores |
| **Display** | `cocoa` (native macOS window) |
| **Devices** | virtio-gpu, virtio-keyboard, usb-tablet, virtio-net, virtio-rng |
| **UEFI** | EDK2 ARM64 firmware (`edk2-aarch64-code.fd`) |
| **Networking** | User-mode with port forwarding |

| Host Port | Guest Port | Service |
|-----------|------------|---------|
| 7777 | 7777 | OpenWhale API / Dashboard |
| 2222 | 22 | SSH |
| 9222 | 9222 | Chrome DevTools Protocol |

---

## 🐧 Quick Start — QEMU (Linux x86_64)

> **Best for:** Running TensorAgent OS on a Linux host with KVM acceleration.

### Prerequisites

```bash
# Ubuntu/Debian
sudo apt install qemu-system-x86 qemu-utils ovmf

# Fedora
sudo dnf install qemu-system-x86 qemu-img edk2-ovmf

# Arch
sudo pacman -S qemu-full edk2-ovmf
```

### Build the ISO & Run

```bash
# Build the full ISO from source
./scripts/build-iso.sh

# Boot in QEMU
./scripts/run-qemu.sh
```

### QEMU Options

```bash
./scripts/run-qemu.sh              # Default: GTK window with GL
./scripts/run-qemu.sh --no-kvm     # Disable KVM (slower, software emulation)
./scripts/run-qemu.sh --vnc        # VNC display on :0 (for headless servers)
./scripts/run-qemu.sh --headless   # No display, runs as daemon
```

### Manual QEMU Command (Linux x86_64)

```bash
qemu-system-x86_64 \
  -enable-kvm -cpu host \
  -m 8G -smp 4 \
  -drive file=ainux.iso,format=raw,media=cdrom,readonly=on \
  -drive file=build/ainux-disk.qcow2,format=qcow2 \
  -boot d \
  -device virtio-vga-gl \
  -display gtk,gl=on \
  -device virtio-net,netdev=net0 \
  -netdev user,id=net0,hostfwd=tcp::7777-:7777,hostfwd=tcp::2222-:22 \
  -device intel-hda -device hda-duplex \
  -usb -device usb-tablet
```

---

## 🔨 Building from Source (Full ISO)

> **Full from-scratch build.** Compiles the kernel, rootfs, and OpenWhale into a bootable ISO. Requires a **Linux x86_64** host.

### System Requirements

| Requirement | Minimum |
|-------------|---------|
| **OS** | Ubuntu 22.04+ (or any modern Linux x86_64) |
| **RAM** | 16 GB |
| **Disk** | 150 GB free |
| **CPU** | Multi-core recommended (build uses all cores) |
| **Time** | ~2 hrs without Chromium, ~8 hrs with Chromium |

### Build Dependencies

```bash
sudo apt install build-essential git python3 wget curl xz-utils \
  gcc g++ make tar patch pkg-config \
  xorriso grub-pc-bin grub-efi-amd64-bin mtools squashfs-tools
```

### Build Commands

```bash
# Full build (with Chromium from source — takes 6–8 hours)
./scripts/build-iso.sh

# Skip Chromium (uses system Chromium — much faster)
./scripts/build-iso.sh --skip-chromium

# Clean build (removes all build artifacts first)
./scripts/build-iso.sh --clean
```

### What the Build Does

1. **Clones Buildroot** (v2024.11) into `build/buildroot/`
2. **Applies TensorAgent OS defconfig** — custom kernel, systemd, Wayland, Mesa, PipeWire, Node.js, Python, etc.
3. **Builds Chromium** (optional) — with Wayland/Ozone, VA-API hardware decode, PipeWire audio
4. **Compiles the Linux kernel** and root filesystem
5. **Integrates OpenWhale** into the rootfs at `/opt/ainux/openwhale/`
6. **Installs WhaleOS** shell at `/opt/ainux/whaleos/`
7. **Generates a bootable ISO** → `ainux.iso`

### Output

```
ainux.iso          — Bootable ISO (flash to USB or boot in QEMU)
build/output/      — Full Buildroot output tree
```

### Flash to USB Drive

```bash
# Find your USB device
lsblk

# Write the ISO (replace /dev/sdX with your actual device)
sudo dd if=ainux.iso of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

> ⚠️ **Replace `/dev/sdX`** with your actual USB device. Double-check with `lsblk` — this will erase the drive.

On **macOS** (for ARM64 ISO):
```bash
# Find your USB device
diskutil list

# Unmount the USB
diskutil unmountDisk /dev/diskN

# Write the ISO (replace /dev/diskN with your actual device)
sudo dd if=ainux.iso of=/dev/rdiskN bs=4m status=progress
sync

# Eject
diskutil eject /dev/diskN
```

---

## 💽 Building a UTM Bundle (macOS)

> **Convert a QEMU disk image into a ready-to-use UTM virtual machine bundle.**

### Prerequisites

- [UTM](https://mac.getutm.app) installed on your Mac
- An existing `vm/ainux.qcow2` disk image (from the QEMU Quick Start)

### Step 1: Create the UTM Bundle Directory

```bash
mkdir -p utm_build/TensorAgentOS.utm/Data
```

### Step 2: Copy the Disk Image

```bash
cp vm/ainux.qcow2 utm_build/TensorAgentOS.utm/Data/ainux.qcow2
```

### Step 3: Create the UTM Configuration

Create `utm_build/TensorAgentOS.utm/config.plist` with the following content:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Backend</key>
  <string>QEMU</string>
  <key>ConfigurationVersion</key>
  <integer>5</integer>
  <key>Display</key>
  <array>
    <dict>
      <key>Hardware</key>
      <string>virtio-ramfb</string>
    </dict>
  </array>
  <key>Drive</key>
  <array>
    <dict>
      <key>Identifier</key>
      <string>drive0</string>
      <key>ImageName</key>
      <string>ainux.qcow2</string>
      <key>ImageType</key>
      <string>Disk</string>
      <key>Interface</key>
      <string>VirtIO</string>
    </dict>
  </array>
  <key>Information</key>
  <dict>
    <key>IconCustom</key>
    <false/>
    <key>Name</key>
    <string>TensorAgent OS</string>
  </dict>
  <key>Input</key>
  <dict>
    <key>Sharing</key>
    <true/>
  </dict>
  <key>Network</key>
  <array>
    <dict>
      <key>Mode</key>
      <string>Emulated</string>
      <key>PortForward</key>
      <array>
        <dict>
          <key>GuestAddress</key>
          <string></string>
          <key>GuestPort</key>
          <integer>7777</integer>
          <key>HostAddress</key>
          <string>127.0.0.1</string>
          <key>HostPort</key>
          <integer>7777</integer>
          <key>Protocol</key>
          <string>TCP</string>
        </dict>
        <dict>
          <key>GuestAddress</key>
          <string></string>
          <key>GuestPort</key>
          <integer>22</integer>
          <key>HostAddress</key>
          <string>127.0.0.1</string>
          <key>HostPort</key>
          <integer>2222</integer>
          <key>Protocol</key>
          <string>TCP</string>
        </dict>
      </array>
    </dict>
  </array>
  <key>QEMU</key>
  <dict>
    <key>MachinePropertyOverride</key>
    <string></string>
  </dict>
  <key>Sound</key>
  <array>
    <dict>
      <key>Hardware</key>
      <string>intel-hda</string>
    </dict>
  </array>
  <key>System</key>
  <dict>
    <key>Architecture</key>
    <string>aarch64</string>
    <key>CPU</key>
    <string>Default</string>
    <key>CPUCount</key>
    <integer>6</integer>
    <key>JitCacheSize</key>
    <integer>0</integer>
    <key>MemorySize</key>
    <integer>6144</integer>
    <key>Target</key>
    <string>virt</string>
  </dict>
</dict>
</plist>
```

### Step 4: Open in UTM

```bash
open utm_build/TensorAgentOS.utm
```

### Network Configuration (Important)

The pre-built UTM image includes `systemd-networkd` DHCP configuration. If building from scratch, ensure the disk image has `/etc/systemd/network/10-dhcp.network`:

```ini
[Match]
Name=enp*

[Network]
DHCP=yes

[DHCP]
UseDNS=yes
UseDomains=yes
```

And enable the services:
```bash
sudo systemctl enable systemd-networkd systemd-resolved
sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
```

> **Note:** The QEMU launcher uses cloud-init for network configuration, but UTM does not include the `seed.img`, so `systemd-networkd` must be configured directly.

---

## 🔩 Bare Metal Installation

> **Install TensorAgent OS on physical hardware.** Currently supports ARM64 (e.g., Raspberry Pi 4/5, Pine64, Apple Silicon with Asahi Linux).

### From ISO (x86_64)

1. Build the ISO: `./scripts/build-iso.sh`
2. Flash to USB: `sudo dd if=ainux.iso of=/dev/sdX bs=4M status=progress`
3. Boot the target computer from USB (UEFI boot required)
4. The OS runs live from the USB or can be installed to disk

### From QCOW2 (ARM64)

To install to a physical ARM64 disk:

```bash
# Convert QCOW2 to raw disk image
qemu-img convert -f qcow2 -O raw vm/ainux.qcow2 ainux-raw.img

# Write to disk (replace /dev/sdX with your target disk)
sudo dd if=ainux-raw.img of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

> ⚠️ **This will erase the target disk entirely.** Double-check the device path.

### Hardware Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| **CPU** | ARM64 or x86_64, 2 cores | 4+ cores |
| **RAM** | 2 GB | 4+ GB |
| **Storage** | 20 GB | 40+ GB |
| **Display** | DRM/KMS compatible GPU | Intel/AMD with Mesa support |
| **Network** | Ethernet or supported WiFi | Ethernet recommended |
| **Boot** | UEFI (GPT) | UEFI with Secure Boot disabled |

---

## 📱 iOS / Remote Access

Since TensorAgent OS exposes OpenWhale on port `7777`, you can access the AI interface from any device on the same network.

### From Your Local Network

1. Find the host machine's IP:
   ```bash
   # macOS
   ipconfig getifaddr en0

   # Linux
   hostname -I | awk '{print $1}'
   ```

2. Navigate to `http://<host-ip>:7777/dashboard` on your iPhone/iPad/any browser.

### Over SSH (iOS Terminal Apps)

Using apps like **Termius**, **Blink Shell**, or **a-Shell** on iOS:

```bash
ssh ainux@<host-ip> -p 2222
# Password: ainux
```

### Expose Over the Internet (Advanced)

```bash
# Option 1: SSH tunnel (requires a server with a public IP)
ssh -R 80:localhost:7777 serveo.net

# Option 2: Cloudflare Tunnel
cloudflared tunnel --url http://localhost:7777

# Option 3: ngrok
ngrok http 7777
```

> ⚠️ **Security:** Change the default password before exposing to the internet: `passwd ainux`

---

## 📁 Project Structure

```
ainux/
├── configs/
│   ├── ainux_defconfig         # Buildroot configuration (x86_64)
│   └── kernel.config           # Custom Linux kernel config
├── buildroot-external/
│   ├── Config.in               # Buildroot external config
│   ├── external.desc           # External tree descriptor
│   ├── external.mk             # External makefiles
│   └── package/                # Custom Buildroot packages
├── packages/
│   ├── core/                   # TensorAgent OS core kernel (Node.js)
│   ├── gui/                    # Web-based GUI components
│   ├── chromium/               # Chromium patches for TensorAgent OS
│   ├── openwhale/              # OpenWhale integration & extensions
│   └── whaleos/                # Qt6 QML native desktop shell
│       ├── main.cpp            # Application entry point
│       ├── main.qml            # Root QML component
│       ├── Desktop.qml         # Desktop environment
│       ├── TopBar.qml          # System status bar
│       ├── AppDock.qml         # Application dock
│       ├── ChatBar.qml         # AI chat interface
│       ├── LoginScreen.qml     # Login screen
│       ├── TerminalApp.qml     # Built-in terminal
│       ├── SettingsApp.qml     # System settings
│       ├── AgentsApp.qml       # AI agents manager
│       ├── SkillsApp.qml       # Skills manager
│       ├── ProvidersApp.qml    # AI provider config
│       ├── McpApp.qml          # MCP server manager
│       ├── AppsApp.qml         # App launcher
│       ├── AppWindow.qml       # Window container
│       ├── api.js              # API client helpers
│       ├── fonts/              # Bundled Font Awesome fonts
│       └── whaleos-helper.mjs  # Node.js helper service
├── scripts/
│   ├── build-iso.sh            # Master build script (x86_64 ISO)
│   ├── run-qemu.sh             # QEMU launcher (x86_64)
│   ├── integrate-openwhale.sh  # Deep integration installer
│   ├── ainux-update.sh         # Update manager
│   ├── post-build.sh           # Buildroot post-build hook
│   └── post-image.sh           # Buildroot post-image hook
├── vm/
│   ├── launch-ainux.py         # One-command launcher (macOS ARM64)
│   ├── boot-ainux.sh           # Boot script (ARM64 + HVF)
│   ├── auto-setup.sh           # Fully automated setup
│   ├── setup.sh                # Manual setup script
│   ├── install-ai-tools.sh     # AI tools installer
│   ├── patch-openwhale.py      # OpenWhale login page patcher
│   └── qemu-type.py            # QEMU monitor keystroke helper
├── utm_build/
│   └── TensorAgentOS.utm/      # Pre-built UTM virtual machine
│       ├── config.plist        # UTM VM configuration
│       └── Data/
│           └── ainux.qcow2     # Boot disk image
├── rootfs-overlay/
│   └── etc/                    # System config overlays
├── package.json                # Workspace root
└── README.md                   # ← You are here
```

---

## 🖥 WhaleOS Desktop Shell

WhaleOS is the native desktop environment, built with **Qt6 QML** and running on the **Cage** Wayland compositor.

| App | Description |
|-----|-------------|
| **ChatBar** | AI conversation interface (the primary interaction method) |
| **Terminal** | Built-in terminal emulator |
| **Settings** | System configuration (users, channels, display, network) |
| **Agents** | Manage AI agents and their configurations |
| **Skills** | Browse and manage OpenWhale skills |
| **Providers** | Configure AI provider API keys (OpenAI, Anthropic, etc.) |
| **MCP** | Model Context Protocol server management |
| **Apps** | Application launcher for generated apps |

### Desktop Architecture

```
┌─────────────────────────────────────────┐
│                 TopBar                  │  ← Clock, system status, icons
├─────────────────────────────────────────┤
│                                         │
│              Desktop.qml                │  ← Main workspace area
│                                         │
│     ┌───────────────────────────┐       │
│     │       App Windows         │       │  ← Floating app windows
│     │    (AppWindow.qml)        │       │
│     └───────────────────────────┘       │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │           ChatBar.qml            │   │  ← AI chat bar (always visible)
│  └──────────────────────────────────┘   │
├─────────────────────────────────────────┤
│               AppDock                   │  ← App launcher dock
└─────────────────────────────────────────┘
```

### Compiling WhaleOS Manually

```bash
cd packages/whaleos
g++ -o whaleos main.cpp \
  $(pkg-config --cflags --libs Qt6Quick Qt6Qml Qt6Core Qt6Gui) -fPIC
```

**Qt6 Dependencies (Debian/Ubuntu):**
```bash
sudo apt install qt6-base-dev qt6-declarative-dev \
  qml6-module-qtquick qml6-module-qtquick-controls \
  qml6-module-qtquick-layouts qml6-module-qtquick-window \
  qt6-wayland libqt6opengl6-dev
```

---

## ⚙️ System Administration

### Default Credentials

| User | Password | Notes |
|------|----------|-------|
| `ainux` | `ainux` | Primary user, has sudo |
| `root` | `ainux` | Root access |

> 🔒 **Change the default passwords** after first login: `passwd ainux && sudo passwd root`

### systemd Services

| Service | Description | Commands |
|---------|-------------|----------|
| `openwhale` | OpenWhale AI Platform | `sudo systemctl {start\|stop\|restart\|status} openwhale` |
| `ainux-gui` | WhaleOS Desktop (Cage + QML) | `sudo systemctl {start\|stop\|restart\|status} ainux-gui` |

### Viewing Logs

```bash
# OpenWhale logs
journalctl -u openwhale -f

# GUI logs
journalctl -u ainux-gui -f

# All TensorAgent OS logs
journalctl -u openwhale -u ainux-gui -f

# Setup completion check
cat /var/log/ainux-setup.log
```

### OpenWhale Configuration

The OpenWhale `.env` file is located at `/opt/ainux/openwhale/.env`:

```env
PORT=7777
NODE_ENV=production
AINUX_MODE=true
AINUX_VERSION=0.1.0
```

### AI System Tools

TensorAgent OS gives the AI **deep, native access** to the operating system through the `kernel_os` tool — 50+ actions across 10 categories:

| Category | Capabilities |
|----------|-------------|
| **Process Management** | List, kill, process tree, `/proc` inspection |
| **Service Management** | systemd start/stop/restart/status/logs |
| **Filesystem** | Read, write, list, find, delete, mkdir, disk usage |
| **Network** | Interfaces, connections, ports, DNS, ping, routing, iptables |
| **Hardware & Kernel** | CPU/RAM info, USB, PCI, storage, kernel modules, dmesg, sysctl |
| **Users & Permissions** | List users, groups, sessions, add users, set passwords |
| **Package Management** | apt install/remove/search/update |
| **System Control** | Env vars, uptime, hostname, timezone, crontab, mounts, swap |
| **Logs & Monitoring** | journalctl, syslog, auth logs |
| **Performance** | top, iostat, vmstat, load averages |

Plus 30+ additional tools: `exec`, `file`, `browser`, `git`, `docker`, `ssh`, `email`, `pdf`, `spreadsheet`, `slides`, `cron`, `image`, `tts`, `web_fetch`, `code_exec`, `memory`, `codebase`, and more.

---

## 🔄 Updating TensorAgent OS

TensorAgent OS includes a built-in update manager:

```bash
# Check for available updates
ainux-update check

# Update OpenWhale only
ainux-update openwhale

# Update TensorAgent OS core
ainux-update ainux

# Update everything
ainux-update all

# Roll back to previous version
ainux-update rollback openwhale
```

### Live Update via SSH (for UTM / QEMU)

You can update the running OS without rebuilding the disk image:

```bash
# SSH into the VM
ssh ainux@localhost -p 2222

# Update WhaleOS shell from the host
scp -P 2222 packages/whaleos/*.qml ainux@localhost:/opt/ainux/whaleos/
scp -P 2222 packages/whaleos/*.js ainux@localhost:/opt/ainux/whaleos/
scp -P 2222 packages/whaleos/*.mjs ainux@localhost:/opt/ainux/whaleos/

# Restart GUI to apply changes
ssh -p 2222 ainux@localhost "sudo systemctl restart ainux-gui"
```

---

## 🐛 Troubleshooting

### QEMU Won't Start (macOS)

**Symptom:** `qemu-system-aarch64: failed to initialize HVF`

```bash
# Ensure QEMU is installed via Homebrew
brew reinstall qemu

# Verify firmware file exists
ls /opt/homebrew/share/qemu/edk2-aarch64-code.fd
```

### UTM VM Shows No Network

**Symptom:** OpenWhale shows "Connection error", can't reach the internet.

The UTM build requires `systemd-networkd` configuration. SSH in and verify:

```bash
ssh ainux@localhost -p 2222
ip addr show                    # Check if enp0s1 has an IP
sudo systemctl status systemd-networkd
cat /etc/systemd/network/10-dhcp.network  # Should contain DHCP=yes
```

If missing, create the network config:
```bash
sudo tee /etc/systemd/network/10-dhcp.network << 'EOF'
[Match]
Name=enp*

[Network]
DHCP=yes

[DHCP]
UseDNS=yes
UseDomains=yes
EOF
sudo systemctl enable --now systemd-networkd systemd-resolved
sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
```

### Icons Not Rendering (UTM)

**Symptom:** Font Awesome icons show as blank squares.

The OS bundles Font Awesome fonts locally in `packages/whaleos/fonts/`. Verify they exist on the VM:

```bash
ssh ainux@localhost -p 2222
ls /opt/ainux/whaleos/fonts/
# Should show: fa-solid-900.woff2, fa-brands-400.woff2
```

If missing, copy from the host:
```bash
scp -P 2222 packages/whaleos/fonts/*.woff2 ainux@localhost:/opt/ainux/whaleos/fonts/
ssh -p 2222 ainux@localhost "sudo systemctl restart ainux-gui"
```

### UTM VM is Slow

**Symptom:** Laggy UI, slow mouse movement.

The OS uses software rendering (`pixman`) by default for VM compatibility. To improve performance:

1. **Increase resources** in UTM → Settings:
   - RAM: **6 GB** (minimum 4 GB)
   - CPU Cores: **6** (minimum 4)

2. **Use virtio-ramfb display** (not virtio-gpu with virgl — it crashes):
   - UTM → Settings → Display → `virtio-ramfb`

> **Note:** `WLR_RENDERER=pixman` is required because OpenGL (virgl) is not supported by the default virtio-gpu configuration. This means rendering is CPU-bound, but with 6 cores it's usable.

### Cloud-Init Stalls / No Network

**Symptom:** First boot hangs at "Waiting for network"

```bash
ssh ainux@localhost -p 2222
sudo cloud-init status --long
sudo cat /var/log/cloud-init-output.log
```

### WhaleOS Black Screen

**Symptom:** QEMU window shows nothing after boot

```bash
ssh ainux@localhost -p 2222
sudo systemctl status ainux-gui
sudo systemctl status openwhale
journalctl -u ainux-gui --no-pager -n 50

# Restart the GUI
sudo systemctl restart openwhale
sleep 5
sudo systemctl restart ainux-gui
```

### OpenWhale Not Starting

```bash
journalctl -u openwhale -n 50

# Try manual start
cd /opt/ainux/openwhale
node openwhale.mjs

# Rebuild native modules if needed
npm rebuild better-sqlite3
```

### No Mouse Cursor in UTM

**Symptom:** Mouse cursor invisible in the VM window.

The GUI service sets `WLR_NO_HARDWARE_CURSORS=1` to force software cursors. If still missing:

```bash
ssh ainux@localhost -p 2222
# Verify the environment variable
sudo systemctl show ainux-gui | grep Environment
# Should include WLR_NO_HARDWARE_CURSORS=1
```

### Re-Running Cloud-Init (Reset First Boot)

```bash
sudo cloud-init clean
sudo reboot
```

---

## 🏗 Architecture Overview

```
┌──────────────────────────────────────────────────────────┐
│                     USER (Browser / iOS / Desktop)        │
│                    http://localhost:7777/dashboard         │
└────────────────────────────┬─────────────────────────────┘
                             │
┌────────────────────────────▼─────────────────────────────┐
│                  WhaleOS (Qt6 QML Desktop)                │
│              Cage Wayland Compositor (kiosk)              │
├──────────────────────────────────────────────────────────┤
│                 OpenWhale AI Platform                     │
│         ┌──────────┬──────────┬──────────────┐           │
│         │  Agents  │  Skills  │  Extensions  │           │
│         └──────────┴──────────┴──────────────┘           │
│         ┌──────────┬──────────┬──────────────┐           │
│         │ Memory   │ Sessions │  Dashboard   │           │
│         └──────────┴──────────┴──────────────┘           │
├──────────────────────────────────────────────────────────┤
│                   Node.js 22.x Runtime                   │
│                   SQLite · better-sqlite3                 │
├──────────────────────────────────────────────────────────┤
│                     systemd (init)                        │
│              openwhale.service + ainux-gui.service        │
├──────────────────────────────────────────────────────────┤
│               Linux Kernel (6.x LTS)                     │
│         DRM/KMS · Mesa · PipeWire · virtio               │
├──────────────────────────────────────────────────────────┤
│ QEMU (HVF/macOS · KVM/Linux) · UTM (macOS) · Bare Metal │
└──────────────────────────────────────────────────────────┘
```

---

## 🤝 Contributing

1. **Fork** the repository
2. **Create a branch:** `git checkout -b feature/my-feature`
3. **Commit:** `git commit -m "Add my feature"`
4. **Push:** `git push origin feature/my-feature`
5. **Open a Pull Request**

### Development Workflow

```bash
# Launch the OS in QEMU for development
python3 vm/launch-ainux.py

# Deploy changes to running VM
scp -P 2222 packages/whaleos/*.qml ainux@localhost:/opt/ainux/whaleos/
ssh -p 2222 ainux@localhost "sudo systemctl restart ainux-gui"

# Build WhaleOS GUI binary
cd packages/whaleos
g++ -o whaleos main.cpp $(pkg-config --cflags --libs Qt6Quick Qt6Qml Qt6Core Qt6Gui) -fPIC

# Lint
npm run lint

# Build full ISO (Linux only)
./scripts/build-iso.sh
```

---

## 📄 License

MIT — see [LICENSE](LICENSE) for details.

---

<p align="center">
  <strong>🐋 TensorAgent OS v0.1.0</strong><br/>
  Built by <a href="https://github.com/viralcode">Jijo John</a><br/>
  Powered by <a href="https://github.com/viralcode/openwhale">OpenWhale</a>
</p>
