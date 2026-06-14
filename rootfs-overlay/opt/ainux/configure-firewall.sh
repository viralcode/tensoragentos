#!/bin/bash
#
# TensorAgent OS — Firewall Configuration Script
# Run during first boot or ISO build to set up UFW defaults.
#
# Default policy: deny all incoming, allow all outgoing.
# Only explicitly needed ports are opened.
#

set -euo pipefail

# Check if UFW is installed
if ! command -v ufw &>/dev/null; then
    echo "[firewall] UFW not installed, skipping firewall setup"
    exit 0
fi

echo "[firewall] Configuring enterprise firewall rules..."

# Reset to defaults
ufw --force reset

# Default policies
ufw default deny incoming
ufw default allow outgoing
ufw default deny routed

# ─── Allow SSH (rate-limited) ─────────────────────────────────────
# Rate limiting: max 6 connections in 30 seconds from same IP
ufw limit ssh comment 'SSH (rate-limited)'

# ─── Allow OpenWhale Dashboard ────────────────────────────────────
# Only from local network by default. Uncomment the second line
# for public access (e.g., behind a reverse proxy).
ufw allow from 10.0.0.0/8 to any port 7777 proto tcp comment 'OpenWhale Dashboard (private)'
ufw allow from 172.16.0.0/12 to any port 7777 proto tcp comment 'OpenWhale Dashboard (private)'
ufw allow from 192.168.0.0/16 to any port 7777 proto tcp comment 'OpenWhale Dashboard (private)'
ufw allow from 127.0.0.0/8 to any port 7777 proto tcp comment 'OpenWhale Dashboard (localhost)'
# ufw allow 7777/tcp comment 'OpenWhale Dashboard (public — use reverse proxy!)'

# ─── Ollama API — localhost only ──────────────────────────────────
# Ollama should only be accessible from the local machine.
# The OpenWhale agent connects to it via localhost.
ufw allow from 127.0.0.1 to any port 11434 proto tcp comment 'Ollama API (localhost only)'

# ─── DENY Chromium CDP ────────────────────────────────────────────
# Chrome DevTools Protocol should NEVER be exposed externally.
# It allows arbitrary code execution in the browser.
ufw deny 9222 comment 'Block CDP (security critical)'

# ─── Enable logging ──────────────────────────────────────────────
ufw logging medium

# ─── Activate ─────────────────────────────────────────────────────
ufw --force enable

echo "[firewall] ✓ Firewall configured and enabled"
echo "[firewall] Rules:"
ufw status verbose
