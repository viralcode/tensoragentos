/**
 * AInux OpenWhale Extension
 * 
 * This file is loaded by OpenWhale's extension-loader system.
 * It registers AInux system tools directly into OpenWhale's toolRegistry
 * at startup, giving every AI agent native OS control.
 * 
 * Installed to: ~/.openwhale/extensions/ainux-os/index.mjs
 * Auto-loaded by OpenWhale on boot via initializeExtensionLoader()
 */

import { readFileSync, existsSync } from 'node:fs';
import { execSync } from 'node:child_process';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { z } from 'zod';

// ─── Extension metadata ─────────────────────────────────────────────────────
export const name = 'ainux-os';
export const version = '0.1.0';
export const description = 'AInux OS integration — hardware, network, audio, display, power, updates';

// ─── Tool Definitions (using Zod schemas like native OpenWhale tools) ──────

export const ainuxHardwareInfo = {
    name: 'ainux_hardware_info',
    description: 'Get detailed hardware information about the AInux system — CPU model & load, GPU, RAM usage, storage, network interfaces, temperature sensors, uptime.',
    category: 'system',
    parameters: z.object({
        subsystem: z.enum(['all', 'cpu', 'memory', 'gpu', 'storage', 'network', 'temperature']).optional().default('all').describe('Which hardware subsystem to query'),
    }),
    async execute(params, context) {
        const info = {};
        const sub = params.subsystem || 'all';

        if (sub === 'all' || sub === 'cpu') {
            try {
                const cpuinfo = readFileSync('/proc/cpuinfo', 'utf-8');
                const model = cpuinfo.match(/model name\s*:\s*(.+)/)?.[1] || 'Unknown';
                const cores = (cpuinfo.match(/^processor/gm) || []).length;
                const loadavg = readFileSync('/proc/loadavg', 'utf-8').trim().split(' ');
                info.cpu = { model, cores, load_1m: loadavg[0], load_5m: loadavg[1], load_15m: loadavg[2] };
            } catch {
                try { info.cpu = { model: execSync('sysctl -n machdep.cpu.brand_string', { encoding: 'utf-8' }).trim() }; } catch { }
            }
        }

        if (sub === 'all' || sub === 'memory') {
            try {
                const meminfo = readFileSync('/proc/meminfo', 'utf-8');
                const total = parseInt(meminfo.match(/MemTotal:\s*(\d+)/)?.[1] || '0');
                const available = parseInt(meminfo.match(/MemAvailable:\s*(\d+)/)?.[1] || '0');
                const used = total - available;
                info.memory = {
                    total_gb: (total / 1024 / 1024).toFixed(1),
                    used_gb: (used / 1024 / 1024).toFixed(1),
                    available_gb: (available / 1024 / 1024).toFixed(1),
                    percent: ((used / total) * 100).toFixed(0) + '%',
                };
            } catch { }
        }

        if (sub === 'all' || sub === 'gpu') {
            try {
                info.gpu = execSync('lspci | grep -i "vga\\|3d\\|display" 2>/dev/null || echo "No GPU info"', { encoding: 'utf-8' }).trim().split('\n');
            } catch { info.gpu = ['Unable to detect']; }
        }

        if (sub === 'all' || sub === 'storage') {
            try {
                info.storage = execSync('df -h / /home 2>/dev/null | tail -n +2', { encoding: 'utf-8' }).trim();
            } catch { }
        }

        if (sub === 'all' || sub === 'network') {
            try {
                info.network = execSync('ip -br addr show 2>/dev/null || ifconfig -a 2>/dev/null | head -30', { encoding: 'utf-8' }).trim();
            } catch { }
        }

        if (sub === 'all' || sub === 'temperature') {
            try {
                const zones = execSync('cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null', { encoding: 'utf-8' }).trim().split('\n');
                info.temperature = zones.map((t, i) => ({ zone: i, celsius: (parseInt(t) / 1000).toFixed(1) }));
            } catch { info.temperature = 'unavailable'; }
        }

        try { info.uptime = execSync('uptime -p 2>/dev/null || uptime', { encoding: 'utf-8' }).trim(); } catch { }
        try { info.kernel = execSync('uname -r', { encoding: 'utf-8' }).trim(); } catch { }

        return { success: true, content: JSON.stringify(info, null, 2) };
    },
};

