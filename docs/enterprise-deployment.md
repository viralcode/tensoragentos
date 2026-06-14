# TensorAgent OS — Enterprise Deployment Guide

## Overview

This guide covers deploying TensorAgent OS across an enterprise fleet, including
fleet management, centralized identity, OTA updates, and monitoring.

## 1. Deployment Options

| Method | Best For | Scale |
|--------|----------|-------|
| **UTM/QEMU VM** | Development, POC | 1-10 nodes |
| **VMware/Hyper-V** | Enterprise pilot | 10-100 nodes |
| **Bare Metal** | Production AI appliances | 10-1000+ nodes |
| **Cloud (AWS/Azure/GCP)** | Cloud-native deployment | Any scale |

### VMware Deployment
```bash
# Build VMware-compatible image
./scripts/build-vmware.sh

# Deploy via vCenter:
# 1. Import OVA template
# 2. Customize: 6GB RAM, 4 vCPUs, 64GB disk
# 3. Network: DHCP or static via cloud-init
```

### Bare Metal Deployment
```bash
# Build ISO
./scripts/build-iso.sh --arch=x86_64

# Flash to USB
sudo dd if=tensoragent-os-x86_64.iso of=/dev/sdX bs=4M status=progress

# Boot from USB and complete first-boot wizard
```

## 2. Fleet Management

### Option A: FleetDM (Recommended for Mixed OS)
FleetDM uses osquery to provide unified visibility across Linux, macOS, and Windows.

```bash
# Install osquery agent on TensorAgent OS
sudo apt install osquery

# Configure enrollment
cat > /etc/osquery/osquery.flags << EOF
--tls_hostname=fleet.yourcompany.com
--tls_server_certs=/etc/osquery/fleet-ca.pem
--host_identifier=hostname
--enroll_secret_path=/etc/osquery/enroll_secret
--config_plugin=tls
--config_tls_refresh=60
--logger_plugin=tls
--logger_tls_period=10
EOF

# Start
sudo systemctl enable osqueryd
sudo systemctl start osqueryd
```

### Option B: Ansible (Configuration Management)
```yaml
# ansible/playbooks/tensoragent-fleet.yml
---
- name: Configure TensorAgent OS Fleet
  hosts: tensoragent_nodes
  become: true
  tasks:
    - name: Ensure security packages
      apt:
        name:
          - apparmor
          - apparmor-utils
          - auditd
          - ufw
          - aide
          - fail2ban
        state: present

    - name: Deploy security config
      copy:
        src: files/security.conf
        dest: /etc/ainux/security.conf
        mode: '0644'

    - name: Enable AppArmor enforce mode
      shell: aa-enforce /etc/apparmor.d/opt.ainux.*

    - name: Configure firewall
      shell: /opt/ainux/configure-firewall.sh

    - name: Restart OpenWhale
      systemd:
        name: openwhale
        state: restarted

    - name: Verify services
      shell: systemctl is-active openwhale ainux-kernel ollama
      register: service_status
      failed_when: "'inactive' in service_status.stdout"
```

## 3. Centralized Identity

### Active Directory Integration
```bash
# Install packages
sudo apt install sssd sssd-tools sssd-ad realmd adcli krb5-user

# Discover and join domain
sudo realm discover your-domain.com
sudo realm join --user=admin your-domain.com

# Restrict login to specific AD group
sudo realm permit -g "TensorAgent-Users"

# Verify
id admin@your-domain.com
```

### LDAP Integration
```bash
# Copy and customize the template
sudo cp /etc/sssd/sssd.conf.example /etc/sssd/sssd.conf
sudo chmod 600 /etc/sssd/sssd.conf

# Edit for your LDAP server
sudo nano /etc/sssd/sssd.conf

# Restart
sudo systemctl enable sssd
sudo systemctl restart sssd
```

## 4. OTA Updates

### Current: ainux-update.sh
```bash
# Check for updates
ainux-update check

# Update OpenWhale
ainux-update openwhale

# Update everything
ainux-update all

# Rollback if something breaks
ainux-update rollback openwhale
```

### Enterprise: Signed Updates (Roadmap)
Future versions will support:
- GPG-signed update packages
- A/B partition scheme for atomic rollback
- Staged rollouts (canary → 10% → 50% → 100%)
- Air-gapped update via USB repository

## 5. Monitoring & Observability

### Log Aggregation
```bash
# Forward logs to remote syslog (ELK, Loki, Splunk)
# Edit /etc/ainux/security.conf:
# syslog_server=logserver.yourcompany.com
# syslog_port=514
# syslog_protocol=tcp

# Or use Fluentd/Vector for structured forwarding:
sudo apt install fluent-bit
cat > /etc/fluent-bit/fluent-bit.conf << EOF
[INPUT]
    Name              systemd
    Tag               tensoragent.*
    Systemd_Filter    _SYSTEMD_UNIT=openwhale.service
    Systemd_Filter    _SYSTEMD_UNIT=ainux-kernel.service
    Systemd_Filter    _SYSTEMD_UNIT=ollama.service

[OUTPUT]
    Name              forward
    Match             *
    Host              logserver.yourcompany.com
    Port              24224
EOF
```

### Health Monitoring
```bash
# OpenWhale API health check
curl -s http://localhost:7777/api/health | jq .

# Service status
systemctl status openwhale ainux-kernel ollama

# System resources
htop
```

### Prometheus Metrics (Roadmap)
Future versions will expose:
- `/metrics` endpoint on port 9090
- AI agent operation counts, latencies
- Tool call success/failure rates
- Model inference times
- System resource usage

## 6. Backup & Recovery

### Data to Back Up
| Path | Contents | Priority |
|------|----------|----------|
| `/home/ainux/.openwhale/` | AI memory, transcripts, config | Critical |
| `/home/ainux/.openwhale/openwhale.db` | All application state | Critical |
| `/home/ainux/Works/` | User workspace | High |
| `/etc/ainux/` | System configuration | High |
| `/etc/sssd/sssd.conf` | Identity config | Medium |
| `/etc/apparmor.d/opt.ainux.*` | Security profiles | Medium |

### Backup Script
```bash
#!/bin/bash
BACKUP_DIR="/backup/tensoragent-$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Critical data
cp -r /home/ainux/.openwhale "$BACKUP_DIR/"
cp -r /home/ainux/Works "$BACKUP_DIR/"
cp -r /etc/ainux "$BACKUP_DIR/"

# Compress
tar czf "${BACKUP_DIR}.tar.gz" "$BACKUP_DIR"
echo "Backup: ${BACKUP_DIR}.tar.gz"
```

## 7. Troubleshooting

### Services Not Starting
```bash
# Check service status and logs
sudo systemctl status openwhale
sudo journalctl -u openwhale -b --no-pager | tail -50

# Common fixes
sudo systemctl daemon-reload
sudo systemctl restart openwhale
```

### AppArmor Blocking Legitimate Operations
```bash
# Check for denials
sudo journalctl -k | grep "apparmor=.*DENIED"

# Temporarily switch to complain mode
sudo aa-complain /etc/apparmor.d/opt.ainux.openwhale

# Generate new rules from log
sudo aa-logprof
```

### Firewall Blocking Connections
```bash
# Check status
sudo ufw status verbose

# Temporarily disable (for debugging only!)
sudo ufw disable

# Add specific rule
sudo ufw allow from 10.0.0.0/8 to any port 7777
```
