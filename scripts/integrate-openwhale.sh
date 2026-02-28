#!/bin/bash
#
# AInux Deep Integration Installer
#
# Wires OpenWhale into AInux at the deepest level:
# 1. Installs AInux extension into OpenWhale's extension directory
# 2. Installs AInux system skill into OpenWhale's skills directory
# 3. Augments OpenWhale's MEMORY.md with AInux OS context
# 4. Configures .env for AInux mode
# 5. Sets up the update manager
#
# Run this once after cloning/installing OpenWhale.
# Safe to re-run (idempotent).
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AINUX_ROOT="$(dirname "$SCRIPT_DIR")"
OPENWHALE_DIR="${AINUX_ROOT}/packages/openwhale/repo"
OW_HOME="${HOME}/.openwhale"
AINUX_DATA="${HOME}/.ainux"

log() { echo -e "\033[36m[ainux-integrate]\033[0m $1"; }
ok()  { echo -e "\033[32m  ✓\033[0m $1"; }

log "🐋 AInux Deep Integration Installer"
echo ""

# ─── 1. Install AInux Extension ─────────────────────────────────────────────
log "Installing AInux extension into OpenWhale..."
EXTENSIONS_DIR="${OW_HOME}/extensions/ainux-os"
mkdir -p "$EXTENSIONS_DIR"
cp "${AINUX_ROOT}/packages/openwhale/ainux-extension/index.mjs" "${EXTENSIONS_DIR}/"

# Create extension metadata
cat > "${EXTENSIONS_DIR}/package.json" << 'EOF'
{
  "name": "ainux-os",
  "version": "0.1.0",
  "description": "AInux OS integration — 8 system tools for hardware, network, audio, display, power, updates",
  "main": "index.mjs",
  "type": "module"
}
EOF
ok "Extension installed → ${EXTENSIONS_DIR}/"

# ─── 2. Install AInux Skill ─────────────────────────────────────────────────
log "Installing AInux system skill..."
SKILL_DIR="${OW_HOME}/skills/ainux-system"
mkdir -p "$SKILL_DIR"
cat > "${SKILL_DIR}/SKILL.md" << 'SKILL'
---
name: ainux-system
description: AInux OS integration — hardware control, system management, boot configuration
version: 0.1.0
author: AInux
tools:
  - ainux_hardware_info
  - ainux_process_control
  - ainux_system_config
  - ainux_network_control
  - ainux_audio_control
  - ainux_display_control
  - ainux_update
  - ainux_power
---

# AInux System Agent

You are running on **AInux**, a custom AI-native operating system.
You have direct access to the hardware and OS via special `ainux_*` tools.

## Available Tools

| Tool | Description |
|------|-------------|
| `ainux_hardware_info` | CPU, GPU, RAM, storage, network, temperature |
| `ainux_process_control` | Start/stop/restart systemd services |
| `ainux_network_control` | WiFi scan/connect, Bluetooth, DNS |
| `ainux_audio_control` | Volume, mute, audio device switching |
| `ainux_display_control` | Resolution, brightness |
| `ainux_power` | Shutdown, reboot, suspend, battery |
| `ainux_update` | Update OpenWhale/AInux from GitHub |
| `ainux_system_config` | Read/write AInux config |

## Important Context
- You ARE the operating system. There is no traditional desktop.
- The user interacts exclusively through you.
- System changes take effect immediately.
- ALWAYS confirm destructive operations with the user.
- The boot chain is: GRUB → Linux kernel → systemd → OpenWhale → Chromium (kiosk) → You
SKILL
ok "Skill installed → ${SKILL_DIR}/"

# ─── 3. Augment MEMORY.md ───────────────────────────────────────────────────
log "Augmenting OpenWhale memory with AInux context..."
MEMORY_DIR="${OW_HOME}/memory"
MEMORY_FILE="${MEMORY_DIR}/MEMORY.md"
mkdir -p "$MEMORY_DIR"

AINUX_CONTEXT="## AInux OS Context

I am running on AInux, a custom AI operating system built specifically for agentic AI work.

