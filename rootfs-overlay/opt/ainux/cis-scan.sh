#!/bin/bash
#
# TensorAgent OS — CIS Benchmark Scanner
# /opt/ainux/cis-scan.sh
#
# Performs a CIS Benchmark-style scan of the system and reports compliance.
# Based on CIS Ubuntu Linux 24.04 LTS Benchmark v1.0.
#
# Usage:
#   cis-scan          — Run full scan
#   cis-scan --fix    — Run scan and auto-fix where possible
#   cis-scan --json   — Output results as JSON
#

set -uo pipefail

FIX_MODE=false
JSON_MODE=false
PASSED=0
FAILED=0
WARNINGS=0
RESULTS=""

for arg in "$@"; do
    case $arg in
        --fix) FIX_MODE=true ;;
        --json) JSON_MODE=true ;;
    esac
done

pass() { ((PASSED++)); [ "$JSON_MODE" = false ] && echo -e "\033[32m  PASS\033[0m $1"; RESULTS="${RESULTS}{\"id\":\"$2\",\"status\":\"pass\",\"desc\":\"$1\"},"; }
fail() { ((FAILED++)); [ "$JSON_MODE" = false ] && echo -e "\033[31m  FAIL\033[0m $1"; RESULTS="${RESULTS}{\"id\":\"$2\",\"status\":\"fail\",\"desc\":\"$1\"},"; }
warn() { ((WARNINGS++)); [ "$JSON_MODE" = false ] && echo -e "\033[33m  WARN\033[0m $1"; RESULTS="${RESULTS}{\"id\":\"$2\",\"status\":\"warn\",\"desc\":\"$1\"},"; }

[ "$JSON_MODE" = false ] && echo ""
[ "$JSON_MODE" = false ] && echo "  🐋 TensorAgent OS — CIS Benchmark Scanner"
[ "$JSON_MODE" = false ] && echo "  ══════════════════════════════════════════"
[ "$JSON_MODE" = false ] && echo ""

# ═══════════════════════════════════════════════════════════════════
# 1. FILESYSTEM CONFIGURATION
# ═══════════════════════════════════════════════════════════════════
[ "$JSON_MODE" = false ] && echo "▶ 1. Filesystem Configuration"

# 1.1.1 /tmp mount
if mount | grep -q " /tmp "; then
    pass "/tmp is a separate mount" "1.1.1"
else
    warn "/tmp is not a separate mount" "1.1.1"
fi

# 1.4.1 AIDE installed
if command -v aide &>/dev/null; then
    pass "AIDE is installed" "1.4.1"
else
    fail "AIDE is not installed" "1.4.1"
    [ "$FIX_MODE" = true ] && apt-get install -y aide &>/dev/null && pass "AIDE installed (fixed)" "1.4.1"
fi

# ═══════════════════════════════════════════════════════════════════
# 2. SERVICES
# ═══════════════════════════════════════════════════════════════════
[ "$JSON_MODE" = false ] && echo ""
[ "$JSON_MODE" = false ] && echo "▶ 2. Services"

# 2.1 AppArmor
if systemctl is-active --quiet apparmor 2>/dev/null; then
    pass "AppArmor is active" "2.1.1"
else
    fail "AppArmor is not active" "2.1.1"
    [ "$FIX_MODE" = true ] && systemctl enable --now apparmor &>/dev/null
fi

# Check AppArmor profiles loaded
PROFILES=$(aa-status 2>/dev/null | grep "profiles are loaded" | awk '{print $1}' || echo "0")
if [ "$PROFILES" -gt 0 ] 2>/dev/null; then
    pass "AppArmor: ${PROFILES} profiles loaded" "2.1.2"
else
    warn "No AppArmor profiles loaded" "2.1.2"
fi

# ═══════════════════════════════════════════════════════════════════
# 3. NETWORK CONFIGURATION
# ═══════════════════════════════════════════════════════════════════
[ "$JSON_MODE" = false ] && echo ""
[ "$JSON_MODE" = false ] && echo "▶ 3. Network Configuration"

# 3.4 Firewall
if ufw status 2>/dev/null | grep -q "Status: active"; then
    pass "UFW firewall is active" "3.4.1"
else
    fail "UFW firewall is not active" "3.4.1"
    [ "$FIX_MODE" = true ] && ufw --force enable &>/dev/null
fi

# Default deny incoming
if ufw status verbose 2>/dev/null | grep -q "deny (incoming)"; then
    pass "UFW default deny incoming" "3.4.2"
else
    fail "UFW does not default deny incoming" "3.4.2"
    [ "$FIX_MODE" = true ] && ufw default deny incoming &>/dev/null
fi

# ═══════════════════════════════════════════════════════════════════
# 4. LOGGING AND AUDITING
# ═══════════════════════════════════════════════════════════════════
[ "$JSON_MODE" = false ] && echo ""
[ "$JSON_MODE" = false ] && echo "▶ 4. Logging and Auditing"

# 4.1 auditd
if systemctl is-active --quiet auditd 2>/dev/null; then
    pass "auditd is running" "4.1.1"
else
    fail "auditd is not running" "4.1.1"
    [ "$FIX_MODE" = true ] && systemctl enable --now auditd &>/dev/null
fi

# Audit rules count
RULES=$(auditctl -l 2>/dev/null | wc -l || echo "0")
if [ "$RULES" -gt 10 ]; then
    pass "Audit rules loaded: ${RULES}" "4.1.2"
else
    warn "Only ${RULES} audit rules loaded" "4.1.2"
fi