export const ainuxProcessControl = {
    name: 'ainux_process_control',
    description: 'Control AInux system processes and services. Start, stop, restart, check status of systemd services. Can manage: openwhale, ainux-kernel, ainux-shell, pipewire, NetworkManager, bluetooth.',
    category: 'system',
    parameters: z.object({
        action: z.enum(['start', 'stop', 'restart', 'status', 'list', 'journal']).describe('Action to perform'),
        service: z.string().optional().describe('Service name (required for start/stop/restart/status/journal)'),
        lines: z.number().optional().default(20).describe('Number of journal lines to show'),
    }),
    async execute(params, context) {
        const SAFE_SERVICES = ['openwhale', 'ainux-kernel', 'ainux-shell', 'pipewire', 'pipewire-pulse', 'wireplumber', 'NetworkManager', 'bluetooth', 'wpa_supplicant'];

        try {
            switch (params.action) {
                case 'list':
                    return { success: true, content: execSync('systemctl list-units --type=service --state=running --no-pager 2>/dev/null || ps aux', { encoding: 'utf-8' }) };
                case 'status':
                    if (!params.service) return { success: false, content: '', error: 'Service name required' };
                    return { success: true, content: execSync(`systemctl status ${params.service} --no-pager 2>/dev/null || echo "Not found"`, { encoding: 'utf-8' }) };
                case 'journal':
                    if (!params.service) return { success: false, content: '', error: 'Service name required' };
                    return { success: true, content: execSync(`journalctl -u ${params.service} -n ${params.lines} --no-pager 2>/dev/null`, { encoding: 'utf-8' }) };
                case 'start':
                case 'stop':
                case 'restart':
                    if (!params.service) return { success: false, content: '', error: 'Service name required' };
                    if (!SAFE_SERVICES.some(s => params.service.includes(s))) {
                        return { success: false, content: '', error: `Restricted. Allowed services: ${SAFE_SERVICES.join(', ')}` };
                    }
                    return { success: true, content: execSync(`sudo systemctl ${params.action} ${params.service} 2>&1`, { encoding: 'utf-8' }) };
                default:
                    return { success: false, content: '', error: 'Unknown action' };
            }
        } catch (err) {
            return { success: false, content: '', error: err.message };
        }
    },
};

export const ainuxNetworkControl = {
    name: 'ainux_network_control',
    description: 'Control networking on AInux — scan and connect to WiFi, check connection status, manage Bluetooth devices, configure DNS.',
    category: 'system',
    parameters: z.object({
        action: z.enum(['wifi_scan', 'wifi_connect', 'wifi_disconnect', 'status', 'bluetooth_scan', 'bluetooth_connect', 'bluetooth_disconnect', 'dns_set']).describe('Network action'),
        ssid: z.string().optional().describe('WiFi SSID'),
        password: z.string().optional().describe('WiFi password'),
        mac: z.string().optional().describe('Bluetooth MAC address'),
        dns: z.string().optional().describe('DNS server (e.g. 1.1.1.1)'),
    }),
    async execute(params, context) {
        try {
            const cmds = {
                wifi_scan: 'nmcli dev wifi list 2>/dev/null || iwlist wlan0 scan 2>/dev/null | grep -E "ESSID|Quality"',
                wifi_disconnect: 'nmcli dev disconnect wlan0 2>&1',
                status: 'nmcli general status 2>/dev/null && echo "---" && nmcli con show --active 2>/dev/null && echo "---" && ip route 2>/dev/null',
                bluetooth_scan: 'bluetoothctl --timeout 5 scan on 2>/dev/null && bluetoothctl devices 2>/dev/null || echo "Bluetooth unavailable"',
            };

            if (params.action === 'wifi_connect') {
                if (!params.ssid) return { success: false, content: '', error: 'ssid required' };
                const cmd = params.password
                    ? `nmcli dev wifi connect "${params.ssid}" password "${params.password}" 2>&1`
                    : `nmcli dev wifi connect "${params.ssid}" 2>&1`;
                return { success: true, content: execSync(cmd, { encoding: 'utf-8' }) };
            }
            if (params.action === 'bluetooth_connect') {
                if (!params.mac) return { success: false, content: '', error: 'mac address required' };
                return { success: true, content: execSync(`bluetoothctl connect ${params.mac} 2>&1`, { encoding: 'utf-8' }) };
            }
            if (params.action === 'bluetooth_disconnect') {
                if (!params.mac) return { success: false, content: '', error: 'mac address required' };
                return { success: true, content: execSync(`bluetoothctl disconnect ${params.mac} 2>&1`, { encoding: 'utf-8' }) };
            }
            if (params.action === 'dns_set') {
                if (!params.dns) return { success: false, content: '', error: 'dns server required' };
                return { success: true, content: execSync(`echo "nameserver ${params.dns}" | sudo tee /etc/resolv.conf 2>&1`, { encoding: 'utf-8' }) };
            }

            const cmd = cmds[params.action];
            if (!cmd) return { success: false, content: '', error: 'Unknown action' };
            return { success: true, content: execSync(cmd, { encoding: 'utf-8' }).trim() };
        } catch (err) {
            return { success: false, content: '', error: err.message };
        }
    },
};

