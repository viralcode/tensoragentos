#!/bin/bash
#
# TensorAgent OS — Post-Build Script
# Runs after the rootfs is built, before image generation.
# Configures user, groups, systemd targets, and permissions.
#

TARGET_DIR="$1"

echo "[tensoragent post-build] Configuring TensorAgent OS..."

# ── Create default user (dynamic — avoids hardcoded UID) ──
if ! grep -q "^ainux:" "${TARGET_DIR}/etc/passwd" 2>/dev/null; then
    # Use chroot useradd for proper UID/GID allocation
    chroot "${TARGET_DIR}" /usr/sbin/useradd -m -s /bin/bash \
        -G sudo,video,audio,input ainux 2>/dev/null || {
        # Fallback: manual creation if useradd unavailable
        echo "ainux:x:1000:1000:TensorAgent User:/home/ainux:/bin/bash" >> "${TARGET_DIR}/etc/passwd"
        echo "ainux:x:1000:" >> "${TARGET_DIR}/etc/group"
        mkdir -p "${TARGET_DIR}/home/ainux"
    }
fi

# Ensure home directory structure
mkdir -p "${TARGET_DIR}/home/ainux/.config"
mkdir -p "${TARGET_DIR}/home/ainux/.local/share"
mkdir -p "${TARGET_DIR}/home/ainux/Works"

# Fix ownership (uses chroot to resolve UID dynamically)
chroot "${TARGET_DIR}" chown -R ainux:ainux /home/ainux 2>/dev/null || true

# ── Systemd: graphical target by default ──
if [ -d "${TARGET_DIR}/etc/systemd/system" ]; then
    ln -sf /lib/systemd/system/graphical.target \
        "${TARGET_DIR}/etc/systemd/system/default.target" 2>/dev/null || true
fi

# ── XDG runtime dir (created by logind at login, but seed the path) ──
# systemd-logind creates /run/user/<UID> dynamically at login.
# We no longer hardcode /run/user/1000.

# ── PAM configuration for WhaleOS login ──
if [ -d "${TARGET_DIR}/etc/pam.d" ]; then
    cat > "${TARGET_DIR}/etc/pam.d/whaleos" << 'PAMCFG'
# PAM configuration for WhaleOS desktop login
auth       required   pam_unix.so
account    required   pam_unix.so
session    required   pam_unix.so
PAMCFG
fi

# ── Make scripts executable ──
chmod +x "${TARGET_DIR}/opt/ainux/whaleos/build.sh"  2>/dev/null || true
chmod +x "${TARGET_DIR}/opt/ainux/bin/"*              2>/dev/null || true

echo "[tensoragent post-build] Done!"
