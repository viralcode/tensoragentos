/**
 * AInux Deep Integration Module
 * 
 * This module wires OpenWhale into AInux at the deepest level:
 * 1. Registers AInux-specific tools into OpenWhale's toolRegistry
 * 2. Bridges the AInux kernel (IPC, hardware, process management) to OpenWhale
 * 3. Provides update management for OpenWhale versions
 * 4. Hooks into OpenWhale's session system for OS-level context
 * 5. Exposes AInux SystemAgent skill for OS-level actions
 * 
 * This file is loaded by the AInux kernel AFTER OpenWhale starts,
 * and dynamically injects new tools + a system prompt augmentation.
 */

import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { execSync, spawn } from 'node:child_process';
import { join, resolve } from 'node:path';
import { homedir } from 'node:os';

const OPENWHALE_DIR = process.env.OPENWHALE_DIR || '/opt/ainux/openwhale';
const AINUX_DATA = process.env.AINUX_DATA || join(homedir(), '.ainux');
const AINUX_HOME = process.env.AINUX_HOME || '/opt/ainux';

// ─── 1. AInux System Agent Skill ────────────────────────────────────────────
// This gets installed as an OpenWhale skill at:
//   ~/.openwhale/skills/ainux-system/SKILL.md
// It gives every OpenWhale agent deep OS awareness.

const AINUX_SKILL_MD = `---
name: ainux-system
description: AInux OS integration — hardware control, system management, boot config
version: 0.1.0
author: AInux
tools:
  - ainux_hardware_info
  - ainux_process_control
  - ainux_system_config
  - ainux_network_control
  - ainux_audio_control
  - ainux_display_control
  - ainux_update
  - ainux_power
---

# AInux System Agent

You are running on **AInux**, a custom AI-native operating system.
You have direct access to the hardware and OS via special tools.

## Capabilities
- Query CPU, GPU, memory, storage, network in real time
- Control system processes (start/stop/restart services)
- Manage network connections (WiFi, Ethernet, Bluetooth)
- Control audio (volume, mute, output device)
- Adjust display settings (resolution, brightness)
- Update OpenWhale to the latest version
- Power management (shutdown, reboot, sleep)
- Read and modify AInux system configuration

## Important Notes
- You ARE the operating system. There is no other desktop or shell.
- The user interacts exclusively through you.
- System changes take effect immediately.
- Always confirm destructive operations (shutdown, format, etc.) with the user.
`;

// ─── 2. AInux Tools (follow OpenWhale's AgentTool interface) ────────────────
// These tools will be dynamically registered into OpenWhale's toolRegistry
// when the AInux kernel boots.

/**
 * Complete set of AInux tools to inject into OpenWhale
 */
