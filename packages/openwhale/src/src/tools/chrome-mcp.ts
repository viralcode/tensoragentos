/**
 * Chrome DevTools MCP Backend
 * 
 * Integrates Google's Chrome DevTools MCP server for browser automation.
 * Uses stdio transport to communicate with `chrome-devtools-mcp` via child process.
 * 
 * This gives the AI agent access to real Chrome DevTools capabilities:
 * - Page navigation and interaction
 * - Network request inspection
 * - Console monitoring
 * - Performance tracing
 * - Screenshot capture
 * - JavaScript evaluation
 * 
 * @see https://www.npmjs.com/package/chrome-devtools-mcp
 */

import type { ToolResult } from "./base.js";
import { logger } from "../logger.js";
import { spawn, exec, type ChildProcess } from "node:child_process";
import { promisify } from "node:util";

const execAsync = promisify(exec);

// ============================================================================
// STDIO MCP CLIENT for Chrome DevTools
// ============================================================================

interface MCPRequest {
    jsonrpc: "2.0";
    id: number;
    method: string;
    params?: Record<string, unknown>;
}

interface MCPResponse {
    jsonrpc: "2.0";
    id: number;
    result?: unknown;
    error?: { code: number; message: string; data?: unknown };
}

interface MCPToolDef {
    name: string;
    description?: string;
    inputSchema?: Record<string, unknown>;
}

class ChromeMCPClient {
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

    /**
     * Start the chrome-devtools-mcp process
     */
    async start(browserUrl: string = "http://127.0.0.1:9222"): Promise<boolean> {
        if (this.process && !this.process.killed) {
            return true;
        }

        return new Promise<boolean>((resolve) => {
            try {
                // Spawn the MCP server as a child process using stdio transport
                this.process = spawn("npx", [
                    "-y",
                    "chrome-devtools-mcp@latest",
                    `--browserUrl=${browserUrl}`,
                ], {
                    stdio: ["pipe", "pipe", "pipe"],
                    env: { ...process.env, NODE_NO_WARNINGS: "1" },
                    shell: true,
                });

                // Handle stdout (MCP responses come here)
                this.process.stdout?.on("data", (chunk: Buffer) => {
                    this.buffer += chunk.toString();
                    this.processBuffer();
                });

                // Handle stderr (debug/error output)
                this.process.stderr?.on("data", (chunk: Buffer) => {
                    const text = chunk.toString().trim();
                    if (text) {
                        logger.debug("tool", `[ChromeMCP stderr] ${text}`);
                    }
                });

                this.process.on("error", (err) => {
                    logger.error("tool", `[ChromeMCP] Process error: ${err.message}`);
                    this.cleanup();
                });

                this.process.on("exit", (code) => {
                    logger.debug("tool", `[ChromeMCP] Process exited with code ${code}`);
                    this.cleanup();
                });

                // Give the process time to start, then initialize
                setTimeout(async () => {
                    try {
                        const initResult = await this.initialize();
                        resolve(initResult);
                    } catch {
                        resolve(false);
                    }
                }, 2000);

            } catch (err) {
                logger.error("tool", `[ChromeMCP] Failed to spawn: ${err instanceof Error ? err.message : String(err)}`);
                resolve(false);
            }
        });
    }

