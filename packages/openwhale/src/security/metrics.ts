/**
 * OpenWhale Metrics — Prometheus-compatible /api/metrics endpoint
 * 
 * Exposes runtime metrics in Prometheus text exposition format:
 * - Process metrics (uptime, memory, CPU)
 * - HTTP request counters and latencies
 * - Agent execution metrics (iterations, tool calls)
 * - Security metrics (blocked commands, active sessions)
 * - Policy enforcement stats
 */

import { getRecentEvents } from "./command-filter.js";
import { getPolicyStats } from "./command-policy.js";

// ─── Counters ──────────────────────────────────────────────────────
const counters = {
    http_requests_total: 0,
    http_errors_total: 0,
    agent_iterations_total: 0,
    agent_tool_calls_total: 0,
    agent_sessions_created: 0,
    commands_blocked_total: 0,
    commands_approved_total: 0,
    commands_allowed_total: 0,
    login_attempts_total: 0,
    login_failures_total: 0,
};

// ─── Histograms (simplified — just track sum and count) ────────────
const histograms: Record<string, { sum: number; count: number; buckets: number[] }> = {
    http_request_duration_seconds: { sum: 0, count: 0, buckets: [0.01, 0.05, 0.1, 0.5, 1, 5, 10] },
    agent_iteration_duration_seconds: { sum: 0, count: 0, buckets: [1, 5, 10, 30, 60, 120, 300] },
};

const bucketCounts: Record<string, number[]> = {
    http_request_duration_seconds: [0, 0, 0, 0, 0, 0, 0],
    agent_iteration_duration_seconds: [0, 0, 0, 0, 0, 0, 0],
};

const startTime = Date.now();

// ─── Public API ───────────────────────────────────────────────────

export function incrementCounter(name: keyof typeof counters, amount = 1): void {
    if (name in counters) {
        counters[name] += amount;
    }
}

export function observeHistogram(name: string, value: number): void {
    const h = histograms[name];
    if (h) {
        h.sum += value;
        h.count += 1;
        const bc = bucketCounts[name];
        for (let i = 0; i < h.buckets.length; i++) {
            if (value <= h.buckets[i]) {
                bc[i]++;
            }
        }
    }
}

/**
 * Generate Prometheus text exposition format
 */
