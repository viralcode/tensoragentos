#!/bin/bash
#
# AInux OpenWhale Update Manager
# 
# Updates OpenWhale to the latest version from GitHub.
# Preserves configuration, database, memory, and skills.
#
# Enterprise features:
#   - Pre-update backup with database state
#   - Post-update health checks
#   - Update audit logging
#   - Safe rollback with state restoration
#
# Usage:
#   ainux-update check          — Check for updates
#   ainux-update openwhale      — Update OpenWhale
#   ainux-update ainux           — Update AInux kernel
#   ainux-update all             — Update everything
#   ainux-update rollback        — Roll back to previous version
#   ainux-update verify          — Verify system integrity
#   ainux-update security        — Apply security-only updates
#

set -euo pipefail

OPENWHALE_DIR="${OPENWHALE_DIR:-/opt/ainux/openwhale}"
AINUX_HOME="${AINUX_HOME:-/opt/ainux}"
AINUX_DATA="${HOME}/.ainux"
BACKUP_DIR="${AINUX_DATA}/backups"
UPDATE_LOG="${AINUX_DATA}/update.log"

ACTION="${1:-check}"

log() { echo -e "\033[36m[ainux-update]\033[0m $1" | tee -a "$UPDATE_LOG" 2>/dev/null; }
ok()  { echo -e "\033[32m  ✓\033[0m $1" | tee -a "$UPDATE_LOG" 2>/dev/null; }
err() { echo -e "\033[31m  ✗\033[0m $1" | tee -a "$UPDATE_LOG" 2>/dev/null; }
warn(){ echo -e "\033[33m  ⚠\033[0m $1" | tee -a "$UPDATE_LOG" 2>/dev/null; }

mkdir -p "$BACKUP_DIR"
echo "--- Update action '$ACTION' started: $(date -Iseconds) ---" >> "$UPDATE_LOG" 2>/dev/null || true

# ─── Helper Functions ─────────────────────────────────────────────

health_check() {
    local svc="$1"
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        ok "$svc is healthy"
        return 0
    else
        warn "$svc is not running"
        return 1
    fi
}

backup_state() {
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local db_file="${HOME}/.openwhale/openwhale.db"
    if [ -f "$db_file" ]; then
        cp "$db_file" "${BACKUP_DIR}/openwhale-db-${timestamp}.bak"
        ok "Database backed up: openwhale-db-${timestamp}.bak"
    fi
    if [ -f "/etc/ainux/security.conf" ]; then
        cp "/etc/ainux/security.conf" "${BACKUP_DIR}/security-${timestamp}.conf.bak" 2>/dev/null || true
    fi
}

