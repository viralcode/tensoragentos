import React from 'react';

/**
 * WebMCPPanel — Shows registered WebMCP tools from the browser
 */
export default function WebMCPPanel({ tools = [] }) {
    const mockTools = tools.length > 0 ? tools : [
        { name: 'openwhale.exec', desc: 'Execute shell commands', source: 'OpenWhale' },
        { name: 'openwhale.file', desc: 'Read/write files', source: 'OpenWhale' },
        { name: 'openwhale.browser', desc: 'Browser automation via CDP', source: 'OpenWhale' },
        { name: 'openwhale.memory', desc: 'Persistent vector memory', source: 'OpenWhale' },
        { name: 'openwhale.code_exec', desc: 'Execute Python/JS code', source: 'OpenWhale' },
        { name: 'openwhale.screenshot', desc: 'Capture screenshots', source: 'OpenWhale' },
        { name: 'openwhale.github', desc: 'GitHub API operations', source: 'Skill' },
        { name: 'openwhale.notion', desc: 'Notion workspace operations', source: 'Skill' },
        { name: 'ainux.system_info', desc: 'Get hardware information', source: 'System' },
        { name: 'ainux.navigate', desc: 'Navigate browser to URL', source: 'System' },
        { name: 'ainux.screenshot', desc: 'Capture current screen', source: 'System' },
        { name: 'ainux.dom_query', desc: 'Query DOM elements', source: 'System' },
    ];

    const sourceColor = {
        'OpenWhale': 'var(--cyan)',
        'Skill': 'var(--amber)',
        'System': 'var(--indigo)',
    };

    const sourceBg = {
        'OpenWhale': 'var(--cyan-dim)',
        'Skill': 'var(--amber-dim)',
        'System': 'var(--indigo-glow)',
    };

    return (
        <>
            <div className="panel-header">
                <span className="panel-header-title">🔗 WebMCP Tools</span>
                <span className="dim" style={{ fontSize: 11 }}>
                    {mockTools.length} registered
                </span>
            </div>
            <div className="panel-body">
                <div className="muted" style={{ fontSize: 11, marginBottom: 12 }}>
                    Tools exposed via <span className="mono" style={{ color: 'var(--cyan)' }}>
                        navigator.modelContext
                    </span> — AI agents can invoke these directly.
                </div>

                {mockTools.map((tool, i) => (
                    <div key={i} className="webmcp-tool">
                        <span className="webmcp-tool-name">{tool.name}</span>
                        <span className="webmcp-tool-desc">{tool.desc}</span>
                        <span className="webmcp-badge" style={{
                            background: sourceBg[tool.source],
                            color: sourceColor[tool.source]
                        }}>
                            {tool.source}
                        </span>
                    </div>
                ))}
            </div>
        </>
    );
}