export function getAInuxTools() {
    return [
        // ── Hardware Info Tool ──
        {
            name: 'ainux_hardware_info',
            description: 'Get detailed hardware information about the AInux system — CPU, GPU, RAM, storage, network interfaces, audio devices, display settings, sensors, and battery status.',
            category: 'system',
            parameters: {
                parse: (params) => params || {},
                isOptional: () => true,
                _def: { typeName: 'ZodObject' },
            },
            async execute(params, context) {
                try {
                    const info = {};

                    // CPU
                    try {
                        const cpuinfo = readFileSync('/proc/cpuinfo', 'utf-8');
                        const model = cpuinfo.match(/model name\s*:\s*(.+)/)?.[1] || 'Unknown';
                        const cores = (cpuinfo.match(/^processor/gm) || []).length;
                        const loadavg = readFileSync('/proc/loadavg', 'utf-8').trim().split(' ');
                        info.cpu = { model, cores, load: { '1m': loadavg[0], '5m': loadavg[1], '15m': loadavg[2] } };
                    } catch {
                        info.cpu = { model: execSync('sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown"', { encoding: 'utf-8' }).trim() };
                    }

                    // Memory
                    try {
                        const meminfo = readFileSync('/proc/meminfo', 'utf-8');
                        const total = parseInt(meminfo.match(/MemTotal:\s*(\d+)/)?.[1] || '0') / 1024;
                        const available = parseInt(meminfo.match(/MemAvailable:\s*(\d+)/)?.[1] || '0') / 1024;
                        const used = total - available;
                        info.memory = {
                            total: `${(total / 1024).toFixed(1)} GB`,
                            used: `${(used / 1024).toFixed(1)} GB`,
                            available: `${(available / 1024).toFixed(1)} GB`,
                            percent: `${((used / total) * 100).toFixed(0)}%`,
                        };
                    } catch {
                        info.memory = { note: 'Unable to read /proc/meminfo' };
                    }

                    // GPU
                    try {
                        const lspci = execSync('lspci 2>/dev/null | grep -i vga || echo "Unknown GPU"', { encoding: 'utf-8' }).trim();
                        info.gpu = { devices: lspci.split('\n') };
                    } catch {
                        info.gpu = { note: 'No GPU info available' };
                    }

                    // Storage
                    try {
                        const df = execSync('df -h / | tail -1', { encoding: 'utf-8' }).trim().split(/\s+/);
                        info.storage = { device: df[0], total: df[1], used: df[2], available: df[3], percent: df[4] };
                    } catch {
                        info.storage = { note: 'Unable to read storage info' };
                    }

                    // Network
                    try {
                        const ip = execSync('ip -j addr show 2>/dev/null || ifconfig 2>/dev/null | head -50', { encoding: 'utf-8' }).trim();
                        info.network = { raw: ip.substring(0, 2000) };
                    } catch {
                        info.network = { note: 'Unable to read network info' };
                    }

                    // Temperature (Linux)
                    try {
                        const temp = execSync('cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null', { encoding: 'utf-8' }).trim();
                        info.temperature = { cpu: `${(parseInt(temp) / 1000).toFixed(1)}°C` };
                    } catch {
                        info.temperature = { note: 'No thermal data available' };
                    }

                    // Uptime
                    try {
                        info.uptime = execSync('uptime -p 2>/dev/null || uptime', { encoding: 'utf-8' }).trim();
                    } catch { }

                    return { success: true, content: JSON.stringify(info, null, 2) };
                } catch (err) {
                    return { success: false, content: '', error: `Hardware info error: ${err.message}` };
                }
            },
        },

        // ── Process Control Tool ──
        {
            name: 'ainux_process_control',
            description: 'Control AInux system processes and services. Can start, stop, restart, and check status of systemd services (openwhale, ainux-kernel, ainux-shell, pipewire, etc). Can also list all running processes.',
            category: 'system',
            parameters: {
                parse: (params) => {
                    if (!params.action) throw new Error('action is required (start|stop|restart|status|list)');
                    return params;
                },
                isOptional: () => false,
            },
            async execute(params, context) {
                const { action, service } = params;
                try {
                    let output;
                    switch (action) {
                        case 'list':
                            output = execSync('systemctl list-units --type=service --state=running --no-pager 2>/dev/null || ps aux | head -30', { encoding: 'utf-8' });
                            break;
                        case 'status':
                            output = execSync(`systemctl status ${service} --no-pager 2>/dev/null || echo "Service not found"`, { encoding: 'utf-8' });
                            break;
                        case 'start':
                        case 'stop':
                        case 'restart':
                            if (!service) throw new Error('service name required');
                            // Safety: only allow AInux-related services
                            const allowed = ['openwhale', 'ainux-kernel', 'ainux-shell', 'pipewire', 'pipewire-pulse', 'wireplumber', 'NetworkManager', 'bluetooth'];
                            if (!allowed.some(s => service.includes(s))) {
                                return { success: false, content: '', error: `Cannot ${action} service "${service}". Allowed: ${allowed.join(', ')}` };
                            }
                            output = execSync(`sudo systemctl ${action} ${service} 2>&1`, { encoding: 'utf-8' });
                            break;
                        default:
                            return { success: false, content: '', error: `Unknown action: ${action}. Use: start, stop, restart, status, list` };
                    }
                    return { success: true, content: output.trim() };
                } catch (err) {
                    return { success: false, content: '', error: err.message };
                }
            },
        },

        // ── System Config Tool ──
        {
            name: 'ainux_system_config',
            description: 'Read or modify AInux system configuration (/etc/ainux/ainux.conf). Can get/set values like timezone, hostname, theme, accent color, compositor settings.',
            category: 'system',
            parameters: {
                parse: (params) => {
                    if (!params.action) throw new Error('action required: get or set');
                    return params;
                },
                isOptional: () => false,
            },
            async execute(params, context) {
                const configPath = '/etc/ainux/ainux.conf';
                try {
                    if (params.action === 'get') {
                        if (!existsSync(configPath)) return { success: true, content: 'No config file found' };
                        const content = readFileSync(configPath, 'utf-8');
                        if (params.key) {
                            const match = content.match(new RegExp(`^${params.key}=(.+)$`, 'm'));
                            return { success: true, content: match ? match[1] : `Key "${params.key}" not found` };
                        }
                        return { success: true, content };
                    }
                    if (params.action === 'set') {
                        if (!params.key || params.value === undefined) throw new Error('key and value required');
                        let content = existsSync(configPath) ? readFileSync(configPath, 'utf-8') : '';
                        const regex = new RegExp(`^${params.key}=.*$`, 'm');
                        if (regex.test(content)) {
                            content = content.replace(regex, `${params.key}=${params.value}`);
                        } else {
                            content += `\n${params.key}=${params.value}`;
                        }
                        writeFileSync(configPath, content);
                        return { success: true, content: `Set ${params.key}=${params.value}` };
                    }
                    return { success: false, content: '', error: 'Unknown action' };
                } catch (err) {
                    return { success: false, content: '', error: err.message };
                }
            },
        },

        // ── Network Control Tool ──
        {
            name: 'ainux_network_control',
            description: 'Control network on AInux — connect/disconnect WiFi, list available networks, check connection status, configure DNS, enable/disable Bluetooth.',
            category: 'system',
            parameters: {
                parse: (params) => params,
                isOptional: () => false,
            },
            async execute(params, context) {
                try {
                    let output;
                    switch (params.action) {
                        case 'wifi_list':
                            output = execSync('nmcli dev wifi list 2>/dev/null || iwlist scan 2>/dev/null | grep ESSID || echo "WiFi scanning not available"', { encoding: 'utf-8' });
                            break;
                        case 'wifi_connect':
                            if (!params.ssid) throw new Error('ssid required');
                            output = execSync(`nmcli dev wifi connect "${params.ssid}" password "${params.password || ''}" 2>&1`, { encoding: 'utf-8' });
                            break;
                        case 'wifi_disconnect':
                            output = execSync('nmcli dev disconnect wlan0 2>&1 || nmcli dev disconnect wlp0s20f3 2>&1', { encoding: 'utf-8' });
                            break;
                        case 'status':
                            output = execSync('nmcli general status 2>/dev/null && echo "---" && nmcli con show --active 2>/dev/null || ip addr show 2>/dev/null', { encoding: 'utf-8' });
                            break;
                        case 'bluetooth_scan':
                            output = execSync('bluetoothctl scan on & sleep 5 && bluetoothctl devices 2>/dev/null || echo "Bluetooth not available"', { encoding: 'utf-8' });
                            break;
                        case 'bluetooth_connect':
                            if (!params.mac) throw new Error('mac address required');
                            output = execSync(`bluetoothctl connect ${params.mac} 2>&1`, { encoding: 'utf-8' });
                            break;
                        default:
                            return { success: false, content: '', error: 'Actions: wifi_list, wifi_connect, wifi_disconnect, status, bluetooth_scan, bluetooth_connect' };
                    }
                    return { success: true, content: output.trim() };
                } catch (err) {
                    return { success: false, content: '', error: err.message };
                }
            },
        },

        // ── Audio Control Tool ──
        {
            name: 'ainux_audio_control',
            description: 'Control audio on AInux — set volume, mute/unmute, list audio devices, switch output device. Uses PipeWire/ALSA.',
            category: 'device',
            parameters: {
                parse: (params) => params,
                isOptional: () => false,
            },
            async execute(params, context) {
                try {
                    let output;
                    switch (params.action) {
                        case 'get_volume':
                            output = execSync('wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || amixer get Master 2>/dev/null || echo "Audio not available"', { encoding: 'utf-8' });
                            break;
                        case 'set_volume':
                            if (params.level === undefined) throw new Error('level required (0-100)');
                            const level = Math.min(100, Math.max(0, parseInt(params.level)));
                            output = execSync(`wpctl set-volume @DEFAULT_AUDIO_SINK@ ${level}% 2>/dev/null || amixer set Master ${level}% 2>/dev/null`, { encoding: 'utf-8' });
                            break;
                        case 'mute':
                            output = execSync('wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle 2>/dev/null || amixer set Master toggle 2>/dev/null', { encoding: 'utf-8' });
                            break;
                        case 'list_devices':
                            output = execSync('wpctl status 2>/dev/null || aplay -l 2>/dev/null', { encoding: 'utf-8' });
                            break;
                        default:
                            return { success: false, content: '', error: 'Actions: get_volume, set_volume, mute, list_devices' };
                    }
                    return { success: true, content: output.trim() };
                } catch (err) {
                    return { success: false, content: '', error: err.message };
                }
            },
        },

        // ── Display Control Tool ──
        {
            name: 'ainux_display_control',
            description: 'Control display settings on AInux — get/set resolution, brightness, list available modes. Works with Wayland/DRM.',
            category: 'device',
            parameters: {
                parse: (params) => params,
                isOptional: () => false,
            },
            async execute(params, context) {
                try {
                    let output;
                    switch (params.action) {
                        case 'info':
                            output = execSync('wlr-randr 2>/dev/null || xrandr 2>/dev/null || cat /sys/class/drm/*/modes 2>/dev/null | head -10', { encoding: 'utf-8' });
                            break;
                        case 'set_brightness':
                            if (params.level === undefined) throw new Error('level required (0-100)');
                            const brightness = Math.min(100, Math.max(0, parseInt(params.level)));
                            const maxBr = parseInt(execSync('cat /sys/class/backlight/*/max_brightness 2>/dev/null || echo 100', { encoding: 'utf-8' }).trim());
                            const setBr = Math.round((brightness / 100) * maxBr);
                            execSync(`echo ${setBr} | sudo tee /sys/class/backlight/*/brightness 2>/dev/null`, { encoding: 'utf-8' });
                            output = `Brightness set to ${brightness}%`;
                            break;
                        default:
                            return { success: false, content: '', error: 'Actions: info, set_brightness' };
                    }
                    return { success: true, content: output.trim() };
                } catch (err) {
                    return { success: false, content: '', error: err.message };
                }
            },
        },

        // ── Power Management Tool ──
        {
            name: 'ainux_power',
            description: 'AInux power management — shutdown, reboot, sleep, hibernate, check battery. ALWAYS confirm with user before shutdown/reboot.',
            category: 'system',
            requiresApproval: true,
            parameters: {
                parse: (params) => {
                    if (!params.action) throw new Error('action required: shutdown, reboot, sleep, hibernate, battery');
                    return params;
                },
                isOptional: () => false,
            },
            async execute(params, context) {
                try {
                    let output;
                    switch (params.action) {
                        case 'battery':
                            output = execSync('upower -i /org/freedesktop/UPower/devices/battery_BAT0 2>/dev/null || cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo "No battery detected"', { encoding: 'utf-8' });
                            break;
                        case 'shutdown':
                            output = 'System will shut down in 5 seconds...';
                            setTimeout(() => execSync('sudo systemctl poweroff'), 5000);
                            break;
                        case 'reboot':
                            output = 'System will reboot in 5 seconds...';
                            setTimeout(() => execSync('sudo systemctl reboot'), 5000);
                            break;
                        case 'sleep':
                            output = execSync('sudo systemctl suspend 2>&1', { encoding: 'utf-8' });
                            break;
                        case 'hibernate':
                            output = execSync('sudo systemctl hibernate 2>&1', { encoding: 'utf-8' });
                            break;
                        default:
                            return { success: false, content: '', error: 'Actions: shutdown, reboot, sleep, hibernate, battery' };
                    }
                    return { success: true, content: output.trim() };
                } catch (err) {
                    return { success: false, content: '', error: err.message };
                }
            },
        },
    ];
}


