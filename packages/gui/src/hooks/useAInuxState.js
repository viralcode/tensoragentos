import { useState, useCallback, useEffect } from 'react';

/**
 * Core state management for the AInux GUI
 * Polls the kernel/OpenWhale for status updates
 */
export function useAInuxState() {
    const [agents, setAgents] = useState([]);
    const [taskEvents, setTaskEvents] = useState([]);
    const [webmcpTools, setWebmcpTools] = useState([]);
    const [hardware, setHardware] = useState(null);
    const [connected, setConnected] = useState(false);

    // Poll system status
    useEffect(() => {
        let active = true;

        const poll = async () => {
            try {
                const res = await fetch('/api/health');
                if (res.ok) {
                    setConnected(true);
                }
            } catch {
                setConnected(false);
            }
        };

        poll();
        const interval = setInterval(poll, 5000);
        return () => { active = false; clearInterval(interval); };
    }, []);

    const addTaskEvent = useCallback((event) => {
        setTaskEvents(prev => [...prev.slice(-100), {
            ...event,
            id: Date.now(),
            time: new Date().toLocaleTimeString('en-US', { hour12: false }),
        }]);
    }, []);

    const addAgent = useCallback((agent) => {
        setAgents(prev => {
            const existing = prev.findIndex(a => a.id === agent.id);
            if (existing >= 0) {
                const updated = [...prev];
                updated[existing] = { ...updated[existing], ...agent };
                return updated;
            }
            return [...prev, agent];
        });
    }, []);

    const removeAgent = useCallback((agentId) => {
        setAgents(prev => prev.filter(a => a.id !== agentId));
    }, []);

    return {
        agents,
        taskEvents,
        webmcpTools,
        hardware,
        connected,
        addTaskEvent,
        addAgent,
        removeAgent,
        setWebmcpTools,
        setHardware,
    };
}