    /**
     * Process incoming buffer for complete JSON-RPC messages
     */
    private processBuffer(): void {
        // Messages are delimited by newlines
        const lines = this.buffer.split("\n");
        this.buffer = lines.pop() || ""; // Keep incomplete last line

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
            } catch {
                // Not valid JSON, could be partial or log output
            }
        }
    }

    /**
     * Send a JSON-RPC request and wait for response
     */
    private async sendRequest(method: string, params?: Record<string, unknown>): Promise<{
        success: boolean;
        result?: unknown;
        error?: string;
    }> {
        if (!this.process || this.process.killed) {
            return { success: false, error: "Chrome MCP process not running" };
        }

        const id = ++this.requestId;
        const request: MCPRequest = {
            jsonrpc: "2.0",
            id,
            method,
            params: params || {},
        };

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
                this.process!.stdin?.write(JSON.stringify(request) + "\n");
            } catch (err) {
                clearTimeout(timeout);
                this.pendingRequests.delete(id);
                resolve({ success: false, error: err instanceof Error ? err.message : "Write failed" });
            }
        });
    }

    /**
     * Initialize MCP connection
     */
    private async initialize(): Promise<boolean> {
        if (this.initialized) return true;

        const result = await this.sendRequest("initialize", {
            protocolVersion: "2024-11-05",
            capabilities: { tools: {} },
            clientInfo: { name: "OpenWhale-TensorAgentOS", version: "0.1.0" },
        });

        if (!result.success) {
            logger.error("tool", `[ChromeMCP] Initialize failed: ${result.error}`);
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

        // Load tools
        const toolsResult = await this.sendRequest("tools/list", {});
        if (toolsResult.success && toolsResult.result) {
            const data = toolsResult.result as { tools?: MCPToolDef[] };
            this.tools = data.tools || [];
            logger.info("tool", `[ChromeMCP] Initialized with ${this.tools.length} tools`);
        }

        this.initialized = true;
        return true;
    }

    /**
     * Call a Chrome DevTools MCP tool
     */
    async callTool(name: string, args: Record<string, unknown> = {}): Promise<{
        success: boolean;
        result?: unknown;
        error?: string;
    }> {
        if (!this.initialized) {
            return { success: false, error: "Chrome MCP not initialized" };
        }

        logger.debug("tool", `[ChromeMCP] Calling tool: ${name}`, { args });

        const result = await this.sendRequest("tools/call", {
            name,
            arguments: args,
        });

        if (!result.success) {
            return result;
        }

        // Extract content from MCP response
        const data = result.result as { content?: Array<{ type: string; text?: string; data?: string }>; isError?: boolean };
        if (data?.isError) {
            const errorText = data.content?.[0]?.text || "Tool execution failed";
            return { success: false, error: errorText };
        }

        return result;
    }

    /**
     * Get available tools
     */
    getTools(): MCPToolDef[] {
        return this.tools;
    }

    /**
     * Stop the MCP process
     */
    stop(): void {
        this.cleanup();
    }

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
    }
}

// ============================================================================
// CHROME MCP BACKEND
// ============================================================================

let chromeMCPClient: ChromeMCPClient | null = null;

/**
 * Check if Chromium/Chrome is available on the system
 */
export async function isChromiumAvailable(): Promise<{ available: boolean; path?: string }> {
    const paths = [
        // Linux (TensorAgent OS)
        "/usr/bin/chromium",
        "/usr/bin/chromium-browser",
        "/usr/bin/google-chrome",
        "/usr/bin/google-chrome-stable",
        "/opt/ainux/chromium/chrome",
        "/snap/bin/chromium",
        // macOS
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
        "/Applications/Chromium.app/Contents/MacOS/Chromium",
    ];

    const { existsSync } = await import("node:fs");

    for (const p of paths) {
        if (existsSync(p)) {
            return { available: true, path: p };
        }
    }

    // Try which command
    try {
        const { stdout } = await execAsync("which chromium-browser || which chromium || which google-chrome 2>/dev/null");
        const chromePath = stdout.trim();
        if (chromePath) {
            return { available: true, path: chromePath };
        }
    } catch { /* not found */ }

    return { available: false };
}

/**
 * Launch Chrome with remote debugging enabled
 */
