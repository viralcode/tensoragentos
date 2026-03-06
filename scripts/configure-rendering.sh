#!/bin/bash
#
# TensorAgent OS — Rendering Configuration
#
# Detects the GPU environment and configures Qt6 rendering
# for optimal performance. Run at boot by ainux-gui.service.
#
# Strategy:
#   1. If real GPU detected (virtio-gpu, AMD, Intel, NVIDIA) → OpenGL backend
#   2. If software rendering (llvmpipe, swrast, ramfb) → Qt Software backend
#   3. Exports env vars consumed by Cage + WhaleOS
#

set -e

RENDER_BACKEND="software"
OPENGL_AVAILABLE=false

# ── Detect GPU capabilities ──
if command -v glxinfo &>/dev/null; then
    GL_RENDERER=$(glxinfo 2>/dev/null | grep "OpenGL renderer" | head -1 || true)
elif [ -f /proc/driver/nvidia/version ]; then
    GL_RENDERER="NVIDIA"
fi

# Check for real GPU
if echo "$GL_RENDERER" | grep -qiE "virtio|virgl|AMD|Intel|NVIDIA|Radeon"; then
    RENDER_BACKEND="opengl"
    OPENGL_AVAILABLE=true
fi

# ── Export rendering environment ──
case "$RENDER_BACKEND" in
    opengl)
        echo "[tensoragent-render] Using OpenGL hardware acceleration"
        export QSG_RENDER_LOOP=threaded
        export QT_QUICK_BACKEND=
        export QSG_RHI_BACKEND=opengl
        export MESA_GL_VERSION_OVERRIDE=4.5
        ;;
    software)
        echo "[tensoragent-render] Using Qt Software rendering (VM/no GPU)"
        export QSG_RENDER_LOOP=basic
        export QT_QUICK_BACKEND=software
        export QSG_RHI_BACKEND=
        # Disable animations that are expensive under software rendering
        export QT_QUICK_CONTROLS_HOVER_ENABLED=0
        ;;
esac

# ── Common Wayland settings ──
export QT_QPA_PLATFORM=wayland
export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
export QT_AUTO_SCREEN_SCALE_FACTOR=0

# ── Cage compositor hints ──
export WLR_NO_HARDWARE_CURSORS=1
export WLR_LIBINPUT_NO_DEVICES=1

# Print config summary
echo "[tensoragent-render] QSG_RENDER_LOOP=$QSG_RENDER_LOOP"
echo "[tensoragent-render] QT_QUICK_BACKEND=$QT_QUICK_BACKEND"
echo "[tensoragent-render] QT_QPA_PLATFORM=$QT_QPA_PLATFORM"
