#!/usr/bin/env node
/**
 * whaleos-helper.mjs — System helper for TensorAgent OS desktop shell
 * Provides direct system access for QML (logs, status, restart, exec).
 * Runs on port 7778 alongside OpenWhale (port 7777).
 */
import { createServer } from 'node:http';
import { exec } from 'node:child_process';

const PORT = 7778;

// Track working directory per simple session
let cwd = '/home/ainux';

// Clipboard bridge buffer
let clipboardBuffer = '';

function parseBody(req) {
    return new Promise((resolve) => {
        let body = '';
        req.on('data', c => body += c);
        req.on('end', () => {
            try { resolve(JSON.parse(body)); }
            catch { resolve({ raw: body }); }
        });
    });
}

const server = createServer(async (req, res) => {
    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') { res.writeHead(204); res.end(); return; }

    const url = req.url.split('?')[0];

    try {
        if (url === '/logs') {
            const output = safeExec('journalctl -u openwhale -n 50 --no-pager 2>/dev/null || echo "No logs available"', '/');
            output.then(r => res.end(JSON.stringify({ ok: true, logs: r.stdout })))
                .catch(e => res.end(JSON.stringify({ ok: true, logs: e.stderr || e.message })));

        } else if (url === '/status') {
            let status = 'unknown', uptime = '';
            try {
                const r = await safeExec('systemctl is-active openwhale 2>/dev/null', '/');
                status = r.stdout.trim();
            } catch { status = 'inactive'; }
            try {
                const r = await safeExec('uptime -p 2>/dev/null || uptime', '/');
                uptime = r.stdout.trim();
            } catch { }
            res.end(JSON.stringify({ ok: true, status, uptime }));

        } else if (url === '/restart' && req.method === 'POST') {
            try {
                await safeExec('sudo systemctl restart openwhale 2>&1', '/');
                res.end(JSON.stringify({ ok: true, message: 'Restart initiated' }));
            } catch (e) {
                res.end(JSON.stringify({ ok: false, error: e.message }));
            }

        } else if (url === '/exec' && req.method === 'POST') {
            const body = await parseBody(req);
            const cmd = (body.command || '').trim();
            if (!cmd) {
                res.end(JSON.stringify({ ok: false, stdout: '', stderr: 'No command provided', code: 1, cwd }));
                return;
            }

            // Handle cd specially — update working directory
            if (cmd === 'cd' || cmd.startsWith('cd ')) {
                const target = cmd === 'cd' ? '/home/ainux' : cmd.slice(3).trim().replace(/^~/, '/home/ainux');
                try {
                    // Resolve the path and verify it exists
                    const r = await safeExec(`cd ${JSON.stringify(target)} && pwd`, cwd);
                    cwd = r.stdout.trim();
                    res.end(JSON.stringify({ ok: true, stdout: '', stderr: '', code: 0, cwd }));
                } catch (e) {
                    res.end(JSON.stringify({ ok: false, stdout: '', stderr: `cd: ${target}: No such file or directory`, code: 1, cwd }));
                }
                return;
            }

            try {
                const r = await safeExec(cmd, cwd);
                res.end(JSON.stringify({ ok: true, stdout: r.stdout, stderr: r.stderr, code: 0, cwd }));
            } catch (e) {
                res.end(JSON.stringify({
                    ok: false,
                    stdout: e.stdout || '',
                    stderr: e.stderr || e.message,
                    code: e.code || 1,
                    cwd
                }));
            }

        } else if (url === '/clipboard' && req.method === 'GET') {
            res.end(JSON.stringify({ ok: true, text: clipboardBuffer }));

        } else if (url === '/clipboard' && req.method === 'POST') {
            const body = await parseBody(req);
            clipboardBuffer = body.text || body.raw || '';
            res.end(JSON.stringify({ ok: true, length: clipboardBuffer.length }));

            // ── Time Management (Linux kernel via timedatectl) ──
        } else if (url === '/time/info') {
            try {
                const r = await safeExec('timedatectl show --no-pager 2>/dev/null || timedatectl status 2>/dev/null', '/');
                const lines = r.stdout.trim().split('\n');
                const info = {};
                for (const line of lines) {
                    const [key, ...vals] = line.split('=');
                    if (key && vals.length) info[key.trim()] = vals.join('=').trim();
                }
                // Also get readable timezone
                let timezone = info.Timezone || '';
                let ntpSync = info.NTPSynchronized === 'yes';
                let ntpActive = info.NTP === 'yes';
                let localTime = info.TimeUSec || '';
                let utcTime = info.UniversalTimeUSec || '';
                // Fallback: parse timedatectl status output
                if (!timezone) {
                    const r2 = await safeExec('timedatectl status 2>/dev/null', '/');
                    const statusLines = r2.stdout.trim().split('\n');
                    for (const sl of statusLines) {
                        if (sl.includes('Time zone:')) timezone = sl.split(':').slice(1).join(':').trim().split(' ')[0];
                        if (sl.includes('NTP synchronized:')) ntpSync = sl.includes('yes');
                        if (sl.includes('NTP service:')) ntpActive = sl.includes('active');
                        if (sl.includes('Local time:')) localTime = sl.split(':').slice(1).join(':').trim();
                        if (sl.includes('Universal time:')) utcTime = sl.split(':').slice(1).join(':').trim();
                    }
                }
                res.end(JSON.stringify({
                    ok: true,
                    timezone, ntpSync, ntpActive, localTime, utcTime,
                    raw: info
                }));
            } catch (e) {
                res.end(JSON.stringify({ ok: false, error: e.message }));
            }

        } else if (url === '/time/timezone' && req.method === 'POST') {
            const body = await parseBody(req);
            const tz = (body.timezone || '').trim();
            if (!tz) { res.end(JSON.stringify({ ok: false, error: 'No timezone provided' })); return; }
            try {
                await safeExec(`sudo timedatectl set-timezone ${JSON.stringify(tz)}`, '/');
                res.end(JSON.stringify({ ok: true, timezone: tz }));
            } catch (e) {
                res.end(JSON.stringify({ ok: false, error: e.stderr || e.message }));
            }

        } else if (url === '/time/ntp' && req.method === 'POST') {
            const body = await parseBody(req);
            const enable = body.enable !== false;
            try {
                await safeExec(`sudo timedatectl set-ntp ${enable ? 'true' : 'false'}`, '/');
                res.end(JSON.stringify({ ok: true, ntp: enable }));
            } catch (e) {
                res.end(JSON.stringify({ ok: false, error: e.stderr || e.message }));
            }

        } else if (url === '/time/set' && req.method === 'POST') {
            const body = await parseBody(req);
            const time = (body.time || '').trim(); // Format: "YYYY-MM-DD HH:MM:SS"
            if (!time) { res.end(JSON.stringify({ ok: false, error: 'No time provided' })); return; }
            try {
                // Must disable NTP first to set manual time
                await safeExec('sudo timedatectl set-ntp false', '/');
                await safeExec(`sudo timedatectl set-time ${JSON.stringify(time)}`, '/');
                res.end(JSON.stringify({ ok: true, time }));
            } catch (e) {
                res.end(JSON.stringify({ ok: false, error: e.stderr || e.message }));
            }

        } else if (url === '/time/timezones') {
            try {
                const r = await safeExec('timedatectl list-timezones 2>/dev/null', '/');
                const zones = r.stdout.trim().split('\n').filter(z => z.length > 0);
                res.end(JSON.stringify({ ok: true, timezones: zones }));
            } catch (e) {
                res.end(JSON.stringify({ ok: false, error: e.message, timezones: [] }));
            }

            // ── WebMCP Status ──
        } else if (url === '/browser/webmcp-status') {
            try {
                const r = await safeExec('firefox-esr --version 2>/dev/null || echo "not found"', '/');
                const version = r.stdout.trim();
                res.end(JSON.stringify({
                    ok: true,
                    browserVersion: version,
                    browser: 'firefox-esr',
                    status: version.includes('not found') ? 'Firefox ESR not installed' : 'Firefox ESR available'
                }));
            } catch (e) {
                res.end(JSON.stringify({ ok: false, error: e.message }));
            }

        } else {
            res.end(JSON.stringify({ ok: true, service: 'tensoragent-helper', port: PORT }));
        }
    } catch (e) {
        res.statusCode = 500;
        res.end(JSON.stringify({ ok: false, error: e.message }));
    }
});

function safeExec(cmd, execCwd) {
    return new Promise((resolve, reject) => {
        exec(cmd, {
            cwd: execCwd || cwd,
            encoding: 'utf-8',
            timeout: 15000,
            maxBuffer: 1024 * 1024,
            env: { ...process.env, HOME: '/home/ainux', TERM: 'xterm-256color' }
        }, (err, stdout, stderr) => {
            if (err) { err.stdout = stdout; err.stderr = stderr; reject(err); }
            else resolve({ stdout, stderr });
        });
    });
}

server.listen(PORT, '0.0.0.0', () => {
    console.log(`[tensoragent-helper] Listening on port ${PORT} (all interfaces)`);
});
