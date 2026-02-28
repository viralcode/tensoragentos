/**
 * AInux Logger — Structured logging with levels and colors
 */

const COLORS = {
    reset: '\x1b[0m',
    bold: '\x1b[1m',
    dim: '\x1b[2m',
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    magenta: '\x1b[35m',
    cyan: '\x1b[36m',
    white: '\x1b[37m',
    gray: '\x1b[90m',
};

class Logger {
    constructor(module = 'ainux') {
        this.module = module;
    }

    _ts() {
        return new Date().toISOString().replace('T', ' ').replace('Z', '');
    }

    _fmt(level, color, icon, msg) {
        const ts = `${COLORS.gray}${this._ts()}${COLORS.reset}`;
        const mod = `${COLORS.cyan}[${this.module}]${COLORS.reset}`;
        const lvl = `${color}${icon} ${level}${COLORS.reset}`;
        console.log(`${ts} ${mod} ${lvl} ${msg}`);
    }

    info(msg) { this._fmt('INFO', COLORS.blue, 'ℹ', msg); }
    success(msg) { this._fmt('OK', COLORS.green, '✓', msg); }
    warn(msg) { this._fmt('WARN', COLORS.yellow, '⚠', msg); }
    error(msg) { this._fmt('ERROR', COLORS.red, '✗', msg); }
    debug(msg) { this._fmt('DEBUG', COLORS.gray, '·', msg); }

    banner(msg) {
        const line = '─'.repeat(60);
        console.log(`\n${COLORS.magenta}${COLORS.bold}${line}${COLORS.reset}`);
        console.log(`${COLORS.magenta}${COLORS.bold}  🐋 ${msg}${COLORS.reset}`);
        console.log(`${COLORS.magenta}${COLORS.bold}${line}${COLORS.reset}\n`);
    }

    child(module) {
        return new Logger(`${this.module}:${module}`);
    }
}

export { Logger };
