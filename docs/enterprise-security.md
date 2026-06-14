# TensorAgent OS — Enterprise Security Guide

## Overview

TensorAgent OS implements a defense-in-depth security model designed for enterprise
deployment. This document covers the security architecture, configuration, and
compliance posture.

## Security Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    TensorAgent OS                            │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Application Layer                                    │   │
│  │  ┌────────────┐  ┌──────────────┐  ┌─────────────┐  │   │
│  │  │ OpenWhale  │  │  WhaleOS     │  │  Ollama     │  │   │
│  │  │ (AI Agent) │  │  (GUI Shell) │  │  (LLM)      │  │   │
│  │  └──────┬─────┘  └──────┬───────┘  └──────┬──────┘  │   │
│  │         │               │                  │          │   │
│  │  ┌──────┴───────────────┴──────────────────┴──────┐  │   │
│  │  │            AppArmor Profiles (MAC)              │  │   │
│  │  └────────────────────┬────────────────────────────┘  │   │
│  └───────────────────────┼───────────────────────────────┘   │
│                          │                                    │
│  ┌───────────────────────┼───────────────────────────────┐   │
│  │  OS Security Layer    │                                │   │
│  │  ┌─────────┐  ┌──────┴──────┐  ┌──────────────────┐  │   │
│  │  │  UFW    │  │  systemd    │  │  auditd          │  │   │
│  │  │Firewall │  │  Hardening  │  │  (Audit Trail)   │  │   │
│  │  └─────────┘  └─────────────┘  └──────────────────┘  │   │
│  └───────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌───────────────────────────────────────────────────────┐   │
│  │  Kernel: Linux 6.1+ LTS                               │   │
│  │  Namespaces │ Cgroups │ Capabilities │ Seccomp         │   │
│  └───────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## 1. First Boot Security

On first boot, TensorAgent OS launches an interactive setup wizard that:

1. **Creates a unique admin account** — no default passwords ship in production
2. **Enforces password complexity** — minimum 8 characters
3. **Configures sudo policy** — password-required by default
4. **Hardens SSH** — key-only auth option, root login disabled, rate limiting
5. **Locks the root account** — prevents direct root login
6. **Sets a security banner** — compliant with NIST/DoD requirements

### Configuration
The first-boot wizard lives at `/opt/ainux/first-boot-setup.sh` and is triggered
by `ainux-first-boot.service`. It runs once and disables itself.

## 2. Mandatory Access Control (AppArmor)

Three AppArmor profiles ship in complain mode:

| Profile | Protects | Key Restrictions |
|---------|----------|------------------|
| `opt.ainux.openwhale` | AI Agent | No access to `/etc/shadow`, SSH keys, boot |
| `opt.ainux.whaleos` | Desktop Shell | Limited to DRM/GPU, fonts, user cache |
| `usr.local.bin.ollama` | LLM Runtime | Model storage only, no system write |

### Switch to Enforce Mode (Production)
```bash
# After verifying no false positives in complain mode:
sudo aa-enforce /etc/apparmor.d/opt.ainux.openwhale
sudo aa-enforce /etc/apparmor.d/opt.ainux.whaleos
sudo aa-enforce /etc/apparmor.d/usr.local.bin.ollama
```

### Monitor Profile Violations
```bash
sudo aa-status
sudo journalctl -k | grep "apparmor="
```

## 3. Systemd Service Hardening

All TensorAgent OS services run with enterprise security directives:

| Directive | Value | Purpose |
|-----------|-------|---------|
| `NoNewPrivileges` | `true` | Prevent privilege escalation via execve() |
| `ProtectSystem` | `strict` | Mount /usr, /boot, /etc as read-only |
| `PrivateTmp` | `true` | Isolate temp files per service |
| `ProtectKernelTunables` | `true` | Block /proc/sys writes |
| `ProtectKernelModules` | `true` | Prevent module loading |
| `ProtectKernelLogs` | `true` | Block kernel log access |
| `ProtectClock` | `true` | Prevent clock manipulation |
| `SystemCallArchitectures` | `native` | Block 32-bit syscall compat |
| `CapabilityBoundingSet` | minimal | Drop all unnecessary capabilities |
| `RestrictNamespaces` | `true` | Prevent namespace creation |
| `PrivateDevices` | `true` | No raw device access |
| `LockPersonality` | `true` | Lock execution domain |

