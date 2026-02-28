/**
 * AInux Hardware Monitor
 * 
 * Detects and monitors system hardware:
 * - CPU (model, cores, usage, temperature)
 * - Memory (total, used, free)
 * - GPU (model, driver, VRAM)
 * - Network (interfaces, connectivity)
 * - Storage (disks, usage)
 * - Audio (devices)
 * - Display (resolution, compositor)
 */

import { execFile } from 'child_process';
import { existsSync, readFileSync } from 'fs';

class HardwareMonitor {
    constructor(log) {
        this.log = log.child('hardware');
        this.cachedInfo = null;
    }

    /**
     * Full hardware detection (run once at boot)
     */
    async detect() {
        this.log.info('Running hardware detection...');

        const [cpu, memory, gpu, network, storage, audio, display] = await Promise.allSettled([
            this._detectCPU(),
            this._detectMemory(),
            this._detectGPU(),
            this._detectNetwork(),
            this._detectStorage(),
            this._detectAudio(),
            this._detectDisplay(),
        ]);

        this.cachedInfo = {
            cpu: cpu.status === 'fulfilled' ? cpu.value : { brand: 'unknown', cores: 0 },
            memory: memory.status === 'fulfilled' ? memory.value : { total: 0, totalFormatted: 'unknown' },
            gpu: gpu.status === 'fulfilled' ? gpu.value : { model: 'unknown' },
            network: network.status === 'fulfilled' ? network.value : { connected: false },
            storage: storage.status === 'fulfilled' ? storage.value : { disks: [] },
            audio: audio.status === 'fulfilled' ? audio.value : { devices: [] },
            display: display.status === 'fulfilled' ? display.value : { resolution: 'unknown' },
            detectedAt: new Date().toISOString(),
        };

        return this.cachedInfo;
    }

    /**
     * Quick snapshot (for health checks)
     */
    async snapshot() {
        const [cpuUsage, memUsage] = await Promise.allSettled([
            this._getCPUUsage(),
            this._getMemUsage(),
        ]);

        return {
            ...this.cachedInfo,
            live: {
                cpuUsage: cpuUsage.status === 'fulfilled' ? cpuUsage.value : null,
                memUsage: memUsage.status === 'fulfilled' ? memUsage.value : null,
                timestamp: Date.now(),
            },
        };
    }

    // ─── Detectors ────────────────────────────────────────────────────────

    async _detectCPU() {
        try {
            // Try /proc/cpuinfo (Linux)
            if (existsSync('/proc/cpuinfo')) {
                const info = readFileSync('/proc/cpuinfo', 'utf8');
                const model = info.match(/model name\s*:\s*(.+)/)?.[1]?.trim() || 'unknown';
                const cores = (info.match(/^processor/gm) || []).length;
                return { brand: model, cores, arch: process.arch };
            }
            // Fallback: macOS sysctl
            const brand = await this._exec('sysctl', ['-n', 'machdep.cpu.brand_string']);
            const cores = await this._exec('sysctl', ['-n', 'hw.ncpu']);
            return { brand: brand.trim(), cores: parseInt(cores), arch: process.arch };
        } catch {
            return { brand: process.arch, cores: 1, arch: process.arch };
        }
    }

    async _detectMemory() {
        try {
            if (existsSync('/proc/meminfo')) {
                const info = readFileSync('/proc/meminfo', 'utf8');
                const totalKb = parseInt(info.match(/MemTotal:\s+(\d+)/)?.[1] || '0');
                const total = totalKb * 1024;
                return { total, totalFormatted: this._formatBytes(total) };
            }
            // macOS
            const mem = await this._exec('sysctl', ['-n', 'hw.memsize']);
            const total = parseInt(mem.trim());
            return { total, totalFormatted: this._formatBytes(total) };
        } catch {
            return { total: 0, totalFormatted: 'unknown' };
        }
    }

    async _detectGPU() {
        try {
            // Linux: lspci
            if (existsSync('/usr/bin/lspci') || existsSync('/sbin/lspci')) {
                const lspci = await this._exec('lspci', []);
                const vgaLine = lspci.split('\n').find(l => l.includes('VGA') || l.includes('3D'));
                const model = vgaLine ? vgaLine.split(': ').slice(1).join(': ').trim() : 'none';

                // Check driver
                let driver = 'unknown';
                try {
                    const drmCards = await this._exec('ls', ['/sys/class/drm/']);
                    if (drmCards.includes('card0')) {
                        driver = await this._exec('cat', ['/sys/class/drm/card0/device/driver/module/drivers']);
                    }
                } catch { /* no driver info */ }

                return { model, driver };
            }
            // macOS
            const gpuInfo = await this._exec('system_profiler', ['SPDisplaysDataType', '-json']);
            const parsed = JSON.parse(gpuInfo);
            const gpu = parsed?.SPDisplaysDataType?.[0];
            return { model: gpu?.sppci_model || 'unknown', driver: 'Metal' };
        } catch {
            return { model: 'unknown', driver: 'unknown' };
        }
    }

