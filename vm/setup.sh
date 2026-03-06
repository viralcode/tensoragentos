#!/bin/bash
#
# TensorAgent OS — VM Quick Setup
#
# Transforms a stock Debian Bookworm install into TensorAgent OS.
# Run inside the VM (SSH or console).
#
# Installs:
#   • Node.js 22.x, Python 3, SQLite
#   • Qt6 + Wayland Compositor + PAM
#   • Cage compositor, Chromium, desktop apps
#   • OpenWhale AI platform + WhaleOS shell
#   • Flatpak for user-installable applications
#   • Ollama local LLM runtime
#
# Usage (inside VM):
#   curl -fsSL http://10.0.2.2:8888/setup.sh | bash
#   — or —
#   bash /media/cdrom/setup.sh
#

set -e

echo ""
echo "  🐋 ═══════════════════════════════════════════"
echo "  🐋  TensorAgent OS Setup"
echo "  🐋  Configuring Debian Bookworm..."
echo "  🐋 ═══════════════════════════════════════════"
echo ""

# ─── 1. Configure apt sources ──────────────────────────────────
echo "[1/9] Configuring apt sources..."
cat > /etc/apt/sources.list << 'SOURCES'
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
SOURCES
apt-get update -qq
echo "  ✓ Sources configured"

# ─── 2. Install system packages ────────────────────────────────
echo "[2/9] Installing system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get install -y -qq \
    bash curl wget git openssh-server sudo htop tmux \
    mesa-utils libgl1-mesa-dri libegl-mesa0 \
    wayland-protocols libwayland-dev cage xwayland \
    qt6-base-dev qt6-declarative-dev \
    qt6-wayland-dev qt6-wayland \
    qml6-module-qtquick qml6-module-qtquick-controls \
    qml6-module-qtquick-layouts qml6-module-qtwayland-compositor \
    libpam0g-dev \
    chromium mousepad galculator \
    pipewire pipewire-alsa wireplumber \
    fonts-dejavu fonts-noto fontconfig \
    xsel wl-clipboard ripgrep jq tree \
    python3 python3-pip python3-venv sqlite3 \
    flatpak \
    2>/dev/null || echo "  ⚠ Some packages unavailable, continuing..."

# Flatpak remote
flatpak remote-add --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true

echo "  ✓ Packages installed"

# ─── 3. Install Node.js 22.x ───────────────────────────────────
echo "[3/9] Installing Node.js 22.x..."
if ! command -v node &>/dev/null || ! node -v | grep -q "v22"; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt-get install -y -qq nodejs
fi
echo "  Node.js $(node -v)"
echo "  ✓ Node.js installed"

# ─── 4. Create TensorAgent user ────────────────────────────────
echo "[4/9] Creating ainux user..."
if ! id ainux 2>/dev/null; then
    useradd -m -s /bin/bash -G sudo,video,audio,input ainux
    echo "ainux:ainux" | chpasswd
    echo "%sudo ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/tensoragent
    chmod 440 /etc/sudoers.d/tensoragent
fi
mkdir -p /home/ainux/.config
mkdir -p /home/ainux/Works
chown -R ainux:ainux /home/ainux
echo "  ✓ User created (ainux/ainux)"

# ─── 5. Clone and build OpenWhale ──────────────────────────────
echo "[5/9] Installing OpenWhale..."
mkdir -p /opt/ainux
if [ ! -d /opt/ainux/openwhale ]; then
    git clone https://github.com/viralcode/openwhale.git /opt/ainux/openwhale
fi
cd /opt/ainux/openwhale
npm install --omit=dev 2>/dev/null || npm install

# Create .env
cat > /opt/ainux/openwhale/.env << 'ENV'
PORT=7777
NODE_ENV=production
AINUX_MODE=true
AINUX_VERSION=0.2.0
ENV

echo "  ✓ OpenWhale installed"

# ─── 6. Install WhaleOS shell ──────────────────────────────────
echo "[6/9] Building WhaleOS shell..."
if [ -d /opt/ainux/whaleos ]; then
    cd /opt/ainux/whaleos
    bash build.sh
else
    echo "  ⚠ WhaleOS source not found at /opt/ainux/whaleos"
    echo "  Copy it manually: scp -r packages/whaleos root@vm:/opt/ainux/"
fi
echo "  ✓ WhaleOS built"

# ─── 7. Install AI tools ──────────────────────────────────────
echo "[7/9] Installing AI tools..."

# Ollama
if ! command -v ollama &>/dev/null; then
    curl -fsSL https://ollama.ai/install.sh | sh 2>/dev/null || \
        echo "  ⚠ Ollama install failed (network issue?)"
fi

# Python AI libraries
pip3 install --break-system-packages --quiet \
    langchain langchain-community chromadb \
    sentence-transformers openai anthropic \
    beautifulsoup4 requests 2>/dev/null || \
pip3 install --quiet \
    langchain openai anthropic requests 2>/dev/null || true

echo "  ✓ AI tools installed"

# ─── 8. Configure systemd services ─────────────────────────────
echo "[8/9] Setting up systemd services..."

# OpenWhale service
cat > /etc/systemd/system/openwhale.service << 'OWSERVICE'
[Unit]
Description=OpenWhale AI Platform
After=network.target

