import React from 'react';

/**
 * StatusBar — Bottom bar showing system state
 */
export default function StatusBar({ state }) {
    return (
        <div className="status-bar">
            <span className="status-bar-item">🐋 AInux v0.1.0</span>
            <span className="status-bar-item">⚡ OpenWhale: {state?.openwhale || 'running'}</span>
            <span className="status-bar-item">🌐 WebMCP: {state?.webmcp || 'active'}</span>
            <div className="status-bar-spacer" />
            <span className="status-bar-item">🔗 CDP :9222</span>
            <span className="status-bar-item">📡 Port :7777</span>
        </div>
    );
}