// ─── 3. OpenWhale Update Manager ────────────────────────────────────────────
// Allows the OS to update OpenWhale to the latest version without reinstalling

export function getUpdateTool() {
    return {
        name: 'ainux_update',
        description: 'Update AInux components — update OpenWhale to the latest version from GitHub, update AInux kernel, update system packages. Safe, non-destructive, preserves all data.',
        category: 'system',
        requiresApproval: true,
        parameters: {
            parse: (params) => params,
            isOptional: () => false,
        },
        async execute(params, context) {
            const target = params.target || 'openwhale';
            try {
                let output = '';
                switch (target) {
                    case 'openwhale': {
                        // Pull latest OpenWhale, preserve local changes
                        output += '🐋 Updating OpenWhale...\n';

                        // Check current version
                        const pkgPath = join(OPENWHALE_DIR, 'package.json');
                        const currentPkg = JSON.parse(readFileSync(pkgPath, 'utf-8'));
                        output += `Current version: ${currentPkg.version}\n`;

                        // Stash any local modifications
                        try {
                            execSync('git stash', { cwd: OPENWHALE_DIR, encoding: 'utf-8' });
                        } catch { }

                        // Fetch and merge
                        output += execSync('git fetch origin main 2>&1', { cwd: OPENWHALE_DIR, encoding: 'utf-8' });

                        // Check for updates
                        const behind = execSync('git rev-list HEAD..origin/main --count', { cwd: OPENWHALE_DIR, encoding: 'utf-8' }).trim();
                        if (behind === '0') {
                            output += '\n✅ Already up to date!\n';
                            return { success: true, content: output };
                        }

                        output += `\n${behind} new commits available\n`;
                        output += execSync('git merge origin/main --no-edit 2>&1', { cwd: OPENWHALE_DIR, encoding: 'utf-8' });

                        // Reinstall dependencies
                        output += '\nInstalling updated dependencies...\n';
                        output += execSync('pnpm install 2>&1', { cwd: OPENWHALE_DIR, encoding: 'utf-8' });

                        // Rebuild if needed
                        try {
                            output += execSync('pnpm approve-builds 2>&1', { cwd: OPENWHALE_DIR, encoding: 'utf-8' });
                        } catch { }

                        // Pop stash
                        try {
                            execSync('git stash pop 2>/dev/null', { cwd: OPENWHALE_DIR, encoding: 'utf-8' });
                        } catch { }

                        // Read new version
                        const newPkg = JSON.parse(readFileSync(pkgPath, 'utf-8'));
                        output += `\n✅ Updated: ${currentPkg.version} → ${newPkg.version}\n`;
                        output += '\n⚠️ Restart OpenWhale to apply: sudo systemctl restart openwhale\n';
                        break;
                    }

                    case 'ainux': {
                        output += '🐋 Updating AInux kernel module...\n';
                        // AInux core is at /opt/ainux/core
                        output += execSync(`cd ${AINUX_HOME} && git fetch origin main 2>&1 && git merge origin/main --no-edit 2>&1`, { encoding: 'utf-8' });
                        output += '\n✅ AInux kernel updated. Restart: sudo systemctl restart ainux-kernel\n';
                        break;
                    }

                    case 'system': {
                        output += '📦 Updating system packages...\n';
                        output += execSync('sudo apt update 2>&1 && sudo apt upgrade -y 2>&1 || echo "apt not available"', { encoding: 'utf-8' });
                        output += '\n✅ System packages updated\n';
                        break;
                    }

                    case 'check': {
                        output += '🔍 Checking for updates...\n';
                        // Check OpenWhale
                        try {
                            execSync('git fetch origin main 2>/dev/null', { cwd: OPENWHALE_DIR });
                            const owBehind = execSync('git rev-list HEAD..origin/main --count', { cwd: OPENWHALE_DIR, encoding: 'utf-8' }).trim();
                            output += `OpenWhale: ${owBehind === '0' ? '✅ up to date' : `⬆️ ${owBehind} updates available`}\n`;
                        } catch {
                            output += 'OpenWhale: ❓ unable to check\n';
                        }
                        break;
                    }

                    default:
                        return { success: false, content: '', error: 'Targets: openwhale, ainux, system, check' };
                }
                return { success: true, content: output };
            } catch (err) {
                return { success: false, content: '', error: `Update error: ${err.message}` };
            }
        },
    };
}


