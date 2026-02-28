import { z } from "zod";
import type { AgentTool, ToolCallContext, ToolResult } from "./base.js";
import { exec } from "node:child_process";
import { promisify } from "node:util";
import * as os from "node:os";
import * as fs from "node:fs";

const execAsync = promisify(exec);

const EXEC_OPTS = {
    timeout: 15000,
    maxBuffer: 1024 * 1024 * 2,
    env: { ...process.env, TERM: "xterm-256color", LANG: "en_US.UTF-8" },
};

async function run(cmd: string, cwd?: string): Promise<string> {
    try {
        const { stdout, stderr } = await execAsync(cmd, { ...EXEC_OPTS, cwd: cwd || "/" });
        return (stdout + (stderr ? `\n${stderr}` : "")).trim();
    } catch (e: any) {
        return (e.stdout || "") + (e.stderr || e.message || "");
    }
}

const KernelOSActionSchema = z.object({
    action: z.enum([
        // Process management
        "process_list", "process_kill", "process_tree", "process_info",
        // Service management (systemd)
        "service_list", "service_status", "service_start", "service_stop", "service_restart", "service_logs",
        // Filesystem operations
        "fs_list", "fs_stat", "fs_read", "fs_write", "fs_mkdir", "fs_delete", "fs_find", "fs_du",
        // Network
        "net_interfaces", "net_connections", "net_ports", "net_dns", "net_ping", "net_route", "net_iptables",
        // Hardware & Kernel
        "hw_info", "kernel_version", "kernel_modules", "kernel_dmesg", "kernel_sysctl",
        "hw_usb", "hw_pci", "hw_storage",
        // Users & permissions
        "user_list", "user_groups", "user_sessions", "user_add", "user_passwd",
        // Package management
        "pkg_list", "pkg_install", "pkg_remove", "pkg_search", "pkg_update",
        // System control
        "sys_env", "sys_uptime", "sys_hostname", "sys_timezone", "sys_locale",
        "sys_crontab", "sys_mounts", "sys_swap",
        // Logs & monitoring
        "log_journal", "log_syslog", "log_auth",
        // Performance
        "perf_top", "perf_iostat", "perf_vmstat", "perf_load",
    ]).describe("The OS/kernel action to perform"),

    target: z.string().optional().describe("Target (PID, service name, path, package, user, etc.)"),
    args: z.string().optional().describe("Additional arguments (signal number, file content, search pattern, etc.)"),
    count: z.number().optional().default(20).describe("Number of items to return"),
    recursive: z.boolean().optional().default(false).describe("Recursive operation for fs commands"),
});

type KernelOSAction = z.infer<typeof KernelOSActionSchema>;