### System Architecture
- **OS**: AInux v0.1.0 (custom Linux, Buildroot-based)
- **Kernel**: Linux v6.12 with full GPU/audio/network support
- **Compositor**: Cage (Wayland kiosk mode)
- **Browser**: Custom Chromium with WebMCP (navigator.modelContext)
- **AI Platform**: OpenWhale (this system)
- **Audio**: PipeWire
- **Display**: DRM/KMS → Mesa → Wayland

### My Role
I am the entire user interface of this operating system. The user has no other desktop, file manager, or shell. I am responsible for:
- Executing all user requests via my tools
- Managing system services and hardware
- Providing real-time system status
- Updating the system when requested

### Available System Tools
ainux_hardware_info, ainux_process_control, ainux_network_control, ainux_audio_control, ainux_display_control, ainux_power, ainux_update, ainux_system_config"

if [ -f "$MEMORY_FILE" ]; then
    if ! grep -q "AInux OS Context" "$MEMORY_FILE"; then
        printf "\n\n%s" "$AINUX_CONTEXT" >> "$MEMORY_FILE"
        ok "Added AInux context to existing MEMORY.md"
    else
        ok "AInux context already present in MEMORY.md"
    fi
else
    printf "%s" "$AINUX_CONTEXT" > "$MEMORY_FILE"
    ok "Created MEMORY.md with AInux context"
fi

# ─── 4. Configure .env ──────────────────────────────────────────────────────
log "Configuring OpenWhale .env for AInux mode..."
ENV_FILE="${OPENWHALE_DIR}/.env"
if [ -f "${OPENWHALE_DIR}/.env.example" ] && [ ! -f "$ENV_FILE" ]; then
    cp "${OPENWHALE_DIR}/.env.example" "$ENV_FILE"
fi

if [ -f "$ENV_FILE" ]; then
    if ! grep -q "AINUX_MODE" "$ENV_FILE"; then
        cat >> "$ENV_FILE" << 'ENVBLOCK'

# ── AInux OS Integration ──
AINUX_MODE=true
AINUX_VERSION=0.1.0
AINUX_HOME=/opt/ainux
OPENWHALE_DIR=/opt/ainux/openwhale
ENVBLOCK
        ok ".env augmented with AINUX_MODE"
    else
        ok "AINUX_MODE already in .env"
    fi
fi

# ─── 5. Install Update Manager ──────────────────────────────────────────────
log "Installing update manager..."
mkdir -p "${AINUX_DATA}/bin"
cp "${AINUX_ROOT}/scripts/ainux-update.sh" "${AINUX_DATA}/bin/ainux-update"
chmod +x "${AINUX_DATA}/bin/ainux-update"
ok "Update manager → ${AINUX_DATA}/bin/ainux-update"

# ─── 6. Create symlinks ─────────────────────────────────────────────────────
log "Creating convenience symlinks..."
mkdir -p "${HOME}/.local/bin"
ln -sf "${AINUX_DATA}/bin/ainux-update" "${HOME}/.local/bin/ainux-update" 2>/dev/null || true
ok "ainux-update available in PATH"

# ─── Done ────────────────────────────────────────────────────────────────────
echo ""
log "🐋 ═════════════════════════════════════════════════════"
log "🐋  Deep Integration Complete!"
log "🐋"
log "🐋  Extension: ~/.openwhale/extensions/ainux-os/"
log "🐋  Skill:     ~/.openwhale/skills/ainux-system/"
log "🐋  Memory:    ~/.openwhale/memory/MEMORY.md"
log "🐋  Updater:   ainux-update check|openwhale|ainux"
log "🐋"
log "🐋  8 new tools registered: ainux_hardware_info,"
log "🐋    ainux_process_control, ainux_network_control,"
log "🐋    ainux_audio_control, ainux_display_control,"
log "🐋    ainux_power, ainux_update, ainux_system_config"
log "🐋"
log "🐋  Restart OpenWhale to activate:"
log "🐋    cd ${OPENWHALE_DIR} && pnpm dev"
log "🐋 ═════════════════════════════════════════════════════"
