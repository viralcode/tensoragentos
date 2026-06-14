#!/bin/bash
#
# TensorAgent OS — First Boot Setup
#
# Interactive first-boot wizard that runs once on initial login.
# Creates the admin user, sets passwords, and configures SSH keys.
# Replaces the insecure hardcoded ainux/ainux credentials.
#
# This script is triggered by ainux-first-boot.service on first boot,
# then disables itself so it never runs again.
#

set -euo pipefail

FIRST_BOOT_FLAG="/etc/ainux/.first-boot-complete"
AINUX_CONF="/etc/ainux/ainux.conf"

# ─── Colors ───────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

banner() {
    clear
    echo -e "${CYAN}"
    echo "  ╔══════════════════════════════════════════════════════════╗"
    echo "  ║                                                          ║"
    echo "  ║           🐋  TensorAgent OS — First Boot Setup          ║"
    echo "  ║                                                          ║"
    echo "  ║    Welcome! Let's secure your system before first use.   ║"
    echo "  ║                                                          ║"
    echo "  ╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

log()  { echo -e "${CYAN}[setup]${NC} $1"; }
ok()   { echo -e "${GREEN}  ✓${NC} $1"; }
warn() { echo -e "${YELLOW}  ⚠${NC} $1"; }
err()  { echo -e "${RED}  ✗${NC} $1"; }

# ─── Guard: Skip if already completed ────────────────────────────
if [ -f "$FIRST_BOOT_FLAG" ]; then
    exit 0
fi

banner

# ─── Step 1: Create Admin User ───────────────────────────────────
echo -e "${BOLD}Step 1/5: Create Administrator Account${NC}"
echo ""

read -p "  Enter admin username [ainux]: " ADMIN_USER
ADMIN_USER="${ADMIN_USER:-ainux}"

# Validate username
if ! echo "$ADMIN_USER" | grep -qE '^[a-z_][a-z0-9_-]*$'; then
    err "Invalid username. Use lowercase letters, numbers, underscore, hyphen."
    exit 1
fi

# Create user if it doesn't exist (or rename default)
if [ "$ADMIN_USER" != "ainux" ]; then
    if id ainux &>/dev/null; then
        log "Renaming default user to ${ADMIN_USER}..."
        usermod -l "$ADMIN_USER" ainux
        usermod -d "/home/${ADMIN_USER}" -m "$ADMIN_USER"
        groupmod -n "$ADMIN_USER" ainux
        # Update sudoers
        sed -i "s/ainux/${ADMIN_USER}/g" /etc/sudoers.d/ainux 2>/dev/null || true
        mv /etc/sudoers.d/ainux "/etc/sudoers.d/${ADMIN_USER}" 2>/dev/null || true
    fi
elif ! id ainux &>/dev/null; then
    useradd -m -s /bin/bash -G sudo,video,audio,input,render,systemd-journal "$ADMIN_USER"
fi

ok "User '${ADMIN_USER}' configured"
echo ""

# ─── Step 2: Set Password ────────────────────────────────────────
echo -e "${BOLD}Step 2/5: Set Password${NC}"
echo ""

while true; do
    read -sp "  Enter password: " ADMIN_PASS
    echo ""
    read -sp "  Confirm password: " ADMIN_PASS_CONFIRM
    echo ""

    if [ "$ADMIN_PASS" != "$ADMIN_PASS_CONFIRM" ]; then
        err "Passwords do not match. Try again."
        continue
    fi

    if [ ${#ADMIN_PASS} -lt 8 ]; then
        err "Password must be at least 8 characters."
        continue
    fi

    break
done

echo "${ADMIN_USER}:${ADMIN_PASS}" | chpasswd
ok "Password set"
echo ""

# ─── Step 3: Configure Sudo ──────────────────────────────────────
echo -e "${BOLD}Step 3/5: Configure Sudo Access${NC}"
echo ""

read -p "  Require password for sudo? (recommended) [Y/n]: " SUDO_PASS
SUDO_PASS="${SUDO_PASS:-Y}"

if [[ "$SUDO_PASS" =~ ^[Yy] ]]; then
    # Remove NOPASSWD
    echo "${ADMIN_USER} ALL=(ALL:ALL) ALL" > "/etc/sudoers.d/${ADMIN_USER}"
    chmod 440 "/etc/sudoers.d/${ADMIN_USER}"
    # Remove the blanket nopasswd rule
    rm -f /etc/sudoers.d/nopasswd
    ok "Sudo requires password (enterprise-grade)"
else
    echo "${ADMIN_USER} ALL=(ALL:ALL) NOPASSWD: ALL" > "/etc/sudoers.d/${ADMIN_USER}"
    chmod 440 "/etc/sudoers.d/${ADMIN_USER}"
    warn "Sudo without password (less secure, but OK for dev/lab)"
fi
echo ""

# ─── Step 4: SSH Configuration ───────────────────────────────────
echo -e "${BOLD}Step 4/5: SSH Access${NC}"
echo ""

read -p "  Enable SSH access? [Y/n]: " ENABLE_SSH
ENABLE_SSH="${ENABLE_SSH:-Y}"

if [[ "$ENABLE_SSH" =~ ^[Yy] ]]; then
    systemctl enable ssh 2>/dev/null || systemctl enable sshd 2>/dev/null || true

    read -p "  Disable password-based SSH? (key-only, more secure) [y/N]: " SSH_KEY_ONLY
    SSH_KEY_ONLY="${SSH_KEY_ONLY:-N}"

    if [[ "$SSH_KEY_ONLY" =~ ^[Yy] ]]; then
        cat > /etc/ssh/sshd_config.d/ainux-hardened.conf << 'SSHCONF'
# TensorAgent OS — Hardened SSH Configuration
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
AllowAgentForwarding no
AllowTcpForwarding no
PrintMotd no
Banner /etc/issue.net
SSHCONF
        ok "SSH: key-only authentication (hardened)"

        echo ""
        read -p "  Paste your SSH public key (or press Enter to skip): " SSH_KEY
        if [ -n "$SSH_KEY" ]; then
            ADMIN_HOME=$(eval echo "~${ADMIN_USER}")
            mkdir -p "${ADMIN_HOME}/.ssh"
            echo "$SSH_KEY" >> "${ADMIN_HOME}/.ssh/authorized_keys"
            chmod 700 "${ADMIN_HOME}/.ssh"
            chmod 600 "${ADMIN_HOME}/.ssh/authorized_keys"
            chown -R "${ADMIN_USER}:${ADMIN_USER}" "${ADMIN_HOME}/.ssh"
            ok "SSH key added"
        else
            warn "No SSH key added — you'll need to add one manually before connecting"
        fi
    else
        cat > /etc/ssh/sshd_config.d/ainux-hardened.conf << 'SSHCONF'
# TensorAgent OS — SSH Configuration
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
MaxAuthTries 5
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
PrintMotd no
Banner /etc/issue.net
SSHCONF
        ok "SSH: password + key authentication"
    fi

    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
else
    systemctl disable ssh 2>/dev/null || systemctl disable sshd 2>/dev/null || true
    ok "SSH disabled"
fi
echo ""

# ─── Step 5: System Hostname ─────────────────────────────────────
echo -e "${BOLD}Step 5/5: System Identity${NC}"
echo ""

read -p "  Hostname [tensoragent]: " NEW_HOSTNAME
NEW_HOSTNAME="${NEW_HOSTNAME:-tensoragent}"

hostnamectl set-hostname "$NEW_HOSTNAME" 2>/dev/null || echo "$NEW_HOSTNAME" > /etc/hostname
# Update /etc/hosts
sed -i "s/tensoragent/${NEW_HOSTNAME}/g" /etc/hosts 2>/dev/null || true
ok "Hostname set to '${NEW_HOSTNAME}'"
echo ""

# ─── Finalize ─────────────────────────────────────────────────────
log "Applying final security settings..."

# Lock the root account
passwd -l root 2>/dev/null || true
ok "Root account locked"

# Set login banner
cat > /etc/issue.net << 'BANNER'
***************************************************************************
*                     TensorAgent OS — Enterprise                         *
*                                                                         *
*  WARNING: Unauthorized access to this system is prohibited.             *
*  All connections and activities are monitored and recorded.             *
*  By accessing this system, you consent to monitoring.                   *
*                                                                         *
*  Disconnect IMMEDIATELY if you are not an authorized user.              *
***************************************************************************
BANNER

cat > /etc/issue << 'LOCAL_BANNER'

  🐋 TensorAgent OS

LOCAL_BANNER

# Mark first boot as complete
mkdir -p /etc/ainux
touch "$FIRST_BOOT_FLAG"

# Update service files with actual username if changed
if [ "$ADMIN_USER" != "ainux" ]; then
    for svc in /etc/systemd/system/openwhale.service \
               /etc/systemd/system/ainux-kernel.service \
               /etc/systemd/system/ollama.service; do
        if [ -f "$svc" ]; then
            sed -i "s/User=ainux/User=${ADMIN_USER}/g" "$svc"
            sed -i "s/Group=ainux/Group=${ADMIN_USER}/g" "$svc"
            sed -i "s|/home/ainux|/home/${ADMIN_USER}|g" "$svc"
        fi
    done
    systemctl daemon-reload
fi

# Disable this service so it doesn't run again
systemctl disable ainux-first-boot.service 2>/dev/null || true

echo ""
echo -e "${GREEN}  ╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}  ║                                                          ║${NC}"
echo -e "${GREEN}  ║          ✓  First boot setup complete!                   ║${NC}"
echo -e "${GREEN}  ║                                                          ║${NC}"
echo -e "${GREEN}  ║    Your system is now secured. Rebooting in 5 seconds... ║${NC}"
echo -e "${GREEN}  ║                                                          ║${NC}"
echo -e "${GREEN}  ╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

sleep 5
reboot
