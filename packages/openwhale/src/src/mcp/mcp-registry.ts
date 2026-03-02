/**
 * MCP Server Registry — manages lifecycle of all MCP servers
 * 
 * Defines available MCP servers, tracks running status, and provides
 * a unified interface for starting/stopping/querying servers.
 */

import { GenericMCPClient, type MCPToolDef } from "./mcp-client.js";
import { logger } from "../logger.js";

export interface MCPServerConfig {
    id: string;
    name: string;
    description: string;
    icon: string;           // Font Awesome icon code
    category: string;       // "ai" | "search" | "data" | "dev" | "productivity" | "analytics"
    tier: 1 | 2 | 3;
    command: string;        // e.g. "npx"
    args: string[];         // e.g. ["-y", "@modelcontextprotocol/server-sequential-thinking"]
    envVars?: string[];     // Required env vars e.g. ["BRAVE_API_KEY"]
    envLabels?: Record<string, string>;  // Human-readable labels for env vars
    installed?: boolean;
    configuredEnv?: Record<string, string>;  // User-provided env values
}

export interface MCPServerStatus {
    id: string;
    name: string;
    description: string;
    icon: string;
    category: string;
    tier: number;
    running: boolean;
    toolCount: number;
    tools: MCPToolDef[];
    needsConfig: boolean;
    envVars: string[];
    configured: boolean;
}