export async function launchChromeWithDebugging(port: number = 9222): Promise<{
    success: boolean;
    pid?: number;
    error?: string;
}> {
    const chrome = await isChromiumAvailable();
    if (!chrome.available || !chrome.path) {
        return { success: false, error: "Chrome/Chromium not found. Install with: sudo apt install chromium" };
    }

    // Check if already running on this port
    try {
        const res = await fetch(`http://127.0.0.1:${port}/json/version`, {
            signal: AbortSignal.timeout(2000),
        });
        if (res.ok) {
            logger.info("tool", `[ChromeMCP] Chrome already running on port ${port}`);
            return { success: true };
        }
    } catch { /* not running */ }

    // Launch Chrome with remote debugging
    const chromeProcess = spawn(chrome.path, [
        `--remote-debugging-port=${port}`,
        "--no-sandbox",
        "--disable-gpu",
        "--headless=new",
        "--disable-dev-shm-usage",
        `--user-data-dir=/tmp/chrome-mcp-profile`,
        "--no-first-run",
        "--no-default-browser-check",
    ], {
        detached: true,
        stdio: "ignore",
    });

    chromeProcess.unref();

    // Wait for Chrome to be ready
    for (let i = 0; i < 15; i++) {
        await new Promise(r => setTimeout(r, 1000));
        try {
            const res = await fetch(`http://127.0.0.1:${port}/json/version`, {
                signal: AbortSignal.timeout(1000),
            });
            if (res.ok) {
                logger.info("tool", `[ChromeMCP] Chrome launched on port ${port}`);
                return { success: true, pid: chromeProcess.pid };
            }
        } catch { /* still starting */ }
    }

    return { success: false, error: "Chrome launched but debugger not responding after 15s" };
}

/**
 * Check if Chrome DevTools MCP is available
 */
export async function isChromeMCPAvailable(port: number = 9222): Promise<{
    available: boolean;
    chromeRunning: boolean;
    mcpReady: boolean;
    error?: string;
}> {
    // Check if Chrome is running with debugging
    let chromeRunning = false;
    try {
        const res = await fetch(`http://127.0.0.1:${port}/json/version`, {
            signal: AbortSignal.timeout(2000),
        });
        chromeRunning = res.ok;
    } catch { /* not running */ }

    // Check if MCP client is connected
    const mcpReady = chromeMCPClient?.getTools().length ? true : false;

    return {
        available: chromeRunning && mcpReady,
        chromeRunning,
        mcpReady,
        error: !chromeRunning ? "Chrome not running with remote debugging" : (!mcpReady ? "MCP client not connected" : undefined),
    };
}

/**
 * Ensure Chrome MCP is running (launch Chrome + connect MCP)
 */
export async function ensureChromeMCPRunning(port: number = 9222): Promise<{
    success: boolean;
    tools: string[];
    error?: string;
}> {
    // Step 1: Launch Chrome with debugging if needed
    const launchResult = await launchChromeWithDebugging(port);
    if (!launchResult.success) {
        return { success: false, tools: [], error: launchResult.error };
    }

    // Step 2: Start MCP client if needed
    if (!chromeMCPClient) {
        chromeMCPClient = new ChromeMCPClient();
    }

    const started = await chromeMCPClient.start(`http://127.0.0.1:${port}`);
    if (!started) {
        return {
            success: false,
            tools: [],
            error: "Failed to start chrome-devtools-mcp. Ensure it's installed: npx chrome-devtools-mcp@latest --help"
        };
    }

    const tools = chromeMCPClient.getTools().map(t => t.name);
    return { success: true, tools };
}

// ============================================================================
// CHROME MCP BROWSER BACKEND (same interface as BrowserOSBackend)
// ============================================================================

export class ChromeMCPBackend {
    private port: number;

    constructor(port: number = 9222) {
        this.port = port;
    }

    private async ensureReady(): Promise<boolean> {
        const result = await ensureChromeMCPRunning(this.port);
        return result.success;
    }

    private async call(toolName: string, args: Record<string, unknown> = {}): Promise<{
        success: boolean;
        result?: unknown;
        error?: string;
    }> {
        if (!chromeMCPClient) {
            return { success: false, error: "Chrome MCP client not initialized" };
        }
        return chromeMCPClient.callTool(toolName, args);
    }

    async getStatus(): Promise<{ running: boolean; tools?: number; backend: string }> {
        const status = await isChromeMCPAvailable(this.port);
        return {
            running: status.available,
            tools: chromeMCPClient?.getTools().length || 0,
            backend: "chrome-mcp",
        };
    }

