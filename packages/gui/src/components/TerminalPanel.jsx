import React, { useRef, useEffect } from 'react';

/**
 * TerminalPanel — Embedded terminal using xterm.js
 * Falls back to a simple output view if xterm.js isn't available
 */
export default function TerminalPanel() {
    const termRef = useRef(null);
    const xtermRef = useRef(null);

    useEffect(() => {
        let cleanup = () => { };

        const initTerminal = async () => {
            try {
                const { Terminal } = await import('@xterm/xterm');
                const { FitAddon } = await import('@xterm/addon-fit');
                await import('@xterm/xterm/css/xterm.css');

                const term = new Terminal({
                    fontFamily: "'JetBrains Mono', 'Fira Code', monospace",
                    fontSize: 13,
                    lineHeight: 1.4,
                    theme: {
                        background: '#09090b',
                        foreground: '#fafafa',
                        cursor: '#6366f1',
                        cursorAccent: '#09090b',
                        selectionBackground: 'rgba(99, 102, 241, 0.3)',
                        black: '#18181b',
                        red: '#ef4444',
                        green: '#22c55e',
                        yellow: '#f59e0b',
                        blue: '#6366f1',
                        magenta: '#a855f7',
                        cyan: '#06b6d4',
                        white: '#fafafa',
                    },
                    cursorBlink: true,
                    cursorStyle: 'bar',
                    scrollback: 5000,
                    rows: 24,
                });

                const fitAddon = new FitAddon();
                term.loadAddon(fitAddon);

                if (termRef.current) {
                    term.open(termRef.current);
                    fitAddon.fit();

                    // Welcome message
                    term.writeln('\x1b[35m  🐋 AInux Terminal\x1b[0m');
                    term.writeln('\x1b[90m  Connected to AInux kernel\x1b[0m');
                    term.writeln('');
                    term.write('\x1b[36mainux\x1b[0m:\x1b[34m~\x1b[0m$ ');

                    // Handle input
                    let currentLine = '';
                    term.onKey(({ key, domEvent }) => {
                        if (domEvent.key === 'Enter') {
                            term.writeln('');
                            if (currentLine.trim()) {
                                // Send to AInux kernel via IPC
                                term.writeln(`\x1b[90m$ ${currentLine}\x1b[0m`);
                                executeCommand(term, currentLine.trim());
                            }
                            currentLine = '';
                            term.write('\x1b[36mainux\x1b[0m:\x1b[34m~\x1b[0m$ ');
                        } else if (domEvent.key === 'Backspace') {
                            if (currentLine.length > 0) {
                                currentLine = currentLine.slice(0, -1);
                                term.write('\b \b');
                            }
                        } else if (key.length === 1 && !domEvent.ctrlKey && !domEvent.metaKey) {
                            currentLine += key;
                            term.write(key);
                        }
                    });

                    // Handle resize
                    const resizeObserver = new ResizeObserver(() => fitAddon.fit());
                    if (termRef.current) resizeObserver.observe(termRef.current);

                    xtermRef.current = term;
                    cleanup = () => {
                        resizeObserver.disconnect();
                        term.dispose();
                    };
                }
            } catch (err) {
                console.warn('xterm.js not available, using fallback terminal');
            }
        };

        initTerminal();
        return () => cleanup();
    }, []);

    return (
        <>
            <div className="panel-header">
                <span className="panel-header-title">⌨️ Terminal</span>
                <span className="dim" style={{ fontSize: 11 }}>bash</span>
            </div>
            <div className="terminal-wrapper" ref={termRef} />
        </>
    );
}

async function executeCommand(term, cmd) {
    try {
        const res = await fetch('/api/tool', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ tool: 'exec', params: { command: cmd } }),
        });
        const data = await res.json();
        if (data.output) {
            term.writeln(data.output);
        }
        if (data.error) {
            term.writeln(`\x1b[31m${data.error}\x1b[0m`);
        }
    } catch (err) {
        term.writeln(`\x1b[31mError: ${err.message}\x1b[0m`);
    }
}
