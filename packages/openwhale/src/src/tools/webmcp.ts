/**
 * Chrome WebMCP Backend — Web Model Context Protocol (2026)
 * 
 * Chrome's WebMCP protocol (navigator.modelContext) allows websites to expose
 * their functionalities as structured "tools" that AI agents can discover and
 * invoke directly — no DOM parsing or screenshot guessing needed.
 * 
 * This backend:
 *  1. Launches Chrome with --enable-features=WebMCP
 *  2. After navigating to a page, discovers WebMCP tools via navigator.modelContext
 *  3. Lets TensorAgent invoke those tools with structured arguments
 *  4. Falls back to Playwright for pages without WebMCP support
 * 
 * @see https://chromestatus.com/feature/webmcp
 * @see https://github.com/nicolo-ribaudo/tc39-proposal-webmcp
 */

import type { ToolResult } from "./base.js";
import { chromium, type Browser, type Page, type BrowserContext } from "playwright";
import { writeFileSync, existsSync, mkdirSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";
import { execSync } from "node:child_process";

// ============================================================================
// TYPES
// ============================================================================

export interface WebMCPToolInfo {
    name: string;
    description: string;
    inputSchema?: Record<string, unknown>;
}

export interface WebMCPDiscoveryResult {
    url: string;
    title: string;
    tools: WebMCPToolInfo[];
    hasWebMCP: boolean;
}

export interface WebMCPInvokeResult {
    toolName: string;
    success: boolean;
    result?: unknown;
    error?: string;
}

// ============================================================================
// DISCOVERY & INVOCATION SCRIPTS (injected into page context)
// ============================================================================

/**
 * Script injected into page to discover WebMCP tools.
 * Checks for navigator.modelContext and enumerates registered tools.
 */
const WEBMCP_DISCOVERY_SCRIPT = `
(async function() {
    // Check if WebMCP API is available
    if (!navigator.modelContext) {
        return JSON.stringify({ hasWebMCP: false, tools: [] });
    }

    try {
        // Get the model context session
        const ctx = navigator.modelContext;
        
        // Enumerate tools — the API exposes registered tools
        const tools = [];
        
        // Method 1: Direct tools enumeration (Chrome 146+)
        if (typeof ctx.getTools === 'function') {
            const registeredTools = await ctx.getTools();
            for (const tool of registeredTools) {
                tools.push({
                    name: tool.name || '',
                    description: tool.description || '',
                    inputSchema: tool.inputSchema || null
                });
            }
        }
        // Method 2: tools property (alternative API shape)
        else if (ctx.tools && Symbol.iterator in Object(ctx.tools)) {
            for (const tool of ctx.tools) {
                tools.push({
                    name: tool.name || '',
                    description: tool.description || '',
                    inputSchema: tool.inputSchema || null
                });
            }
        }
        // Method 3: Declarative tools from HTML forms with toolname attribute
        else {
            const forms = document.querySelectorAll('form[toolname]');
            for (const form of forms) {
                const schema = { type: 'object', properties: {} };
                const inputs = form.querySelectorAll('input[name], select[name], textarea[name]');
                for (const input of inputs) {
                    schema.properties[input.name] = {
                        type: input.type === 'number' ? 'number' : 'string',
                        description: input.placeholder || input.name
                    };
                }
                tools.push({
                    name: form.getAttribute('toolname') || '',
                    description: form.getAttribute('tooldescription') || '',
                    inputSchema: schema
                });
            }
        }

        return JSON.stringify({ hasWebMCP: true, tools });
    } catch (err) {
        return JSON.stringify({ hasWebMCP: true, tools: [], error: err.message });
    }
})()
`;

/**
 * Script injected to invoke a WebMCP tool by name with arguments.
 * Returns the tool's response as JSON.
 */
function getWebMCPInvokeScript(toolName: string, args: Record<string, unknown>): string {
    return `
(async function() {
    if (!navigator.modelContext) {
        return JSON.stringify({ success: false, error: 'WebMCP not available on this page' });
    }

    try {
        const ctx = navigator.modelContext;
        let result;

        // Method 1: invokeTool method (Chrome 146+)
        if (typeof ctx.invokeTool === 'function') {
            result = await ctx.invokeTool(${JSON.stringify(toolName)}, ${JSON.stringify(args)});
        }
        // Method 2: callTool method (alternative API shape)
        else if (typeof ctx.callTool === 'function') {
            result = await ctx.callTool(${JSON.stringify(toolName)}, ${JSON.stringify(args)});
        }
        // Method 3: Declarative form submission
        else {
            const form = document.querySelector('form[toolname="${toolName}"]');
            if (!form) {
                return JSON.stringify({ success: false, error: 'Tool not found: ${toolName}' });
            }
            // Fill form fields
            const args = ${JSON.stringify(args)};
            for (const [key, value] of Object.entries(args)) {
                const input = form.querySelector('[name="' + key + '"]');
                if (input) {
                    input.value = String(value);
                    input.dispatchEvent(new Event('input', { bubbles: true }));
                    input.dispatchEvent(new Event('change', { bubbles: true }));
                }
            }
            // Submit if autosubmit
            if (form.getAttribute('toolautosubmit') !== null) {
                form.submit();
            }
            result = { submitted: true };
        }

        return JSON.stringify({ success: true, result: result });
    } catch (err) {
        return JSON.stringify({ success: false, error: err.message });
    }
})()
`;
}

// ============================================================================
// CHROME DETECTION FOR WEBMCP
// ============================================================================

/** Check if a Chrome version with WebMCP support is available */
export async function isWebMCPAvailable(): Promise<{
    available: boolean;
    chromePath?: string;
    chromeVersion?: string;
    error?: string;
}> {
    // Check common Chrome/Chromium paths
    const paths = [
        "/usr/bin/chromium",
        "/usr/bin/chromium-browser",
        "/usr/bin/google-chrome",
        "/usr/bin/google-chrome-stable",
        "/opt/chromium/chrome",
        "/opt/ainux/chromium/chrome",
    ];

    for (const p of paths) {
        try {
            if (existsSync(p)) {
                const version = execSync(`${p} --version 2>/dev/null`, { timeout: 5000 })
                    .toString().trim();
                // WebMCP feature flag works on Chrome 133+ when passed via --enable-features=WebMCP
                // Chrome 146+ has it enabled by default
                const match = version.match(/(\d+)\./);
                const major = match ? parseInt(match[1]) : 0;
                if (major >= 133) {
                    return { available: true, chromePath: p, chromeVersion: version };
                }
                return {
                    available: false,
                    chromePath: p,
                    chromeVersion: version,
                    error: `Chrome ${major} found, but WebMCP requires Chrome 133+ with --enable-features=WebMCP`
                };
            }
        } catch { /* skip */ }
    }

    // Try Playwright's bundled Chromium (may support WebMCP flag)
    try {
        const playwrightPath = chromium.executablePath();
        if (playwrightPath && existsSync(playwrightPath)) {
            return {
                available: true,
                chromePath: playwrightPath,
                chromeVersion: "Playwright bundled Chromium"
            };
        }
    } catch { /* skip */ }

    return { available: false, error: "No compatible Chrome/Chromium found" };
}

// ============================================================================
// WEBMCP BROWSER BACKEND
// ============================================================================

export class WebMCPBackend {
    private browser: Browser | null = null;
    private context: BrowserContext | null = null;
    private page: Page | null = null;
    private discoveredTools: WebMCPToolInfo[] = [];
    private lastDiscoveryUrl: string = "";

    /** Launch Chrome with WebMCP flag enabled */
    async start(): Promise<void> {
        if (this.browser?.isConnected()) return;

        const chromeInfo = await isWebMCPAvailable();

        const launchArgs = [
            "--no-sandbox",
            "--disable-setuid-sandbox",
            "--enable-features=WebMCP",  // Enable WebMCP API
            "--disable-blink-features=AutomationControlled",
        ];

        const launchOptions: Record<string, unknown> = {
            headless: true,
            args: launchArgs,
        };

        // Use system Chrome if available (for proper WebMCP support)
        if (chromeInfo.available && chromeInfo.chromePath &&
            !chromeInfo.chromePath.includes("playwright")) {
            launchOptions.executablePath = chromeInfo.chromePath;
        }

        this.browser = await chromium.launch(launchOptions as any);
        this.context = await this.browser.newContext({
            viewport: { width: 1280, height: 720 },
            userAgent: "Mozilla/5.0 (X11; Linux aarch64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36",
            bypassCSP: true,
        });

        this.page = await this.context.newPage();
        console.log("[WebMCP] Browser started with WebMCP enabled");
    }

    /** Stop the browser */
    async stop(): Promise<void> {
        if (this.page && !this.page.isClosed()) await this.page.close();
        if (this.context) await this.context.close();
        if (this.browser) await this.browser.close();
        this.page = null;
        this.context = null;
        this.browser = null;
        this.discoveredTools = [];
        console.log("[WebMCP] Browser stopped");
    }

    /** Ensure browser is running */
    private async ensureBrowser(): Promise<Page> {
        if (!this.browser?.isConnected() || !this.page || this.page.isClosed()) {
            await this.start();
        }
        return this.page!;
    }

    /** Navigate to a URL and auto-discover WebMCP tools */
    async navigate(url: string): Promise<ToolResult> {
        const page = await this.ensureBrowser();

        try {
            await page.goto(url, { waitUntil: "domcontentloaded", timeout: 30000 });

            // Wait for page JavaScript to register WebMCP tools
            await page.waitForTimeout(2000);

            // Auto-discover WebMCP tools
            const discovery = await this.discoverTools();

            let content = `Navigated to: ${url}\nTitle: ${await page.title()}`;
            if (discovery.hasWebMCP && discovery.tools.length > 0) {
                content += `\n\n🔌 WebMCP Tools Discovered (${discovery.tools.length}):`;
                for (const tool of discovery.tools) {
                    content += `\n  • ${tool.name}: ${tool.description}`;
                    if (tool.inputSchema) {
                        const props = (tool.inputSchema as any).properties;
                        if (props) {
                            const params = Object.keys(props).join(", ");
                            content += ` (params: ${params})`;
                        }
                    }
                }
                content += `\n\nUse webmcp_invoke to call these tools directly.`;
            } else {
                content += `\n\nNo WebMCP tools found on this page. Standard browser automation available.`;
            }

            return {
                success: true,
                content,
                metadata: {
                    url: page.url(),
                    title: await page.title(),
                    webmcpTools: discovery.tools.length,
                    backend: "webmcp"
                }
            };
        } catch (err) {
            return {
                success: false,
                content: "",
                error: `Navigation failed: ${err instanceof Error ? err.message : String(err)}`
            };
        }
    }

    /** Discover WebMCP tools on the current page */
    async discoverTools(): Promise<WebMCPDiscoveryResult> {
        const page = await this.ensureBrowser();

        try {
            const resultJson = await page.evaluate(WEBMCP_DISCOVERY_SCRIPT) as string;
            const result = JSON.parse(resultJson);

            this.discoveredTools = result.tools || [];
            this.lastDiscoveryUrl = page.url();

            return {
                url: page.url(),
                title: await page.title(),
                tools: this.discoveredTools,
                hasWebMCP: result.hasWebMCP || false,
            };
        } catch (err) {
            return {
                url: page.url(),
                title: await page.title(),
                tools: [],
                hasWebMCP: false,
            };
        }
    }

    /** Invoke a specific WebMCP tool on the current page */
    async invokeTool(toolName: string, args: Record<string, unknown> = {}): Promise<ToolResult> {
        const page = await this.ensureBrowser();

        // Verify tool exists
        if (this.discoveredTools.length === 0) {
            await this.discoverTools();
        }

        const tool = this.discoveredTools.find(t => t.name === toolName);
        if (!tool) {
            const availableTools = this.discoveredTools.map(t => t.name).join(", ") || "none";
            return {
                success: false,
                content: "",
                error: `WebMCP tool "${toolName}" not found. Available: ${availableTools}. Run webmcp_discover first.`
            };
        }

        try {
            const script = getWebMCPInvokeScript(toolName, args);
            const resultJson = await page.evaluate(script) as string;
            const result = JSON.parse(resultJson);

            if (result.success) {
                return {
                    success: true,
                    content: `WebMCP tool "${toolName}" executed successfully.\n\nResult:\n${JSON.stringify(result.result, null, 2)}`,
                    metadata: {
                        tool: toolName,
                        args,
                        result: result.result,
                        backend: "webmcp"
                    }
                };
            } else {
                return {
                    success: false,
                    content: "",
                    error: `WebMCP tool "${toolName}" failed: ${result.error}`
                };
            }
        } catch (err) {
            return {
                success: false,
                content: "",
                error: `WebMCP invoke error: ${err instanceof Error ? err.message : String(err)}`
            };
        }
    }

    /** Take a snapshot with WebMCP tool information */
    async snapshot(): Promise<ToolResult> {
        const page = await this.ensureBrowser();

        try {
            // Get page text content
            const textContent = await page.evaluate(`
                JSON.stringify({
                    title: document.title,
                    url: location.href,
                    text: document.body.innerText.slice(0, 30000)
                })
            `) as string;

            const pageInfo = JSON.parse(textContent);

            // Get interactive elements (same as Playwright backend)
            const elementsJson = await page.evaluate(`
                (function() {
                    const selectors = ['a[href]', 'button', 'input', 'select', 'textarea', '[role="button"]', '[role="link"]', '[onclick]', 'label'];
                    const results = [];
                    let ref = 1;
                    for (const sel of selectors) {
                        document.querySelectorAll(sel).forEach(el => {
                            if (el.offsetParent === null && el.tagName !== 'BODY') return;
                            let selector = el.id ? '#' + el.id : el.tagName.toLowerCase();
                            if (!el.id && el.classList.length) selector += '.' + Array.from(el.classList).slice(0,2).join('.');
                            results.push({
                                ref: ref++,
                                tag: el.tagName.toLowerCase(),
                                type: el.type || undefined,
                                text: (el.innerText || el.textContent || '').trim().slice(0, 100),
                                href: el.href || undefined,
                                placeholder: el.placeholder || undefined,
                                selector: selector
                            });
                        });
                    }
                    return JSON.stringify(results.slice(0, 200));
                })()
            `) as string;

            const elements = JSON.parse(elementsJson);

            // Discover WebMCP tools
            const webmcpDiscovery = await this.discoverTools();

            // Build output
            const lines: string[] = [];
            lines.push(`Page: ${pageInfo.title}`);
            lines.push(`URL: ${pageInfo.url}`);
            lines.push(`Backend: WebMCP`);

            // WebMCP tools section
            if (webmcpDiscovery.hasWebMCP && webmcpDiscovery.tools.length > 0) {
                lines.push(`\n🔌 WebMCP Tools (${webmcpDiscovery.tools.length}):`);
                for (const tool of webmcpDiscovery.tools) {
                    let line = `  [webmcp] ${tool.name}: ${tool.description}`;
                    if (tool.inputSchema) {
                        const props = (tool.inputSchema as any).properties;
                        if (props) {
                            const params = Object.entries(props)
                                .map(([k, v]: [string, any]) => `${k}: ${v.type || 'string'}`)
                                .join(", ");
                            line += ` (${params})`;
                        }
                    }
                    lines.push(line);
                }
                lines.push(`\nUse webmcp_invoke action to call these tools directly.`);
            }

            // Standard interactive elements
            lines.push(`\nInteractive Elements:`);
            for (const el of elements) {
                let line = `[ref=${el.ref}] <${el.tag}`;
                if (el.type) line += ` type="${el.type}"`;
                line += `>`;
                if (el.text) line += ` "${el.text}"`;
                if (el.href) line += ` → ${el.href}`;
                if (el.placeholder) line += ` (placeholder: ${el.placeholder})`;
                lines.push(line);
            }

            const content = lines.join('\n');
            return {
                success: true,
                content: content.slice(0, 50000),
                metadata: {
                    url: pageInfo.url,
                    title: pageInfo.title,
                    webmcpTools: webmcpDiscovery.tools.length,
                    interactiveElements: elements.length,
                    backend: "webmcp"
                }
            };
        } catch (err) {
            return {
                success: false,
                content: "",
                error: `Snapshot failed: ${err instanceof Error ? err.message : String(err)}`
            };
        }
    }

    /** Take a screenshot */
    async screenshot(fullPage: boolean = false): Promise<ToolResult> {
        const page = await this.ensureBrowser();

        try {
            const buffer = await page.screenshot({ fullPage, type: "png" });
            const dir = join(homedir(), ".openwhale", "screenshots");
            if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
            const path = join(dir, `webmcp_screenshot_${Date.now()}.png`);
            writeFileSync(path, buffer);

            return {
                success: true,
                content: `Screenshot saved: ${path}`,
                metadata: { path, size: buffer.length, backend: "webmcp" }
            };
        } catch (err) {
            return {
                success: false,
                content: "",
                error: `Screenshot failed: ${err instanceof Error ? err.message : String(err)}`
            };
        }
    }

    /** Click an element */
    async click(selector: string): Promise<ToolResult> {
        const page = await this.ensureBrowser();
        try {
            await page.click(selector);
            return { success: true, content: `Clicked: ${selector}` };
        } catch (err) {
            return { success: false, content: "", error: `Click failed: ${err instanceof Error ? err.message : String(err)}` };
        }
    }

    /** Type text into an element */
    async type(selector: string, text: string): Promise<ToolResult> {
        const page = await this.ensureBrowser();
        try {
            await page.fill(selector, text);
            return { success: true, content: `Typed "${text}" into ${selector}` };
        } catch (err) {
            return { success: false, content: "", error: `Type failed: ${err instanceof Error ? err.message : String(err)}` };
        }
    }

    /** Press a key */
    async press(key: string): Promise<ToolResult> {
        const page = await this.ensureBrowser();
        try {
            await page.keyboard.press(key);
            return { success: true, content: `Pressed: ${key}` };
        } catch (err) {
            return { success: false, content: "", error: `Press failed: ${err instanceof Error ? err.message : String(err)}` };
        }
    }

    /** Evaluate JavaScript */
    async evaluate(script: string): Promise<ToolResult> {
        const page = await this.ensureBrowser();
        try {
            const result = await page.evaluate(script);
            return { success: true, content: JSON.stringify(result, null, 2) };
        } catch (err) {
            return { success: false, content: "", error: `Evaluate failed: ${err instanceof Error ? err.message : String(err)}` };
        }
    }

    /** Get backend status */
    async getStatus(): Promise<{
        running: boolean;
        webmcpEnabled: boolean;
        currentUrl?: string;
        discoveredTools: number;
        toolNames: string[];
        backend: string;
    }> {
        return {
            running: this.browser?.isConnected() ?? false,
            webmcpEnabled: true,
            currentUrl: this.page && !this.page.isClosed() ? this.page.url() : undefined,
            discoveredTools: this.discoveredTools.length,
            toolNames: this.discoveredTools.map(t => t.name),
            backend: "webmcp",
        };
    }
}

// Singleton
let webmcpBackend: WebMCPBackend | null = null;

export function getWebMCPBackend(): WebMCPBackend {
    if (!webmcpBackend) {
        webmcpBackend = new WebMCPBackend();
    }
    return webmcpBackend;
}

/** Ensure WebMCP backend is running */
export async function ensureWebMCPRunning(): Promise<{
    success: boolean;
    error?: string;
}> {
    try {
        const backend = getWebMCPBackend();
        await backend.start();
        return { success: true };
    } catch (err) {
        return {
            success: false,
            error: err instanceof Error ? err.message : String(err)
        };
    }
}
