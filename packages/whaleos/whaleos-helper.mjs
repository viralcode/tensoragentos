#!/usr/bin/env node
/**
 * whaleos-helper.mjs — Tiny HTTP helper for WhaleOS QML desktop
 * Serves system logs and status directly (no AI processing needed).
 * Runs on port 7778 alongside OpenWhale (port 7777).
 */
import { createServer } from 'node:http';
import { execSync } from 'node:child_process';

const PORT = 7778;

const server = createServer((req, res) => {
    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Access-Control-Allow-Origin', '*');

    try {
        if (req.url === '/logs') {
            const lines = new URL(req.url, `http://localhost:${PORT}`).searchParams?.get('n') || '50';
            const output = execSync(`journalctl -u openwhale -n ${parseInt(lines) || 50} --no-pager 2>/dev/null || echo "No logs available"`, { encoding: 'utf-8', timeout: 5000 });
            res.end(JSON.stringify({ ok: true, logs: output }));
        } else if (req.url === '/status') {
            let status = 'unknown';
            try {
                const out = execSync('systemctl is-active openwhale 2>/dev/null', { encoding: 'utf-8', timeout: 3000 }).trim();
                status = out; // 'active', 'inactive', 'failed', etc.
            } catch { status = 'inactive'; }

            let uptime = '';
            try { uptime = execSync('uptime -p 2>/dev/null || uptime', { encoding: 'utf-8', timeout: 3000 }).trim(); } catch { }

            res.end(JSON.stringify({ ok: true, status, uptime }));
        } else if (req.url === '/restart') {
            if (req.method !== 'POST') {
                res.statusCode = 405;
                res.end(JSON.stringify({ ok: false, error: 'POST only' }));
                return;
            }
            try {
                execSync('sudo systemctl restart openwhale 2>&1', { encoding: 'utf-8', timeout: 10000 });
                res.end(JSON.stringify({ ok: true, message: 'Restart initiated' }));
            } catch (e) {
                res.end(JSON.stringify({ ok: false, error: e.message }));
            }
        } else {
            res.end(JSON.stringify({ ok: true, service: 'whaleos-helper', port: PORT }));
        }
    } catch (e) {
        res.statusCode = 500;
        res.end(JSON.stringify({ ok: false, error: e.message }));
    }
});

server.listen(PORT, '127.0.0.1', () => {
    console.log(`[whaleos-helper] Listening on port ${PORT}`);
});
