<p align="center">
  <img src="packages/whaleos/whale_logo.png" alt="TensorAgent OS" width="100" />
</p>

<h1 align="center">TensorAgent OS</h1>

<p align="center">
  <strong>The World's First AI-Native Operating System</strong><br/>
  A bootable OS where an AI agent <em>is</em> the interface.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-0.1.0-blue" />
  <img src="https://img.shields.io/badge/license-MIT-green" />
  <img src="https://img.shields.io/badge/arch-x86__64%20%7C%20ARM64-orange" />
  <img src="https://img.shields.io/badge/powered_by-OpenWhale-blueviolet" />
</p>

---

No file manager. No app launcher. Just you and an AI with native access to the entire operating system — kernel, hardware, filesystem, network, services, everything.

| Layer | Tech |
|-------|------|
| AI Engine | [OpenWhale](https://github.com/viralcode/openwhale) (multi-agent, MCP, tools) |
| Desktop | WhaleOS — Qt6 QML native shell |
| Compositor | Cage (Wayland kiosk) |
| Base | Debian Bookworm (ARM64) / Buildroot (x86_64) |
| Runtime | Node.js 22, Python 3, SQLite, systemd |

---

## Quick Start — UTM (macOS, Recommended)

The fastest way. Double-click and boot.

```bash
brew install --cask utm
open utm_build/TensorAgentOS.utm
```

Sign in: `ainux` / `ainux`

Pre-configured: 6 GB RAM, 6 cores, ARM64, port forwarding on `7777` (API) and `2222` (SSH).

---

## Quick Start — QEMU (macOS ARM64)

```bash
brew install qemu

# Download Debian ARM64 base image
curl -L -o vm/debian-generic.qcow2 \
  "https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-arm64.qcow2"

# Launch (first boot takes ~5 min for setup)
python3 vm/launch-ainux.py
```

After boot:

| Service | Access |
|---------|--------|
| Desktop | QEMU window |
| API / Dashboard | http://localhost:7777 |
| SSH | `ssh ainux@localhost -p 2222` |

---

## Build ISO from Source (Linux x86_64)

Full from-scratch bootable ISO. Requires Linux x86_64, 16 GB RAM, 150 GB disk.

```bash
# Install build deps
sudo apt install build-essential git python3 wget curl xz-utils \
  gcc g++ make tar patch pkg-config \
  xorriso grub-pc-bin grub-efi-amd64-bin mtools squashfs-tools

# Build ISO
./scripts/build-iso.sh

# Build without Chromium (faster)
./scripts/build-iso.sh --skip-chromium

# Boot ISO in QEMU
./scripts/run-qemu.sh
```

### Flash to USB

```bash
sudo dd if=ainux.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

---

## Build UTM Bundle (macOS)

Convert a QEMU disk image into a UTM VM:

```bash
# 1. Run QEMU quick start first to create vm/ainux.qcow2
python3 vm/launch-ainux.py

# 2. Create UTM bundle
mkdir -p utm_build/TensorAgentOS.utm/Data
cp vm/ainux.qcow2 utm_build/TensorAgentOS.utm/Data/ainux.qcow2

# 3. Copy the config.plist (see utm_build/TensorAgentOS.utm/config.plist)

# 4. Open
open utm_build/TensorAgentOS.utm
```

> **Note:** UTM doesn't use cloud-init. Ensure `systemd-networkd` DHCP is configured in the disk image for networking.

---

## Project Structure

```
ainux/
├── packages/
│   ├── openwhale/         # OpenWhale AI engine source
│   └── whaleos/           # Qt6 QML desktop shell (main.qml, ChatBar, Desktop, etc.)
├── scripts/
│   ├── build-iso.sh       # Build bootable ISO (x86_64)
│   └── run-qemu.sh        # Launch ISO in QEMU
├── vm/
│   ├── launch-ainux.py    # One-command QEMU launcher (ARM64)
│   └── boot-ainux.sh      # Boot script
├── utm_build/             # Pre-built UTM virtual machine
├── configs/               # Buildroot + kernel configs
└── buildroot-external/    # Custom Buildroot packages
```

---

## Development

```bash
# Deploy QML changes to running VM
scp -P 2222 packages/whaleos/*.qml ainux@localhost:/opt/ainux/whaleos/
ssh -p 2222 ainux@localhost "sudo systemctl restart ainux-gui"

# Deploy OpenWhale changes
scp -P 2222 packages/openwhale/src/**/*.ts ainux@localhost:/tmp/
ssh -p 2222 ainux@localhost "sudo cp /tmp/*.ts /opt/ainux/openwhale/src/ && cd /opt/ainux/openwhale && sudo npm run build && sudo systemctl restart openwhale"

# Logs
ssh -p 2222 ainux@localhost "journalctl -u openwhale -u ainux-gui -f"
```

**Default credentials:** `ainux` / `ainux` (SSH, login, sudo)

---

## Architecture

```
USER (Browser / Desktop / iOS)
        │
WhaleOS (Qt6 QML) ← Cage Wayland Compositor
        │
OpenWhale (Agents, Skills, Extensions, MCP, Memory, Sessions)
        │
Node.js 22 + SQLite
        │
systemd (openwhale.service + ainux-gui.service)
        │
Linux Kernel (DRM/KMS, Mesa, PipeWire, virtio)
        │
QEMU (HVF/KVM) · UTM · Bare Metal
```

---

## License

MIT — see [LICENSE](LICENSE)

<p align="center">
  Built by <a href="https://github.com/viralcode">Jijo John</a> · Powered by <a href="https://github.com/viralcode/openwhale">OpenWhale</a>
</p>