export const ainuxAudioControl = {
    name: 'ainux_audio_control',
    description: 'Control audio on AInux — get/set volume, mute/unmute, list audio sinks/sources, switch output device. Uses PipeWire (wpctl) or ALSA fallback.',
    category: 'device',
    parameters: z.object({
        action: z.enum(['get_volume', 'set_volume', 'mute', 'unmute', 'list_sinks', 'list_sources']).describe('Audio action'),
        level: z.number().min(0).max(150).optional().describe('Volume level (0-100, up to 150 for boost)'),
        sink_id: z.number().optional().describe('PipeWire sink ID to switch to'),
    }),
    async execute(params, context) {
        try {
            switch (params.action) {
                case 'get_volume':
                    return { success: true, content: execSync('wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || amixer get Master 2>/dev/null', { encoding: 'utf-8' }).trim() };
                case 'set_volume':
                    if (params.level === undefined) return { success: false, content: '', error: 'level required' };
                    const pct = params.level / 100;
                    execSync(`wpctl set-volume @DEFAULT_AUDIO_SINK@ ${pct} 2>/dev/null || amixer set Master ${params.level}% 2>/dev/null`);
                    return { success: true, content: `Volume set to ${params.level}%` };
                case 'mute':
                    execSync('wpctl set-mute @DEFAULT_AUDIO_SINK@ 1 2>/dev/null || amixer set Master mute 2>/dev/null');
                    return { success: true, content: 'Audio muted' };
                case 'unmute':
                    execSync('wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 2>/dev/null || amixer set Master unmute 2>/dev/null');
                    return { success: true, content: 'Audio unmuted' };
                case 'list_sinks':
                    return { success: true, content: execSync('wpctl status 2>/dev/null | head -40 || aplay -l 2>/dev/null', { encoding: 'utf-8' }).trim() };
                case 'list_sources':
                    return { success: true, content: execSync('wpctl status 2>/dev/null | grep -A20 "Sources" || arecord -l 2>/dev/null', { encoding: 'utf-8' }).trim() };
                default:
                    return { success: false, content: '', error: 'Unknown action' };
            }
        } catch (err) {
            return { success: false, content: '', error: err.message };
        }
    },
};

