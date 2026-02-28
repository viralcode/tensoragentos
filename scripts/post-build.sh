#!/bin/bash
#
# Buildroot post-build script
# Runs after the rootfs is built, before image generation
#

TARGET_DIR="$1"

echo "[ainux post-build] Configuring AInux..."

# Create ainux user
if ! grep -q "ainux" "${TARGET_DIR}/etc/passwd"; then
    echo "ainux:x:1000:1000:AInux User:/home/ainux:/bin/bash" >> "${TARGET_DIR}/etc/passwd"
    echo "ainux:x:1000:" >> "${TARGET_DIR}/etc/group"
    echo "ainux:*:19000:0:99999:7:::" >> "${TARGET_DIR}/etc/shadow"
    mkdir -p "${TARGET_DIR}/home/ainux/.ainux"
    
    # Add ainux to necessary groups
    sed -i '/^audio:/s/$/ainux/' "${TARGET_DIR}/etc/group"
    sed -i '/^video:/s/$/ainux/' "${TARGET_DIR}/etc/group"
    sed -i '/^input:/s/$/ainux/' "${TARGET_DIR}/etc/group"
    sed -i '/^render:/s/$/,ainux/' "${TARGET_DIR}/etc/group" 2>/dev/null || true
fi

# Set up XDG runtime dir
mkdir -p "${TARGET_DIR}/run/user/1000"

# Install pnpm globally
if [ -f "${TARGET_DIR}/usr/bin/node" ]; then
    echo "[ainux post-build] Installing pnpm..."
    chroot "${TARGET_DIR}" /usr/bin/node -e "
        const https = require('https');
        // pnpm will be installed on first boot via setup.sh
    " 2>/dev/null || true
fi

# Set default systemd target to graphical
ln -sf /usr/lib/systemd/system/graphical.target \
    "${TARGET_DIR}/etc/systemd/system/default.target"

# Make scripts executable
chmod +x "${TARGET_DIR}/opt/ainux/bin/"* 2>/dev/null || true

echo "[ainux post-build] Done!"
