import React, { useCallback, useEffect, useRef, useState } from 'react';

const POLL_MS = 8000;
const URGENT = ['ReportReceived', 'TripNearlyFull', 'NearlyFull', 'TripDelayed', 'TripCancelled'];

const when = (value) => (value ? new Date(value).toLocaleString([], { dateStyle: 'medium', timeStyle: 'short' }) : '');

/** Bell with a red unread badge, a dropdown inbox, and pop-up toasts for new alerts. */
export default function NotificationBell({ api, onOpenTrip }) {
  const [items, setItems] = useState([]);
  const [open, setOpen] = useState(false);
  const [toasts, setToasts] = useState([]);
  const seen = useRef(null);

  const load = useCallback(async () => {
    try {
      const list = await api('/api/notifications?take=50');
      setItems(list);
      const ids = new Set(list.map((item) => item.id));
      if (seen.current === null) {
        seen.current = ids; // first load: do not pop up old messages
        return;
      }
      const fresh = list.filter((item) => !seen.current.has(item.id) && !item.readAtUtc);
      seen.current = ids;
      if (fresh.length > 0) {
        setToasts((current) => [...fresh.slice(0, 3), ...current].slice(0, 4));
        window.setTimeout(() => setToasts((current) => current.filter((t) => !fresh.includes(t))), 9000);
      }
    } catch {
      // The inbox simply keeps its last state while the API is unreachable.
    }
  }, [api]);

  useEffect(() => {
    load();
    const timer = window.setInterval(load, POLL_MS);
    return () => window.clearInterval(timer);
  }, [load]);

  const unread = items.filter((item) => !item.readAtUtc).length;

  const markRead = async (item) => {
    if (!item.readAtUtc) {
      try {
        await api(`/api/notifications/${item.id}/read`, { method: 'PUT' });
      } catch { /* ignore */ }
    }
    setItems((current) => current.map((n) => (n.id === item.id ? { ...n, readAtUtc: new Date().toISOString() } : n)));
    if (item.tripId && onOpenTrip) {
      setOpen(false);
      onOpenTrip(item.tripId);
    }
  };

  const markAll = async () => {
    try {
      await api('/api/notifications/read-all', { method: 'PUT' });
    } catch { /* ignore */ }
    setItems((current) => current.map((n) => ({ ...n, readAtUtc: n.readAtUtc || new Date().toISOString() })));
  };

  return (
    <div className="bell-wrap">
      <button type="button" className="bell-button" aria-label={`Notifications${unread ? `, ${unread} unread` : ''}`}
        onClick={() => setOpen((value) => !value)}>
        <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
          <path d="M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9" /><path d="M13.7 21a2 2 0 0 1-3.4 0" />
        </svg>
        {unread > 0 && <span className="bell-badge">{unread > 9 ? '9+' : unread}</span>}
      </button>

      {open && (
        <div className="bell-panel" role="dialog" aria-label="Notifications">
          <div className="bell-head">
            <strong>Notifications</strong>
            <button type="button" className="link-button" onClick={markAll} disabled={unread === 0}>Mark all read</button>
          </div>
          {items.length === 0 && <p className="bell-empty">Nothing yet. New reports and trip alerts appear here.</p>}
          <ul>
            {items.map((item) => (
              <li key={item.id} className={`${item.readAtUtc ? '' : 'unread'} ${URGENT.includes(item.type) ? 'urgent' : ''}`}>
                <button type="button" onClick={() => markRead(item)}>
                  <span className="dot" />
                  <span className="text"><b>{item.title}</b><small>{item.message}</small><em>{when(item.createdAtUtc)}</em></span>
                </button>
              </li>
            ))}
          </ul>
        </div>
      )}

      <div className="toast-stack" aria-live="assertive">
        {toasts.map((item) => (
          <div key={item.id} className={`toast ${URGENT.includes(item.type) ? 'urgent' : ''}`}>
            <b>{item.title}</b><span>{item.message}</span>
            <button type="button" aria-label="Dismiss" onClick={() => setToasts((c) => c.filter((t) => t.id !== item.id))}>×</button>
          </div>
        ))}
      </div>
    </div>
  );
}
