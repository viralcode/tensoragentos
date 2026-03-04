/**
 * MCP Manager — manages MCP server lifecycles and tool injection
 * 
 * Spawns MCP servers via StdIO transport, discovers tools via listTools(),
 * wraps them as AgentTool objects, and registers into the toolRegistry.
 */

import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";
import { z } from "zod";
import { toolRegistry, type AgentTool, type ToolResult, type ToolCallContext } from "./base.js";
import { logger } from "../logger.js";
import { readFileSync, writeFileSync, existsSync, mkdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));

export interface McpServerConfig {
    id: string;
    name: string;
    description: string;
    command: string;
    args: string[];
    envVars: string[];     // env var names needed
    env: Record<string, string>;  // actual env values
    category: string;
    tier: number;
    configured: boolean;
}

export interface McpServerStatus extends McpServerConfig {
    running: boolean;
    toolCount: number;
    tools: string[];
    error?: string;
}

// Built-in registry of known MCP servers
const BUILT_IN_SERVERS: McpServerConfig[] = [
    {
        id: "brave-search",
        name: "Brave Search",
        description: "Web search powered by Brave Search API",
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-brave-search"],
        envVars: ["BRAVE_API_KEY"],
        env: {},
        category: "search",
        tier: 1,
        configured: false,
    },
    {
        id: "memory",
        name: "Memory",
        description: "Persistent memory using a knowledge graph",
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-memory"],
        envVars: [],
        env: {},
        category: "ai",
        tier: 1,
        configured: true,
    },
    {
        id: "puppeteer",
        name: "Puppeteer",
        description: "Headless browser automation and web scraping",
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-puppeteer"],
        envVars: [],
        env: {},
        category: "dev",
        tier: 2,
        configured: true,
    },
    {
        id: "slack",
        name: "Slack",
        description: "Send messages and manage Slack workspaces",
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-slack"],
        envVars: ["SLACK_BOT_TOKEN"],
        env: {},
        category: "productivity",
        tier: 2,
        configured: false,
    },
    {
        id: "google-maps",
        name: "Google Maps",
        description: "Geocoding, directions, and place search",
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-google-maps"],
        envVars: ["GOOGLE_MAPS_API_KEY"],
        env: {},
        category: "data",
        tier: 2,
        configured: false,
    },
    {
        id: "sentry",
        name: "Sentry",
        description: "Error tracking and performance monitoring",
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-sentry"],
        envVars: ["SENTRY_AUTH_TOKEN"],
        env: {},
        category: "analytics",
        tier: 3,
        configured: false,
    },
    {
        id: "postgres",
        name: "PostgreSQL",
        description: "Query and manage PostgreSQL databases",
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-postgres"],
        envVars: ["DATABASE_URL"],
        env: {},
        category: "data",
        tier: 2,
        configured: false,
    },
    {
        id: "everything",
        name: "Everything",
        description: "Reference MCP server with sample tools for testing",
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-everything"],
        envVars: [],
        env: {},
        category: "dev",
        tier: 3,
        configured: true,
    },
];

/**
 * Convert JSON Schema to a Zod schema (simplified)
 */
function jsonSchemaToZod(schema: any): z.ZodType {
    if (!schema || schema.type === "string") return z.string().optional();
    if (schema.type === "number" || schema.type === "integer") return z.number().optional();
    if (schema.type === "boolean") return z.boolean().optional();
    if (schema.type === "array") {
        return z.array(jsonSchemaToZod(schema.items || {})).optional();
    }
    if (schema.type === "object" && schema.properties) {
        const shape: Record<string, z.ZodType> = {};
        for (const [key, val] of Object.entries(schema.properties)) {
            const required = schema.required?.includes(key);
            const field = jsonSchemaToZod(val as any);
            shape[key] = required ? field : field.optional();
        }
        return z.object(shape);
    }
    // Fallback: accept anything
    return z.any();
}

class McpManager {
    private servers: Map<string, McpServerConfig> = new Map();
    private clients: Map<string, Client> = new Map();
    private transports: Map<string, StdioClientTransport> = new Map();
    private serverTools: Map<string, string[]> = new Map(); // serverId -> tool names
    private configPath: string;

    constructor() {
        const dataDir = join(__dirname, "../../data");
        if (!existsSync(dataDir)) mkdirSync(dataDir, { recursive: true });
        this.configPath = join(dataDir, "mcp-servers.json");
        this.loadConfig();
    }

