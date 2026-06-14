#!/bin/bash
#
# TensorAgent OS — TLS Certificate Generator
#
# Generates self-signed TLS certificates for the OpenWhale dashboard.
# For production, replace with certificates from your enterprise CA
# or use Let's Encrypt via certbot.
#
# Usage:
#   /opt/ainux/generate-tls.sh              — Generate self-signed cert
#   /opt/ainux/generate-tls.sh --letsencrypt — Use Let's Encrypt (requires public DNS)
#

set -euo pipefail

CERT_DIR="/etc/ainux/tls"
CERT_FILE="${CERT_DIR}/server.crt"
KEY_FILE="${CERT_DIR}/server.key"
CA_FILE="${CERT_DIR}/ca.crt"
DAYS=365
HOSTNAME=$(hostname -f 2>/dev/null || hostname)

log() { echo -e "\033[36m[tls]\033[0m $1"; }
ok()  { echo -e "\033[32m  ✓\033[0m $1"; }
err() { echo -e "\033[31m  ✗\033[0m $1"; }

mkdir -p "$CERT_DIR"
chmod 750 "$CERT_DIR"

MODE="${1:-self-signed}"

case "$MODE" in
    --letsencrypt)
        log "Requesting Let's Encrypt certificate..."
        if ! command -v certbot &>/dev/null; then
            err "certbot not installed. Run: sudo apt install certbot"
            exit 1
        fi

        read -p "  Domain name: " DOMAIN
        certbot certonly --standalone \
            --non-interactive \
            --agree-tos \
            --email "admin@${DOMAIN}" \
            -d "$DOMAIN"

        # Symlink to standard location
        ln -sf "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" "$CERT_FILE"
        ln -sf "/etc/letsencrypt/live/${DOMAIN}/privkey.pem" "$KEY_FILE"
        ok "Let's Encrypt certificate installed for ${DOMAIN}"
        ;;

    *)
        log "Generating self-signed TLS certificate..."
        log "  Hostname: ${HOSTNAME}"
        log "  Validity: ${DAYS} days"

        # Generate CA key and cert
        openssl genrsa -out "${CERT_DIR}/ca.key" 4096 2>/dev/null
        openssl req -new -x509 -days $DAYS \
            -key "${CERT_DIR}/ca.key" \
            -out "$CA_FILE" \
            -subj "/C=US/ST=Enterprise/L=TensorAgent/O=TensorAgent OS/OU=Security/CN=TensorAgent CA" \
            2>/dev/null

        # Generate server key
        openssl genrsa -out "$KEY_FILE" 2048 2>/dev/null

        # Generate CSR with SANs
        cat > "${CERT_DIR}/server.cnf" << CNFEOF
[req]
default_bits = 2048
prompt = no
distinguished_name = dn
req_extensions = v3_req

[dn]
C = US
ST = Enterprise
L = TensorAgent
O = TensorAgent OS
OU = AI Platform
CN = ${HOSTNAME}

[v3_req]
subjectAltName = @alt_names
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth

[alt_names]
DNS.1 = ${HOSTNAME}
DNS.2 = localhost
DNS.3 = tensoragent
DNS.4 = tensoragent.local
IP.1 = 127.0.0.1
IP.2 = ::1
CNFEOF

        openssl req -new \
            -key "$KEY_FILE" \
            -out "${CERT_DIR}/server.csr" \
            -config "${CERT_DIR}/server.cnf" \
            2>/dev/null

        # Sign with CA
        openssl x509 -req -days $DAYS \
            -in "${CERT_DIR}/server.csr" \
            -CA "$CA_FILE" \
            -CAkey "${CERT_DIR}/ca.key" \
            -CAcreateserial \
            -out "$CERT_FILE" \
            -extensions v3_req \
            -extfile "${CERT_DIR}/server.cnf" \
            2>/dev/null

        # Set permissions
        chmod 600 "$KEY_FILE" "${CERT_DIR}/ca.key"
        chmod 644 "$CERT_FILE" "$CA_FILE"
        chown root:root "$KEY_FILE" "${CERT_DIR}/ca.key"

        # Clean up
        rm -f "${CERT_DIR}/server.csr" "${CERT_DIR}/server.cnf" "${CERT_DIR}/ca.srl"

        ok "Self-signed TLS certificate generated"
        echo ""
        echo "  Certificate: ${CERT_FILE}"
        echo "  Private Key: ${KEY_FILE}"
        echo "  CA Cert:     ${CA_FILE}"
        echo ""
        echo "  To trust on clients, import ${CA_FILE}"
        echo ""
        echo "  OpenWhale will use these on next restart if TLS is configured in:"
        echo "  /etc/ainux/security.conf"
        ;;
esac

# Update security.conf with TLS paths
if [ -f "/etc/ainux/security.conf" ]; then
    if ! grep -q "tls_cert" /etc/ainux/security.conf 2>/dev/null; then
        cat >> /etc/ainux/security.conf << TLSCONF

[tls]
# TLS configuration for OpenWhale dashboard
enabled=true
cert_file=${CERT_FILE}
key_file=${KEY_FILE}
ca_file=${CA_FILE}
TLSCONF
        ok "TLS paths added to security.conf"
    fi
fi
