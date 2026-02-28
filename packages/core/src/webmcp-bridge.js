/**
 * AInux WebMCP Bridge
 * 
 * Connects OpenWhale's tool system to Chromium's navigator.modelContext API
 * via Chrome DevTools Protocol (CDP).
 * 
 * Architecture:
 * 1. Connects to Chromium via CDP (ws://localhost:9222)
 * 2. Fetches OpenWhale's tool registry
 * 3. Injects WebMCP registration code into the browser
 * 4. Exposes all OpenWhale tools as WebMCP tools
 * 5. Handles bi-directional tool invocation
 */

import WebSocket from 'ws';

class WebMCPBridge {
    constructor(options) {
        this.cdpPort = options.cdpPort || 9222;
        this.openwhalePort = options.openwhalePort || 7777;
        this.log = options.log.child('webmcp');
        this.ws = null;
        this.connected = false;
        this.registeredTools = [];
        this.messageId = 0;
        this.pendingMessages = new Map();
        this.reconnectTimer = null;
    }

    /**
     * Connect to Chromium via CDP and initialize WebMCP bridge
     */
    async connect() {
        try {
            // Get CDP WebSocket URL
            const wsUrl = await this._getCDPWebSocketUrl();
            if (!wsUrl) {
                this.log.warn('Chromium CDP not available yet, will retry...');
                this._scheduleReconnect();
                return;
            }

            this.log.info(`Connecting to CDP: ${wsUrl}`);
            this.ws = new WebSocket(wsUrl);

            this.ws.on('open', async () => {
                this.connected = true;
                this.log.success('CDP connection established');

                // Enable necessary CDP domains
                await this._cdpSend('Runtime.enable');
                await this._cdpSend('Page.enable');
                await this._cdpSend('Network.enable');

                // Fetch OpenWhale tools and register them via WebMCP
                await this._registerOpenWhaleTools();

                // Listen for page navigations to re-register tools
                this.ws.on('message', (data) => {
                    try {
                        const msg = JSON.parse(data.toString());
                        this._handleCDPMessage(msg);
                    } catch { /* ignore parse errors */ }
                });
            });

            this.ws.on('close', () => {
                this.connected = false;
                this.log.warn('CDP connection lost');
                this._scheduleReconnect();
            });

            this.ws.on('error', (err) => {
                this.log.error(`CDP error: ${err.message}`);
            });
        } catch (err) {
            this.log.error(`WebMCP bridge connection failed: ${err.message}`);
            this._scheduleReconnect();
        }
    }

    /**
     * Register all OpenWhale tools as WebMCP tools in the browser
     */
    async _registerOpenWhaleTools() {
        try {
            // Fetch tool list from OpenWhale
            const res = await fetch(`http://localhost:${this.openwhalePort}/api/tools`);
            if (!res.ok) {
                this.log.warn('OpenWhale tools API not available yet');
                return;
            }
            const tools = await res.json();
            this.registeredTools = tools;

            this.log.info(`Registering ${tools.length} OpenWhale tools via WebMCP...`);

            // Inject the WebMCP registration script
            const script = this._generateWebMCPRegistrationScript(tools);
            await this._cdpSend('Runtime.evaluate', {
                expression: script,
                awaitPromise: true,
            });

            this.log.success(`${tools.length} tools registered via WebMCP`);

            // Also register AInux OS-level tools
            await this._registerSystemTools();
        } catch (err) {
            this.log.error(`Tool registration failed: ${err.message}`);
        }
    }

    /**
     * Register AInux system-level tools
     */
    async _registerSystemTools() {
        const systemTools = [
            {
                name: 'ainux.screenshot',
                description: 'Capture current screen state',
                inputSchema: { type: 'object', properties: {} },
            },
            {
                name: 'ainux.system_info',
                description: 'Get CPU, memory, GPU, network status',
                inputSchema: { type: 'object', properties: {} },
            },
            {
                name: 'ainux.open_terminal',
                description: 'Open an embedded terminal session',
                inputSchema: {
                    type: 'object',
                    properties: {
                        command: { type: 'string', description: 'Initial command to run' },
                    },
                },
            },
            {
                name: 'ainux.navigate',
                description: 'Navigate browser to a URL',
                inputSchema: {
                    type: 'object',
                    properties: {
                        url: { type: 'string', description: 'URL to navigate to' },
                    },
                    required: ['url'],
                },
            },
            {
                name: 'ainux.dom_query',
                description: 'Query DOM elements on the current page',
                inputSchema: {
                    type: 'object',
                    properties: {
                        selector: { type: 'string', description: 'CSS selector' },
                    },
                    required: ['selector'],
                },
            },
        ];

        const script = this._generateWebMCPRegistrationScript(systemTools, true);
        await this._cdpSend('Runtime.evaluate', {
            expression: script,
            awaitPromise: true,
        });

        this.log.success(`${systemTools.length} system tools registered via WebMCP`);
    }