    async _detectNetwork() {
        try {
            // Quick connectivity check
            const connected = await this._exec('ping', ['-c', '1', '-W', '2', '8.8.8.8'])
                .then(() => true)
                .catch(() => false);

            // Get interfaces
            let interfaces = [];
            try {
                if (existsSync('/sys/class/net')) {
                    const nets = await this._exec('ls', ['/sys/class/net']);
                    interfaces = nets.trim().split('\n').filter(n => n !== 'lo');
                }
            } catch { /* fallback */ }

            return { connected, interfaces };
        } catch {
            return { connected: false, interfaces: [] };
        }
    }

    async _detectStorage() {
        try {
            const df = await this._exec('df', ['-h', '/']);
            const lines = df.trim().split('\n');
            if (lines.length >= 2) {
                const parts = lines[1].split(/\s+/);
                return {
                    disks: [{
                        mount: parts[5] || '/',
                        total: parts[1] || 'unknown',
                        used: parts[2] || 'unknown',
                        available: parts[3] || 'unknown',
                        usePercent: parts[4] || 'unknown',
                    }],
                };
            }
            return { disks: [] };
        } catch {
            return { disks: [] };
        }
    }

    async _detectAudio() {
        try {
            // Linux: ALSA
            if (existsSync('/proc/asound/cards')) {
                const cards = readFileSync('/proc/asound/cards', 'utf8');
                const devices = cards.split('\n')
                    .filter(l => l.match(/^\s*\d/))
                    .map(l => l.trim());
                return { devices, backend: 'ALSA' };
            }
            // macOS
            const audio = await this._exec('system_profiler', ['SPAudioDataType', '-json']);
            const parsed = JSON.parse(audio);
            const devices = parsed?.SPAudioDataType?.map(d => d._name) || [];
            return { devices, backend: 'CoreAudio' };
        } catch {
            return { devices: [], backend: 'unknown' };
        }
    }

    async _detectDisplay() {
        try {
            // Check Wayland
            if (process.env.WAYLAND_DISPLAY) {
                return { compositor: 'wayland', display: process.env.WAYLAND_DISPLAY };
            }
            // Check X11
            if (process.env.DISPLAY) {
                const xrandr = await this._exec('xrandr', ['--current']);
                const res = xrandr.match(/current (\d+) x (\d+)/);
                return {
                    compositor: 'x11',
                    display: process.env.DISPLAY,
                    resolution: res ? `${res[1]}x${res[2]}` : 'unknown',
                };
            }
            return { compositor: 'none', resolution: 'unknown' };
        } catch {
            return { compositor: 'unknown', resolution: 'unknown' };
        }
    }

    // ─── Live Metrics ─────────────────────────────────────────────────────

    async _getCPUUsage() {
        try {
            if (existsSync('/proc/stat')) {
                const stat = readFileSync('/proc/stat', 'utf8');
                const cpuLine = stat.split('\n')[0];
                const values = cpuLine.split(/\s+/).slice(1).map(Number);
                const idle = values[3];
                const total = values.reduce((a, b) => a + b, 0);
                return { idle, total, percent: ((1 - idle / total) * 100).toFixed(1) + '%' };
            }
            return null;
        } catch {
            return null;
        }
    }

    async _getMemUsage() {
        try {
            if (existsSync('/proc/meminfo')) {
                const info = readFileSync('/proc/meminfo', 'utf8');
                const total = parseInt(info.match(/MemTotal:\s+(\d+)/)?.[1] || '0') * 1024;
                const available = parseInt(info.match(/MemAvailable:\s+(\d+)/)?.[1] || '0') * 1024;
                const used = total - available;
                return {
                    total: this._formatBytes(total),
                    used: this._formatBytes(used),
                    available: this._formatBytes(available),
                    percent: ((used / total) * 100).toFixed(1) + '%',
                };
            }
            return null;
        } catch {
            return null;
        }
    }

    // ─── Helpers ──────────────────────────────────────────────────────────

    _exec(cmd, args) {
        return new Promise((resolve, reject) => {
            execFile(cmd, args, { timeout: 5000 }, (err, stdout) => {
                if (err) reject(err);
                else resolve(stdout);
            });
        });
    }

    _formatBytes(bytes) {
        if (bytes === 0) return '0 B';
        const k = 1024;
        const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return `${(bytes / Math.pow(k, i)).toFixed(1)} ${sizes[i]}`;
    }
}

export { HardwareMonitor };
