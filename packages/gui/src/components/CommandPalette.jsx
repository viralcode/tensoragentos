import React, { useState, useRef, useEffect } from 'react';

/**
 * CommandPalette — Ctrl+K overlay for natural language commands
 */
export default function CommandPalette({ onCommand, onClose }) {
    const [query, setQuery] = useState('');
    const [selectedIdx, setSelectedIdx] = useState(0);
    const inputRef = useRef(null);

    const commands = [
        { action: 'layout.quad', label: 'Layout: Quad panels', icon: '⊞', shortcut: '' },
        { action: 'layout.single', label: 'Layout: Single panel', icon: '⬜', shortcut: '' },
        { action: 'layout.split-h', label: 'Layout: Horizontal split', icon: '⬜⬜', shortcut: '' },
        { action: 'layout.split-v', label: 'Layout: Vertical split', icon: '⬛', shortcut: '' },
        { action: 'panel.agents', label: 'Show: Agent Grid', icon: '🤖', shortcut: '' },
        { action: 'panel.terminal', label: 'Show: Terminal', icon: '⌨️', shortcut: '' },
        { action: 'panel.webmcp', label: 'Show: WebMCP Tools', icon: '🔗', shortcut: '' },
        { action: 'panel.system', label: 'Show: System Monitor', icon: '📊', shortcut: '' },
    ];

    const filtered = query.trim()
        ? commands.filter(c => c.label.toLowerCase().includes(query.toLowerCase()))
        : commands;

    // If no matches, treat input as natural language command
    const items = filtered.length > 0 ? filtered : [
        { action: query, label: `Ask AI: "${query}"`, icon: '🐋', shortcut: '↵' },
    ];

    useEffect(() => {
        inputRef.current?.focus();
    }, []);

    useEffect(() => {
        setSelectedIdx(0);
    }, [query]);

    const handleKeyDown = (e) => {
        if (e.key === 'ArrowDown') {
            e.preventDefault();
            setSelectedIdx(i => Math.min(i + 1, items.length - 1));
        } else if (e.key === 'ArrowUp') {
            e.preventDefault();
            setSelectedIdx(i => Math.max(i - 1, 0));
        } else if (e.key === 'Enter') {
            e.preventDefault();
            onCommand(items[selectedIdx]);
        } else if (e.key === 'Escape') {
            onClose();
        }
    };

    return (
        <div className="cmd-palette-overlay" onClick={onClose}>
            <div className="cmd-palette" onClick={e => e.stopPropagation()}>
                <input
                    ref={inputRef}
                    className="cmd-palette-input"
                    type="text"
                    placeholder="Type a command or ask anything..."
                    value={query}
                    onChange={e => setQuery(e.target.value)}
                    onKeyDown={handleKeyDown}
                />
                <div className="cmd-palette-results">
                    {items.map((item, i) => (
                        <div
                            key={item.action}
                            className={`cmd-palette-item ${i === selectedIdx ? 'selected' : ''}`}
                            onClick={() => onCommand(item)}
                            onMouseEnter={() => setSelectedIdx(i)}
                        >
                            <span className="cmd-palette-item-icon">{item.icon}</span>
                            <span className="cmd-palette-item-label">{item.label}</span>
                            {item.shortcut && (
                                <span className="cmd-palette-item-shortcut">{item.shortcut}</span>
                            )}
                        </div>
                    ))}
                </div>
            </div>
        </div>
    );
}