[Service]
Type=simple
User=ainux
WorkingDirectory=/opt/ainux/openwhale
ExecStart=/usr/bin/node openwhale.mjs
Environment=NODE_ENV=production PORT=7777 HOME=/home/ainux
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
OWSERVICE

# WhaleOS desktop service
cat > /etc/systemd/system/ainux-gui.service << 'GUISERVICE'
[Unit]
Description=TensorAgent OS Desktop Shell
After=openwhale.service systemd-logind.service
Wants=openwhale.service

[Service]
Type=simple
User=ainux
PAMName=login
Environment=WLR_LIBINPUT_NO_DEVICES=1
Environment=WLR_NO_HARDWARE_CURSORS=1
Environment=QT_QPA_PLATFORM=wayland
Environment=QSG_RENDER_LOOP=basic
Environment=QT_QUICK_BACKEND=software
ExecStartPre=/bin/sleep 3
ExecStart=/usr/bin/cage -- /opt/ainux/whaleos/whaleos
Restart=on-failure
RestartSec=3

[Install]
WantedBy=graphical.target
GUISERVICE

# Ollama service (optional)
cat > /etc/systemd/system/ollama.service << 'OLLAMA'
[Unit]
Description=Ollama Local LLM Runtime
After=network.target

[Service]
Type=simple
User=ainux
ExecStart=/usr/local/bin/ollama serve
Environment=HOME=/home/ainux OLLAMA_HOST=0.0.0.0
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
OLLAMA

# WhaleOS Helper Service (system APIs on port 7778)
cat > /etc/systemd/system/whaleos-helper.service << 'HELPERSERVICE'
[Unit]
Description=WhaleOS Helper Service
After=network.target openwhale.service

[Service]
Type=simple
ExecStart=/usr/bin/node /opt/ainux/whaleos/whaleos-helper.mjs
User=root
Restart=always
RestartSec=3
Environment=HOME=/home/ainux

[Install]
WantedBy=multi-user.target
HELPERSERVICE

# PAM config for WhaleOS
cat > /etc/pam.d/whaleos << 'PAMCFG'
auth       required   pam_unix.so
account    required   pam_unix.so
session    required   pam_unix.so
PAMCFG

# Enable services
systemctl daemon-reload
systemctl enable openwhale.service
systemctl enable ainux-gui.service
systemctl enable ollama.service 2>/dev/null || true
systemctl enable whaleos-helper.service
systemctl enable systemd-logind
systemctl set-default graphical.target

# Auto-login on tty1
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << 'AUTOLOGIN'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ainux --noclear %I $TERM
AUTOLOGIN

echo "  ✓ Services configured"

# ─── 9. Install TensorAgent OS skill + finalize ───────────────
echo "[9/9] Finalizing TensorAgent OS..."

# Set hostname
echo "tensoragent" > /etc/hostname
hostname tensoragent

# Openwhale system skill
mkdir -p /home/ainux/.openwhale/skills/tensoragent-system
cat > /home/ainux/.openwhale/skills/tensoragent-system/SKILL.md << 'SKILL'
---
name: tensoragent-system
description: TensorAgent OS — AI-native operating system tools and system management
version: 0.2.0
---

# TensorAgent OS System Agent

You are running on **TensorAgent OS**, an AI-first operating system.
You have direct access to hardware, shell commands, and AI tools.

## Available Services
- `openwhale` — AI agent platform (port 7777)
- `ollama` — Local LLM runtime (port 11434)
- `ainux-gui` — Desktop shell (Cage + WhaleOS)

## Key Commands
- `sudo systemctl restart <service>` — Restart a service
- `sudo journalctl -u <service> -n 50 --no-pager` — View logs
- `ollama run llama3.2` — Chat with local LLM
- `flatpak install flathub <app>` — Install applications
SKILL

# Memory context
mkdir -p /home/ainux/.openwhale/memory
cat > /home/ainux/.openwhale/memory/MEMORY.md << 'MEM'
## TensorAgent OS Context

I am running on TensorAgent OS, a custom AI-native operating system built on Debian Bookworm.
I am the primary user interface. I can execute system commands, manage services, and control hardware.
Users can install additional software via apt or flatpak.
MEM

# Fix ownership
chown -R ainux:ainux /home/ainux
chown -R ainux:ainux /opt/ainux

# MOTD
cat > /etc/motd << 'MOTD'

  🐋 ══════════════════════════════════════════════
  🐋  TensorAgent OS v0.2.0 — AI-Native Operating System
  🐋
  🐋  OpenWhale:   http://localhost:7777/dashboard
  🐋  Ollama:      http://localhost:11434
  🐋  SSH:         ssh ainux@<ip> -p 2222
  🐋
  🐋  Commands:
  🐋    systemctl status openwhale
  🐋    systemctl status ainux-gui
  🐋    flatpak install flathub <app>
  🐋 ══════════════════════════════════════════════

MOTD

echo ""
echo "  🐋 ═══════════════════════════════════════════"
echo "  🐋  TensorAgent OS Setup Complete!"
echo "  🐋"
echo "  🐋  Start services:"
echo "  🐋    sudo systemctl start openwhale"
echo "  🐋    sudo systemctl start ainux-gui"
echo "  🐋"
echo "  🐋  Or reboot to auto-start everything:"
echo "  🐋    sudo reboot"
echo "  🐋 ═══════════════════════════════════════════"
echo ""
