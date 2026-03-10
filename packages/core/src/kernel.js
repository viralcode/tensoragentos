/**
 * AInux Kernel — The Node.js Orchestrator
 * 
 * This is the heart of AInux. It manages:
 * - Process lifecycle (OpenWhale, Chromium, system services)
 * - IPC between agents, GUI shell, and browser
 * - System health monitoring
 * - WebMCP bridge initialization
 * - Hardware abstraction
 * 
 * Boot sequence:
 * systemd → ainux-kernel → OpenWhale → Chromium → GUI
 */

import { EventEmitter } from 'events';
import { spawn } from 'child_process';
import { existsSync, mkdirSync, writeFileSync, readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { createIPCServer } from './ipc.js';
import { HardwareMonitor } from './hardware.js';
import { WebMCPBridge } from './webmcp-bridge.js';
import { ProcessManager } from './process-manager.js';
import { Logger } from './logger.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// ─── Configuration ───────────────────────────────────────────────────────────

const AINUX_VERSION = '0.1.0';
const AINUX_HOME = process.env.AINUX_HOME || '/opt/ainux';
const AINUX_DATA = process.env.AINUX_DATA || join(process.env.HOME || '/home/ainux', '.ainux');
const OPENWHALE_PORT = parseInt(process.env.OPENWHALE_PORT || '7777', 10);
const CDP_PORT = parseInt(process.env.CDP_PORT || '9222', 10);
const IPC_SOCKET = process.env.AINUX_IPC_SOCKET || join(AINUX_DATA, 'ainux.sock');

const CONFIG_DEFAULTS = {
    openwhale: {
        path: process.env.OPENWHALE_PATH || join(AINUX_HOME, 'openwhale'),
        port: OPENWHALE_PORT,
        autoStart: true,
    },
    chromium: {
        path: process.env.CHROMIUM_PATH || join(AINUX_HOME, 'chromium', 'chrome'),
        cdpPort: CDP_PORT,
        autoStart: true,
        flags: [
            '--ozone-platform=wayland',
            '--enable-features=WebMCP,ExperimentalWebPlatformFeatures',
            `--remote-debugging-port=${CDP_PORT}`,
            '--no-first-run',
            '--disable-translate',
            '--disable-default-apps',
            '--disable-popup-blocking',
            '--disable-background-timer-throttling',
            `--user-data-dir=${join(AINUX_DATA, 'browser')}`,
            `--app=http://localhost:${OPENWHALE_PORT}/dashboard`,
        ],
    },
    gui: {
        compositor: 'cage',  // 'cage' for kiosk, 'sway' for tiling
    },
    system: {
        healthCheckInterval: 10_000,  // 10s
        maxRestarts: 5,
        restartBackoffMs: 2_000,
    },
};

// ─── AInux Kernel ────────────────────────────────────────────────────────────

class AInuxKernel extends EventEmitter {
    constructor() {
        super();
        this.version = AINUX_VERSION;
        this.config = { ...CONFIG_DEFAULTS };
        this.state = 'initializing';  // initializing | booting | running | shutting-down | error
        this.startTime = Date.now();
        this.log = new Logger('kernel');
        this.processes = new ProcessManager(this.log);
        this.hardware = new HardwareMonitor(this.log);
        this.ipc = null;
        this.webmcpBridge = null;
        this.healthTimer = null;
    }

    /**
     * Main boot sequence — called once at startup
     */
    async boot() {
        this.log.banner(`AInux v${this.version} — Booting...`);
        this.state = 'booting';

        try {
            // Phase 1: Ensure data directories exist
            this._ensureDirectories();

            // Phase 2: Start IPC server (for agent ↔ GUI communication)
            this.log.info('Starting IPC server...');
            this.ipc = await createIPCServer(IPC_SOCKET, this);
            this.log.success(`IPC server listening on ${IPC_SOCKET}`);

            // Phase 3: Detect hardware
            this.log.info('Detecting hardware...');
            const hw = await this.hardware.detect();
            this.log.info(`CPU: ${hw.cpu.brand} (${hw.cpu.cores} cores)`);
            this.log.info(`RAM: ${hw.memory.totalFormatted}`);
            this.log.info(`GPU: ${hw.gpu.model || 'none detected'}`);
            this.log.info(`Network: ${hw.network.connected ? 'connected' : 'disconnected'}`);

            // Phase 4: Start OpenWhale
            if (this.config.openwhale.autoStart) {
                await this._startOpenWhale();
            }

            // Phase 5: Start Chromium with WebMCP
            if (this.config.chromium.autoStart) {
                await this._startChromium();
            }

            // Phase 6: Initialize WebMCP bridge
            this.log.info('Initializing WebMCP bridge...');
            this.webmcpBridge = new WebMCPBridge({
                cdpPort: this.config.chromium.cdpPort,
                openwhalePort: this.config.openwhale.port,
                log: this.log,
            });
            await this.webmcpBridge.connect();
            this.log.success('WebMCP bridge active');

            // Phase 7: Start health monitoring
            this._startHealthCheck();

            // Done
            this.state = 'running';
            this.log.banner('AInux is LIVE 🚀');
            this.log.info(`Dashboard: http://localhost:${OPENWHALE_PORT}/dashboard`);
            this.log.info(`CDP: ws://localhost:${CDP_PORT}`);
            this.log.info(`Uptime: ${this._uptime()}`);

            this.emit('ready');
        } catch (err) {
            this.state = 'error';
            this.log.error(`Boot failed: ${err.message}`);
            this.log.error(err.stack);
            this.emit('error', err);
            process.exit(1);
        }
    }

    /**
     * Start OpenWhale server process
     */
    async _startOpenWhale() {
        const owPath = this.config.openwhale.path;
        this.log.info(`Starting OpenWhale from ${owPath}...`);

        if (!existsSync(owPath)) {
            this.log.warn(`OpenWhale not found at ${owPath}, running first-boot setup...`);
            await this._firstBootSetup();
        }

        await this.processes.start('openwhale', {
            command: 'node',
            args: ['openwhale.mjs'],
            cwd: owPath,
            env: {
                ...process.env,
                NODE_ENV: 'production',
                PORT: String(this.config.openwhale.port),
                AINUX_MODE: 'true',
            },
            readyCheck: async () => {
                try {
                    const res = await fetch(`http://localhost:${this.config.openwhale.port}/api/health`);
                    return res.ok;
                } catch {
                    return false;
                }
            },
            readyTimeout: 30_000,
            maxRestarts: this.config.system.maxRestarts,
        });

        this.log.success(`OpenWhale running on port ${this.config.openwhale.port}`);
    }

    /**
     * Start Chromium browser process
     */
    async _startChromium() {
        const chromiumPath = this.config.chromium.path;
        this.log.info('Starting Chromium with WebMCP...');

        await this.processes.start('chromium', {
            command: chromiumPath,
            args: this.config.chromium.flags,
            env: {
                ...process.env,
                DISPLAY: process.env.DISPLAY || ':0',
                WAYLAND_DISPLAY: process.env.WAYLAND_DISPLAY || 'whaleos-0',
            },
            readyCheck: async () => {
                try {
                    const res = await fetch(`http://localhost:${this.config.chromium.cdpPort}/json/version`);
                    return res.ok;
                } catch {
                    return false;
                }
            },
            readyTimeout: 15_000,
            maxRestarts: this.config.system.maxRestarts,
        });

        this.log.success('Chromium running with WebMCP enabled');
    }

    /**
     * First-boot setup: clone & install OpenWhale
     */
    async _firstBootSetup() {
        const owPath = this.config.openwhale.path;
        this.log.info('First boot detected — installing OpenWhale...');

        mkdirSync(dirname(owPath), { recursive: true });

        // Clone
        await this.processes.exec('git', [
            'clone', 'https://github.com/viralcode/openwhale.git', owPath,
        ]);

        // Install deps
        await this.processes.exec('pnpm', ['install'], { cwd: owPath });
        await this.processes.exec('pnpm', ['approve-builds'], { cwd: owPath });

        this.log.success('OpenWhale installed successfully');
    }

    /**
     * Periodic health check
     */
    _startHealthCheck() {
        this.healthTimer = setInterval(async () => {
            const status = {
                state: this.state,
                uptime: this._uptime(),
                processes: this.processes.getStatus(),
                hardware: await this.hardware.snapshot(),
                webmcp: this.webmcpBridge?.isConnected() || false,
            };

            // Broadcast to IPC clients
            this.ipc?.broadcast('health', status);

            // Check for crashed processes and restart
            for (const [name, proc] of Object.entries(status.processes)) {
                if (proc.state === 'crashed') {
                    this.log.warn(`Process ${name} has crashed, attempting restart...`);
                    if (name === 'openwhale') await this._startOpenWhale();
                    if (name === 'chromium') await this._startChromium();
                }
            }
        }, this.config.system.healthCheckInterval);
    }

    /**
     * Graceful shutdown
     */
    async shutdown(signal = 'SIGTERM') {
        if (this.state === 'shutting-down') return;
        this.state = 'shutting-down';
        this.log.banner(`Shutting down (${signal})...`);

        clearInterval(this.healthTimer);

        // Stop WebMCP bridge
        if (this.webmcpBridge) {
            await this.webmcpBridge.disconnect();
        }

        // Stop all managed processes
        await this.processes.stopAll();

        // Close IPC
        if (this.ipc) {
            this.ipc.close();
        }

        this.log.banner('AInux shutdown complete. Goodbye! 👋');
        process.exit(0);
    }

    /**
     * Ensure required directories exist
     */
    _ensureDirectories() {
        const dirs = [
            AINUX_DATA,
            join(AINUX_DATA, 'browser'),
            join(AINUX_DATA, 'logs'),
            join(AINUX_DATA, 'state'),
        ];
        for (const dir of dirs) {
            mkdirSync(dir, { recursive: true });
        }
    }

    /**
     * Get formatted uptime
     */
    _uptime() {
        const ms = Date.now() - this.startTime;
        const s = Math.floor(ms / 1000) % 60;
        const m = Math.floor(ms / 60_000) % 60;
        const h = Math.floor(ms / 3_600_000);
        return `${h}h ${m}m ${s}s`;
    }

    /**
     * Get system status (for IPC / API)
     */
    getStatus() {
        return {
            version: this.version,
            state: this.state,
            uptime: this._uptime(),
            config: {
                openwhalePort: this.config.openwhale.port,
                cdpPort: this.config.chromium.cdpPort,
            },
            processes: this.processes.getStatus(),
        };
    }
}

// ─── Boot ────────────────────────────────────────────────────────────────────

const kernel = new AInuxKernel();

// Handle signals
process.on('SIGINT', () => kernel.shutdown('SIGINT'));
process.on('SIGTERM', () => kernel.shutdown('SIGTERM'));
process.on('uncaughtException', (err) => {
    kernel.log.error(`Uncaught exception: ${err.message}`);
    kernel.log.error(err.stack);
    kernel.shutdown('uncaughtException');
});

// Boot!
kernel.boot();

export { AInuxKernel };