    private loadConfig() {
        // Start with built-in servers
        for (const server of BUILT_IN_SERVERS) {
            this.servers.set(server.id, { ...server });
        }

        // Override with saved config (env vars, configured status)
        if (existsSync(this.configPath)) {
            try {
                const saved = JSON.parse(readFileSync(this.configPath, "utf-8"));
                for (const s of saved) {
                    const existing = this.servers.get(s.id);
                    if (existing) {
                        existing.env = s.env || {};
                        existing.configured = s.configured ?? existing.configured;
                    }
                }
            } catch (e) {
                logger.warn("mcp", "Failed to load MCP config: " + e);
            }
        }
    }

    private saveConfig() {
        const data = Array.from(this.servers.values()).map(s => ({
            id: s.id,
            env: s.env,
            configured: s.configured,
        }));
        writeFileSync(this.configPath, JSON.stringify(data, null, 2));
    }

    listServers(): McpServerStatus[] {
        return Array.from(this.servers.values()).map(s => ({
            ...s,
            running: this.clients.has(s.id),
            toolCount: this.serverTools.get(s.id)?.length || 0,
            tools: this.serverTools.get(s.id) || [],
        }));
    }

    async startServer(id: string): Promise<{ success: boolean; tools?: string[]; error?: string }> {
        const config = this.servers.get(id);
        if (!config) return { success: false, error: "Unknown server: " + id };
        if (this.clients.has(id)) return { success: false, error: "Server already running" };

        // Check required env vars
        for (const envVar of config.envVars) {
            if (!config.env[envVar]) {
                return { success: false, error: `Missing required env var: ${envVar}. Configure the server first.` };
            }
        }

        try {
            logger.info("mcp", `Starting MCP server: ${config.name} (${config.command} ${config.args.join(" ")})`);

            // Merge env vars
            const env = { ...process.env, ...config.env };

            const transport = new StdioClientTransport({
                command: config.command,
                args: config.args,
                env,
            });

            const client = new Client(
                { name: "openwhale", version: "1.0.0" },
                { capabilities: {} }
            );

            await client.connect(transport);

            // Discover tools
            const toolsResult = await client.listTools();
            const toolNames: string[] = [];

            for (const mcpTool of toolsResult.tools) {
                const toolName = `mcp:${id}:${mcpTool.name}`;
                toolNames.push(toolName);

                // Create AgentTool wrapper
                const agentTool: AgentTool = {
                    name: toolName,
                    description: `[MCP:${config.name}] ${mcpTool.description || mcpTool.name}`,
                    category: "utility",
                    parameters: jsonSchemaToZod(mcpTool.inputSchema),
                    execute: async (params: unknown, _context: ToolCallContext): Promise<ToolResult> => {
                        try {
                            const result = await client.callTool({
                                name: mcpTool.name,
                                arguments: params as Record<string, unknown>,
                            });
                            const content = result.content
                                ?.map((c: any) => c.type === "text" ? c.text : JSON.stringify(c))
                                .join("\n") || "";
                            return { success: !result.isError, content, error: result.isError ? content : undefined };
                        } catch (err) {
                            const msg = err instanceof Error ? err.message : String(err);
                            return { success: false, content: "", error: msg };
                        }
                    },
                };

                toolRegistry.register(agentTool);
            }

            this.clients.set(id, client);
            this.transports.set(id, transport);
            this.serverTools.set(id, toolNames);

            logger.info("mcp", `MCP server ${config.name} started with ${toolNames.length} tools: ${toolNames.join(", ")}`);
            return { success: true, tools: toolNames };
        } catch (err) {
            const msg = err instanceof Error ? err.message : String(err);
            logger.error("mcp", `Failed to start MCP server ${config.name}: ${msg}`);
            return { success: false, error: msg };
        }
    }

    async stopServer(id: string): Promise<{ success: boolean; error?: string }> {
        const client = this.clients.get(id);
        if (!client) return { success: false, error: "Server not running" };

        try {
            // Unregister tools
            const toolNames = this.serverTools.get(id) || [];
            for (const name of toolNames) {
                // Remove from registry via the internal map
                (toolRegistry as any).tools?.delete(name);
            }

            await client.close();
            this.clients.delete(id);
            this.transports.delete(id);
            this.serverTools.delete(id);

            logger.info("mcp", `MCP server ${id} stopped`);
            return { success: true };
        } catch (err) {
            const msg = err instanceof Error ? err.message : String(err);
            return { success: false, error: msg };
        }
    }

    configure(id: string, env: Record<string, string>): { success: boolean; error?: string } {
        const config = this.servers.get(id);
        if (!config) return { success: false, error: "Unknown server: " + id };

        config.env = { ...config.env, ...env };
        config.configured = true;
        this.saveConfig();

        return { success: true };
    }

    getActiveToolCount(): number {
        let count = 0;
        for (const tools of this.serverTools.values()) {
            count += tools.length;
        }
        return count;
    }
}

// Singleton instance
export const mcpManager = new McpManager();
