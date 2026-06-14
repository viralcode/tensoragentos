/**
 * OpenWhale Command Policy Engine
 * 
 * Reads /etc/ainux/command-policy.conf at startup and enforces DENY/APPROVE/ALLOW
 * rules at runtime. This bridges the static policy file with the live command
 * filter, providing enterprise-grade command governance.
 * 
 * Policy syntax:
 *   DENY <pattern>       — Always blocked, logged as security event
 *   APPROVE <pattern>    — Requires human approval via dashboard
 *   ALLOW <pattern>      — Automatically permitted
 *
 * Rules are evaluated top-to-bottom. First match wins.
 * Commands not matching any rule fall through to APPROVE (fail-safe).
 */

import { readFileSync, existsSync, watchFile } from "node:fs";
import { createLogger } from "../utils/logger.js";

const log = createLogger("command-policy");

export interface PolicyRule {
    action: "DENY" | "APPROVE" | "ALLOW";
    pattern: string;
    regex: RegExp;
    line: number;
}

export interface PolicyCheckResult {
    action: "DENY" | "APPROVE" | "ALLOW";
    matchedRule?: PolicyRule;
    reason: string;
}

// Default policy paths (checked in order)
const POLICY_PATHS = [
    "/etc/ainux/command-policy.conf",
    "./command-policy.conf",
];

let loadedRules: PolicyRule[] = [];
let policyFilePath: string | null = null;
let lastLoadTime: Date | null = null;

/**
 * Parse a command-policy.conf file into rules
 */
function parsePolicy(content: string): PolicyRule[] {
    const rules: PolicyRule[] = [];
    const lines = content.split("\n");

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();

        // Skip comments and empty lines
        if (!line || line.startsWith("#")) continue;

        const match = line.match(/^(DENY|APPROVE|ALLOW)\s+(.+)$/);
        if (!match) {
            log.warn(`Invalid policy line ${i + 1}: ${line}`);
            continue;
        }

        const action = match[1] as "DENY" | "APPROVE" | "ALLOW";
        const pattern = match[2].trim();

        // Convert glob-like pattern to regex
        // * → .* (match anything)
        // Other regex special chars are escaped
        const regexStr = pattern
            .replace(/[.+^${}()|[\]\\]/g, "\\$&")  // escape regex specials (except *)
            .replace(/\*/g, ".*");                    // * → .*

        try {
            rules.push({
                action,
                pattern,
                regex: new RegExp(regexStr),
                line: i + 1,
            });
        } catch (e) {
            log.warn(`Invalid regex from pattern on line ${i + 1}: ${pattern}`, e);
        }
    }

    return rules;
}

/**
 * Load command policy from disk
 */
export function loadPolicy(customPath?: string): void {
    const paths = customPath ? [customPath, ...POLICY_PATHS] : POLICY_PATHS;

    for (const path of paths) {
        if (existsSync(path)) {
            try {
                const content = readFileSync(path, "utf-8");
                loadedRules = parsePolicy(content);
                policyFilePath = path;
                lastLoadTime = new Date();
                log.info(`Loaded ${loadedRules.length} policy rules from ${path}`);

                // Watch for changes (hot-reload)
                try {
                    watchFile(path, { interval: 5000 }, () => {
                        log.info(`Policy file changed, reloading: ${path}`);
                        loadPolicy(path);
                    });
                } catch {
                    // watchFile might fail in containers, that's ok
                }

                return;
            } catch (e) {
                log.warn(`Failed to read policy file ${path}:`, e);
            }
        }
    }

    log.info("No command-policy.conf found, using defaults (all commands require approval)");
}

/**
 * Check a command against the loaded policy
 */
export function checkPolicy(command: string): PolicyCheckResult {
    const trimmed = command.trim();

    // Check loaded rules top-to-bottom (first match wins)
    for (const rule of loadedRules) {
        if (rule.regex.test(trimmed)) {
            return {
                action: rule.action,
                matchedRule: rule,
                reason: `Matched policy rule line ${rule.line}: ${rule.action} ${rule.pattern}`,
            };
        }
    }

    // Default: require approval (fail-safe)
    return {
        action: "APPROVE",
        reason: "No policy rule matched — defaulting to APPROVE (requires human approval)",
    };
}

/**
 * Get policy stats for metrics/dashboard
 */
export function getPolicyStats(): {
    rulesLoaded: number;
    policyFile: string | null;
    lastLoadTime: Date | null;
    denyCount: number;
    approveCount: number;
    allowCount: number;
} {
    return {
        rulesLoaded: loadedRules.length,
        policyFile: policyFilePath,
        lastLoadTime,
        denyCount: loadedRules.filter(r => r.action === "DENY").length,
        approveCount: loadedRules.filter(r => r.action === "APPROVE").length,
        allowCount: loadedRules.filter(r => r.action === "ALLOW").length,
    };
}

/**
 * Get all loaded rules (for dashboard display)
 */
export function getPolicyRules(): PolicyRule[] {
    return [...loadedRules];
}

// Auto-load on import
loadPolicy();