### Verify Service Security
```bash
systemd-analyze security openwhale.service
systemd-analyze security ainux-kernel.service
systemd-analyze security ollama.service
```

## 4. Firewall (UFW)

Default policy: **deny all incoming, allow all outgoing**.

| Port | Service | Access |
|------|---------|--------|
| 22 | SSH | Rate-limited (6/30s) |
| 7777 | OpenWhale Dashboard | Private networks only (10/172/192) |
| 11434 | Ollama API | localhost only |
| 9222 | Chrome CDP | **BLOCKED** (security critical) |

### Manage Rules
```bash
sudo ufw status verbose
sudo ufw allow from 10.0.0.0/8 to any port 7777  # Add network
sudo ufw delete allow 7777                         # Remove rule
```

## 5. Audit Trail (auditd)

Enterprise audit rules monitor:

- **Authentication**: Login attempts, PAM changes, credential modifications
- **Identity**: User/group database changes, sudoers modifications
- **AI Agent**: Tool calls, extension installs, workspace modifications
- **Privilege Escalation**: sudo/su usage, setuid changes
- **System Integrity**: Binary modifications, kernel module loading
- **Security Tools**: Firewall and AppArmor configuration changes

### Review Audit Logs
```bash
sudo ausearch -k auth_log --start today       # Auth events
sudo ausearch -k ai_agent --start today       # AI agent activity
sudo ausearch -k privilege_escalation          # Sudo usage
sudo aureport --auth                          # Auth summary
sudo aureport --summary                       # Full summary
```

## 6. AI Agent Security

### Sandbox Mode (Default: ON)
Configuration: `/etc/ainux/security.conf`

- **Workspace Restriction**: Agent can only modify files in `/home/ainux/Works`
- **Human-in-the-Loop**: Destructive operations require dashboard approval
- **Loop Limits**: Max 15 iterations to prevent runaway agents
- **Tool Auditing**: All tool calls logged to audit trail

### Command Filtering
OpenWhale implements two layers of command filtering:
1. **Static Pattern Matching**: Blocks `rm -rf /`, `sudo`, `curl | bash`, etc.
2. **Path-Aware Sandboxing**: Restricts filesystem operations to workspace

### Anti-Hallucination
System prompt includes:
- Mandatory tool call verification (no "I did it" without actual execution)
- Structured output format enforcement
- Context window management to prevent saturation

## 7. Network Security

- **Ollama**: Binds to `127.0.0.1` only (not `0.0.0.0`)
- **SSH**: Root login disabled, rate-limited, optional key-only auth
- **CDP**: Firewall-blocked (allows arbitrary browser code execution)
- **Dashboard**: Private network access by default

## 8. Enterprise Identity Integration

TensorAgent OS supports centralized identity via SSSD:

- **Active Directory**: Full AD join via `realm`
- **LDAP**: Direct LDAP(S) integration
- **Kerberos**: SSO via GSSAPI
- **Group-based Access**: Restrict login to specific AD/LDAP groups

Template: `/etc/sssd/sssd.conf.example`

### Quick AD Join
```bash
sudo apt install sssd realmd adcli
sudo realm join your-domain.com
sudo systemctl enable sssd
```

## 9. Compliance Status

| Framework | Status | Notes |
|-----------|--------|-------|
| CIS Benchmark | Partial | Audit rules, service hardening, firewall |
| FIPS 140-3 | Not Yet | Requires validated crypto modules |
| SOC 2 Type II | Foundation | Audit trail, access control, logging |
| FedRAMP | Not Yet | Requires full NIST 800-53 implementation |

## 10. Security Checklist for Deployment

- [ ] Complete first-boot wizard (change default credentials)
- [ ] Switch AppArmor profiles to enforce mode
- [ ] Review and customize firewall rules for your network
- [ ] Configure SSSD for your identity provider (AD/LDAP)
- [ ] Set up remote syslog forwarding (in security.conf)
- [ ] Enable audit log immutability (uncomment `-e 2` in audit rules)
- [ ] Generate and install SSH host keys
- [ ] Configure TLS certificates for dashboard
- [ ] Review AI agent workspace restrictions
- [ ] Test human-in-the-loop approval flow