// ── All available MCP servers ──
const SERVER_DEFINITIONS: MCPServerConfig[] = [
    // ─── Tier 1: Pre-installed (no keys) ─────────────────────────────────
    {
        id: "sequential-thinking",
        name: "Sequential Thinking",
        description: "Dynamic problem-solving through structured thought sequences",
        icon: "\uf5dc",  // brain
        category: "ai",
        tier: 1,
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-sequential-thinking"],
    },
    {
        id: "puppeteer",
        name: "Puppeteer",
        description: "Headless Chrome browser automation and scraping",
        icon: "\uf542",  // robot
        category: "dev",
        tier: 1,
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-puppeteer"],
    },

    // ─── Tier 2: Needs API keys ──────────────────────────────────────────
    {
        id: "brave-search",
        name: "Brave Search",
        description: "Web and local search via Brave Search API",
        icon: "\uf002",  // search
        category: "search",
        tier: 2,
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-brave-search"],
        envVars: ["BRAVE_API_KEY"],
        envLabels: { "BRAVE_API_KEY": "Brave Search API Key" },
    },
    {
        id: "google-maps",
        name: "Google Maps",
        description: "Location intelligence, directions, places, and geocoding",
        icon: "\uf5a0",  // map-marked
        category: "search",
        tier: 2,
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-google-maps"],
        envVars: ["GOOGLE_MAPS_API_KEY"],
        envLabels: { "GOOGLE_MAPS_API_KEY": "Google Maps API Key" },
    },
    {
        id: "sentry",
        name: "Sentry",
        description: "Error tracking, debugging, and performance monitoring",
        icon: "\uf188",  // bug
        category: "dev",
        tier: 2,
        command: "npx",
        args: ["-y", "@sentry/mcp-server-sentry"],
        envVars: ["SENTRY_AUTH_TOKEN"],
        envLabels: { "SENTRY_AUTH_TOKEN": "Sentry Auth Token" },
    },
    {
        id: "postgres",
        name: "PostgreSQL",
        description: "Schema inspection and read-only SQL queries on Postgres databases",
        icon: "\uf1c0",  // database
        category: "data",
        tier: 2,
        command: "npx",
        args: ["-y", "@modelcontextprotocol/server-postgres"],
        envVars: ["POSTGRES_CONNECTION_STRING"],
        envLabels: { "POSTGRES_CONNECTION_STRING": "PostgreSQL Connection String" },
    },
    {
        id: "notion",
        name: "Notion",
        description: "Access Notion pages, databases, and workspace content",
        icon: "\uf15c",  // file-alt
        category: "productivity",
        tier: 2,
        command: "npx",
        args: ["-y", "@notionhq/notion-mcp-server"],
        envVars: ["OPENAPI_MCP_HEADERS"],
        envLabels: { "OPENAPI_MCP_HEADERS": "Notion API Key (as JSON header)" },
    },

    // ─── Tier 3: App Store ───────────────────────────────────────────────
    {
        id: "stripe",
        name: "Stripe",
        description: "Payment processing, billing, and subscription management",
        icon: "\uf09d",  // credit-card
        category: "data",
        tier: 3,
        command: "npx",
        args: ["-y", "@stripe/mcp", "--tools=all"],
        envVars: ["STRIPE_SECRET_KEY"],
        envLabels: { "STRIPE_SECRET_KEY": "Stripe Secret Key" },
    },
    {
        id: "linear",
        name: "Linear",
        description: "Project management — issues, projects, teams, and cycles",
        icon: "\uf0ae",  // tasks
        category: "productivity",
        tier: 3,
        command: "npx",
        args: ["-y", "@linear/mcp-server-linear"],
        envVars: ["LINEAR_API_KEY"],
        envLabels: { "LINEAR_API_KEY": "Linear API Key" },
    },
    {
        id: "cloudflare",
        name: "Cloudflare",
        description: "Edge computing, Workers, DNS, and R2 storage management",
        icon: "\uf0c2",  // cloud
        category: "dev",
        tier: 3,
        command: "npx",
        args: ["-y", "@cloudflare/mcp-server-cloudflare"],
        envVars: ["CLOUDFLARE_API_TOKEN"],
        envLabels: { "CLOUDFLARE_API_TOKEN": "Cloudflare API Token" },
    },
    {
        id: "mongodb",
        name: "MongoDB",
        description: "Document database — query, inspect, and manage collections",
        icon: "\uf1c0",  // database
        category: "data",
        tier: 3,
        command: "npx",
        args: ["-y", "mongodb-mcp-server"],
        envVars: ["MDB_MCP_CONNECTION_STRING"],
        envLabels: { "MDB_MCP_CONNECTION_STRING": "MongoDB Connection String" },
    },
    {
        id: "supabase",
        name: "Supabase",
        description: "Authentication, database, and storage management",
        icon: "\uf233",  // server
        category: "data",
        tier: 3,
        command: "npx",
        args: ["-y", "@supabase/mcp-server-supabase"],
        envVars: ["SUPABASE_ACCESS_TOKEN"],
        envLabels: { "SUPABASE_ACCESS_TOKEN": "Supabase Access Token" },
    },
    {
        id: "posthog",
        name: "PostHog",
        description: "Product analytics, events, funnels, and user insights",
        icon: "\uf201",  // line-chart
        category: "analytics",
        tier: 3,
        command: "npx",
        args: ["-y", "posthog-mcp-server"],
        envVars: ["POSTHOG_API_KEY", "POSTHOG_PROJECT_ID"],
        envLabels: {
            "POSTHOG_API_KEY": "PostHog API Key",
            "POSTHOG_PROJECT_ID": "PostHog Project ID",
        },
    },
];

// ── Runtime Registry ──
const runningClients = new Map<string, GenericMCPClient>();
const serverEnvConfigs = new Map<string, Record<string, string>>();

/**
 * Get all server definitions with current status
 */
export function getAllServers(): MCPServerStatus[] {
    return SERVER_DEFINITIONS.map(def => {
        const client = runningClients.get(def.id);
        const envConfig = serverEnvConfigs.get(def.id) || {};
        const needsConfig = (def.envVars || []).length > 0;
        const configured = needsConfig
            ? (def.envVars || []).every(v => !!envConfig[v])
            : true;

        return {
            id: def.id,
            name: def.name,
            description: def.description,
            icon: def.icon,
            category: def.category,
            tier: def.tier,
            running: client?.isRunning || false,
            toolCount: client?.getTools().length || 0,
            tools: client?.getTools() || [],
            needsConfig,
            envVars: def.envVars || [],
            configured,
        };
    });
}

