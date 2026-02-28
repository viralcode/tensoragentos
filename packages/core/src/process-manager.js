/**
 * AInux Process Manager
 * 
 * Manages child processes with:
 * - Ready checks (poll until process is responsive)
 * - Automatic restart on crash with backoff
 * - Graceful shutdown
 * - Status tracking
 */

import { spawn, execFile } from 'child_process';
import { EventEmitter } from 'events';

class ManagedProcess extends EventEmitter {
    constructor(name, options, log) {
        super();
        this.name = name;
        this.options = options;
        this.log = log.child(`proc:${name}`);
        this.process = null;
        this.state = 'stopped';   // stopped | starting | running | crashed | stopping
        this.pid = null;
        this.restartCount = 0;
        this.lastStartTime = null;
        this.exitCode = null;
    }

    async start() {
        if (this.state === 'running' || this.state === 'starting') {
            this.log.warn(`Already ${this.state}`);
            return;
        }

        this.state = 'starting';
        this.lastStartTime = Date.now();
        this.exitCode = null;

        const { command, args = [], cwd, env } = this.options;

        this.log.info(`Starting: ${command} ${args.join(' ')}`);

        this.process = spawn(command, args, {
            cwd,
            env: env || process.env,
            stdio: ['pipe', 'pipe', 'pipe'],
            detached: false,
        });

        this.pid = this.process.pid;
        this.log.info(`PID: ${this.pid}`);

        // Capture stdout/stderr
        this.process.stdout?.on('data', (data) => {
            const lines = data.toString().trim().split('\n');
            for (const line of lines) {
                this.log.debug(`stdout: ${line}`);
            }
        });

        this.process.stderr?.on('data', (data) => {
            const lines = data.toString().trim().split('\n');
            for (const line of lines) {
                this.log.warn(`stderr: ${line}`);
            }
        });

        // Handle exit
        this.process.on('exit', (code, signal) => {
            this.exitCode = code;
            if (this.state === 'stopping') {
                this.state = 'stopped';
                this.log.info(`Stopped (code=${code}, signal=${signal})`);
            } else {
                this.state = 'crashed';
                this.log.error(`Crashed (code=${code}, signal=${signal})`);
                this.emit('crash', { code, signal });
                this._maybeRestart();
            }
        });

        this.process.on('error', (err) => {
            this.state = 'crashed';
            this.log.error(`Process error: ${err.message}`);
            this.emit('crash', { error: err.message });
        });

        // Wait for ready check
        if (this.options.readyCheck) {
            const ready = await this._waitForReady();
            if (!ready) {
                throw new Error(`${this.name} failed ready check after ${this.options.readyTimeout}ms`);
            }
        }

        this.state = 'running';
        this.log.success(`Running (PID: ${this.pid})`);
        this.emit('ready');
    }

    async _waitForReady() {
        const timeout = this.options.readyTimeout || 30_000;
        const interval = 500;
        const maxAttempts = Math.ceil(timeout / interval);

        for (let i = 0; i < maxAttempts; i++) {
            try {
                const ready = await this.options.readyCheck();
                if (ready) return true;
            } catch {
                // Not ready yet
            }
            await new Promise(r => setTimeout(r, interval));
        }
        return false;
    }

    async _maybeRestart() {
        const maxRestarts = this.options.maxRestarts || 5;
        if (this.restartCount >= maxRestarts) {
            this.log.error(`Max restarts (${maxRestarts}) reached, giving up`);
            return;
        }

        const backoff = (this.restartCount + 1) * 2_000;
        this.restartCount++;
        this.log.warn(`Restarting in ${backoff}ms (attempt ${this.restartCount}/${maxRestarts})`);

        await new Promise(r => setTimeout(r, backoff));

        try {
            await this.start();
        } catch (err) {
            this.log.error(`Restart failed: ${err.message}`);
        }
    }

    async stop(signal = 'SIGTERM', timeout = 10_000) {
        if (!this.process || this.state === 'stopped') return;

        this.state = 'stopping';
        this.log.info(`Stopping (${signal})...`);

        return new Promise((resolve) => {
            const timer = setTimeout(() => {
                this.log.warn('Force killing (SIGKILL)...');
                this.process.kill('SIGKILL');
                resolve();
            }, timeout);

            this.process.once('exit', () => {
                clearTimeout(timer);
                resolve();
            });

            this.process.kill(signal);
        });
    }

    getStatus() {
        return {
            name: this.name,
            state: this.state,
            pid: this.pid,
            restartCount: this.restartCount,
            exitCode: this.exitCode,
            uptime: this.lastStartTime ? Date.now() - this.lastStartTime : 0,
        };
    }
}

class ProcessManager {
    constructor(log) {
        this.log = log.child('processes');
        this.managed = new Map();
    }

    async start(name, options) {
        if (this.managed.has(name)) {
            const existing = this.managed.get(name);
            if (existing.state === 'running') {
                this.log.warn(`${name} already running`);
                return existing;
            }
        }

        const proc = new ManagedProcess(name, options, this.log);
        this.managed.set(name, proc);
        await proc.start();
        return proc;
    }

    async stop(name) {
        const proc = this.managed.get(name);
        if (proc) {
            await proc.stop();
        }
    }

    async stopAll() {
        const promises = [];
        for (const [name, proc] of this.managed) {
            this.log.info(`Stopping ${name}...`);
            promises.push(proc.stop());
        }
        await Promise.allSettled(promises);
    }

    getStatus() {
        const status = {};
        for (const [name, proc] of this.managed) {
            status[name] = proc.getStatus();
        }
        return status;
    }

    /**
     * Execute a command and wait for it to complete (for setup scripts)
     */
    async exec(command, args = [], options = {}) {
        return new Promise((resolve, reject) => {
            this.log.info(`exec: ${command} ${args.join(' ')}`);
            const child = execFile(command, args, {
                cwd: options.cwd,
                env: options.env || process.env,
                maxBuffer: 50 * 1024 * 1024,  // 50MB
            }, (err, stdout, stderr) => {
                if (err) {
                    this.log.error(`exec failed: ${err.message}`);
                    reject(err);
                } else {
                    if (stdout) this.log.debug(stdout.trim());
                    resolve({ stdout, stderr });
                }
            });
        });
    }
}

export { ProcessManager, ManagedProcess };
