/**
 * Generic MCP Client — stdio transport
 * 
 * Generalized from ChromeMCPClient. Connects to any MCP server via stdio,
 * performs JSON-RPC 2.0 handshake, discovers tools, and calls them.
 */

import { spawn, type ChildProcess } from "node:child_process";
import { logger } from "../logger.js";

export interface MCPToolDef {
    name: string;
    description?: string;
    inputSchema?: Record<string, unknown>;
}

interface MCPResponse {
    jsonrpc: "2.0";
    id: number;
    result?: unknown;
    error?: { code: number; message: string; data?: unknown };
}

export class GenericMCPClient {
    private process: ChildProcess | null = null;
    private requestId = 0;
    private pendingRequests = new Map<number, {
        resolve: (value: MCPResponse) => void;
        reject: (error: Error) => void;
        timeout: NodeJS.Timeout;
    }>();
    private buffer = "";
    private initialized = false;
    private tools: MCPToolDef[] = [];
    public serverId: string;

    constructor(serverId: string) {
        this.serverId = serverId;
    }

    get isRunning(): boolean {
        return this.process !== null && !this.process.killed && this.initialized;
    }

    /**
     * Start an MCP server via command + args
     */
    async start(command: string, args: string[], env?: Record<string, string>): Promise<boolean> {
        if (this.process && !this.process.killed) return true;

        return new Promise<boolean>((resolve) => {
            try {
                this.process = spawn(command, args, {
                    stdio: ["pipe", "pipe", "pipe"],
                    env: { ...process.env, NODE_NO_WARNINGS: "1", ...env },
                    shell: true,
                });

                this.process.stdout?.on("data", (chunk: Buffer) => {
                    this.buffer += chunk.toString();
                    this.processBuffer();
                });

                this.process.stderr?.on("data", (chunk: Buffer) => {
                    const text = chunk.toString().trim();
                    if (text) logger.debug("mcp", `[${this.serverId}] stderr: ${text.slice(0, 200)}`);
                });

                this.process.on("error", (err) => {
                    logger.error("mcp", `[${this.serverId}] Process error: ${err.message}`);
                    this.cleanup();
                });

                this.process.on("exit", (code) => {
                    logger.debug("mcp", `[${this.serverId}] Exited with code ${code}`);
                    this.cleanup();
                });

                // Wait for process to start, then MCP handshake
                setTimeout(async () => {
                    try {
                        resolve(await this.initialize());
                    } catch {
                        resolve(false);
                    }
                }, 4000);
            } catch (err) {
                logger.error("mcp", `[${this.serverId}] Spawn failed: ${err instanceof Error ? err.message : String(err)}`);
                resolve(false);
            }
        });
    }

    private processBuffer(): void {
        const lines = this.buffer.split("\n");
        this.buffer = lines.pop() || "";

        for (const line of lines) {
            const trimmed = line.trim();
            if (!trimmed) continue;
            try {
                const msg = JSON.parse(trimmed) as MCPResponse;
                if (msg.id !== undefined) {
                    const pending = this.pendingRequests.get(msg.id);
                    if (pending) {
                        clearTimeout(pending.timeout);
                        this.pendingRequests.delete(msg.id);
                        pending.resolve(msg);
                    }
                }
            } catch { /* not JSON */ }
        }
    }

    private async sendRequest(method: string, params?: Record<string, unknown>): Promise<{
        success: boolean;
        result?: unknown;
        error?: string;
    }> {
        if (!this.process || this.process.killed) {
            return { success: false, error: `MCP server ${this.serverId} not running` };
        }

        const id = ++this.requestId;

        return new Promise((resolve) => {
            const timeout = setTimeout(() => {
                this.pendingRequests.delete(id);
                resolve({ success: false, error: `Request timeout (${method})` });
            }, 30000);

            this.pendingRequests.set(id, {
                resolve: (response: MCPResponse) => {
                    if (response.error) {
                        resolve({ success: false, error: response.error.message });
                    } else {
                        resolve({ success: true, result: response.result });
                    }
                },
                reject: (error: Error) => {
                    resolve({ success: false, error: error.message });
                },
                timeout,
            });

            try {
                this.process!.stdin?.write(JSON.stringify({
                    jsonrpc: "2.0",
                    id,
                    method,
                    params: params || {},
                }) + "\n");
            } catch (err) {
                clearTimeout(timeout);
                this.pendingRequests.delete(id);
                resolve({ success: false, error: err instanceof Error ? err.message : "Write failed" });
            }
        });
    }

    private async initialize(): Promise<boolean> {
        if (this.initialized) return true;

        const result = await this.sendRequest("initialize", {
            protocolVersion: "2024-11-05",
            capabilities: { tools: {} },
            clientInfo: { name: "OpenWhale-TensorAgentOS", version: "0.1.0" },
        });

        if (!result.success) {
            logger.error("mcp", `[${this.serverId}] Initialize failed: ${result.error}`);
            return false;
        }

        // Send initialized notification
        if (this.process && !this.process.killed) {
            try {
                this.process.stdin?.write(JSON.stringify({
                    jsonrpc: "2.0",
                    method: "notifications/initialized",
                    params: {},
                }) + "\n");
            } catch { /* ignore */ }
        }

        // Discover tools
        const toolsResult = await this.sendRequest("tools/list", {});
        if (toolsResult.success && toolsResult.result) {
            const data = toolsResult.result as { tools?: MCPToolDef[] };
            this.tools = data.tools || [];
            logger.info("mcp", `[${this.serverId}] Initialized with ${this.tools.length} tools: ${this.tools.map(t => t.name).join(", ")}`);
        }

        this.initialized = true;
        return true;
    }

    async callTool(name: string, args: Record<string, unknown> = {}): Promise<{
        success: boolean;
        content: string;
        error?: string;
        metadata?: Record<string, unknown>;
    }> {
        if (!this.initialized) {
            return { success: false, content: "", error: `MCP server ${this.serverId} not initialized` };
        }

        logger.debug("mcp", `[${this.serverId}] → ${name}`, { args });

        const result = await this.sendRequest("tools/call", { name, arguments: args });
        if (!result.success) return { success: false, content: "", error: result.error };

        const data = result.result as {
            content?: Array<{ type: string; text?: string; data?: string; mimeType?: string }>;
            isError?: boolean;
        };

        if (data?.isError) {
            const errorText = data.content?.[0]?.text || "Tool execution failed";
            return { success: false, content: "", error: errorText };
        }

        // Extract text content
        let text = "";
        let metadata: Record<string, unknown> | undefined;
        if (data?.content) {
            const texts = data.content.filter(c => c.type === "text" && c.text).map(c => c.text!);
            text = texts.join("\n");

            // Extract images
            const img = data.content.find(c => c.type === "image" && c.data);
            if (img?.data) {
                metadata = { image: `data:${img.mimeType || "image/png"};base64,${img.data}` };
            }
        }

        if (!text) text = JSON.stringify(result.result, null, 2);

        return { success: true, content: text, metadata };
    }

    getTools(): MCPToolDef[] { return this.tools; }
    getToolNames(): string[] { return this.tools.map(t => t.name); }

    stop(): void { this.cleanup(); }

    private cleanup(): void {
        this.pendingRequests.forEach((pending) => {
            clearTimeout(pending.timeout);
            pending.reject(new Error("Process terminated"));
        });
        this.pendingRequests.clear();

        if (this.process && !this.process.killed) {
            this.process.kill();
        }
        this.process = null;
        this.initialized = false;
        this.buffer = "";
        this.tools = [];
    }
}
