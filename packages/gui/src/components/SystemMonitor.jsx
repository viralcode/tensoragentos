import React from 'react';

/**
 * SystemMonitor — CPU, Memory, GPU, Network status
 */
export default function SystemMonitor({ hardware }) {
    const stats = hardware || {
        cpu: { brand: 'Detecting...', usage: '0%' },
        memory: { used: '0 GB', total: '0 GB', percent: '0%' },
        gpu: { model: 'Detecting...' },
        network: { connected: true },
        storage: { used: '0 GB', total: '0 GB', percent: '0%' },
    };

    const barClass = (pct) => {
        const n = parseFloat(pct);
        if (n > 80) return 'high';
        if (n > 50) return 'medium';
        return 'low';
    };

    return (
        <>
            <div className="panel-header">
                <span className="panel-header-title">📊 System</span>
                <span className="dim" style={{ fontSize: 11 }}>AInux v0.1.0</span>
            </div>
            <div className="panel-body">
                {/* CPU */}
                <div className="sys-stat">
                    <span className="sys-stat-label">⚡ CPU</span>
                    <span className="sys-stat-value">{stats.cpu.usage || '12%'}</span>
                </div>
                <div className="sys-bar">
                    <div className={`sys-bar-fill ${barClass(stats.cpu.usage || '12')}`}
                        style={{ width: stats.cpu.usage || '12%' }} />
                </div>
                <div className="muted" style={{ fontSize: 10, marginTop: 2, marginBottom: 12 }}>
                    {stats.cpu.brand || 'Unknown CPU'}
                </div>

                {/* Memory */}
                <div className="sys-stat">
                    <span className="sys-stat-label">🧠 Memory</span>
                    <span className="sys-stat-value">{stats.memory.percent || '45%'}</span>
                </div>
                <div className="sys-bar">
                    <div className={`sys-bar-fill ${barClass(stats.memory.percent || '45')}`}
                        style={{ width: stats.memory.percent || '45%' }} />
                </div>
                <div className="muted" style={{ fontSize: 10, marginTop: 2, marginBottom: 12 }}>
                    {stats.memory.used || '7.2 GB'} / {stats.memory.total || '16.0 GB'}
                </div>

                {/* GPU */}
                <div className="sys-stat">
                    <span className="sys-stat-label">🎮 GPU</span>
                    <span className="sys-stat-value" style={{ fontSize: 11 }}>{stats.gpu.model || 'Mesa Intel'}</span>
                </div>
                <div style={{ marginBottom: 12 }} />

                {/* Network */}
                <div className="sys-stat">
                    <span className="sys-stat-label">🌐 Network</span>
                    <span className="sys-stat-value" style={{
                        color: stats.network?.connected !== false ? '#22c55e' : '#ef4444'
                    }}>
                        {stats.network?.connected !== false ? '● Connected' : '● Disconnected'}
                    </span>
                </div>
                <div style={{ marginBottom: 12 }} />

                {/* Storage */}
                <div className="sys-stat">
                    <span className="sys-stat-label">💾 Storage</span>
                    <span className="sys-stat-value">{stats.storage?.percent || '32%'}</span>
                </div>
                <div className="sys-bar">
                    <div className={`sys-bar-fill ${barClass(stats.storage?.percent || '32')}`}
                        style={{ width: stats.storage?.percent || '32%' }} />
                </div>
                <div className="muted" style={{ fontSize: 10, marginTop: 2, marginBottom: 12 }}>
                    {stats.storage?.used || '6.4 GB'} / {stats.storage?.total || '20 GB'}
                </div>

                {/* Processes */}
                <div style={{ marginTop: 16 }}>
                    <div className="sys-stat">
                        <span className="sys-stat-label" style={{ fontWeight: 600 }}>Processes</span>
                    </div>
                    {['OpenWhale', 'Chromium', 'AInux Kernel', 'PipeWire'].map(proc => (
                        <div key={proc} className="sys-stat">
                            <span className="sys-stat-label mono" style={{ fontSize: 11 }}>{proc}</span>
                            <span className="sys-stat-value" style={{ color: '#22c55e', fontSize: 11 }}>● running</span>
                        </div>
                    ))}
                </div>
            </div>
        </>
    );
}