export function generateMetrics(): string {
    const lines: string[] = [];
    const mem = process.memoryUsage();
    const cpu = process.cpuUsage();
    const uptime = (Date.now() - startTime) / 1000;

    // Process metrics
    lines.push("# HELP process_uptime_seconds Process uptime in seconds");
    lines.push("# TYPE process_uptime_seconds gauge");
    lines.push(`process_uptime_seconds ${uptime.toFixed(1)}`);

    lines.push("# HELP process_resident_memory_bytes Resident memory size in bytes");
    lines.push("# TYPE process_resident_memory_bytes gauge");
    lines.push(`process_resident_memory_bytes ${mem.rss}`);

    lines.push("# HELP process_heap_used_bytes V8 heap used in bytes");
    lines.push("# TYPE process_heap_used_bytes gauge");
    lines.push(`process_heap_used_bytes ${mem.heapUsed}`);

    lines.push("# HELP process_heap_total_bytes V8 heap total in bytes");
    lines.push("# TYPE process_heap_total_bytes gauge");
    lines.push(`process_heap_total_bytes ${mem.heapTotal}`);

    lines.push("# HELP process_cpu_user_seconds_total CPU user time in seconds");
    lines.push("# TYPE process_cpu_user_seconds_total counter");
    lines.push(`process_cpu_user_seconds_total ${(cpu.user / 1e6).toFixed(3)}`);

    lines.push("# HELP process_cpu_system_seconds_total CPU system time in seconds");
    lines.push("# TYPE process_cpu_system_seconds_total counter");
    lines.push(`process_cpu_system_seconds_total ${(cpu.system / 1e6).toFixed(3)}`);

    // HTTP counters
    lines.push("# HELP openwhale_http_requests_total Total HTTP requests");
    lines.push("# TYPE openwhale_http_requests_total counter");
    lines.push(`openwhale_http_requests_total ${counters.http_requests_total}`);

    lines.push("# HELP openwhale_http_errors_total Total HTTP errors");
    lines.push("# TYPE openwhale_http_errors_total counter");
    lines.push(`openwhale_http_errors_total ${counters.http_errors_total}`);

    // Agent metrics
    lines.push("# HELP openwhale_agent_iterations_total Total agent loop iterations");
    lines.push("# TYPE openwhale_agent_iterations_total counter");
    lines.push(`openwhale_agent_iterations_total ${counters.agent_iterations_total}`);

    lines.push("# HELP openwhale_agent_tool_calls_total Total tool calls executed");
    lines.push("# TYPE openwhale_agent_tool_calls_total counter");
    lines.push(`openwhale_agent_tool_calls_total ${counters.agent_tool_calls_total}`);

    lines.push("# HELP openwhale_agent_sessions_created Total sessions created");
    lines.push("# TYPE openwhale_agent_sessions_created counter");
    lines.push(`openwhale_agent_sessions_created ${counters.agent_sessions_created}`);

    // Security metrics
    lines.push("# HELP openwhale_commands_blocked_total Commands blocked by policy");
    lines.push("# TYPE openwhale_commands_blocked_total counter");
    lines.push(`openwhale_commands_blocked_total ${counters.commands_blocked_total}`);

    lines.push("# HELP openwhale_commands_approved_total Commands requiring approval");
    lines.push("# TYPE openwhale_commands_approved_total counter");
    lines.push(`openwhale_commands_approved_total ${counters.commands_approved_total}`);

    lines.push("# HELP openwhale_commands_allowed_total Commands auto-allowed");
    lines.push("# TYPE openwhale_commands_allowed_total counter");
    lines.push(`openwhale_commands_allowed_total ${counters.commands_allowed_total}`);

    lines.push("# HELP openwhale_login_attempts_total Total login attempts");
    lines.push("# TYPE openwhale_login_attempts_total counter");
    lines.push(`openwhale_login_attempts_total ${counters.login_attempts_total}`);

    lines.push("# HELP openwhale_login_failures_total Failed login attempts");
    lines.push("# TYPE openwhale_login_failures_total counter");
    lines.push(`openwhale_login_failures_total ${counters.login_failures_total}`);

    // Policy stats
    const policy = getPolicyStats();
    lines.push("# HELP openwhale_policy_rules_loaded Number of policy rules loaded");
    lines.push("# TYPE openwhale_policy_rules_loaded gauge");
    lines.push(`openwhale_policy_rules_loaded ${policy.rulesLoaded}`);

    lines.push(`openwhale_policy_deny_rules ${policy.denyCount}`);
    lines.push(`openwhale_policy_approve_rules ${policy.approveCount}`);
    lines.push(`openwhale_policy_allow_rules ${policy.allowCount}`);

    // Security events (last 5 minutes)
    const recentEvents = getRecentEvents(100);
    const fiveMinAgo = Date.now() - 5 * 60 * 1000;
    const recentBlocked = recentEvents.filter(
        e => e.type === "blocked" && e.timestamp.getTime() > fiveMinAgo
    ).length;

    lines.push("# HELP openwhale_security_events_recent_blocked Blocked events in last 5 minutes");
    lines.push("# TYPE openwhale_security_events_recent_blocked gauge");
    lines.push(`openwhale_security_events_recent_blocked ${recentBlocked}`);

    // Histograms
    for (const [name, h] of Object.entries(histograms)) {
        const bc = bucketCounts[name];
        lines.push(`# HELP openwhale_${name} ${name.replace(/_/g, " ")}`);
        lines.push(`# TYPE openwhale_${name} histogram`);
        let cumulative = 0;
        for (let i = 0; i < h.buckets.length; i++) {
            cumulative += bc[i];
            lines.push(`openwhale_${name}_bucket{le="${h.buckets[i]}"} ${cumulative}`);
        }
        lines.push(`openwhale_${name}_bucket{le="+Inf"} ${h.count}`);
        lines.push(`openwhale_${name}_sum ${h.sum.toFixed(3)}`);
        lines.push(`openwhale_${name}_count ${h.count}`);
    }

    // Node.js info
    lines.push("# HELP nodejs_version_info Node.js version");
    lines.push("# TYPE nodejs_version_info gauge");
    lines.push(`nodejs_version_info{version="${process.version}",platform="${process.platform}",arch="${process.arch}"} 1`);

    return lines.join("\n") + "\n";
}

/**
 * Get metrics as structured JSON (for dashboard)
 */
export function getMetricsJSON(): Record<string, unknown> {
    const mem = process.memoryUsage();
    const policy = getPolicyStats();

    return {
        uptime: (Date.now() - startTime) / 1000,
        memory: {
            rss: mem.rss,
            heapUsed: mem.heapUsed,
            heapTotal: mem.heapTotal,
        },
        counters: { ...counters },
        policy,
        node: {
            version: process.version,
            platform: process.platform,
            arch: process.arch,
        },
    };
}