export const ainuxDisplayControl = {
    name: 'ainux_display_control',
    description: 'Control display settings on AInux — list modes, check resolution, set brightness. Works with Wayland (wlr-randr).',
    category: 'device',
    parameters: z.object({
        action: z.enum(['info', 'set_brightness', 'list_modes']).describe('Display action'),
        brightness: z.number().min(0).max(100).optional().describe('Brightness percentage'),
    }),
    async execute(params, context) {
        try {
            switch (params.action) {
                case 'info':
                    return { success: true, content: execSync('wlr-randr 2>/dev/null || xrandr --current 2>/dev/null || cat /sys/class/drm/card*/*/modes 2>/dev/null | head -5', { encoding: 'utf-8' }).trim() };
                case 'list_modes':
                    return { success: true, content: execSync('wlr-randr 2>/dev/null || xrandr 2>/dev/null', { encoding: 'utf-8' }).trim() };
                case 'set_brightness':
                    if (params.brightness === undefined) return { success: false, content: '', error: 'brightness required (0-100)' };
                    try {
                        const max = parseInt(execSync('cat /sys/class/backlight/*/max_brightness', { encoding: 'utf-8' }).trim());
                        const val = Math.round((params.brightness / 100) * max);
                        execSync(`echo ${val} | sudo tee /sys/class/backlight/*/brightness`);
                        return { success: true, content: `Brightness set to ${params.brightness}%` };
                    } catch {
                        return { success: false, content: '', error: 'No backlight control available' };
                    }
                default:
                    return { success: false, content: '', error: 'Unknown action' };
            }
        } catch (err) {
            return { success: false, content: '', error: err.message };
        }
    },
};

export const ainuxPower = {
    name: 'ainux_power',
    description: 'AInux power management — shutdown, reboot, suspend, hibernate, check battery. ALWAYS confirm destructive actions with the user first.',
    category: 'system',
    requiresApproval: true,
    parameters: z.object({
        action: z.enum(['shutdown', 'reboot', 'suspend', 'hibernate', 'battery', 'uptime']).describe('Power action'),
        delay: z.number().optional().default(5).describe('Delay in seconds before shutdown/reboot'),
    }),
    async execute(params, context) {
        try {
            switch (params.action) {
                case 'battery':
                    return { success: true, content: execSync('upower -i $(upower -e | grep BAT) 2>/dev/null || cat /sys/class/power_supply/BAT*/capacity 2>/dev/null || echo "No battery"', { encoding: 'utf-8' }).trim() };
                case 'uptime':
                    return { success: true, content: execSync('uptime', { encoding: 'utf-8' }).trim() };
                case 'shutdown':
                    setTimeout(() => { try { execSync('sudo systemctl poweroff'); } catch { } }, (params.delay || 5) * 1000);
                    return { success: true, content: `System will shut down in ${params.delay || 5} seconds` };
                case 'reboot':
                    setTimeout(() => { try { execSync('sudo systemctl reboot'); } catch { } }, (params.delay || 5) * 1000);
                    return { success: true, content: `System will reboot in ${params.delay || 5} seconds` };
                case 'suspend':
                    return { success: true, content: execSync('sudo systemctl suspend 2>&1', { encoding: 'utf-8' }).trim() || 'Suspended' };
                case 'hibernate':
                    return { success: true, content: execSync('sudo systemctl hibernate 2>&1', { encoding: 'utf-8' }).trim() || 'Hibernated' };
                default:
                    return { success: false, content: '', error: 'Unknown action' };
            }
        } catch (err) {
            return { success: false, content: '', error: err.message };
        }
    },
};

