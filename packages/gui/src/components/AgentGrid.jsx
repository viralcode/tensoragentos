import React from 'react';

/**
 * AgentGrid — Shows all running AI agents with status
 */
export default function AgentGrid({ agents = [] }) {
    const mockAgents = agents.length > 0 ? agents : [
        { id: 1, name: 'Orchestrator', status: 'running', task: 'Coordinating agent swarm', model: 'Claude 5' },
        { id: 2, name: 'Research Agent', status: 'running', task: 'Analyzing web search results', model: 'GPT-5' },
        { id: 3, name: 'Coder Agent', status: 'waiting', task: 'Waiting for research results', model: 'Gemini 3' },
        { id: 4, name: 'Browser Agent', status: 'running', task: 'Navigating github.com', model: 'Claude 5' },
    ];

    return (
        <>
            <div className="panel-header">
                <span className="panel-header-title">🤖 Agent Grid</span>
                <span className="dim" style={{ fontSize: 11 }}>
                    {mockAgents.filter(a => a.status === 'running').length}/{mockAgents.length} active
                </span>
            </div>
            <div className="panel-body">
                {mockAgents.map(agent => (
                    <div key={agent.id} className={`agent-card ${agent.status}`}>
                        <div className={`agent-avatar ${agent.status}`}>
                            {agent.status === 'running' ? '⚡' : agent.status === 'waiting' ? '⏳' : '❌'}
                        </div>
                        <div className="agent-info">
                            <div className="agent-name">{agent.name}</div>
                            <div className="agent-task">{agent.task}</div>
                        </div>
                        <span className="mono muted" style={{ fontSize: 10 }}>{agent.model}</span>
                        <div className={`agent-status-dot ${agent.status}`} />
                    </div>
                ))}

                {mockAgents.length === 0 && (
                    <div className="empty-state">
                        <div className="empty-state-icon">🤖</div>
                        <div className="empty-state-text">No agents running</div>
                        <div className="muted" style={{ fontSize: 11 }}>
                            Send a message to start an agent swarm
                        </div>
                    </div>
                )}
            </div>
        </>
    );
}
