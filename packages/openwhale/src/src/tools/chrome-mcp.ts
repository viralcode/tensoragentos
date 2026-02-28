/**
 * Chrome DevTools MCP Backend — v0.18.1 (Feb 2026)
 * 
 * Integrates Google's official Chrome DevTools MCP server for browser automation.
 * Uses stdio transport to communicate with `chrome-devtools-mcp` via child process.
 * 
 * This is the latest (v0.18.1) tool set from Google's chrome-devtools-mcp:
 * 
 * INPUT:       click, drag, fill, fill_form, handle_dialog, hover, press_key, type_text, upload_file
 * NAVIGATION:  close_page, list_pages, navigate_page, new_page, select_page, wait_for
 * EMULATION:   emulate_cpu, emulate_network, resize_page
 * PERFORMANCE: performance_start_trace, performance_stop_trace, performance_analyze_insight, take_memory_snapshot
 * NETWORK:     get_network_request, list_network_requests
 * DEBUGGING:   evaluate_script, get_console_message, list_console_messages, take_screenshot, take_snapshot
 * 
 * v0.18 features: --slim mode for token savings, accessibility debugging/auditing,
 *                 experimental screencast recording, LCP optimization debugging,
 *                 storage-isolated browser contexts, Linux X server display fix
 * 
 * @see https://github.com/nichochar/chrome-devtools-mcp
 * @see https://www.npmjs.com/package/chrome-devtools-mcp
 */

import type { ToolResult } from "./base.js";
import { logger } from "../logger.js";
import { spawn, exec, type ChildProcess } from "node:child_process";
import { promisify } from "node:util";

const execAsync = promisify(exec);

// ============================================================================
// STDIO MCP CLIENT for Chrome DevTools MCP
// ============================================================================

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
     * Start the chrome-devtools-mcp process via npx (v0.18+)
     */
    async start(browserUrl: string = "http://127.0.0.1:9222"): Promise<boolean> {
        if (this.process && !this.process.killed) {
            return true;
        }

        return new Promise<boolean>((resolve) => {
            try {
                this.process = spawn("npx", [
                    "-y",
                    "chrome-devtools-mcp@latest",
                    `--browserUrl=${browserUrl}`,
                ], {
                    stdio: ["pipe", "pipe", "pipe"],
                    env: { ...process.env, NODE_NO_WARNINGS: "1" },
                    shell: true,
                });

                this.process.stdout?.on("data", (chunk: Buffer) => {
                    this.buffer += chunk.toString();
                    this.processBuffer();
                });

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

                // Wait for process to start, then MCP handshake
                setTimeout(async () => {
                    try {
                        resolve(await this.initialize());
                    } catch {
                        resolve(false);
                    }
                }, 3000);

            } catch (err) {
                logger.error("tool", `[ChromeMCP] Failed to spawn: ${err instanceof Error ? err.message : String(err)}`);
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
            return { success: false, error: "Chrome MCP process not running" };
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

        // Discover tools
        const toolsResult = await this.sendRequest("tools/list", {});
        if (toolsResult.success && toolsResult.result) {
            const data = toolsResult.result as { tools?: MCPToolDef[] };
            this.tools = data.tools || [];
            logger.info("tool", `[ChromeMCP] v0.18+ initialized with ${this.tools.length} tools: ${this.tools.map(t => t.name).join(", ")}`);
        }

        this.initialized = true;
        return true;
    }

    async callTool(name: string, args: Record<string, unknown> = {}): Promise<{
        success: boolean;
        result?: unknown;
        error?: string;
    }> {
        if (!this.initialized) {
            return { success: false, error: "Chrome MCP not initialized" };
        }

        logger.debug("tool", `[ChromeMCP] → ${name}`, { args });

        const result = await this.sendRequest("tools/call", {
            name,
            arguments: args,
        });

        if (!result.success) return result;

        const data = result.result as { content?: Array<{ type: string; text?: string; data?: string }>; isError?: boolean };
        if (data?.isError) {
            const errorText = data.content?.[0]?.text || "Tool execution failed";
            return { success: false, error: errorText };
        }

        return result;
    }

    // Helper: extract text content from MCP response
    static extractText(result: { result?: unknown }): string {
        const data = result.result as { content?: Array<{ type: string; text?: string }> };
        if (data?.content) {
            const texts = data.content.filter(c => c.type === "text" && c.text).map(c => c.text!);
            if (texts.length > 0) return texts.join("\n");
        }
        return JSON.stringify(result.result, null, 2);
    }

    // Helper: extract base64 image from MCP response
    static extractImage(result: { result?: unknown }): string | undefined {
        const data = result.result as { content?: Array<{ type: string; data?: string }> };
        if (data?.content) {
            const img = data.content.find(c => c.type === "image" && c.data);
            return img?.data;
        }
        return undefined;
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
    }
}

// ============================================================================
// CHROME DETECTION & LAUNCH
// ============================================================================

let chromeMCPClient: ChromeMCPClient | null = null;

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
        if (existsSync(p)) return { available: true, path: p };
    }

    try {
        const { stdout } = await execAsync("which chromium-browser || which chromium || which google-chrome 2>/dev/null");
        const chromePath = stdout.trim();
        if (chromePath) return { available: true, path: chromePath };
    } catch { /* not found */ }

    return { available: false };
}

