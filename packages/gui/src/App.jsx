import React, { useState, useEffect, useCallback } from 'react';
import Sidebar from './components/Sidebar';
import AgentGrid from './components/AgentGrid';
import TaskStream from './components/TaskStream';
import SystemMonitor from './components/SystemMonitor';
import WebMCPPanel from './components/WebMCPPanel';
import TerminalPanel from './components/TerminalPanel';
import CommandPalette from './components/CommandPalette';
import ChatInput from './components/ChatInput';
import StatusBar from './components/StatusBar';
import { useAInuxState } from './hooks/useAInuxState';
import { useWebSocket } from './hooks/useWebSocket';

/**
 * AInux — The Agentic GUI
 * 
 * This is the entire OS user interface. No desktop, no file manager.
 * Just the AI agent control surface.
 */
export default function App() {
    const [activePanel, setActivePanel] = useState('dashboard');
    const [showPalette, setShowPalette] = useState(false);
    const [layout, setLayout] = useState('quad'); // single, split-h, split-v, quad

    const state = useAInuxState();
    const ws = useWebSocket('ws://localhost:7777/ws');

    // Ctrl+K / Cmd+K → Command Palette
    useEffect(() => {
        const handler = (e) => {
            if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
                e.preventDefault();
                setShowPalette(prev => !prev);
            }
            if (e.key === 'Escape') {
                setShowPalette(false);
            }
        };
        window.addEventListener('keydown', handler);
        return () => window.removeEventListener('keydown', handler);
    }, []);

    const handleChatSubmit = useCallback(async (message) => {
        try {
            const res = await fetch('/api/chat', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ message }),
            });
            const data = await res.json();
            state.addTaskEvent({
                type: 'chat_response',
                agent: 'OpenWhale',
                content: data.response || data.message,
                timestamp: Date.now(),
            });
        } catch (err) {
            state.addTaskEvent({
                type: 'error',
                content: `Chat error: ${err.message}`,
                timestamp: Date.now(),
            });
        }
    }, [state]);

    const handlePaletteCommand = useCallback((command) => {
        setShowPalette(false);

        switch (command.action) {
            case 'layout.single': setLayout('single'); break;
            case 'layout.split-h': setLayout('split-h'); break;
            case 'layout.split-v': setLayout('split-v'); break;
            case 'layout.quad': setLayout('quad'); break;
            case 'panel.agents': setActivePanel('agents'); break;
            case 'panel.terminal': setActivePanel('terminal'); break;
            case 'panel.webmcp': setActivePanel('webmcp'); break;
            case 'panel.system': setActivePanel('system'); break;
            default:
                // Treat as natural language → send to OpenWhale
                handleChatSubmit(command.label || command.action);
        }
    }, [handleChatSubmit]);

    const renderPanel = (type) => {
        switch (type) {
            case 'agents': return <AgentGrid agents={state.agents} />;
            case 'tasks': return <TaskStream events={state.taskEvents} />;
            case 'terminal': return <TerminalPanel />;
            case 'webmcp': return <WebMCPPanel tools={state.webmcpTools} />;
            case 'system': return <SystemMonitor hardware={state.hardware} />;
            default: return <TaskStream events={state.taskEvents} />;
        }
    };

    const layoutClass = layout === 'quad' ? '' : layout;

    return (
        <div className="ainux-root">
            <Sidebar
                activePanel={activePanel}
                onPanelChange={setActivePanel}
                onOpenPalette={() => setShowPalette(true)}
                systemState={state}
            />

            <div className="ainux-main">
                {layout === 'single' ? (
                    <div className="panel-grid single">
                        <div className="panel">{renderPanel(activePanel)}</div>
                    </div>
                ) : layout === 'split-h' ? (
                    <div className="panel-grid split-h">
                        <div className="panel">{renderPanel('agents')}</div>
                        <div className="panel">{renderPanel('tasks')}</div>
                    </div>
                ) : layout === 'split-v' ? (
                    <div className="panel-grid split-v">
                        <div className="panel">{renderPanel('tasks')}</div>
                        <div className="panel">{renderPanel('terminal')}</div>
                    </div>
                ) : (
                    <div className="panel-grid">
                        <div className="panel"><AgentGrid agents={state.agents} /></div>
                        <div className="panel"><TaskStream events={state.taskEvents} /></div>
                        <div className="panel"><SystemMonitor hardware={state.hardware} /></div>
                        <div className="panel"><WebMCPPanel tools={state.webmcpTools} /></div>
                    </div>
                )}

                <ChatInput onSubmit={handleChatSubmit} />

                {showPalette && (
                    <CommandPalette
                        onCommand={handlePaletteCommand}
                        onClose={() => setShowPalette(false)}
                    />
                )}
            </div>
        </div>
    );
}
