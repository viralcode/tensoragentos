import React, { useState, useRef } from 'react';

/**
 * ChatInput — Floating capsule at the bottom of the screen
 * Natural language input → routed to OpenWhale
 */
export default function ChatInput({ onSubmit }) {
    const [message, setMessage] = useState('');
    const [isLoading, setIsLoading] = useState(false);
    const inputRef = useRef(null);

    const handleSubmit = async (e) => {
        e?.preventDefault();
        if (!message.trim() || isLoading) return;

        setIsLoading(true);
        try {
            await onSubmit(message.trim());
            setMessage('');
        } finally {
            setIsLoading(false);
            inputRef.current?.focus();
        }
    };

    const handleKeyDown = (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            handleSubmit();
        }
    };

    return (
        <div className="chat-input-container">
            <form className="chat-input-capsule" onSubmit={handleSubmit}>
                <span style={{ fontSize: 18, marginLeft: 4 }}>🐋</span>
                <input
                    ref={inputRef}
                    className="chat-input"
                    type="text"
                    placeholder="Ask anything... (agents will handle it)"
                    value={message}
                    onChange={e => setMessage(e.target.value)}
                    onKeyDown={handleKeyDown}
                    disabled={isLoading}
                />
                <button
                    className="chat-send-btn"
                    type="submit"
                    disabled={!message.trim() || isLoading}
                >
                    {isLoading ? '⏳' : '↑'}
                </button>
            </form>
        </div>
    );
}
