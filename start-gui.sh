#!/bin/bash
# TensorAgent OS — smart display startup
# WhaleOS IS a Wayland compositor — no need for Cage.
# Runs directly on the framebuffer via EGLFS.

LOGFILE=/tmp/tensoragent-gui.log

# Simple logging — no process substitution pipes that block VT
log() { echo "[TensorAgent] $*" | tee -a "$LOGFILE"; }
log "=== TensorAgent GUI starting at $(date) ==="

# Create XDG_RUNTIME_DIR if it doesn't exist
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
if [ ! -d "$XDG_RUNTIME_DIR" ]; then
    mkdir -p "$XDG_RUNTIME_DIR"
    chmod 0700 "$XDG_RUNTIME_DIR"
fi

# Qt rendering config — software rendering for VM compatibility
export QT_QPA_PLATFORM=eglfs
export QSG_RENDER_LOOP=basic
export QT_QUICK_BACKEND=software
export QML2_IMPORT_PATH=/usr/lib/aarch64-linux-gnu/qt6/qml:/usr/lib/qt6/qml

# EGLFS config — use linuxfb fallback if no working EGL
export QT_QPA_EGLFS_INTEGRATION=eglfs_kms
export QT_QPA_EGLFS_ALWAYS_SET_MODE=1
export LIBGL_ALWAYS_SOFTWARE=1

# Disable GTK client-side decorations — WhaleOS provides server-side title bars
export GTK_CSD=0
export XDG_CURRENT_DESKTOP=WhaleOS

# Detect hypervisor
HYPERVISOR=$(systemd-detect-virt 2>/dev/null || echo "none")
log "Detected hypervisor: $HYPERVISOR"

case "$HYPERVISOR" in
    vmware)
        log "VMware detected — using software renderer with linuxfb fallback"
        export GALLIUM_DRIVER=llvmpipe
        modprobe vmwgfx 2>/dev/null || true
        # Try eglfs first, fall back to linuxfb if it fails
        export QT_QPA_EGLFS_KMS_CONFIG=""
        ;;
    qemu|kvm)
        log "QEMU/KVM detected — using virtio-gpu"
        ;;
    *)
        log "Bare metal or unknown — auto-detecting display"
        ;;
esac

# Wait for DRM device (up to 10 seconds)
for i in $(seq 1 20); do
    if ls /dev/dri/card* 2>/dev/null; then
        log "DRM device found"
        ls /dev/dri/ >> "$LOGFILE" 2>&1
        break
    fi
    log "Waiting for DRM device... ($i/20)"
    sleep 0.5
done

# If no DRM device, fall back to linuxfb
if ! ls /dev/dri/card* 2>/dev/null; then
    log "No DRM device — falling back to linuxfb"
    export QT_QPA_PLATFORM=linuxfb
fi

# Pre-flight checks
log "Checking WhaleOS binary..."
if [ ! -x /opt/ainux/whaleos/whaleos ]; then
    log "ERROR: WhaleOS binary not found or not executable"
    ls -la /opt/ainux/whaleos/ >> "$LOGFILE" 2>&1 || echo "  whaleos directory missing" >> "$LOGFILE"
    exit 1
fi

log "Checking main.qml..."
if [ ! -f /opt/ainux/whaleos/main.qml ]; then
    log "ERROR: main.qml not found"
    exit 1
fi

log "Environment:"
log "  QT_QPA_PLATFORM=$QT_QPA_PLATFORM"
log "  QT_QUICK_BACKEND=$QT_QUICK_BACKEND"
log "  QSG_RENDER_LOOP=$QSG_RENDER_LOOP"
log "  XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"

# Launch WhaleOS directly — it IS a Wayland compositor
# No Cage needed. WhaleOS renders via EGLFS to the DRM device.
log "Starting WhaleOS compositor directly..."

# Refresh apt cache in background so Package Store works immediately
apt-get update -qq &>/dev/null &

exec /opt/ainux/whaleos/whaleos >> "$LOGFILE" 2>&1
