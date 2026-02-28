/**
 * AInux IPC Server — Unix Socket-based Inter-Process Communication
 * 
 * Enables communication between:
 * - OpenWhale agents ↔ GUI shell
 * - Chromium (WebMCP) ↔ Kernel
 * - System services ↔ Kernel
 * 
 * Protocol: JSON-RPC 2.0 over Unix domain sockets
 */

import { createServer } from 'net';
import { existsSync, unlinkSync } from 'fs';
import { EventEmitter } from 'events';

class IPCServer extends EventEmitter {
    constructor(socketPath, kernel, log) {
        super();
        this.socketPath = socketPath;
        this.kernel = kernel;
        this.log = log.child('ipc');
        this.server = null;
        this.clients = new Map();
        this.clientIdCounter = 0;
        this.handlers = new Map();

        this._registerBuiltinHandlers();
    }

    async start() {
        // Clean up stale socket
        if (existsSync(this.socketPath)) {
            unlinkSync(this.socketPath);
        }

        return new Promise((resolve, reject) => {
            this.server = createServer((socket) => {
                this._handleConnection(socket);
            });

            this.server.on('error', (err) => {
                this.log.error(`IPC server error: ${err.message}`);
                reject(err);
            });

            this.server.listen(this.socketPath, () => {
                this.log.success(`IPC listening on ${this.socketPath}`);
                resolve();
            });
        });
    }

    _handleConnection(socket) {
        const clientId = ++this.clientIdCounter;
        this.clients.set(clientId, { socket, name: null, subscriptions: new Set() });
        this.log.debug(`Client ${clientId} connected`);

        let buffer = '';

        socket.on('data', (data) => {
            buffer += data.toString();

            // Parse newline-delimited JSON messages
            const lines = buffer.split('\n');
            buffer = lines.pop(); // Keep incomplete last line

            for (const line of lines) {
                if (!line.trim()) continue;
                try {
                    const msg = JSON.parse(line);
                    this._handleMessage(clientId, msg);
                } catch (err) {
                    this.log.warn(`Invalid JSON from client ${clientId}: ${err.message}`);
                }
            }
        });

        socket.on('close', () => {
            this.clients.delete(clientId);
            this.log.debug(`Client ${clientId} disconnected`);
        });

        socket.on('error', (err) => {
            this.log.warn(`Client ${clientId} error: ${err.message}`);
            this.clients.delete(clientId);
        });
    }

    _handleMessage(clientId, msg) {
        const { id, method, params } = msg;

        // JSON-RPC 2.0 request
        if (method) {
            const handler = this.handlers.get(method);
            if (!handler) {
                this._send(clientId, { id, error: { code: -32601, message: `Unknown method: ${method}` } });
                return;
            }

            try {
                const result = handler(params, clientId);
                if (result instanceof Promise) {
                    result
                        .then(r => this._send(clientId, { id, result: r }))
                        .catch(e => this._send(clientId, { id, error: { code: -1, message: e.message } }));
                } else {
                    this._send(clientId, { id, result });
                }
            } catch (err) {
                this._send(clientId, { id, error: { code: -1, message: err.message } });
            }
        }
    }

    _send(clientId, msg) {
        const client = this.clients.get(clientId);
        if (client?.socket?.writable) {
            client.socket.write(JSON.stringify(msg) + '\n');
        }
    }

    /**
     * Broadcast an event to all connected clients (or those subscribed to the topic)
     */
    broadcast(topic, data) {
        const msg = JSON.stringify({ jsonrpc: '2.0', method: 'event', params: { topic, data } }) + '\n';
        for (const [id, client] of this.clients) {
            if (client.subscriptions.has(topic) || client.subscriptions.has('*')) {
                if (client.socket?.writable) {
                    client.socket.write(msg);
                }
            }
        }
    }

    /**
     * Register built-in IPC handlers
     */
    _registerBuiltinHandlers() {
        // System status
        this.handlers.set('system.status', () => {
            return this.kernel.getStatus();
        });

        // Subscribe to events
        this.handlers.set('system.subscribe', (params, clientId) => {
            const client = this.clients.get(clientId);
            if (client && params?.topics) {
                for (const topic of params.topics) {
                    client.subscriptions.add(topic);
                }
            }
            return { subscribed: params?.topics || [] };
        });

        // Identify client
        this.handlers.set('system.identify', (params, clientId) => {
            const client = this.clients.get(clientId);
            if (client && params?.name) {
                client.name = params.name;
            }
            return { clientId, name: params?.name };
        });

        // Process management
        this.handlers.set('process.list', () => {
            return this.kernel.processes.getStatus();
        });

        this.handlers.set('process.restart', async (params) => {
            const { name } = params;
            await this.kernel.processes.stop(name);
            // Kernel will auto-restart via health check
            return { restarting: name };
        });

        // Hardware info
        this.handlers.set('hardware.info', async () => {
            return await this.kernel.hardware.snapshot();
        });

        // WebMCP bridge status
        this.handlers.set('webmcp.status', () => {
            return {
                connected: this.kernel.webmcpBridge?.isConnected() || false,
                tools: this.kernel.webmcpBridge?.getRegisteredTools() || [],
            };
        });

        // Execute tool via OpenWhale
        this.handlers.set('agent.execute', async (params) => {
            const { tool, args } = params;
            try {
                const res = await fetch(`http://localhost:${this.kernel.config.openwhale.port}/api/tool`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ tool, params: args }),
                });
                return await res.json();
            } catch (err) {
                throw new Error(`Tool execution failed: ${err.message}`);
            }
        });

        // Send chat message to OpenWhale
        this.handlers.set('agent.chat', async (params) => {
            const { message, sessionId } = params;
            try {
                const res = await fetch(`http://localhost:${this.kernel.config.openwhale.port}/api/chat`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ message, sessionId }),
                });
                return await res.json();
            } catch (err) {
                throw new Error(`Chat failed: ${err.message}`);
            }
        });
    }

    close() {
        for (const [id, client] of this.clients) {
            client.socket.destroy();
        }
        this.clients.clear();
        this.server?.close();
        this.log.info('IPC server closed');
    }
}

async function createIPCServer(socketPath, kernel) {
    const log = kernel.log;
    const server = new IPCServer(socketPath, kernel, log);
    await server.start();
    return server;
}

export { createIPCServer, IPCServer };