export async function launchChromeWithDebugging(port: number = 9222): Promise<{
    success: boolean;
    pid?: number;
    error?: string;
}> {
    const chrome = await isChromiumAvailable();
    if (!chrome.available || !chrome.path) {
        return { success: false, error: "Chrome/Chromium not found. Install with: sudo apt install chromium" };
    }

    // Already running?
    try {
        const res = await fetch(`http://127.0.0.1:${port}/json/version`, { signal: AbortSignal.timeout(2000) });
        if (res.ok) {
            logger.info("tool", `[ChromeMCP] Chrome already running on port ${port}`);
            return { success: true };
        }
    } catch { /* not running */ }

    const chromeProcess = spawn(chrome.path, [
        `--remote-debugging-port=${port}`,
        "--no-sandbox",
        "--disable-gpu",
        "--headless=new",
        "--disable-dev-shm-usage",
        "--user-data-dir=/tmp/chrome-mcp-profile",
        "--no-first-run",
        "--no-default-browser-check",
    ], { detached: true, stdio: "ignore" });

    chromeProcess.unref();

    for (let i = 0; i < 15; i++) {
        await new Promise(r => setTimeout(r, 1000));
        try {
            const res = await fetch(`http://127.0.0.1:${port}/json/version`, { signal: AbortSignal.timeout(1000) });
            if (res.ok) {
                logger.info("tool", `[ChromeMCP] Chrome launched on port ${port}`);
                return { success: true, pid: chromeProcess.pid };
            }
        } catch { /* still starting */ }
    }

    return { success: false, error: "Chrome launched but debugger not responding after 15s" };
}

export async function isChromeMCPAvailable(port: number = 9222): Promise<{
    available: boolean;
    chromeRunning: boolean;
    mcpReady: boolean;
    toolCount: number;
    error?: string;
}> {
    let chromeRunning = false;
    try {
        const res = await fetch(`http://127.0.0.1:${port}/json/version`, { signal: AbortSignal.timeout(2000) });
        chromeRunning = res.ok;
    } catch { /* not running */ }

    const mcpReady = (chromeMCPClient?.getTools().length || 0) > 0;

    return {
        available: chromeRunning && mcpReady,
        chromeRunning,
        mcpReady,
        toolCount: chromeMCPClient?.getTools().length || 0,
        error: !chromeRunning ? "Chrome not running with remote debugging"
            : (!mcpReady ? "MCP client not connected" : undefined),
    };
}

export async function ensureChromeMCPRunning(port: number = 9222): Promise<{
    success: boolean;
    tools: string[];
    error?: string;
}> {
    const launchResult = await launchChromeWithDebugging(port);
    if (!launchResult.success) {
        return { success: false, tools: [], error: launchResult.error };
    }

    if (!chromeMCPClient) {
        chromeMCPClient = new ChromeMCPClient();
    }

    const started = await chromeMCPClient.start(`http://127.0.0.1:${port}`);
    if (!started) {
        return {
            success: false,
            tools: [],
            error: "Failed to start chrome-devtools-mcp. Install: npm i -g chrome-devtools-mcp"
        };
    }

    return { success: true, tools: chromeMCPClient.getToolNames() };
}

// ============================================================================
// CHROME MCP BROWSER BACKEND (v0.18.1)
// Full tool names from Google's official chrome-devtools-mcp
// ============================================================================

export class ChromeMCPBackend {
    private port: number;

    constructor(port: number = 9222) {
        this.port = port;
    }