/**
 * Start an MCP server by id
 */
export async function startServer(id: string): Promise<{ success: boolean; error?: string; tools?: string[] }> {
    const def = SERVER_DEFINITIONS.find(s => s.id === id);
    if (!def) return { success: false, error: `Unknown MCP server: ${id}` };

    // Already running?
    const existing = runningClients.get(id);
    if (existing?.isRunning) {
        return { success: true, tools: existing.getToolNames() };
    }

    // Check env vars
    const env: Record<string, string> = {};
    const savedEnv = serverEnvConfigs.get(id) || {};
    if (def.envVars) {
        for (const v of def.envVars) {
            const val = savedEnv[v] || process.env[v];
            if (!val) {
                return { success: false, error: `Missing required configuration: ${v}` };
            }
            env[v] = val;
        }
    }

    // Special handling for postgres — connection string goes as an arg
    let args = [...def.args];
    if (id === "postgres" && env.POSTGRES_CONNECTION_STRING) {
        args.push(env.POSTGRES_CONNECTION_STRING);
    }

    const client = new GenericMCPClient(id);
    const started = await client.start(def.command, args, env);

    if (!started) {
        return { success: false, error: `Failed to start ${def.name}. Make sure Node.js/npx is available.` };
    }

    runningClients.set(id, client);
    logger.info("mcp", `[Registry] Started server: ${def.name} with ${client.getTools().length} tools`);

    return { success: true, tools: client.getToolNames() };
}

/**
 * Stop an MCP server
 */
export function stopServer(id: string): { success: boolean } {
    const client = runningClients.get(id);
    if (client) {
        client.stop();
        runningClients.delete(id);
        logger.info("mcp", `[Registry] Stopped server: ${id}`);
    }
    return { success: true };
}

/**
 * Configure env vars for a server
 */
export function configureServer(id: string, envValues: Record<string, string>): { success: boolean } {
    const existing = serverEnvConfigs.get(id) || {};
    serverEnvConfigs.set(id, { ...existing, ...envValues });
    return { success: true };
}

/**
 * Get all running MCP tools for injection into AI
 */
export function getAllMCPTools(): Array<{
    serverId: string;
    name: string;
    prefixedName: string;
    description: string;
    parameters: unknown;
}> {
    const tools: Array<{
        serverId: string;
        name: string;
        prefixedName: string;
        description: string;
        parameters: unknown;
    }> = [];

    for (const [serverId, client] of runningClients) {
        if (!client.isRunning) continue;
        for (const tool of client.getTools()) {
            tools.push({
                serverId,
                name: tool.name,
                prefixedName: `mcp_${serverId.replace(/-/g, "_")}__${tool.name}`,
                description: `[MCP:${serverId}] ${tool.description || tool.name}`,
                parameters: tool.inputSchema || { type: "object", properties: {}, required: [] },
            });
        }
    }

    return tools;
}

/**
 * Call an MCP tool by its prefixed name
 */
export async function callMCPTool(prefixedName: string, args: Record<string, unknown>): Promise<{
    success: boolean;
    content: string;
    error?: string;
    metadata?: Record<string, unknown>;
}> {
    // Parse prefixed name: mcp_server_id__tool_name
    const match = prefixedName.match(/^mcp_(.+?)__(.+)$/);
    if (!match) {
        return { success: false, content: "", error: `Invalid MCP tool name: ${prefixedName}` };
    }

    const serverId = match[1].replace(/_/g, "-");
    const toolName = match[2];

    const client = runningClients.get(serverId);
    if (!client?.isRunning) {
        return { success: false, content: "", error: `MCP server ${serverId} is not running` };
    }

    return client.callTool(toolName, args);
}

/**
 * Stop all running servers (cleanup on shutdown)
 */
export function stopAllServers(): void {
    for (const [id, client] of runningClients) {
        logger.info("mcp", `[Registry] Stopping: ${id}`);
        client.stop();
    }
    runningClients.clear();
}