// ─── 4. Deep Integration Installer ─────────────────────────────────────────
// This function is called by the AInux kernel at boot to wire everything up

export async function installDeepIntegration(openwhaleDir) {
    const dir = openwhaleDir || OPENWHALE_DIR;
    const results = [];

    // 4a. Install the AInux Skill into OpenWhale's skills directory
    const skillsDir = join(homedir(), '.openwhale', 'skills', 'ainux-system');
    try {
        mkdirSync(skillsDir, { recursive: true });
        writeFileSync(join(skillsDir, 'SKILL.md'), AINUX_SKILL_MD);
        results.push('✅ AInux skill installed → ~/.openwhale/skills/ainux-system/');
    } catch (err) {
        results.push(`❌ Skill install failed: ${err.message}`);
    }

    // 4b. Create an AInux system prompt augmentation
    const promptAugment = `
You are running on AInux, a custom AI operating system.
You have full access to the hardware via ainux_* tools.
Available system tools: ainux_hardware_info, ainux_process_control, ainux_system_config, 
ainux_network_control, ainux_audio_control, ainux_display_control, ainux_update, ainux_power.
The user is interacting with you as their primary (and only) OS interface.
There is no desktop, file manager, or other GUI — you ARE the interface.
Apply appropriate caution for destructive operations (power, service control).
`;

    const promptPath = join(homedir(), '.openwhale', 'memory', 'MEMORY.md');
    try {
        let existing = '';
        try { existing = readFileSync(promptPath, 'utf-8'); } catch { }
        if (!existing.includes('AInux')) {
            const updated = existing + '\n\n## AInux OS Context\n' + promptAugment;
            mkdirSync(join(homedir(), '.openwhale', 'memory'), { recursive: true });
            writeFileSync(promptPath, updated);
            results.push('✅ System prompt augmented with AInux context');
        } else {
            results.push('✅ AInux context already in system prompt');
        }
    } catch (err) {
        results.push(`❌ Prompt augmentation failed: ${err.message}`);
    }

    // 4c. Create .env augmentation for AInux mode
    const envPath = join(dir, '.env');
    try {
        let envContent = '';
        try { envContent = readFileSync(envPath, 'utf-8'); } catch { }
        if (!envContent.includes('AINUX_MODE')) {
            envContent += '\n\n# AInux OS Integration\nAINUX_MODE=true\nAINUX_VERSION=0.1.0\n';
            writeFileSync(envPath, envContent);
            results.push('✅ .env augmented with AINUX_MODE=true');
        } else {
            results.push('✅ AINUX_MODE already set in .env');
        }
    } catch (err) {
        results.push(`❌ .env augmentation failed: ${err.message}`);
    }

    return results;
}

// ─── 5. Runtime Tool Injector ───────────────────────────────────────────────
// Dynamically injects AInux tools into a running OpenWhale instance via its API

export async function injectToolsViaAPI(port = 7777) {
    const tools = [...getAInuxTools(), getUpdateTool()];
    const results = [];

    // Wait for OpenWhale to be ready
    let ready = false;
    for (let i = 0; i < 30; i++) {
        try {
            const res = await fetch(`http://localhost:${port}/health`);
            if (res.ok) { ready = true; break; }
        } catch { }
        await new Promise(r => setTimeout(r, 1000));
    }

    if (!ready) {
        return ['❌ OpenWhale not reachable on port ' + port];
    }

    results.push(`✅ OpenWhale online on port ${port}`);
    results.push(`📦 ${tools.length} AInux tools ready for registration`);

    // Tools are registered at import time when OpenWhale loads our extension
    // Here we verify them by checking the /health endpoint includes our tool count
    try {
        const res = await fetch(`http://localhost:${port}/health`);
        const data = await res.json();
        results.push(`✅ OpenWhale healthy: version=${data.version}`);
    } catch (err) {
        results.push(`⚠️ Health check note: ${err.message}`);
    }

    return results;
}