    private async ensureReady(): Promise<void> {
        await ensureChromeMCPRunning(this.port);
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

    // ── Status ──────────────────────────────────────────────────────────────
    async getStatus(): Promise<{ running: boolean; tools?: number; toolNames?: string[]; backend: string }> {
        const status = await isChromeMCPAvailable(this.port);
        return {
            running: status.available,
            tools: status.toolCount,
            toolNames: chromeMCPClient?.getToolNames(),
            backend: "chrome-devtools-mcp",
        };
    }

    // ── NAVIGATION: navigate_page, new_page, list_pages, select_page, close_page, wait_for ──
    async navigate(url: string): Promise<ToolResult> {
        await this.ensureReady();
        const result = await this.call("navigate_page", { url });
        if (!result.success) return { success: false, content: "", error: result.error };
        return { success: true, content: `Navigated to ${url}\n${ChromeMCPClient.extractText(result)}` };
    }

    async newPage(url?: string): Promise<ToolResult> {
        await this.ensureReady();
        const result = await this.call("new_page", url ? { url } : {});
        if (!result.success) return { success: false, content: "", error: result.error };
        return { success: true, content: `New page${url ? `: ${url}` : " created"}\n${ChromeMCPClient.extractText(result)}` };
    }

    async listPages(): Promise<ToolResult> {
        const result = await this.call("list_pages", {});
        return { success: result.success, content: result.success ? ChromeMCPClient.extractText(result) : "", error: result.error };
    }

    async selectPage(index: number): Promise<ToolResult> {
        const result = await this.call("select_page", { index });
        return { success: result.success, content: result.success ? `Selected page ${index}` : "", error: result.error };
    }

    async closePage(): Promise<ToolResult> {
        const result = await this.call("close_page", {});
        return { success: result.success, content: result.success ? "Page closed" : "", error: result.error };
    }

    async waitFor(args: { selector?: string; timeout?: number; waitForNavigation?: boolean; text?: string | string[] }): Promise<ToolResult> {
        const result = await this.call("wait_for", args);
        return { success: result.success, content: result.success ? ChromeMCPClient.extractText(result) : "", error: result.error };
    }

    // ── INPUT: click, drag, fill, fill_form, handle_dialog, hover, press_key, type_text, upload_file ──
    async click(selector: string): Promise<ToolResult> {
        const result = await this.call("click", { selector });
        return { success: result.success, content: result.success ? `Clicked: ${selector}` : "", error: result.error };
    }

    async type(_selector: string, text: string): Promise<ToolResult> {
        // type_text types into the currently focused element
        const result = await this.call("type_text", { text });
        return { success: result.success, content: result.success ? `Typed: "${text}"` : "", error: result.error };
    }

    async fill(selector: string, value: string): Promise<ToolResult> {
        const result = await this.call("fill", { selector, value });
        return { success: result.success, content: result.success ? `Filled: ${selector}` : "", error: result.error };
    }

    async fillForm(fields: Array<{ selector: string; value: string }>): Promise<ToolResult> {
        const result = await this.call("fill_form", { fields });
        return { success: result.success, content: result.success ? `Filled ${fields.length} form fields` : "", error: result.error };
    }

    async pressKey(key: string): Promise<ToolResult> {
        const result = await this.call("press_key", { key });
        return { success: result.success, content: result.success ? `Pressed: ${key}` : "", error: result.error };
    }

    async hover(selector: string): Promise<ToolResult> {
        const result = await this.call("hover", { selector });
        return { success: result.success, content: result.success ? `Hovered: ${selector}` : "", error: result.error };
    }

    async drag(startSelector: string, endSelector: string): Promise<ToolResult> {
        const result = await this.call("drag", { startSelector, endSelector });
        return { success: result.success, content: result.success ? "Drag completed" : "", error: result.error };
    }

    async uploadFile(selector: string, paths: string[]): Promise<ToolResult> {
        const result = await this.call("upload_file", { selector, paths });
        return { success: result.success, content: result.success ? `Uploaded ${paths.length} file(s)` : "", error: result.error };
    }

    async handleDialog(accept: boolean, promptText?: string): Promise<ToolResult> {
        const result = await this.call("handle_dialog", { accept, promptText });
        return { success: result.success, content: result.success ? `Dialog ${accept ? "accepted" : "dismissed"}` : "", error: result.error };
    }

    // ── DEBUGGING: take_screenshot, take_snapshot, evaluate_script, list_console_messages, get_console_message ──
    async screenshot(): Promise<ToolResult> {
        const result = await this.call("take_screenshot", {});
        if (!result.success) return { success: false, content: "", error: result.error };

        const base64 = ChromeMCPClient.extractImage(result);
        return {
            success: true,
            content: "Screenshot captured via Chrome DevTools MCP",
            metadata: base64 ? { image: `data:image/png;base64,${base64}`, base64 } : undefined,
        };
    }

    async snapshot(): Promise<ToolResult> {
        // take_snapshot returns the accessibility tree (recommended for AI)
        const result = await this.call("take_snapshot", {});
        if (!result.success) return { success: false, content: "", error: result.error };
        return { success: true, content: ChromeMCPClient.extractText(result) };
    }

    async evaluate(expression: string): Promise<ToolResult> {
        const result = await this.call("evaluate_script", { expression });
        if (!result.success) return { success: false, content: "", error: result.error };
        return { success: true, content: ChromeMCPClient.extractText(result) };
    }

    async getConsole(): Promise<ToolResult> {
        const result = await this.call("list_console_messages", {});
        if (!result.success) return { success: false, content: "", error: result.error };
        return { success: true, content: ChromeMCPClient.extractText(result) };
    }

    async getConsoleMessage(id: string): Promise<ToolResult> {
        const result = await this.call("get_console_message", { id });
        if (!result.success) return { success: false, content: "", error: result.error };
        return { success: true, content: ChromeMCPClient.extractText(result) };
    }

    // ── NETWORK: list_network_requests, get_network_request ──
    async listNetworkRequests(): Promise<ToolResult> {
        const result = await this.call("list_network_requests", {});
        if (!result.success) return { success: false, content: "", error: result.error };
        return { success: true, content: ChromeMCPClient.extractText(result) };
    }

    async getNetworkRequest(id: string): Promise<ToolResult> {
        const result = await this.call("get_network_request", { id });
        if (!result.success) return { success: false, content: "", error: result.error };
        return { success: true, content: ChromeMCPClient.extractText(result) };
    }

    // ── PERFORMANCE: performance_start_trace, performance_stop_trace, performance_analyze_insight, take_memory_snapshot ──
    async startPerformanceTrace(): Promise<ToolResult> {
        const result = await this.call("performance_start_trace", {});
        if (!result.success) return { success: false, content: "", error: result.error };
        return { success: true, content: "Performance trace started (includes Core Web Vitals, LCP)" };
    }

    async stopPerformanceTrace(): Promise<ToolResult> {
        const result = await this.call("performance_stop_trace", {});
        if (!result.success) return { success: false, content: "", error: result.error };
        return { success: true, content: ChromeMCPClient.extractText(result) };
    }

    async analyzePerformance(insight?: string): Promise<ToolResult> {
        // e.g. insight = "LCPBreakdown" for LCP-specific debugging
        const result = await this.call("performance_analyze_insight", insight ? { insight } : {});
        if (!result.success) return { success: false, content: "", error: result.error };
        return { success: true, content: ChromeMCPClient.extractText(result) };
    }

    async takeMemorySnapshot(): Promise<ToolResult> {
        const result = await this.call("take_memory_snapshot", {});
        if (!result.success) return { success: false, content: "", error: result.error };
        return { success: true, content: ChromeMCPClient.extractText(result) };
    }

    // ── EMULATION: emulate_cpu, emulate_network, resize_page ──
    async emulateCPU(cpuThrottling: number): Promise<ToolResult> {
        const result = await this.call("emulate_cpu", { cpuThrottling });
        if (!result.success) return { success: false, content: "", error: result.error };
        return { success: true, content: `CPU throttling set to ${cpuThrottling}x` };
    }

    async emulateNetwork(preset: string): Promise<ToolResult> {
        // Presets: "3G", "4G", "WiFi", "offline", etc.
        const result = await this.call("emulate_network", { preset });
        if (!result.success) return { success: false, content: "", error: result.error };
        return { success: true, content: `Network emulation: ${preset}` };
    }

    async resizePage(width: number, height: number): Promise<ToolResult> {
        const result = await this.call("resize_page", { width, height });
        if (!result.success) return { success: false, content: "", error: result.error };
        return { success: true, content: `Resized to ${width}x${height}` };
    }

    stop(): void {
        if (chromeMCPClient) {
            chromeMCPClient.stop();
            chromeMCPClient = null;
        }
    }
}
