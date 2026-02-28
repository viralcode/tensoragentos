import React, { useRef, useEffect } from 'react';

/**
 * TaskStream — Real-time feed of agent actions
 */
export default function TaskStream({ events = [] }) {
    const bottomRef = useRef(null);

    const mockEvents = events.length > 0 ? events : [
        { id: 1, time: '22:15:03', type: 'tool', agent: 'Orchestrator', icon: '🔀', content: 'Fan-out: deploying 3 parallel agents' },
        { id: 2, time: '22:15:04', type: 'tool', agent: 'Research Agent', icon: '🌐', content: 'browser.navigate → github.com/viralcode/openwhale' },
        { id: 3, time: '22:15:06', type: 'tool', agent: 'Browser Agent', icon: '📸', content: 'screenshot → captured page state (1920x1080)' },
        { id: 4, time: '22:15:08', type: 'tool', agent: 'Research Agent', icon: '🔍', content: 'exec → grep -r "modelContext" src/' },
        { id: 5, time: '22:15:10', type: 'message', agent: 'Coder Agent', icon: '💬', content: 'Received research results, starting implementation...' },
        { id: 6, time: '22:15:12', type: 'tool', agent: 'Coder Agent', icon: '📝', content: 'file.write → packages/core/src/webmcp-bridge.js' },
        { id: 7, time: '22:15:15', type: 'tool', agent: 'Coder Agent', icon: '⚡', content: 'code_exec → npm test (3 passed, 0 failed)' },
        { id: 8, time: '22:15:18', type: 'result', agent: 'Orchestrator', icon: '✅', content: 'Fan-in complete: all agents finished successfully' },
    ];

    useEffect(() => {
        bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
    }, [mockEvents.length]);

    return (
        <>
            <div className="panel-header">
                <span className="panel-header-title">📋 Task Stream</span>
                <span className="dim" style={{ fontSize: 11 }}>
                    {mockEvents.length} events
                </span>
            </div>
            <div className="panel-body">
                {mockEvents.map(event => (
                    <div key={event.id} className="task-item">
                        <span className="task-time">{event.time}</span>
                        <span className="task-icon">{event.icon}</span>
                        <div className="task-content">
                            <span className="agent-ref">{event.agent}</span>{' '}
                            {event.type === 'tool' && (
                                <span className="tool-name">{event.content}</span>
                            )}
                            {event.type !== 'tool' && event.content}
                        </div>
                    </div>
                ))}
                <div ref={bottomRef} />

                {mockEvents.length === 0 && (
                    <div className="empty-state">
                        <div className="empty-state-icon">📋</div>
                        <div className="empty-state-text">No activity yet</div>
                    </div>
                )}
            </div>
        </>
    );
}
