#!/bin/bash
#
# AInux OpenWhale Update Manager
# 
# Updates OpenWhale to the latest version from GitHub.
# Preserves configuration, database, memory, and skills.
#
# Usage:
#   ainux-update check          — Check for updates
#   ainux-update openwhale      — Update OpenWhale
#   ainux-update ainux           — Update AInux kernel
#   ainux-update all             — Update everything
#   ainux-update rollback        — Roll back to previous version
#

set -euo pipefail

OPENWHALE_DIR="${OPENWHALE_DIR:-/opt/ainux/openwhale}"
AINUX_HOME="${AINUX_HOME:-/opt/ainux}"
AINUX_DATA="${HOME}/.ainux"
BACKUP_DIR="${AINUX_DATA}/backups"

ACTION="${1:-check}"

log() { echo -e "\033[36m[ainux-update]\033[0m $1"; }
ok()  { echo -e "\033[32m  ✓\033[0m $1"; }
err() { echo -e "\033[31m  ✗\033[0m $1"; }

mkdir -p "$BACKUP_DIR"

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
        ;;

    openwhale)
        log "Updating OpenWhale..."
        
        if [ ! -d "${OPENWHALE_DIR}/.git" ]; then
            err "Not a git repo. Cloning fresh..."
            git clone https://github.com/viralcode/openwhale.git "${OPENWHALE_DIR}"
        fi
        
        cd "$OPENWHALE_DIR"
        
        # Backup current version
        CURRENT_SHA=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
        echo "$CURRENT_SHA" > "${BACKUP_DIR}/openwhale-pre-update-sha"
        log "Backed up current SHA: ${CURRENT_SHA}"
        
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
        log "Restart OpenWhale: sudo systemctl restart openwhale"
        ;;

    ainux)
        log "Updating AInux..."
        cd "$AINUX_HOME"
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
        fi
        
        ok "Rolled back ${TARGET} to ${ROLLBACK_SHA}"
        log "Restart the service to apply"
        ;;

    *)
        echo "Usage: ainux-update {check|openwhale|ainux|all|rollback [target]}"
        exit 1
        ;;
esac