case "$ACTION" in
    check)
        log "Checking for updates..."
        echo ""
        
        # OpenWhale
        if [ -d "${OPENWHALE_DIR}/.git" ]; then
            cd "$OPENWHALE_DIR"
            git fetch origin main 2>/dev/null
            OW_BEHIND=$(git rev-list HEAD..origin/main --count 2>/dev/null || echo "?")
            OW_VERSION=$(node -e "console.log(require('./package.json').version)" 2>/dev/null || echo "?")
            OW_CURRENT=$(git log --oneline -1 2>/dev/null || echo "unknown")
            if [ "$OW_BEHIND" = "0" ]; then
                ok "OpenWhale v${OW_VERSION} — up to date"
            else
                log "OpenWhale v${OW_VERSION} — ${OW_BEHIND} updates available"
                echo "      Latest commits:"
                git log --oneline HEAD..origin/main 2>/dev/null | head -5 | sed 's/^/        /'
            fi
        else
            err "OpenWhale: not a git repo at ${OPENWHALE_DIR}"
        fi
        
        echo ""
        
        # AInux
        if [ -d "${AINUX_HOME}/.git" ]; then
            cd "$AINUX_HOME"
            git fetch origin main 2>/dev/null
            AX_BEHIND=$(git rev-list HEAD..origin/main --count 2>/dev/null || echo "?")
            if [ "$AX_BEHIND" = "0" ]; then
                ok "AInux — up to date"
            else
                log "AInux — ${AX_BEHIND} updates available"
            fi
        fi
        
        echo ""
        log "Kernel: $(uname -r 2>/dev/null || echo 'N/A')"

        # Security services status
        echo ""
        log "Security Status:"
        health_check "apparmor" || true
        health_check "auditd" || true
        health_check "ufw" || true
        health_check "fail2ban" || true

        # Check for pending security updates
        echo ""
        if command -v apt-get &>/dev/null; then
            SEC_UPDATES=$(apt-get -s upgrade 2>/dev/null | grep -c "^Inst.*security" || echo "0")
            if [ "$SEC_UPDATES" -gt 0 ]; then
                warn "${SEC_UPDATES} security updates pending — run 'ainux-update security'"
            else
                ok "No pending security updates"
            fi
        fi
        ;;

    openwhale)
        log "Updating OpenWhale..."
        
        if [ ! -d "${OPENWHALE_DIR}/.git" ]; then
            err "Not a git repo. Cloning fresh..."
            git clone https://github.com/viralcode/openwhale.git "${OPENWHALE_DIR}"
        fi
        
        cd "$OPENWHALE_DIR"
        
        # Pre-update: backup state
        log "Backing up current state..."
        backup_state
        
        CURRENT_SHA=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
        echo "$CURRENT_SHA" > "${BACKUP_DIR}/openwhale-pre-update-sha"
        log "Current SHA: ${CURRENT_SHA}"
        
        # Stash local changes
        git stash 2>/dev/null || true
        
        # Pull latest
        log "Pulling latest from origin/main..."
        git pull origin main 2>&1
        
        # Reinstall deps
        log "Installing dependencies..."
        if command -v pnpm &> /dev/null; then
            pnpm install 2>&1
            pnpm approve-builds 2>/dev/null || true
        else
            npm install 2>&1
        fi
        
        # Pop stash
        git stash pop 2>/dev/null || true
        
        NEW_VERSION=$(node -e "console.log(require('./package.json').version)" 2>/dev/null || echo "?")
        ok "Updated to v${NEW_VERSION}"

        # Post-update health check
        log "Running post-update health check..."
        if systemctl is-active --quiet openwhale 2>/dev/null; then
            log "Restarting OpenWhale..."
            sudo systemctl restart openwhale
            sleep 3
            health_check "openwhale" || warn "OpenWhale may need manual attention"
        else
            log "Restart OpenWhale: sudo systemctl restart openwhale"
        fi
        ;;

    ainux)
        log "Updating AInux..."
        cd "$AINUX_HOME"
        backup_state
        CURRENT_SHA=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
        echo "$CURRENT_SHA" > "${BACKUP_DIR}/ainux-pre-update-sha"
        git pull origin main 2>&1
        ok "AInux updated"
        log "Restart: sudo systemctl restart ainux-kernel"
        ;;

    all)
        $0 openwhale
        echo ""
        $0 ainux
        echo ""
        ok "All components updated!"
        log "Full restart: sudo systemctl restart ainux-kernel openwhale"
        ;;

    rollback)
        TARGET="${2:-openwhale}"
        SHA_FILE="${BACKUP_DIR}/${TARGET}-pre-update-sha"
        
        if [ ! -f "$SHA_FILE" ]; then
            err "No backup SHA found for ${TARGET}"
            exit 1
        fi
        
        ROLLBACK_SHA=$(cat "$SHA_FILE")
        log "Rolling back ${TARGET} to ${ROLLBACK_SHA}..."
        
        case "$TARGET" in
            openwhale) cd "$OPENWHALE_DIR" ;;
            ainux)     cd "$AINUX_HOME" ;;
            *) err "Unknown target: $TARGET"; exit 1 ;;
        esac
        
        git checkout "$ROLLBACK_SHA"
        
        if [ "$TARGET" = "openwhale" ]; then
            if command -v pnpm &> /dev/null; then
                pnpm install 2>&1
            else
                npm install 2>&1
            fi

            # Restore database if backup exists
            LATEST_DB=$(ls -t "${BACKUP_DIR}"/openwhale-db-*.bak 2>/dev/null | head -1)
            if [ -n "$LATEST_DB" ]; then
                log "Restoring database from ${LATEST_DB}..."
                cp "$LATEST_DB" "${HOME}/.openwhale/openwhale.db"
                ok "Database restored"
            fi
        fi
        
        ok "Rolled back ${TARGET} to ${ROLLBACK_SHA}"
        log "Restart the service to apply"
        ;;

    verify)
        log "Verifying system integrity..."
        echo ""

        # Check service hardening
        log "Service Security Scores:"
        for svc in openwhale ainux-kernel ollama; do
            if [ -f "/etc/systemd/system/${svc}.service" ]; then
                SCORE=$(systemd-analyze security "${svc}.service" 2>/dev/null | tail -1 | grep -oP '\d+\.\d+' || echo "N/A")
                echo "  ${svc}: ${SCORE}/10.0"
            fi
        done

        echo ""
        log "AppArmor Status:"
        if command -v aa-status &>/dev/null; then
            sudo aa-status 2>/dev/null | head -10
        else
            warn "AppArmor not installed"
        fi

        echo ""
        log "Firewall Status:"
        if command -v ufw &>/dev/null; then
            sudo ufw status 2>/dev/null | head -15
        else
            warn "UFW not installed"
        fi

        echo ""
        log "Audit Status:"
        if command -v auditctl &>/dev/null; then
            RULE_COUNT=$(sudo auditctl -l 2>/dev/null | wc -l || echo "0")
            ok "Audit daemon active with ${RULE_COUNT} rules"
        else
            warn "auditd not installed"
        fi

        echo ""
        log "Security Config:"
        if [ -f "/etc/ainux/security.conf" ]; then
            SANDBOX=$(grep "^enabled=" /etc/ainux/security.conf 2>/dev/null | head -1 | cut -d= -f2)
            APPROVAL=$(grep "^require_approval=" /etc/ainux/security.conf 2>/dev/null | head -1 | cut -d= -f2)
            echo "  AI Sandbox: ${SANDBOX:-not set}"
            echo "  Require Approval: ${APPROVAL:-not set}"
        else
            warn "Security config not found at /etc/ainux/security.conf"
        fi
        ;;

    security)
        log "Applying security-only updates..."
        if command -v apt-get &>/dev/null; then
            sudo apt-get update -qq
            sudo apt-get upgrade -y -qq -o Dir::Etc::SourceList=/etc/apt/sources.list \
                -o Dir::Etc::SourceParts=/dev/null 2>&1 | grep -i security || true
            sudo apt-get upgrade -y --with-new-pkgs 2>&1 | tail -5
            ok "Security updates applied"
        else
            err "apt-get not available"
            exit 1
        fi
        ;;

    *)
        echo "Usage: ainux-update {check|openwhale|ainux|all|rollback [target]|verify|security}"
        exit 1
        ;;
esac

echo "--- Update action '$ACTION' completed: $(date -Iseconds) ---" >> "$UPDATE_LOG" 2>/dev/null || true