export const ainuxUpdate = {
    name: 'ainux_update',
    description: 'Update AInux and OpenWhale. Safely pulls the latest code from GitHub, reinstalls dependencies, and reports changes. Preserves all user data and configuration. Targets: openwhale, ainux, check.',
    category: 'system',
    requiresApproval: true,
    parameters: z.object({
        target: z.enum(['openwhale', 'ainux', 'check']).default('check').describe('What to update'),
    }),
    async execute(params, context) {
        const OPENWHALE_DIR = process.env.OPENWHALE_DIR || '/opt/ainux/openwhale';
        const AINUX_HOME = process.env.AINUX_HOME || '/opt/ainux';

        try {
            let output = '';
            switch (params.target) {
                case 'check': {
                    output += '🔍 Checking for updates...\n\n';
                    for (const [label, dir] of [['OpenWhale', OPENWHALE_DIR], ['AInux', AINUX_HOME]]) {
                        try {
                            execSync('git fetch origin 2>/dev/null', { cwd: dir });
                            const behind = execSync('git rev-list HEAD..origin/main --count 2>/dev/null', { cwd: dir, encoding: 'utf-8' }).trim();
                            const current = execSync('git log --oneline -1 2>/dev/null', { cwd: dir, encoding: 'utf-8' }).trim();
                            output += `${label}: ${behind === '0' ? '✅ up to date' : `⬆️ ${behind} commits behind`}\n  Current: ${current}\n\n`;
                        } catch {
                            output += `${label}: ❓ unable to check (dir: ${dir})\n\n`;
                        }
                    }
                    break;
                }
                case 'openwhale': {
                    output += '🐋 Updating OpenWhale...\n';
                    try { execSync('git stash 2>/dev/null', { cwd: OPENWHALE_DIR }); } catch { }
                    output += execSync('git pull origin main 2>&1', { cwd: OPENWHALE_DIR, encoding: 'utf-8' });
                    output += '\n📦 Reinstalling dependencies...\n';
                    output += execSync('pnpm install 2>&1', { cwd: OPENWHALE_DIR, encoding: 'utf-8' });
                    try { execSync('pnpm approve-builds 2>/dev/null', { cwd: OPENWHALE_DIR }); } catch { }
                    try { execSync('git stash pop 2>/dev/null', { cwd: OPENWHALE_DIR }); } catch { }
                    output += '\n✅ OpenWhale updated! Restart with: sudo systemctl restart openwhale';
                    break;
                }
                case 'ainux': {
                    output += '🖥️ Updating AInux...\n';
                    output += execSync('git pull origin main 2>&1', { cwd: AINUX_HOME, encoding: 'utf-8' });
                    output += '\n✅ AInux updated! Restart with: sudo systemctl restart ainux-kernel';
                    break;
                }
            }
            return { success: true, content: output };
        } catch (err) {
            return { success: false, content: '', error: `Update failed: ${err.message}` };
        }
    },
};

export const ainuxSystemConfig = {
    name: 'ainux_system_config',
    description: 'Read or modify AInux system configuration (/etc/ainux/ainux.conf). Get/set hostname, timezone, theme, accent color, audio backend, compositor settings.',
    category: 'system',
    parameters: z.object({
        action: z.enum(['get', 'set', 'list']).describe('Config action'),
        key: z.string().optional().describe('Config key to get/set'),
        value: z.string().optional().describe('Value to set'),
    }),
    async execute(params, context) {
        const configPath = '/etc/ainux/ainux.conf';
        try {
            if (params.action === 'list' || (params.action === 'get' && !params.key)) {
                if (!existsSync(configPath)) return { success: true, content: 'No config file (defaults active)' };
                return { success: true, content: readFileSync(configPath, 'utf-8') };
            }
            if (params.action === 'get') {
                if (!existsSync(configPath)) return { success: true, content: `${params.key}: (default)` };
                const content = readFileSync(configPath, 'utf-8');
                const match = content.match(new RegExp(`^${params.key}=(.+)$`, 'm'));
                return { success: true, content: match ? `${params.key}=${match[1]}` : `${params.key}: not set` };
            }
            if (params.action === 'set') {
                if (!params.key || !params.value) return { success: false, content: '', error: 'key and value required' };
                let content = existsSync(configPath) ? readFileSync(configPath, 'utf-8') : '';
                const re = new RegExp(`^${params.key}=.*$`, 'm');
                content = re.test(content) ? content.replace(re, `${params.key}=${params.value}`) : content + `\n${params.key}=${params.value}`;
                writeFileSync(configPath, content);
                return { success: true, content: `✅ ${params.key}=${params.value}` };
            }
            return { success: false, content: '', error: 'Unknown action' };
        } catch (err) {
            return { success: false, content: '', error: err.message };
        }
    },
};

// ─── Export all tools for registration ──────────────────────────────────────
export const tools = [
    ainuxHardwareInfo,
    ainuxProcessControl,
    ainuxNetworkControl,
    ainuxAudioControl,
    ainuxDisplayControl,
    ainuxPower,
    ainuxUpdate,
    ainuxSystemConfig,
];