    async navigate(url: string): Promise<ToolResult> {
        await this.ensureReady();
        // Chrome DevTools MCP typically has navigate or browser_navigate
        const result = await this.call("navigate", { url })
            || await this.call("browser_navigate", { url });

        if (!result.success) {
            return { success: false, content: "", error: result.error || "Navigate failed" };
        }
        return { success: true, content: `Navigated to ${url}` };
    }

    async click(selector: string): Promise<ToolResult> {
        const result = await this.call("click", { selector })
            || await this.call("browser_click", { selector });
        return {
            success: result.success,
            content: result.success ? `Clicked: ${selector}` : "",
            error: result.error,
        };
    }

    async type(selector: string, text: string): Promise<ToolResult> {
        const result = await this.call("type", { selector, text })
            || await this.call("browser_type", { selector, text });
        return {
            success: result.success,
            content: result.success ? `Typed into: ${selector}` : "",
            error: result.error,
        };
    }

    async screenshot(): Promise<ToolResult> {
        const result = await this.call("screenshot", {})
            || await this.call("browser_screenshot", {});

        if (!result.success) {
            return { success: false, content: "", error: result.error };
        }

        // Extract image data from MCP response
        const data = result.result as {
            content?: Array<{ type: string; data?: string; text?: string }>;
        };

        let base64: string | undefined;
        if (data?.content) {
            const imgContent = data.content.find(c => c.type === "image" || c.type === "image/png");
            if (imgContent?.data) {
                base64 = imgContent.data;
            }
        }

        return {
            success: true,
            content: "Screenshot captured via Chrome DevTools MCP",
            metadata: base64 ? { image: `data:image/png;base64,${base64}`, base64 } : undefined,
        };
    }

    async snapshot(): Promise<ToolResult> {
        // Try to get accessibility snapshot or page content
        const result = await this.call("accessibility_snapshot", {})
            || await this.call("browser_snapshot", {})
            || await this.call("get_page_content", {});

        if (!result.success) {
            return { success: false, content: "", error: result.error };
        }

        const data = result.result as { content?: Array<{ text?: string }> };
        const text = data?.content?.[0]?.text || JSON.stringify(result.result);

        return { success: true, content: text };
    }

    async evaluate(script: string): Promise<ToolResult> {
        const result = await this.call("evaluate", { expression: script })
            || await this.call("browser_evaluate", { code: script });

        if (!result.success) {
            return { success: false, content: "", error: result.error };
        }

        const data = result.result as { content?: Array<{ text?: string }> };
        const output = data?.content?.[0]?.text || JSON.stringify(result.result);

        return { success: true, content: output };
    }

    async getConsole(): Promise<ToolResult> {
        const result = await this.call("console_messages", {})
            || await this.call("browser_console", {});

        if (!result.success) {
            return { success: false, content: "", error: result.error };
        }

        const data = result.result as { content?: Array<{ text?: string }> };
        const text = data?.content?.[0]?.text || JSON.stringify(result.result);

        return { success: true, content: text };
    }

    async getNetwork(): Promise<ToolResult> {
        const result = await this.call("network_requests", {})
            || await this.call("browser_network", {});

        if (!result.success) {
            return { success: false, content: "", error: result.error };
        }

        const data = result.result as { content?: Array<{ text?: string }> };
        const text = data?.content?.[0]?.text || JSON.stringify(result.result);

        return { success: true, content: text };
    }

    async performanceTrace(): Promise<ToolResult> {
        const result = await this.call("performance_trace", {})
            || await this.call("browser_performance", {});

        if (!result.success) {
            return { success: false, content: "", error: result.error };
        }

        const data = result.result as { content?: Array<{ text?: string }> };
        const text = data?.content?.[0]?.text || JSON.stringify(result.result);

        return { success: true, content: text };
    }

    stop(): void {
        if (chromeMCPClient) {
            chromeMCPClient.stop();
            chromeMCPClient = null;
        }
    }
}
