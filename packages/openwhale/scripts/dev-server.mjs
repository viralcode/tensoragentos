#!/usr/bin/env node
/**
 * dev-server.mjs — Safe development server launcher for OpenWhale
 *
 * Replaces the bare `tsx watch src/index.ts` in package.json "dev" script.
 *
 * Problems this solves:
 *  1. Zombie tsx processes — tsx watch orphans its child Node process on
 *     SIGINT, leaving it running and holding port 7777 hostage.
 *  2. EADDRINUSE on restart — because the zombie owns the port, a fresh
 *     `npm run dev` immediately fails without a nuclear `pkill -9 -f tsx`.
 *  3. Stale code — a zombie running old code silently intercepts requests
 *     while the new process fails to bind, making debugging nightmarish.
 *
 * How it works:
 *  - Kills any process squatting on PORT before spawning tsx watch
 *  - Spawns tsx as a process GROUP (negative PID kill target)
 *  - Forwards SIGINT / SIGTERM to the entire group so no orphans survive
 *  - Exits with the child's exit code so npm scripts propagate failures
 */

import { execSync, spawn } from 'child_process';
import { createServer } from 'net';

const PORT = parseInt(process.env.PORT ?? '7777', 10);
const TSX_ARGS = ['watch', 'src/index.ts'];

// ─── Utilities ──────────────────────────────────────────────────────────────

function log(msg) {
  process.stdout.write(`[dev-server] ${msg}\n`);
}

/** Returns true if something is already listening on the port. */
function isPortInUse(port) {
  return new Promise((resolve) => {
    const tester = createServer()
      .once('error', () => resolve(true))
      .once('listening', () => { tester.close(); resolve(false); });
    tester.listen(port, '0.0.0.0');
  });
}

/** Kill all processes squatting on `port` using lsof (macOS / Linux). */
function killPort(port) {
  try {
    // lsof -ti :<port> prints PIDs; xargs kill -9 terminates them.
    // On Linux, fuser -k <port>/tcp can be used as an alternative.
    const pids = execSync(`lsof -ti :${port} 2>/dev/null || true`, { encoding: 'utf8' })
      .trim()
      .split('\n')
      .filter(Boolean);

    if (pids.length === 0) return;

    log(`⚠️  Port ${port} occupied by PID(s): ${pids.join(', ')} — killing…`);
    for (const pid of pids) {
      try { process.kill(parseInt(pid, 10), 'SIGKILL'); } catch { /* already dead */ }
    }
    // Give the OS a moment to release the port
    execSync('sleep 0.3 2>/dev/null || timeout /T 0 2>nul', { stdio: 'ignore' });
  } catch {
    // lsof may not be installed (unlikely on macOS/Linux but be safe)
    log(`⚠️  Could not probe port ${port} (lsof missing?) — proceeding anyway`);
  }
}

// ─── Main ───────────────────────────────────────────────────────────────────

async function main() {
  log(`Starting OpenWhale dev server on port ${PORT}…`);

  // Step 1: Evict any port squatter
  if (await isPortInUse(PORT)) {
    killPort(PORT);
    // Double-check
    if (await isPortInUse(PORT)) {
      log(`❌ Port ${PORT} still in use after kill attempt. Aborting.`);
      log(`   Run manually: lsof -ti :${PORT} | xargs kill -9`);
      process.exit(1);
    }
  } else {
    log(`✓ Port ${PORT} is free`);
  }

  // Step 2: Find tsx binary
  let tsxBin = 'tsx';
  try {
    // Prefer the local node_modules/.bin/tsx for version consistency
    tsxBin = execSync('node -e "require.resolve(\'tsx/dist/cli.mjs\')"', {
      encoding: 'utf8', stdio: ['pipe', 'pipe', 'ignore']
    }).trim();
    // Fallback: use the CLI shim
    tsxBin = new URL('../node_modules/.bin/tsx', import.meta.url).pathname;
  } catch {
    // Global tsx fallback — will error properly if not installed
  }

  log(`Launching: tsx ${TSX_ARGS.join(' ')}`);
  log(`Press Ctrl+C to stop (all child processes will be cleaned up)\n`);

  // Step 3: Spawn tsx watch in its own process group (detached=true gives it
  // a new PGID so we can kill the whole group with -PGID, not just the tsx parent)
  const child = spawn('tsx', TSX_ARGS, {
    stdio: 'inherit',
    detached: true,   // new process group
    env: { ...process.env, PORT: String(PORT) },
  });

  // Attach so the parent doesn't exit while child is running
  child.unref();     // unref so parent can receive signals
  let exiting = false;

  function cleanup(signal) {
    if (exiting) return;
    exiting = true;
    log(`\nReceived ${signal} — stopping all processes…`);
    try {
      // Kill the entire process GROUP (child + all grandchildren)
      process.kill(-child.pid, 'SIGTERM');
    } catch {
      // Child already dead
    }
    // Forcefully kill after grace period
    setTimeout(() => {
      try { process.kill(-child.pid, 'SIGKILL'); } catch { /* gone */ }
      process.exit(0);
    }, 3000).unref();
  }

  process.on('SIGINT',  () => cleanup('SIGINT'));
  process.on('SIGTERM', () => cleanup('SIGTERM'));
  process.on('SIGHUP',  () => cleanup('SIGHUP'));

  child.on('exit', (code, sig) => {
    if (!exiting) {
      const reason = sig ? `signal ${sig}` : `code ${code}`;
      log(`tsx exited (${reason})`);
      process.exit(code ?? 1);
    }
  });
}

main().catch((err) => {
  process.stderr.write(`[dev-server] Fatal: ${err.message}\n`);
  process.exit(1);
});
