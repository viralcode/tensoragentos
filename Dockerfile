# TensorAgent OS — Docker / Cloud Container Image
# Dockerfile
#
# Builds a containerized version of TensorAgent OS (OpenWhale + Ollama)
# for cloud deployment on AWS, Azure, GCP, or any container platform.
#
# Usage:
#   docker build -t tensoragent-os .
#   docker run -p 7777:7777 -v tensoragent-data:/data tensoragent-os
#
# Cloud Marketplace:
#   docker tag tensoragent-os:latest ghcr.io/viralcode/tensoragent-os:latest
#   docker push ghcr.io/viralcode/tensoragent-os:latest
#

FROM ubuntu:24.04 AS base

LABEL org.opencontainers.image.title="TensorAgent OS"
LABEL org.opencontainers.image.description="AI-Native Operating System — Enterprise Container"
LABEL org.opencontainers.image.vendor="ViralCode"
LABEL org.opencontainers.image.source="https://github.com/viralcode/tensoragent-os"
LABEL org.opencontainers.image.licenses="BUSL-1.1"

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install minimal runtime dependencies
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        nodejs npm \
        python3 python3-pip \
        curl wget git \
        sqlite3 jq \
        ca-certificates \
        openssl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -s /bin/bash -u 1000 ainux && \
    mkdir -p /opt/ainux /data/workspace /data/openwhale /etc/ainux && \
    chown -R ainux:ainux /opt/ainux /data /etc/ainux

# Copy security configuration
COPY rootfs-overlay/etc/ainux/security.conf /etc/ainux/security.conf
COPY rootfs-overlay/etc/ainux/command-policy.conf /etc/ainux/command-policy.conf

# Copy OpenWhale application
COPY packages/openwhale /opt/ainux/openwhale

# Install OpenWhale dependencies
WORKDIR /opt/ainux/openwhale
RUN npm install --production 2>&1 | tail -5 && \
    npm cache clean --force && \
    chown -R ainux:ainux /opt/ainux/openwhale

# Environment
ENV NODE_ENV=production \
    PORT=7777 \
    AINUX_MODE=true \
    OPENWHALE_SANDBOX=true \
    OPENWHALE_REQUIRE_APPROVAL=true \
    HOME=/home/ainux

# Security: run as non-root
USER ainux

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:7777/api/health || exit 1

# Expose dashboard port
EXPOSE 7777

# Data volume
VOLUME ["/data"]

CMD ["node", "openwhale.mjs"]
