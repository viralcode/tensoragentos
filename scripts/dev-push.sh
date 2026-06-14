#!/bin/bash
# ─────────────────────────────────────────────────────────────
# dev-push.sh — Fast QML hot-reload for WhaleOS development
# ─────────────────────────────────────────────────────────────
#
# Instead of rebuilding the ISO (~5 min), this script:
#   1. Copies changed QML files to the running VM via SSH
#   2. Restarts the WhaleOS compositor (takes ~2 seconds)
#
# Usage:
#   ./scripts/dev-push.sh <VM_IP>
#
# First time setup:
#   1. Boot the ISO in UTM/VMware
#   2. Find VM's IP: run `ip addr` in the VM terminal
#   3. Run: ./scripts/dev-push.sh 192.168.x.x
#
# Credentials: ainux/ainux
# ─────────────────────────────────────────────────────────────

set -e

VM_IP="${1:-}"
VM_USER="ainux"
VM_PASS="ainux"
REMOTE_QML_DIR="/opt/ainux/whaleos"
LOCAL_QML_DIR="$(cd "$(dirname "$0")/.." && pwd)/packages/whaleos"

if [ -z "$VM_IP" ]; then
    echo "Usage: $0 <VM_IP>"
    echo ""
    echo "Find the VM IP by running 'ip addr' in the VM terminal,"
    echo "or check UTM's network settings."
    echo ""
    echo "Example: $0 192.168.64.3"
    exit 1
fi

echo "🚀 Dev Push — Fast QML hot-reload"
echo "   VM: ${VM_USER}@${VM_IP}"
echo "   Local: ${LOCAL_QML_DIR}"
echo "   Remote: ${REMOTE_QML_DIR}"
echo ""

# Check SSH connectivity
echo "1️⃣  Testing SSH connection..."
if ! sshpass -p "$VM_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
    "${VM_USER}@${VM_IP}" "echo ok" 2>/dev/null; then
    echo "❌ Cannot connect to ${VM_USER}@${VM_IP}"
    echo ""
    echo "Make sure:"
    echo "  • The VM is running"
    echo "  • SSH is accessible (port 22)"
    echo "  • If using UTM, enable port forwarding or bridged networking"
    echo ""
    echo "Tip: If sshpass is not installed, run: brew install hudochenkov/sshpass/sshpass"
    exit 1
fi
echo "   ✓ Connected"

# Copy QML, JS, MJS, C++ and SH files
echo "2️⃣  Pushing files..."
sshpass -p "$VM_PASS" scp -o StrictHostKeyChecking=no -r \
    "${LOCAL_QML_DIR}/"*.qml "${LOCAL_QML_DIR}/"*.js "${LOCAL_QML_DIR}/"*.mjs "${LOCAL_QML_DIR}/"*.h "${LOCAL_QML_DIR}/"*.cpp "${LOCAL_QML_DIR}/"*.sh \
    "${VM_USER}@${VM_IP}:/tmp/whaleos-qml/" 2>/dev/null || {
    # Create remote temp dir first
    sshpass -p "$VM_PASS" ssh -o StrictHostKeyChecking=no \
        "${VM_USER}@${VM_IP}" "mkdir -p /tmp/whaleos-qml"
    sshpass -p "$VM_PASS" scp -o StrictHostKeyChecking=no \
        "${LOCAL_QML_DIR}/"*.qml "${LOCAL_QML_DIR}/"*.js "${LOCAL_QML_DIR}/"*.mjs "${LOCAL_QML_DIR}/"*.h "${LOCAL_QML_DIR}/"*.cpp "${LOCAL_QML_DIR}/"*.sh \
        "${VM_USER}@${VM_IP}:/tmp/whaleos-qml/"
}

# Move files into place (needs sudo), build and restart compositor & services
echo "3️⃣  Installing, rebuilding & restarting compositor and services..."
sshpass -p "$VM_PASS" ssh -o StrictHostKeyChecking=no \
    "${VM_USER}@${VM_IP}" "
    echo '$VM_PASS' | sudo -S cp /tmp/whaleos-qml/* ${REMOTE_QML_DIR}/ 2>/dev/null
    echo '$VM_PASS' | sudo -S chmod +x ${REMOTE_QML_DIR}/*.sh 2>/dev/null
    echo '$VM_PASS' | sudo -S bash ${REMOTE_QML_DIR}/patch-gui-service.sh
    echo '$VM_PASS' | sudo -S bash /opt/ainux/whaleos/build.sh
    echo '$VM_PASS' | sudo -S systemctl restart whaleos-gui.service
    echo '$VM_PASS' | sudo -S systemctl restart clipboard-sync.service
    echo '   ✓ Compositor and services rebuilt and restarted'
"

echo ""
echo "✅ Done! Changes are live — check the VM screen."
echo "   (The compositor restarts automatically on tty1)"
