import { useState, useEffect, useCallback, useRef } from 'react';

/**
 * WebSocket hook for real-time OpenWhale events
 */
export function useWebSocket(url) {
    const [connected, setConnected] = useState(false);
    const [lastMessage, setLastMessage] = useState(null);
    const wsRef = useRef(null);
    const reconnectTimer = useRef(null);

    const connect = useCallback(() => {
        try {
            const ws = new WebSocket(url);

            ws.onopen = () => {
                setConnected(true);
                console.log('[WS] Connected to', url);
            };

            ws.onmessage = (event) => {
                try {
                    const data = JSON.parse(event.data);
                    setLastMessage(data);
                } catch {
                    setLastMessage({ raw: event.data });
                }
            };

            ws.onclose = () => {
                setConnected(false);
                console.log('[WS] Disconnected, reconnecting in 3s...');
                reconnectTimer.current = setTimeout(connect, 3000);
            };

            ws.onerror = (err) => {
                console.warn('[WS] Error:', err);
                ws.close();
            };

            wsRef.current = ws;
        } catch (err) {
            console.warn('[WS] Connection failed:', err);
            reconnectTimer.current = setTimeout(connect, 3000);
        }
    }, [url]);

    useEffect(() => {
        connect();
        return () => {
            clearTimeout(reconnectTimer.current);
            wsRef.current?.close();
        };
    }, [connect]);

    const send = useCallback((data) => {
        if (wsRef.current?.readyState === WebSocket.OPEN) {
            wsRef.current.send(typeof data === 'string' ? data : JSON.stringify(data));
        }
    }, []);

    return { connected, lastMessage, send };
}
