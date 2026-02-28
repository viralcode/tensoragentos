import React from 'react';

/**
 * Sidebar — The left navigation rail
 * Icons only, with active indicator
 */
export default function Sidebar({ activePanel, onPanelChange, onOpenPalette, systemState }) {
    const navItems = [
        { id: 'dashboard', icon: '⚡', label: 'Dashboard' },
        { id: 'agents', icon: '🤖', label: 'Agents' },
        { id: 'tasks', icon: '📋', label: 'Tasks' },
        { id: 'terminal', icon: '⌨️', label: 'Terminal' },
        { id: 'webmcp', icon: '🔗', label: 'WebMCP' },
        { id: 'system', icon: '📊', label: 'System' },
    ];

    return (
        <nav className="ainux-sidebar">
            <div className="sidebar-logo" title="AInux v0.1.0">🐋</div>

            {navItems.map(item => (
                <button
                    key={item.id}
                    className={`sidebar-btn ${activePanel === item.id ? 'active' : ''}`}
                    onClick={() => onPanelChange(item.id)}
                    title={item.label}
                >
                    <span style={{ fontSize: '18px' }}>{item.icon}</span>
                </button>
            ))}

            <div className="sidebar-spacer" />

            <button
                className="sidebar-btn"
                onClick={onOpenPalette}
                title="Command Palette (⌘K)"
            >
                <span style={{ fontSize: '16px' }}>🔍</span>
            </button>

            <button className="sidebar-btn" title="Settings">
                <span style={{ fontSize: '16px' }}>⚙️</span>
            </button>

            {/* Connection indicator */}
            <div style={{
                width: 8, height: 8, borderRadius: '50%',
                background: systemState?.connected ? '#22c55e' : '#ef4444',
                marginBottom: 8,
                boxShadow: systemState?.connected ? '0 0 8px #22c55e' : 'none',
            }} title={systemState?.connected ? 'Connected' : 'Disconnected'} />
        </nav>
    );
}