export const kernelOSTool: AgentTool<KernelOSAction> = {
    name: "kernel_os",
    description: `Deep OS and kernel integration tool for TensorAgent OS. Provides full control over:
- Processes: list, kill, inspect, tree visualization
- Services: systemd management (start/stop/restart/status/logs)
- Filesystem: read/write/list/find/delete/permissions
- Network: interfaces, connections, ports, DNS, routing, firewall
- Hardware: USB, PCI, storage, kernel modules, dmesg
- Users: list, groups, sessions, add users
- Packages: apt install/remove/search/update
- System: environment, crontab, mounts, swap, timezone
- Logs: journalctl, syslog, auth logs
- Performance: top, iostat, vmstat, load averages`,
    category: "system",
    parameters: KernelOSActionSchema,
    requiresElevated: true,

    async execute(params: KernelOSAction, _context: ToolCallContext): Promise<ToolResult> {
        const { action, target, args, count, recursive } = params;

        try {
            switch (action) {
                // ═══════════════ PROCESS MANAGEMENT ═══════════════
                case "process_list": {
                    const out = await run(`ps aux --sort=-%cpu | head -${(count || 20) + 1}`);
                    return { success: true, content: `**Running Processes (top ${count} by CPU)**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "process_kill": {
                    if (!target) return { success: false, content: "", error: "PID required (target)" };
                    const signal = args || "TERM";
                    const out = await run(`kill -${signal} ${target}`);
                    return { success: true, content: `Sent signal ${signal} to PID ${target}\n${out}` };
                }
                case "process_tree": {
                    const out = target
                        ? await run(`pstree -p ${target}`)
                        : await run(`pstree -p | head -${count || 40}`);
                    return { success: true, content: `**Process Tree**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "process_info": {
                    if (!target) return { success: false, content: "", error: "PID required (target)" };
                    const out = await run(`cat /proc/${target}/status 2>/dev/null; echo "---CMDLINE---"; cat /proc/${target}/cmdline 2>/dev/null | tr '\\0' ' '; echo ""; echo "---FD_COUNT---"; ls /proc/${target}/fd 2>/dev/null | wc -l; echo "---CWD---"; readlink /proc/${target}/cwd 2>/dev/null`);
                    return { success: true, content: `**Process ${target} Info**\n\`\`\`\n${out}\n\`\`\`` };
                }

                // ═══════════════ SERVICE MANAGEMENT ═══════════════
                case "service_list": {
                    const out = await run(`systemctl list-units --type=service --no-pager | head -${count || 30}`);
                    return { success: true, content: `**System Services**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "service_status": {
                    if (!target) return { success: false, content: "", error: "Service name required (target)" };
                    const out = await run(`systemctl status ${target} --no-pager -l`);
                    return { success: true, content: `**Service: ${target}**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "service_start": {
                    if (!target) return { success: false, content: "", error: "Service name required" };
                    const out = await run(`sudo systemctl start ${target} 2>&1`);
                    return { success: true, content: `Started service ${target}\n${out}` };
                }
                case "service_stop": {
                    if (!target) return { success: false, content: "", error: "Service name required" };
                    const out = await run(`sudo systemctl stop ${target} 2>&1`);
                    return { success: true, content: `Stopped service ${target}\n${out}` };
                }
                case "service_restart": {
                    if (!target) return { success: false, content: "", error: "Service name required" };
                    const out = await run(`sudo systemctl restart ${target} 2>&1`);
                    return { success: true, content: `Restarted service ${target}\n${out}` };
                }
                case "service_logs": {
                    if (!target) return { success: false, content: "", error: "Service name required" };
                    const n = count || 50;
                    const out = await run(`journalctl -u ${target} -n ${n} --no-pager`);
                    return { success: true, content: `**Logs: ${target} (last ${n})**\n\`\`\`\n${out}\n\`\`\`` };
                }

                // ═══════════════ FILESYSTEM ═══════════════
                case "fs_list": {
                    const p = target || "/";
                    const flags = recursive ? "-laR" : "-la";
                    const out = await run(`ls ${flags} ${JSON.stringify(p)} | head -${count || 50}`);
                    return { success: true, content: `**Directory: ${p}**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "fs_stat": {
                    if (!target) return { success: false, content: "", error: "Path required" };
                    const out = await run(`stat ${JSON.stringify(target)}`);
                    return { success: true, content: `**File Info: ${target}**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "fs_read": {
                    if (!target) return { success: false, content: "", error: "File path required" };
                    try {
                        const content = fs.readFileSync(target, "utf-8");
                        const lines = content.split("\n");
                        const truncated = lines.length > (count || 100)
                            ? lines.slice(0, count || 100).join("\n") + `\n... (${lines.length - (count || 100)} more lines)`
                            : content;
                        return { success: true, content: `**File: ${target}** (${lines.length} lines)\n\`\`\`\n${truncated}\n\`\`\`` };
                    } catch (e: any) {
                        return { success: false, content: "", error: e.message };
                    }
                }
                case "fs_write": {
                    if (!target) return { success: false, content: "", error: "File path required" };
                    if (!args) return { success: false, content: "", error: "Content required (args)" };
                    try {
                        fs.writeFileSync(target, args);
                        return { success: true, content: `Written ${args.length} bytes to ${target}` };
                    } catch (e: any) {
                        return { success: false, content: "", error: e.message };
                    }
                }
                case "fs_mkdir": {
                    if (!target) return { success: false, content: "", error: "Path required" };
                    try {
                        fs.mkdirSync(target, { recursive: true });
                        return { success: true, content: `Created directory: ${target}` };
                    } catch (e: any) {
                        return { success: false, content: "", error: e.message };
                    }
                }
                case "fs_delete": {
                    if (!target) return { success: false, content: "", error: "Path required" };
                    const out = await run(`rm ${recursive ? "-rf" : ""} ${JSON.stringify(target)}`);
                    return { success: true, content: `Deleted: ${target}\n${out}` };
                }
                case "fs_find": {
                    const dir = target || "/";
                    const pattern = args || "*";
                    const out = await run(`find ${JSON.stringify(dir)} -name ${JSON.stringify(pattern)} -maxdepth ${recursive ? 10 : 3} 2>/dev/null | head -${count || 30}`);
                    return { success: true, content: `**Find: ${pattern} in ${dir}**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "fs_du": {
                    const p = target || "/";
                    const out = await run(`du -sh ${JSON.stringify(p)} 2>/dev/null; echo "---"; du -sh ${JSON.stringify(p)}/* 2>/dev/null | sort -rh | head -${count || 15}`);
                    return { success: true, content: `**Disk Usage: ${p}**\n\`\`\`\n${out}\n\`\`\`` };
                }

                // ═══════════════ NETWORK ═══════════════
                case "net_interfaces": {
                    const out = await run("ip -4 addr show 2>/dev/null || ifconfig 2>/dev/null");
                    return { success: true, content: `**Network Interfaces**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "net_connections": {
                    const out = await run(`ss -tunap 2>/dev/null | head -${count || 30} || netstat -tunap 2>/dev/null | head -${count || 30}`);
                    return { success: true, content: `**Active Connections**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "net_ports": {
                    const out = await run(`ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null`);
                    return { success: true, content: `**Listening Ports**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "net_dns": {
                    const host = target || "google.com";
                    const out = await run(`cat /etc/resolv.conf; echo "---LOOKUP---"; nslookup ${host} 2>/dev/null || dig ${host} 2>/dev/null || host ${host} 2>/dev/null`);
                    return { success: true, content: `**DNS**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "net_ping": {
                    const host = target || "1.1.1.1";
                    const out = await run(`ping -c 4 ${host}`);
                    return { success: true, content: `**Ping: ${host}**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "net_route": {
                    const out = await run("ip route show 2>/dev/null || route -n 2>/dev/null");
                    return { success: true, content: `**Routing Table**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "net_iptables": {
                    const out = await run("sudo iptables -L -n -v 2>/dev/null || echo 'iptables not available'");
                    return { success: true, content: `**Firewall Rules (iptables)**\n\`\`\`\n${out}\n\`\`\`` };
                }

                // ═══════════════ HARDWARE & KERNEL ═══════════════
                case "hw_info": {
                    const cpus = os.cpus();
                    const arch = os.arch();
                    const platform = os.platform();
                    const lscpu = await run("lscpu 2>/dev/null | head -20");
                    const meminfo = await run("cat /proc/meminfo 2>/dev/null | head -10");
                    return {
                        success: true,
                        content: [
                            `**Hardware Info**`,
                            `• Architecture: ${arch}`,
                            `• Platform: ${platform}`,
                            `• CPU: ${cpus[0]?.model || "Unknown"} (${cpus.length} cores)`,
                            `• Total RAM: ${(os.totalmem() / 1024 / 1024 / 1024).toFixed(1)} GB`,
                            ``,
                            `\`\`\``,
                            lscpu,
                            `---`,
                            meminfo,
                            `\`\`\``,
                        ].join("\n"),
                    };
                }
                case "kernel_version": {
                    const uname = await run("uname -a");
                    const version = await run("cat /proc/version 2>/dev/null");
                    return { success: true, content: `**Kernel**\n\`\`\`\n${uname}\n${version}\n\`\`\`` };
                }
                case "kernel_modules": {
                    const out = await run(`lsmod | head -${count || 30}`);
                    return { success: true, content: `**Kernel Modules**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "kernel_dmesg": {
                    const out = await run(`dmesg | tail -${count || 30}`);
                    return { success: true, content: `**Kernel Messages (dmesg)**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "kernel_sysctl": {
                    if (target) {
                        if (args) {
                            // Set a sysctl value
                            const out = await run(`sudo sysctl -w ${target}=${args}`);
                            return { success: true, content: `Set ${target} = ${args}\n${out}` };
                        }
                        const out = await run(`sysctl ${target}`);
                        return { success: true, content: `**sysctl ${target}**\n${out}` };
                    }
                    const out = await run(`sysctl -a 2>/dev/null | head -${count || 30}`);
                    return { success: true, content: `**Kernel Parameters**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "hw_usb": {
                    const out = await run("lsusb 2>/dev/null || echo 'lsusb not available'");
                    return { success: true, content: `**USB Devices**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "hw_pci": {
                    const out = await run("lspci 2>/dev/null || echo 'lspci not available'");
                    return { success: true, content: `**PCI Devices**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "hw_storage": {
                    const out = await run("lsblk -f 2>/dev/null; echo '---'; df -h");
                    return { success: true, content: `**Storage**\n\`\`\`\n${out}\n\`\`\`` };
                }

                // ═══════════════ USERS & PERMISSIONS ═══════════════
                case "user_list": {
                    const out = await run("cat /etc/passwd | grep -v nologin | grep -v /bin/false");
                    return { success: true, content: `**Users**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "user_groups": {
                    const user = target || os.userInfo().username;
                    const out = await run(`groups ${user}; echo "---"; id ${user}`);
                    return { success: true, content: `**Groups for ${user}**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "user_sessions": {
                    const out = await run("who; echo '---'; w");
                    return { success: true, content: `**Active Sessions**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "user_add": {
                    if (!target) return { success: false, content: "", error: "Username required" };
                    const out = await run(`sudo useradd -m -s /bin/bash ${target} 2>&1`);
                    return { success: true, content: `Added user: ${target}\n${out}` };
                }
                case "user_passwd": {
                    if (!target || !args) return { success: false, content: "", error: "Username (target) and password (args) required" };
                    const out = await run(`echo "${target}:${args}" | sudo chpasswd 2>&1`);
                    return { success: true, content: `Password set for ${target}\n${out}` };
                }

                // ═══════════════ PACKAGE MANAGEMENT ═══════════════
                case "pkg_list": {
                    const out = await run(`dpkg --list 2>/dev/null | tail -${count || 30} || rpm -qa 2>/dev/null | head -${count || 30} || apk list --installed 2>/dev/null | head -${count || 30}`);
                    return { success: true, content: `**Installed Packages**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "pkg_install": {
                    if (!target) return { success: false, content: "", error: "Package name required" };
                    const out = await run(`sudo apt-get install -y ${target} 2>&1 || sudo yum install -y ${target} 2>&1 || sudo apk add ${target} 2>&1`);
                    return { success: true, content: `**Install: ${target}**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "pkg_remove": {
                    if (!target) return { success: false, content: "", error: "Package name required" };
                    const out = await run(`sudo apt-get remove -y ${target} 2>&1 || sudo yum remove -y ${target} 2>&1 || sudo apk del ${target} 2>&1`);
                    return { success: true, content: `**Remove: ${target}**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "pkg_search": {
                    if (!target) return { success: false, content: "", error: "Search term required" };
                    const out = await run(`apt-cache search ${target} 2>/dev/null | head -${count || 20} || yum search ${target} 2>/dev/null | head -${count || 20}`);
                    return { success: true, content: `**Package Search: ${target}**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "pkg_update": {
                    const out = await run("sudo apt-get update 2>&1 | tail -5 || sudo yum check-update 2>&1 | tail -5");
                    return { success: true, content: `**Package Index Updated**\n\`\`\`\n${out}\n\`\`\`` };
                }

                // ═══════════════ SYSTEM CONTROL ═══════════════
                case "sys_env": {
                    if (target) {
                        return { success: true, content: `${target}=${process.env[target] || "(not set)"}` };
                    }
                    const envStr = Object.entries(process.env)
                        .filter(([k]) => !k.includes("KEY") && !k.includes("SECRET") && !k.includes("TOKEN") && !k.includes("PASS"))
                        .slice(0, count || 30)
                        .map(([k, v]) => `${k}=${v}`)
                        .join("\n");
                    return { success: true, content: `**Environment Variables**\n\`\`\`\n${envStr}\n\`\`\`` };
                }
                case "sys_uptime": {
                    const out = await run("uptime; echo '---'; cat /proc/uptime 2>/dev/null");
                    return { success: true, content: `**Uptime**\n${out}` };
                }
                case "sys_hostname": {
                    if (target) {
                        const out = await run(`sudo hostnamectl set-hostname ${target} 2>&1`);
                        return { success: true, content: `Hostname set to: ${target}\n${out}` };
                    }
                    const out = await run("hostname; echo '---'; hostnamectl 2>/dev/null");
                    return { success: true, content: `**Hostname**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "sys_timezone": {
                    if (target) {
                        const out = await run(`sudo timedatectl set-timezone ${target} 2>&1`);
                        return { success: true, content: `Timezone set to: ${target}\n${out}` };
                    }
                    const out = await run("timedatectl 2>/dev/null || date +%Z");
                    return { success: true, content: `**Timezone**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "sys_locale": {
                    const out = await run("locale; echo '---'; localectl 2>/dev/null");
                    return { success: true, content: `**Locale**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "sys_crontab": {
                    if (target && args) {
                        // Add a cron entry
                        const out = await run(`(crontab -l 2>/dev/null; echo "${args}") | crontab -`);
                        return { success: true, content: `Added cron entry: ${args}\n${out}` };
                    }
                    const out = await run("crontab -l 2>/dev/null || echo 'No crontab'; echo '---SYSTEM---'; cat /etc/crontab 2>/dev/null | head -20");
                    return { success: true, content: `**Crontab**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "sys_mounts": {
                    const out = await run("mount | column -t 2>/dev/null || mount; echo '---'; cat /etc/fstab 2>/dev/null");
                    return { success: true, content: `**Mounts**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "sys_swap": {
                    const out = await run("swapon --show 2>/dev/null || cat /proc/swaps; echo '---'; free -h");
                    return { success: true, content: `**Swap & Memory**\n\`\`\`\n${out}\n\`\`\`` };
                }

                // ═══════════════ LOGS ═══════════════
                case "log_journal": {
                    const unit = target ? `-u ${target}` : "";
                    const out = await run(`journalctl ${unit} -n ${count || 30} --no-pager`);
                    return { success: true, content: `**System Journal${target ? ` (${target})` : ""}**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "log_syslog": {
                    const out = await run(`tail -${count || 30} /var/log/syslog 2>/dev/null || tail -${count || 30} /var/log/messages 2>/dev/null || journalctl -n ${count || 30} --no-pager`);
                    return { success: true, content: `**Syslog**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "log_auth": {
                    const out = await run(`tail -${count || 30} /var/log/auth.log 2>/dev/null || journalctl -u sshd -n ${count || 30} --no-pager`);
                    return { success: true, content: `**Auth Log**\n\`\`\`\n${out}\n\`\`\`` };
                }

                // ═══════════════ PERFORMANCE ═══════════════
                case "perf_top": {
                    const out = await run(`top -b -n 1 | head -${(count || 20) + 7}`);
                    return { success: true, content: `**System Load (top)**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "perf_iostat": {
                    const out = await run("iostat 2>/dev/null || cat /proc/diskstats | head -10");
                    return { success: true, content: `**I/O Statistics**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "perf_vmstat": {
                    const out = await run("vmstat 1 3 2>/dev/null || cat /proc/vmstat | head -20");
                    return { success: true, content: `**VM Statistics**\n\`\`\`\n${out}\n\`\`\`` };
                }
                case "perf_load": {
                    const loadAvg = os.loadavg();
                    const cpuCount = os.cpus().length;
                    const totalMem = os.totalmem();
                    const freeMem = os.freemem();
                    const usedPct = Math.round((1 - freeMem / totalMem) * 100);
                    return {
                        success: true,
                        content: [
                            `**System Load**`,
                            `• Load Average: ${loadAvg.map(l => l.toFixed(2)).join(", ")} (1m, 5m, 15m)`,
                            `• CPU Cores: ${cpuCount}`,
                            `• CPU Saturation: ${(loadAvg[0] / cpuCount * 100).toFixed(0)}%`,
                            `• Memory: ${usedPct}% used (${((totalMem - freeMem) / 1024 / 1024 / 1024).toFixed(1)} GB / ${(totalMem / 1024 / 1024 / 1024).toFixed(1)} GB)`,
                        ].join("\n"),
                    };
                }

                default:
                    return { success: false, content: "", error: `Unknown kernel_os action: ${action}` };
            }
        } catch (err) {
            const message = err instanceof Error ? err.message : String(err);
            return { success: false, content: "", error: `Kernel/OS error: ${message}` };
        }
    },
};