# ═══════════════════════════════════════════════════════════════════
# 5. ACCESS, AUTHENTICATION, AUTHORIZATION
# ═══════════════════════════════════════════════════════════════════
[ "$JSON_MODE" = false ] && echo ""
[ "$JSON_MODE" = false ] && echo "▶ 5. Access, Authentication, Authorization"

# 5.1 SSH
if grep -q "PermitRootLogin no" /etc/ssh/sshd_config.d/*.conf 2>/dev/null || \
   grep -q "PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null; then
    pass "SSH root login disabled" "5.1.1"
else
    fail "SSH root login not explicitly disabled" "5.1.1"
fi

if grep -q "MaxAuthTries" /etc/ssh/sshd_config.d/*.conf 2>/dev/null; then
    pass "SSH MaxAuthTries configured" "5.1.2"
else
    warn "SSH MaxAuthTries not configured" "5.1.2"
fi

# 5.2 Password policy
if [ -f /etc/security/pwquality.conf ]; then
    if grep -q "minlen" /etc/security/pwquality.conf 2>/dev/null; then
        pass "Password quality requirements set" "5.2.1"
    else
        warn "Password quality not configured" "5.2.1"
    fi
else
    fail "pwquality.conf not found" "5.2.1"
fi

# 5.3 No empty passwords
EMPTY_PASS=$(awk -F: '($2 == "" ) { print $1 }' /etc/shadow 2>/dev/null | wc -l || echo "0")
if [ "$EMPTY_PASS" -eq 0 ]; then
    pass "No accounts with empty passwords" "5.3.1"
else
    fail "${EMPTY_PASS} accounts with empty passwords" "5.3.1"
fi

# 5.4 Root account locked
if passwd -S root 2>/dev/null | grep -q "L"; then
    pass "Root account is locked" "5.4.1"
else
    warn "Root account is not locked" "5.4.1"
fi

# ═══════════════════════════════════════════════════════════════════
# 6. SYSTEM MAINTENANCE
# ═══════════════════════════════════════════════════════════════════
[ "$JSON_MODE" = false ] && echo ""
[ "$JSON_MODE" = false ] && echo "▶ 6. System Maintenance"

# 6.1 SUID files
SUID_COUNT=$(find / -perm -4000 -type f 2>/dev/null | wc -l || echo "0")
if [ "$SUID_COUNT" -lt 30 ]; then
    pass "SUID binaries: ${SUID_COUNT} (acceptable)" "6.1.1"
else
    warn "SUID binaries: ${SUID_COUNT} (review recommended)" "6.1.1"
fi

# 6.2 No world-writable files in /etc
WW_ETC=$(find /etc -perm -0002 -type f 2>/dev/null | wc -l || echo "0")
if [ "$WW_ETC" -eq 0 ]; then
    pass "No world-writable files in /etc" "6.2.1"
else
    fail "${WW_ETC} world-writable files in /etc" "6.2.1"
fi

# ═══════════════════════════════════════════════════════════════════
# 7. TENSORAGENT-SPECIFIC
# ═══════════════════════════════════════════════════════════════════
[ "$JSON_MODE" = false ] && echo ""
[ "$JSON_MODE" = false ] && echo "▶ 7. TensorAgent OS Specific"

# 7.1 AI sandbox
if grep -q "enabled=true" /etc/ainux/security.conf 2>/dev/null; then
    pass "AI sandbox is enabled" "7.1.1"
else
    fail "AI sandbox is disabled" "7.1.1"
fi

# 7.2 Command policy
if [ -f /etc/ainux/command-policy.conf ]; then
    DENY_COUNT=$(grep -c "^DENY" /etc/ainux/command-policy.conf 2>/dev/null || echo "0")
    pass "Command policy: ${DENY_COUNT} deny rules" "7.2.1"
else
    fail "No command policy configured" "7.2.1"
fi

# 7.3 Service hardening scores
for SVC in openwhale ainux-kernel ollama; do
    if [ -f "/etc/systemd/system/${SVC}.service" ]; then
        if grep -q "NoNewPrivileges=true" "/etc/systemd/system/${SVC}.service" 2>/dev/null; then
            pass "${SVC}: NoNewPrivileges=true" "7.3.${SVC}"
        else
            fail "${SVC}: NoNewPrivileges is not true" "7.3.${SVC}"
        fi
    fi
done

# 7.4 Fail2ban
if systemctl is-active --quiet fail2ban 2>/dev/null; then
    pass "fail2ban is active" "7.4.1"
else
    fail "fail2ban is not active" "7.4.1"
fi

# 7.5 Ollama binding
if grep -q "OLLAMA_HOST=127.0.0.1" /etc/systemd/system/ollama.service 2>/dev/null; then
    pass "Ollama bound to localhost" "7.5.1"
else
    fail "Ollama not bound to localhost (exposed to network!)" "7.5.1"
fi

# ═══════════════════════════════════════════════════════════════════
# RESULTS
# ═══════════════════════════════════════════════════════════════════
TOTAL=$((PASSED + FAILED + WARNINGS))

if [ "$JSON_MODE" = true ]; then
    echo "{\"scan_time\":\"$(date -Iseconds)\",\"passed\":${PASSED},\"failed\":${FAILED},\"warnings\":${WARNINGS},\"total\":${TOTAL},\"results\":[${RESULTS%,}]}"
else
    echo ""
    echo "  ══════════════════════════════════════════"
    echo "  Results: ${PASSED} passed / ${FAILED} failed / ${WARNINGS} warnings"
    echo "  Score:   ${PASSED}/${TOTAL} ($(( PASSED * 100 / TOTAL ))%)"
    echo "  ══════════════════════════════════════════"
    echo ""
    if [ "$FAILED" -gt 0 ]; then
        echo "  Run with --fix to auto-remediate failures"
    fi
fi

exit $FAILED