    /**
     * Generate JavaScript to inject into the browser page
     * that registers tools via navigator.modelContext
     */
    _generateWebMCPRegistrationScript(tools, isSystem = false) {
        const port = this.openwhalePort;
        const toolsJson = JSON.stringify(tools);

        return `
      (async () => {
        // Wait for navigator.modelContext to be available
        if (!navigator.modelContext) {
          console.warn('[AInux WebMCP] navigator.modelContext not available');
          return { registered: 0 };
        }

        const tools = ${toolsJson};
        let registered = 0;

        for (const tool of tools) {
          try {
            navigator.modelContext.registerTool({
              name: tool.name,
              description: tool.description,
              inputSchema: tool.inputSchema || tool.schema || { type: 'object', properties: {} },
              execute: async (params) => {
                ${isSystem ? `
                  // System tools call the AInux kernel IPC
                  const res = await fetch('http://localhost:${port}/api/ainux/system-tool', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ tool: tool.name, params })
                  });
                  return await res.json();
                ` : `
                  // OpenWhale tools call the OpenWhale API
                  const res = await fetch('http://localhost:${port}/api/tool', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ tool: tool.name, params })
                  });
                  return await res.json();
                `}
              }
            });
            registered++;
          } catch (err) {
            console.warn('[AInux WebMCP] Failed to register tool:', tool.name, err);
          }
        }

        console.log('[AInux WebMCP] Registered ' + registered + '/${isSystem ? 'system' : 'OpenWhale'} tools');
        return { registered };
      })()
    `;
    }

    /**
     * Handle CDP messages (events and responses)
     */
    _handleCDPMessage(msg) {
        // Handle responses to our commands
        if (msg.id && this.pendingMessages.has(msg.id)) {
            const { resolve, reject } = this.pendingMessages.get(msg.id);
            this.pendingMessages.delete(msg.id);
            if (msg.error) {
                reject(new Error(msg.error.message));
            } else {
                resolve(msg.result);
            }
        }

        // Handle events
        if (msg.method) {
            switch (msg.method) {
                case 'Page.loadEventFired':
                    // Re-register tools on page load
                    this.log.debug('Page loaded, re-registering WebMCP tools...');
                    setTimeout(() => this._registerOpenWhaleTools(), 1000);
                    break;

                case 'Page.navigatedWithinDocument':
                    this.log.debug(`Navigation: ${msg.params?.url}`);
                    break;

                case 'Network.requestWillBeSent':
                    // Could intercept network requests for AI routing
                    break;
            }
        }
    }

    /**
     * Send a CDP command
     */
    _cdpSend(method, params = {}) {
        return new Promise((resolve, reject) => {
            if (!this.ws || this.ws.readyState !== WebSocket.OPEN) {
                reject(new Error('CDP not connected'));
                return;
            }

            const id = ++this.messageId;
            this.pendingMessages.set(id, { resolve, reject });

            const timeout = setTimeout(() => {
                if (this.pendingMessages.has(id)) {
                    this.pendingMessages.delete(id);
                    reject(new Error(`CDP command timeout: ${method}`));
                }
            }, 10_000);

            this.ws.send(JSON.stringify({ id, method, params }));
        });
    }

    /**
     * Get the CDP WebSocket URL from Chromium's debug endpoint
     */
    async _getCDPWebSocketUrl() {
        try {
            const res = await fetch(`http://localhost:${this.cdpPort}/json/version`);
            const data = await res.json();
            return data.webSocketDebuggerUrl;
        } catch {
            return null;
        }
    }

    /**
     * Schedule a reconnection attempt
     */
    _scheduleReconnect() {
        if (this.reconnectTimer) return;
        this.reconnectTimer = setTimeout(() => {
            this.reconnectTimer = null;
            this.log.info('Attempting CDP reconnection...');
            this.connect();
        }, 5_000);
    }

    /**
     * Disconnect from CDP
     */
    async disconnect() {
        clearTimeout(this.reconnectTimer);
        if (this.ws) {
            this.ws.close();
            this.ws = null;
        }
        this.connected = false;
        this.log.info('WebMCP bridge disconnected');
    }

    isConnected() {
        return this.connected;
    }

    getRegisteredTools() {
        return this.registeredTools.map(t => t.name);
    }
}

export { WebMCPBridge };
