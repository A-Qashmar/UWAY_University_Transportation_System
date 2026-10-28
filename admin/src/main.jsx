import React, { useCallback, useEffect, useState } from 'react';
import { createRoot } from 'react-dom/client';
import StopsSourceMap from './StopsSourceMap.jsx';
import TripDetailPage from './TripDetailPage.jsx';
import ReportsPanel from './ReportsPanel.jsx';
import NotificationBell from './NotificationBell.jsx';
import './styles.css';

const API_URL = import.meta.env.VITE_UWAY_API_URL || 'http://localhost:5251';
const SESSION_KEY = 'uway-admin-session';

function loadSession() {
  try {
    const stored = JSON.parse(sessionStorage.getItem(SESSION_KEY) || 'null');
    return stored && new Date(stored.expiresAtUtc) > new Date() ? stored : null;
  } catch { return null; }
}
function saveSession(session) {
  try {
    if (session) sessionStorage.setItem(SESSION_KEY, JSON.stringify(session));
    else sessionStorage.removeItem(SESSION_KEY);
  } catch { /* the session then lasts until the page is reloaded */ }
}
let currentSession = loadSession();
function parseBody(text) {
  try { return text ? JSON.parse(text) : null; } catch { return null; }
}

async function apiBlob(path) {
  const response = await fetch(`${API_URL}${path}`, {
    headers: currentSession ? { Authorization: `Bearer ${currentSession.token}` } : {},
  });
  if (!response.ok) throw new Error(`The file could not be loaded (${response.status}).`);
  return response.blob();
}

async function api(path, options = {}) {
  const response = await fetch(`${API_URL}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...(currentSession ? { Authorization: `Bearer ${currentSession.token}` } : {}),
      ...options.headers,
    },
  });
  const text = await response.text();
  const data = parseBody(text);
  if (response.status === 401 && currentSession) {
    window.dispatchEvent(new Event('uway-auth-expired'));
    throw new Error('Your session has ended. Please sign in again.');
  }
  if (!response.ok) {
    const detail = data?.detail || data?.title ||
      Object.values(data?.errors || {}).flat().join(' ') ||
      `Request failed (${response.status}).`;
    throw new Error(detail);
  }
  return data;
}

const NAV = [
  { id: 'overview', label: 'Overview', icon: 'M4 4h7v7H4zM13 4h7v7h-7zM4 13h7v7H4zM13 13h7v7h-7z' },
  { id: 'trips', label: 'Trips', icon: 'M5 16V6a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v10M5 16h14M5 16v2h2v-2M17 16v2h2v-2M5 10h14M8.5 13h.01M15.5 13h.01' },
  { id: 'routes', label: 'Routes', icon: 'M6 19a2 2 0 1 0 0-4 2 2 0 0 0 0 4zM18 9a2 2 0 1 0 0-4 2 2 0 0 0 0 4zM8 17h6a3 3 0 0 0 0-6h-4a3 3 0 0 1 0-6h6' },
  { id: 'stops', label: 'Stops', icon: 'M12 21s-6-5.2-6-10a6 6 0 1 1 12 0c0 4.8-6 10-6 10zM12 11.5a2 2 0 1 0 0-4 2 2 0 0 0 0 4z' },
  { id: 'fleet', label: 'Buses & drivers', icon: 'M16 19v-1a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v1M10 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6M20 19v-1a3 3 0 0 0-2-2.8M16 5.2a3 3 0 0 1 0 5.6' },
  { id: 'source-map', label: 'Source map', icon: 'M9 4L3 6v14l6-2 6 2 6-2V4l-6 2zM9 4v14M15 6v14' },
  { id: 'reports', label: 'Reports', icon: 'M7 3h8l4 4v14H7zM14 3v5h5M10 13h6M10 17h6' },
];
const ACCOUNT_ICON = 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM4 21a8 8 0 0 1 16 0';

function parseTripHash() {
  const match = window.location.hash.match(/^#trip\/([0-9a-fA-F-]+)$/);
  return match ? match[1].toLowerCase() : null;
}

function StatusCell({ trip }) {
  const cancelled = Boolean(trip.cancelledAtUtc);
  return <span className="status-cell">
    {cancelled
      ? <span className="pill pill-cancelled" title={trip.cancellationReason || ''}><i />Cancelled</span>
      : <span className={`pill pill-${trip.status.toLowerCase()}`}><i />{trip.status}</span>}
    {!cancelled && trip.delayMinutes > 0 && <span className="pill pill-delayed" title={trip.delayReason || ''}><i />Delayed {trip.delayMinutes} min</span>}
  </span>;
}

function NavIcon({ path }) {
  return <svg className="nav-icon" viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d={path} /></svg>;
}

function Dashboard({ session, onSignOut }) {
  const [data, setData] = useState({ stops: [], routes: [], buses: [], drivers: [], trips: [] });
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState('');
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [apiHealth, setApiHealth] = useState('checking');
  const [editor, setEditor] = useState(null);
  const [cancellingTrip, setCancellingTrip] = useState(null);
  const [editingTrip, setEditingTrip] = useState(null);
  const [tripError, setTripError] = useState('');
  const [activeNav, setActiveNav] = useState('overview');
  const [openTripId, setOpenTripId] = useState(parseTripHash);
  const [tripSearch, setTripSearch] = useState('');
  const [showAllTrips, setShowAllTrips] = useState(false);
  const [tripStatusFilter, setTripStatusFilter] = useState('All');
  const [stopForm, setStopForm] = useState({ name: '', latitude: '', longitude: '', audience: '' });
  const [routeForm, setRouteForm] = useState({ code: '', name: '', stopIds: [] });
  const [busForm, setBusForm] = useState({ fleetNumber: '', capacity: '', assignedDriverId: '' });
  const [driverForm, setDriverForm] = useState({ fullName: '', phoneNumber: '', assignedBusId: '' });
  const [tripForm, setTripForm] = useState({ routeId: '', busId: '', driverId: '', audience: '' });

  const refresh = useCallback(async () => {
    const [stops, routes, buses, drivers, trips] = await Promise.all([
      api('/api/stops'), api('/api/routes'), api('/api/buses'), api('/api/drivers'), api('/api/trips'),
    ]);
    setData({ stops, routes, buses, drivers, trips });
  }, []);

  useEffect(() => {
    refresh()
      .catch((reason) => setError(reason.message))
      .finally(() => setLoading(false));
  }, [refresh]);

  // Keep the lists fresh without a manual reload.
  useEffect(() => {
    const timer = window.setInterval(() => {
      if (document.visibilityState === 'visible') refresh().catch(() => {});
    }, 15000);
    return () => window.clearInterval(timer);
  }, [refresh]);

  useEffect(() => {
    let active = true;
    const check = () => fetch(`${API_URL}/health`)
      .then((response) => response.ok ? response.text() : Promise.reject(new Error('unavailable')))
      .then(() => { if (active) setApiHealth('healthy'); })
      .catch(() => { if (active) setApiHealth('unavailable'); });
    check();
    const timer = window.setInterval(check, 30000);
    return () => { active = false; window.clearInterval(timer); };
  }, []);

  useEffect(() => {
    const onHash = () => {
      const id = parseTripHash();
      setOpenTripId(id);
      if (id) setActiveNav('trips');
    };
    window.addEventListener('hashchange', onHash);
    return () => window.removeEventListener('hashchange', onHash);
  }, []);

  useEffect(() => {
    if (!notice) return undefined;
    const timer = window.setTimeout(() => setNotice(''), 6000);
    return () => window.clearTimeout(timer);
  }, [notice]);

  // Highlight the menu entry of the section that is currently on screen.
  useEffect(() => {
    if (loading) return undefined;
    const ids = [...NAV.map((item) => item.id), 'account'];
    const observer = new IntersectionObserver((entries) => {
      const visible = entries.filter((entry) => entry.isIntersecting).sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top)[0];
      if (visible) setActiveNav(visible.target.id);
    }, { rootMargin: '-15% 0px -70% 0px' });
    ids.forEach((id) => { const element = document.getElementById(id); if (element) observer.observe(element); });
    return () => observer.disconnect();
  }, [loading, openTripId]);

  async function submit(key, path, body, after) {
    setBusy(key);
    setError('');
    setNotice('');
    try {
      await api(path, { method: 'POST', body: JSON.stringify(body) });
      after();
      await refresh();
      setNotice('Saved. The latest information is shown below.');
    } catch (reason) {
      setError(reason.message);
    } finally {
      setBusy('');
    }
  }

  async function changeTripStatus(trip, action) {
    const label = action === 'start' ? 'start' : 'finish';
    if (!window.confirm(`Mark this trip as ${label === 'start' ? 'Started' : 'Finished'}? Passengers will be notified.`)) return;
    setBusy('trip-status');
    setError('');
    setNotice('');
    try {
      await api(`/api/trips/${trip.id}/${action === 'start' ? 'start' : 'end'}`, { method: 'POST' });
      setEditingTrip(null);
      await refresh();
      setNotice(`Trip marked as ${action === 'start' ? 'Started' : 'Finished'}.`);
    } catch (failure) {
      setError(failure.message);
    } finally {
      setBusy('');
    }
  }

  async function saveTrip(trip, body) {
    setBusy('edit-trip');
    setError('');
    setNotice('');
    setTripError('');
    try {
      await api(`/api/trips/${trip.id}`, { method: 'PUT', body: JSON.stringify(body) });
      setEditingTrip(null);
      await refresh();
      setNotice('Trip updated.');
    } catch (reason) {
      setTripError(reason.message);
    } finally {
      setBusy('');
    }
  }

  async function saveRecord(type, record, body) {
    const path = { stop: 'stops', route: 'routes', bus: 'buses', driver: 'drivers' }[type];
    setBusy(`edit-${type}`);
    setError('');
    try {
      await api(`/api/${path}/${record.id}`, { method: 'PUT', body: JSON.stringify(body) });
      setEditor(null);
      await refresh();
      setNotice(`${type[0].toUpperCase()}${type.slice(1)} updated.`);
    } catch (reason) {
      setError(reason.message);
    } finally {
      setBusy('');
    }
  }

  async function deleteRecord(type, record) {
    const label = type === 'bus' ? record.fleetNumber : type === 'driver' ? record.fullName : record.name;
    if (!window.confirm(`Delete ${label}? The API will keep the record if it is still referenced.`)) return;
    const path = { stop: 'stops', route: 'routes', bus: 'buses', driver: 'drivers' }[type];
    setBusy(`delete-${type}`);
    setError('');
    try {
      await api(`/api/${path}/${record.id}`, { method: 'DELETE' });
      await refresh();
      setNotice(`${type[0].toUpperCase()}${type.slice(1)} deleted.`);
    } catch (reason) {
      setError(reason.message);
    } finally {
      setBusy('');
    }
  }

  async function cancelTrip(trip, reason) {
    setBusy('cancel-trip');
    setError('');
    try {
      await api(`/api/trips/${trip.id}/cancel`, { method: 'POST', body: JSON.stringify({ reason }) });
      setCancellingTrip(null);
      await refresh();
      setNotice('Trip cancelled. Existing Trip Intent records were retained.');
    } catch (failure) {
      setError(failure.message);
    } finally {
      setBusy('');
    }
  }

  async function restoreTrip(trip) {
    if (!window.confirm('Put this cancelled trip back to Scheduled? Passengers who joined will be notified.')) return;
    setBusy('trip-status');
    setError('');
    setNotice('');
    try {
      await api(`/api/trips/${trip.id}/restore`, { method: 'POST' });
      await refresh();
      setNotice('Trip is scheduled again. Passengers who joined were notified.');
    } catch (failure) {
      setError(failure.message);
    } finally {
      setBusy('');
    }
  }

  function openTrip(id) { window.location.hash = `trip/${id}`; }
  function closeTrip() { window.location.hash = 'trips'; }

  // Action buttons for one trip, used by the table and by the trip page.
  function tripActions(trip) {
    const cancelled = Boolean(trip.cancelledAtUtc);
    return <>
      {trip.status === 'Scheduled' && !cancelled && <>
        <button className="table-action" type="button" disabled={busy !== ''} onClick={() => { setTripError(''); setEditingTrip(trip); }}>Edit</button>
        <button className="table-action" type="button" disabled={busy !== ''} onClick={() => changeTripStatus(trip, 'start')}>Start</button>
      </>}
      {trip.status === 'Started' && !cancelled && <button className="table-action" type="button" disabled={busy !== ''} onClick={() => changeTripStatus(trip, 'end')}>Finish</button>}
      {trip.status !== 'Finished' && !cancelled && <button className="table-action danger-action" type="button" disabled={busy !== ''} onClick={() => setCancellingTrip(trip)}>Cancel trip</button>}
      {trip.status !== 'Finished' && cancelled && <button className="table-action restore-action" type="button" disabled={busy !== ''} onClick={() => restoreTrip(trip)}>Restore trip</button>}
    </>;
  }

  function toggleStop(id) {
    setRouteForm((form) => ({
      ...form,
      stopIds: form.stopIds.includes(id)
        ? form.stopIds.filter((value) => value !== id)
        : [...form.stopIds, id],
    }));
  }

  function createTrip(event) {
    event.preventDefault();
    const form = event.currentTarget;
    const departureValue = new FormData(form).get('departureAt');
    const departure = new Date(String(departureValue ?? ''));
    if (!departureValue || Number.isNaN(departure.getTime())) {
      setError('Choose a valid departure date and time.');
      return;
    }
    submit('trip', '/api/trips', {
      routeId: Number(tripForm.routeId),
      busId: Number(tripForm.busId),
      driverId: Number(tripForm.driverId),
      departureAtUtc: departure.toISOString(),
      audience: tripForm.audience,
    }, () => {
      setTripForm({ routeId: '', busId: '', driverId: '', audience: '' });
      form.reset();
    });
  }

  const scheduledTrips = data.trips.filter((trip) => trip.status !== 'Finished' && !trip.cancelledAtUtc);
  const activeTrips = data.trips.filter((trip) => trip.status === 'Started');
  const visibleTrips = data.trips.filter((trip) =>
    (tripStatusFilter === 'All' || (tripStatusFilter === 'Delayed' ? trip.delayMinutes > 0 : tripStatusFilter === 'Cancelled' ? Boolean(trip.cancelledAtUtc) : trip.status === tripStatusFilter)) &&
    `${trip.routeName || ''} ${trip.routeCode} ${trip.status} ${trip.fleetNumber || ''} ${trip.driverName || ''}`
      .toLowerCase().includes(tripSearch.trim().toLowerCase()));

  return (
    <div className="app-shell">
      <aside className="sidebar">
          <a className="brand" href="#overview"><img src="/uway-mark.png" alt="" /><span><b>UWAY</b><small>Operations · University transport</small></span></a>
        <p className="side-label">MENU</p>
        <nav aria-label="Sections">
          {NAV.map((item) => (
            <a key={item.id} href={`#${item.id}`} className={activeNav === item.id ? 'active' : ''} aria-current={activeNav === item.id ? 'true' : undefined} onClick={() => setActiveNav(item.id)}>
              <NavIcon path={item.icon} /><span>{item.label}</span>
            </a>
          ))}
        </nav>
        <nav className="side-bottom" aria-label="Account">
          <a href="#account" className={activeNav === 'account' ? 'active' : ''} aria-current={activeNav === 'account' ? 'true' : undefined} onClick={() => setActiveNav('account')}>
            <NavIcon path={ACCOUNT_ICON} /><span>Account</span>
          </a>
          <div className="side-note">Local project demo<br />Development access only</div>
        </nav>
      </aside>

      <main className="content" id="overview">
        <div className="topline"><div><p className="eyebrow">ADMIN PORTAL</p><h1>Operations dashboard</h1></div><div className="topline-actions"><NotificationBell api={api} onOpenTrip={(id) => { window.location.hash = `#trip/${id}`; }} /><div className={`api-indicator ${apiHealth}`}><span /> API · {apiHealth === 'healthy' ? 'Connected' : apiHealth === 'checking' ? 'Checking' : 'Unavailable'} <small>{API_URL}</small></div></div></div>
        <p className="intro">Set up the route and assigned trip. Passengers can then browse it in the mobile app, and the assigned driver can start it.</p>

        {error && <div className="alert error" role="alert">{error}</div>}
        {notice && <div className="alert success" role="status">{notice}</div>}
        {loading ? <div className="loading">Loading project data…</div> : openTripId ? (
          <TripDetailPage trip={data.trips.find((item) => item.id.toLowerCase() === openTripId)} route={null} routes={data.routes} api={api} actions={tripActions} onBack={closeTrip} />
        ) : (
          <>
            <div className="sections">
            <section className="summary-grid" aria-label="Current records">
              <SummaryCard label="Stops" value={data.stops.length} />
              <SummaryCard label="Routes" value={data.routes.length} />
              <SummaryCard label="Active fleet" value={data.buses.filter((item) => item.isActive).length} />
              <SummaryCard label="Upcoming trips" value={scheduledTrips.filter((item) => item.status !== 'Started').length} />
              <SummaryCard label="Active trips" value={activeTrips.length} />
            </section>

            <section id="source-map" className="panel">
              <SectionTitle icon="map" title="University City stop points" subtitle="Explore the supplied source points before assigning them to UWAY routes." />
              <StopsSourceMap />
            </section>

            <section id="stops" className="panel">
              <SectionTitle icon="stops" title="Add a stop" subtitle="Add campus pickup or drop-off locations first." />
              <form className="form-row" onSubmit={(event) => { event.preventDefault(); submit('stop', '/api/stops', { name: stopForm.name, latitude: stopForm.latitude === '' ? null : Number(stopForm.latitude), longitude: stopForm.longitude === '' ? null : Number(stopForm.longitude), audience: stopForm.audience || null }, () => setStopForm({ name: '', latitude: '', longitude: '', audience: '' })); }}>
                <Field label="Stop name"><input required maxLength="120" value={stopForm.name} onChange={(event) => setStopForm({ ...stopForm, name: event.target.value })} placeholder="e.g. Main Library" /></Field>
                <Field label="Latitude (optional)"><input type="number" step="any" min="-90" max="90" value={stopForm.latitude} onChange={(event) => setStopForm({ ...stopForm, latitude: event.target.value })} placeholder="25.32" /></Field>
                <Field label="Longitude (optional)"><input type="number" step="any" min="-180" max="180" value={stopForm.longitude} onChange={(event) => setStopForm({ ...stopForm, longitude: event.target.value })} placeholder="55.42" /></Field>
                <Field label="For"><select value={stopForm.audience} onChange={(event) => setStopForm({ ...stopForm, audience: event.target.value })}><option value="">Everyone</option><option value="M">Men only</option><option value="F">Women only</option></select></Field>
                <button disabled={busy !== ''} type="submit">{busy === 'stop' ? 'Saving…' : 'Add stop'}</button>
              </form>
              <RecordTable columns={['Stop', 'For', 'Coordinates', 'Source', 'Status']} rows={data.stops.map((item) => [item.name, item.audience === 'M' ? 'Men only' : item.audience === 'F' ? 'Women only' : 'Everyone', item.latitude == null ? 'No coordinates' : `${item.latitude}, ${item.longitude}`, item.sourceGroup || 'UWAY', item.isActive ? 'Active' : 'Inactive'])} records={data.stops} onEdit={(record) => setEditor({ type: 'stop', record })} onDelete={(record) => deleteRecord('stop', record)} />
            </section>

            <section id="routes" className="panel">
              <SectionTitle icon="routes" title="Create a route" subtitle="Choose stops in travel order." />
              <form className="stack-form" onSubmit={(event) => { event.preventDefault(); submit('route', '/api/routes', { code: routeForm.code, name: routeForm.name, stopIds: routeForm.stopIds }, () => setRouteForm({ code: '', name: '', stopIds: [] })); }}>
                <div className="form-row two-col">
                  <Field label="Route code"><input required maxLength="32" value={routeForm.code} onChange={(event) => setRouteForm({ ...routeForm, code: event.target.value })} placeholder="e.g. CAMPUS-A" /></Field>
                  <Field label="Route name"><input required maxLength="120" value={routeForm.name} onChange={(event) => setRouteForm({ ...routeForm, name: event.target.value })} placeholder="e.g. Main Campus Loop" /></Field>
                </div>
                {data.stops.length === 0 ? <p className="muted">Add stops before creating a route.</p> : <StopPicker legend="Stops · select at least one" stops={data.stops} selected={routeForm.stopIds} onToggle={toggleStop} />}
                <button disabled={busy !== '' || data.stops.length === 0 || routeForm.stopIds.length === 0} type="submit">{busy === 'route' ? 'Saving…' : 'Create route'}</button>
              </form>
              <RecordTable columns={['Code', 'Route', 'Ordered stops', 'Status']} rows={data.routes.map((item) => [item.code, item.name, item.stops.map((stop) => stop.name).join(' → ') || 'No stops', item.isActive ? 'Active' : 'Inactive'])} records={data.routes} onEdit={(record) => setEditor({ type: 'route', record })} onDelete={(record) => deleteRecord('route', record)} />
            </section>

            <section id="fleet" className="panel">
              <SectionTitle icon="fleet" title="Add bus and driver" subtitle="Assign both to a trip so the driver app can test trip operations." />
              <div className="form-columns">
                <form className="stack-form" onSubmit={(event) => { event.preventDefault(); submit('bus', '/api/buses', { fleetNumber: busForm.fleetNumber, capacity: Number(busForm.capacity), isActive: true, assignedDriverId: busForm.assignedDriverId === '' ? null : Number(busForm.assignedDriverId) }, () => setBusForm({ fleetNumber: '', capacity: '', assignedDriverId: '' })); }}>
                  <h3>Bus</h3>
                  <Field label="Fleet number"><input required maxLength="32" value={busForm.fleetNumber} onChange={(event) => setBusForm({ ...busForm, fleetNumber: event.target.value })} placeholder="BUS-01" /></Field>
                  <Field label="Capacity"><input required type="number" min="1" max="500" value={busForm.capacity} onChange={(event) => setBusForm({ ...busForm, capacity: event.target.value })} placeholder="30" /></Field>
                  <Field label="Usual driver (optional)"><select value={busForm.assignedDriverId} onChange={(event) => setBusForm({ ...busForm, assignedDriverId: event.target.value })}><option value="">No fixed driver</option>{data.drivers.filter((item) => item.isActive).map((item) => <option key={item.id} value={item.id}>{item.fullName}{item.assignedBusId ? ' (has a bus already)' : ''}</option>)}</select></Field>
                  <button disabled={busy !== ''} type="submit">{busy === 'bus' ? 'Saving…' : 'Add bus'}</button>
                  <RecordTable columns={['Fleet number', 'Capacity', 'Usual driver', 'Status']} rows={data.buses.map((item) => [item.fleetNumber, item.capacity, item.assignedDriverName || '—', item.isActive ? 'Active' : 'Inactive'])} records={data.buses} onEdit={(record) => setEditor({ type: 'bus', record })} onDelete={(record) => deleteRecord('bus', record)} />
                </form>
                <form className="stack-form" onSubmit={(event) => { event.preventDefault(); submit('driver', '/api/drivers', { fullName: driverForm.fullName, phoneNumber: driverForm.phoneNumber.trim(), isActive: true, assignedBusId: driverForm.assignedBusId === '' ? null : Number(driverForm.assignedBusId) }, () => setDriverForm({ fullName: '', phoneNumber: '', assignedBusId: '' })); }}>
                  <h3>Driver</h3>
                  <Field label="Driver name"><input required maxLength="120" value={driverForm.fullName} onChange={(event) => setDriverForm({ ...driverForm, fullName: event.target.value })} placeholder="Driver name" /></Field>
                  <Field label="Phone number"><input required type="tel" minLength="6" maxLength="32" pattern="\+?[0-9 ()\-]{6,32}" title="Digits, spaces, + ( ) and - only" value={driverForm.phoneNumber} onChange={(event) => setDriverForm({ ...driverForm, phoneNumber: event.target.value })} placeholder="e.g. +971 50 123 4567" /></Field>
                  <Field label="Usual bus (optional)"><select value={driverForm.assignedBusId} onChange={(event) => setDriverForm({ ...driverForm, assignedBusId: event.target.value })}><option value="">No fixed bus</option>{data.buses.filter((item) => item.isActive).map((item) => <option key={item.id} value={item.id} disabled={Boolean(item.assignedDriverId)}>{item.fleetNumber}{item.assignedDriverName ? ` (${item.assignedDriverName})` : ''}</option>)}</select></Field>
                  <button disabled={busy !== ''} type="submit">{busy === 'driver' ? 'Saving…' : 'Add driver'}</button>
                  <RecordTable columns={['Driver', 'Phone', 'Usual bus', 'Status']} rows={data.drivers.map((item) => [item.fullName, item.phoneNumber || 'Add a phone number', data.buses.find((bus) => bus.id === item.assignedBusId)?.fleetNumber || '—', item.isActive ? 'Active' : 'Inactive'])} records={data.drivers} onEdit={(record) => setEditor({ type: 'driver', record })} onDelete={(record) => deleteRecord('driver', record)} />
                </form>
              </div>
            </section>

            <section id="trips" className="panel">
              <SectionTitle icon="trips" title="Schedule a trip" subtitle="The trip will appear in Passenger browsing after it is saved." />
              <form className="form-row trip-form" onSubmit={createTrip}>
                <Field label="Route"><select required value={tripForm.routeId} onChange={(event) => setTripForm({ ...tripForm, routeId: event.target.value })}><option value="">Choose route</option>{data.routes.filter((item) => item.isActive && item.stops.length).map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></Field>
                <Field label="Driver"><select required value={tripForm.driverId} onChange={(event) => setTripForm(pairFromDriver(tripForm, event.target.value, data))}><option value="">Choose driver</option>{data.drivers.filter((item) => item.isActive).map((item) => <option key={item.id} value={item.id}>{item.fullName}</option>)}</select></Field>
                <Field label="Bus"><select required value={tripForm.busId} onChange={(event) => setTripForm(pairFromBus(tripForm, event.target.value, data))}><option value="">Choose bus</option>{data.buses.filter((item) => item.isActive).map((item) => <option key={item.id} value={item.id}>{item.fleetNumber} · {item.capacity} seats{item.assignedDriverName ? ` · ${item.assignedDriverName}` : ''}</option>)}</select></Field>
                <Field label="Trip for"><select required value={tripForm.audience} onChange={(event) => setTripForm({ ...tripForm, audience: event.target.value })}><option value="">Choose men or women</option><option value="M">Men</option><option value="F">Women</option></select></Field>
                <Field label="Departure"><input name="departureAt" type="datetime-local" required defaultValue="" /></Field>
                <button disabled={busy !== '' || !data.routes.some((item) => item.isActive && item.stops.length) || !data.buses.some((item) => item.isActive) || !data.drivers.some((item) => item.isActive)} type="submit">{busy === 'trip' ? 'Saving…' : 'Create trip'}</button>
              </form>
              <div className="trip-filters"><Field label="Search trips"><input type="search" value={tripSearch} onChange={(event) => setTripSearch(event.target.value)} placeholder="Route, bus, driver…" /></Field><Field label="Status"><select value={tripStatusFilter} onChange={(event) => setTripStatusFilter(event.target.value)}>{['All', 'Scheduled', 'Started', 'Finished', 'Delayed', 'Cancelled'].map((status) => <option key={status}>{status}</option>)}</select></Field></div>
              <div className="table-wrap"><table><thead><tr><th>Departure</th><th>Route</th><th>For</th><th>Bus</th><th>Driver</th><th>Status</th><th>Action</th></tr></thead><tbody>
                {(showAllTrips || tripSearch.trim() ? visibleTrips : visibleTrips.slice(0, 10)).map((trip) => <tr key={trip.id} className="clickable-row" onClick={() => openTrip(trip.id)}><td>{new Date(trip.departureAtUtc).toLocaleString()}</td><td>{trip.routeName || trip.routeCode}</td><td><span className={`badge audience-${trip.audience || 'none'}`}>{trip.audience === 'F' ? 'Women' : trip.audience === 'M' ? 'Men' : 'Not set'}</span></td><td>{trip.fleetNumber || 'Unassigned'}</td><td>{trip.driverName || 'Unassigned'}</td><td><StatusCell trip={trip} /></td><td className="record-actions" onClick={(event) => event.stopPropagation()}>{tripActions(trip)}</td></tr>)}
                {visibleTrips.length === 0 && <tr><td colSpan="7" className="empty-cell">No trips match this search.</td></tr>}
              </tbody></table></div>
              {!tripSearch.trim() && visibleTrips.length > 10 && <button type="button" className="show-more" onClick={() => setShowAllTrips(!showAllTrips)}>{showAllTrips ? 'Show fewer trips' : `Show ${visibleTrips.length - 10} more trips`}</button>}
            </section>
            <section id="account" className="panel">
              <SectionTitle icon="account" title="Account" subtitle="Who is using this dashboard." />
              <div className="capability-note"><strong>Signed in as</strong><p>{session.fullName} · {session.email}</p></div>
              <div className="capability-note"><strong>Role</strong><p>Administrator</p></div>
              <div className="capability-note"><strong>API</strong><p>{apiHealth === 'healthy' ? 'Connected' : apiHealth === 'checking' ? 'Checking…' : 'Unavailable'}</p></div>
              <div className="capability-note"><strong>Session</strong><p>Ends automatically after 12 hours or when you sign out.</p></div>
              <button type="button" className="secondary-button" onClick={onSignOut}>Sign out</button>
            </section>
            <section id="reports" className="panel">
              <SectionTitle icon="reports" title="Passenger reports" subtitle="Lost items and problems sent from the passenger app. Reply and update the status." />
              <ReportsPanel api={api} loadFile={apiBlob} />
            </section>
            </div>
            <footer>UWAY · Academic prototype · Local development only</footer>
          </>
        )}
      </main>
      {editor && <EditRecordDialog key={`${editor.type}-${editor.record.id}`} type={editor.type} record={editor.record} stops={data.stops} buses={data.buses} drivers={data.drivers} busy={busy === `edit-${editor.type}`} onClose={() => setEditor(null)} onSave={(body) => saveRecord(editor.type, editor.record, body)} />}
      {editingTrip && <EditTripDialog key={editingTrip.id} trip={editingTrip} routes={data.routes} buses={data.buses} drivers={data.drivers} busy={busy === 'edit-trip'} error={tripError} onClose={() => setEditingTrip(null)} onSave={(body) => saveTrip(editingTrip, body)} />}
      {cancellingTrip && <CancelTripDialog trip={cancellingTrip} busy={busy === 'cancel-trip'} onClose={() => setCancellingTrip(null)} onCancel={(reason) => cancelTrip(cancellingTrip, reason)} />}
    </div>
  );
}

function Field({ label, children }) {
  return <label className="field"><span>{label}</span>{children}</label>;
}

/** Choosing a driver fills in the bus they normally drive. */
function pairFromDriver(values, driverId, data) {
  const driver = data.drivers.find((item) => String(item.id) === String(driverId));
  const bus = driver?.assignedBusId ? data.buses.find((item) => item.id === driver.assignedBusId && item.isActive) : null;
  return { ...values, driverId, busId: bus ? String(bus.id) : values.busId };
}
/** Choosing a bus fills in its usual driver when none is chosen yet. */
function pairFromBus(values, busId, data) {
  const bus = data.buses.find((item) => String(item.id) === String(busId));
  const driver = bus?.assignedDriverId ? data.drivers.find((item) => item.id === bus.assignedDriverId && item.isActive) : null;
  return { ...values, busId, driverId: values.driverId === '' && driver ? String(driver.id) : values.driverId };
}

function SectionTitle({ icon, title, subtitle }) {
  const path = icon === 'account' ? ACCOUNT_ICON : NAV.find((entry) => entry.id === (icon === 'map' ? 'source-map' : icon))?.icon;
  return <div className="section-title"><span>{path ? <NavIcon path={path} /> : null}</span><div><h2>{title}</h2><p>{subtitle}</p></div></div>;
}

function SummaryCard({ label, value }) {
  return <div className="summary-card"><span>{label}</span><strong>{value}</strong></div>;
}

function CompactList({ items, empty }) {
  return items.length ? <ul className="compact-list">{items.map((item) => <li key={item}>{item}</li>)}</ul> : <p className="muted empty-list">{empty}</p>;
}

const PAGE = 8;

function RecordTable({ columns, rows, records, onEdit, onDelete }) {
  const [search, setSearch] = useState('');
  const [expanded, setExpanded] = useState(false);
  const filtered = rows.map((row, index) => ({ row, index })).filter(({ row }) => row.join(' ').toLowerCase().includes(search.trim().toLowerCase()));
  const shown = expanded || search.trim() ? filtered : filtered.slice(0, PAGE);
  const hidden = filtered.length - shown.length;
  return <><label className="record-search"><span>Search records</span><input type="search" value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Type to filter…" /></label><div className="table-wrap"><table><thead><tr>{columns.map((column) => <th key={column}>{column}</th>)}<th>Manage</th></tr></thead><tbody>
    {shown.map(({ row, index }) => <tr key={records[index].id}>{row.map((cell, cellIndex) => <td key={cellIndex}>{cell}</td>)}<td className="record-actions"><button className="table-action" type="button" onClick={() => onEdit(records[index])}>Edit</button><button className="table-action danger-action" type="button" onClick={() => onDelete(records[index])}>Delete</button></td></tr>)}
    {filtered.length === 0 && <tr><td colSpan={columns.length + 1} className="empty-cell">No records match this search.</td></tr>}
  </tbody></table></div>
  {(hidden > 0 || (expanded && filtered.length > PAGE)) && <button type="button" className="show-more" onClick={() => setExpanded(!expanded)}>{expanded ? 'Show fewer' : `Show ${hidden} more`}</button>}</>;
}

/** A searchable stop list that shows a few stops first and the rest on request. */
function StopPicker({ stops, selected, onToggle, legend }) {
  const [search, setSearch] = useState('');
  const [expanded, setExpanded] = useState(false);
  const query = search.trim().toLowerCase();
  const matches = stops.filter((stop) => !query || stop.name.toLowerCase().includes(query) || selected.includes(stop.id));
  const shown = expanded || query ? matches : matches.slice(0, 10);
  const hidden = matches.length - shown.length;
  return <fieldset className="stop-picker"><legend>{legend}</legend>
    <input className="stop-search" type="search" value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search stops…" />
    <div className="stop-list">{shown.map((stop) => <label className="check-row" key={stop.id}><input type="checkbox" checked={selected.includes(stop.id)} onChange={() => onToggle(stop.id)} /><span>{stop.name}{stop.audience && <small className="muted"> · {stop.audience === 'M' ? 'men only' : 'women only'}</small>}</span></label>)}</div>
    {(hidden > 0 || (expanded && matches.length > 10)) && <button type="button" className="show-more" onClick={() => setExpanded(!expanded)}>{expanded ? 'Show fewer' : `Show ${hidden} more`}</button>}
    <small className="muted">{selected.length} selected</small>
  </fieldset>;
}

function EditRecordDialog({ type, record, stops, buses, drivers, busy, onClose, onSave }) {
  const [values, setValues] = useState(() => ({ ...record, stopIds: type === 'route' ? record.stops.map((stop) => stop.id) : [] }));
  const label = { stop: 'stop', route: 'route', bus: 'bus', driver: 'driver' }[type];
  function update(key, value) { setValues((current) => ({ ...current, [key]: value })); }
  function submit(event) {
    event.preventDefault();
    if (type === 'stop') {
      const latitude = values.latitude === '' || values.latitude == null ? null : Number(values.latitude);
      const longitude = values.longitude === '' || values.longitude == null ? null : Number(values.longitude);
      if ((latitude == null) !== (longitude == null)) return;
      onSave({ name: values.name, latitude, longitude, isActive: values.isActive, audience: values.audience || null });
    } else if (type === 'route') {
      onSave({ code: values.code, name: values.name, isActive: values.isActive, stopIds: values.stopIds });
    } else if (type === 'bus') {
      onSave({ fleetNumber: values.fleetNumber, capacity: Number(values.capacity), isActive: values.isActive, assignedDriverId: values.assignedDriverId ? Number(values.assignedDriverId) : null });
    } else {
      onSave({ fullName: values.fullName, phoneNumber: (values.phoneNumber || '').trim(), isActive: values.isActive, assignedBusId: values.assignedBusId ? Number(values.assignedBusId) : null });
    }
  }
  return <div className="modal-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}><form className="record-modal" role="dialog" aria-modal="true" aria-labelledby="edit-title" onSubmit={submit}>
    <div className="modal-heading"><div><p className="eyebrow">RECORD MANAGEMENT</p><h2 id="edit-title">Edit {label}</h2></div><button className="icon-button" type="button" aria-label="Close" onClick={onClose}>×</button></div>
    {type === 'stop' && <><Field label="Stop name"><input required maxLength="120" value={values.name} onChange={(event) => update('name', event.target.value)} /></Field><div className="form-row two-col"><Field label="Latitude"><input type="number" step="any" min="-90" max="90" value={values.latitude ?? ''} onChange={(event) => update('latitude', event.target.value)} /></Field><Field label="Longitude"><input type="number" step="any" min="-180" max="180" value={values.longitude ?? ''} onChange={(event) => update('longitude', event.target.value)} /></Field></div><Field label="For"><select value={values.audience ?? ''} onChange={(event) => update('audience', event.target.value)}><option value="">Everyone</option><option value="M">Men only</option><option value="F">Women only</option></select></Field><p className="muted">Provide both coordinates or leave both blank. A men-only or women-only stop is hidden from trips of the other gender. Source map metadata is preserved.</p></>}
    {type === 'route' && <><div className="form-row two-col"><Field label="Route code"><input required maxLength="32" value={values.code} onChange={(event) => update('code', event.target.value)} /></Field><Field label="Route name"><input required maxLength="120" value={values.name} onChange={(event) => update('name', event.target.value)} /></Field></div><StopPicker legend="Stops in travel order" stops={stops} selected={values.stopIds} onToggle={(id) => update('stopIds', values.stopIds.includes(id) ? values.stopIds.filter((item) => item !== id) : [...values.stopIds, id])} /></>}
    {type === 'bus' && <div className="form-row two-col"><Field label="Fleet number"><input required maxLength="32" value={values.fleetNumber} onChange={(event) => update('fleetNumber', event.target.value)} /></Field><Field label="Capacity"><input required type="number" min="1" max="500" value={values.capacity} onChange={(event) => update('capacity', event.target.value)} /></Field><Field label="Usual driver (optional)"><select value={values.assignedDriverId ?? ''} onChange={(event) => update('assignedDriverId', event.target.value)}><option value="">No fixed driver</option>{drivers.filter((item) => item.isActive || item.id === values.assignedDriverId).map((item) => <option key={item.id} value={item.id}>{item.fullName}{item.assignedBusId && item.assignedBusId !== values.id ? ' (has another bus)' : ''}</option>)}</select></Field></div>}
    {type === 'driver' && <div className="form-row two-col"><Field label="Driver name"><input required maxLength="120" value={values.fullName} onChange={(event) => update('fullName', event.target.value)} /></Field><Field label="Phone number"><input required type="tel" minLength="6" maxLength="32" pattern="\+?[0-9 ()\-]{6,32}" title="Digits, spaces, + ( ) and - only" value={values.phoneNumber || ''} onChange={(event) => update('phoneNumber', event.target.value)} /></Field><Field label="Usual bus (optional)"><select value={values.assignedBusId ?? ''} onChange={(event) => update('assignedBusId', event.target.value)}><option value="">No fixed bus</option>{buses.filter((item) => item.isActive || item.id === values.assignedBusId).map((item) => <option key={item.id} value={item.id} disabled={Boolean(item.assignedDriverId) && item.assignedDriverId !== values.id}>{item.fleetNumber}{item.assignedDriverName && item.assignedDriverId !== values.id ? ` (${item.assignedDriverName})` : ''}</option>)}</select></Field></div>}
    <label className="active-toggle"><input type="checkbox" checked={Boolean(values.isActive)} onChange={(event) => update('isActive', event.target.checked)} /> Active</label>
    <div className="modal-actions"><button type="button" className="secondary-button" onClick={onClose}>Cancel</button><button type="submit" disabled={busy}>{busy ? 'Saving…' : 'Save changes'}</button></div>
  </form></div>;
}

function toLocalInput(iso) {
  const date = new Date(iso);
  const pad = (value) => String(value).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function EditTripDialog({ trip, routes, buses, drivers, busy, error, onClose, onSave }) {
  const [values, setValues] = useState(() => ({
    routeId: String(trip.routeId),
    busId: trip.busId == null ? '' : String(trip.busId),
    driverId: trip.driverId == null ? '' : String(trip.driverId),
    audience: trip.audience || '',
    departureAt: toLocalInput(trip.departureAtUtc)
  }));
  function update(key, value) { setValues((current) => ({ ...current, [key]: value })); }
  function submit(event) {
    event.preventDefault();
    const departure = new Date(values.departureAt);
    if (Number.isNaN(departure.getTime())) return;
    onSave({
      routeId: Number(values.routeId),
      busId: values.busId === '' ? null : Number(values.busId),
      driverId: values.driverId === '' ? null : Number(values.driverId),
      departureAtUtc: departure.toISOString(),
      audience: values.audience,
    });
  }
  return <div className="modal-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}><form className="record-modal" role="dialog" aria-modal="true" aria-labelledby="edit-trip-title" onSubmit={submit}>
    <div className="modal-heading"><div><p className="eyebrow">TRIP OPERATIONS</p><h2 id="edit-trip-title">Edit trip · {trip.routeName || trip.routeCode}</h2></div><button className="icon-button" type="button" aria-label="Close" onClick={onClose}>×</button></div>
    <p>Only scheduled trips can be edited. Once passengers have joined, the route and the Men/Women choice are locked.</p>
    <Field label="Trip for"><select required value={values.audience} onChange={(event) => update('audience', event.target.value)}><option value="">Choose men or women</option><option value="M">Men</option><option value="F">Women</option></select></Field>
    <Field label="Route"><select required value={values.routeId} onChange={(event) => update('routeId', event.target.value)}>{routes.filter((item) => (item.isActive && item.stops.length) || String(item.id) === values.routeId).map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}</select></Field>
    <div className="form-row two-col">
      <Field label="Bus"><select value={values.busId} onChange={(event) => setValues((current) => pairFromBus(current, event.target.value, { buses, drivers }))}><option value="">Unassigned</option>{buses.filter((item) => item.isActive || String(item.id) === values.busId).map((item) => <option key={item.id} value={item.id}>{item.fleetNumber}</option>)}</select></Field>
      <Field label="Driver"><select value={values.driverId} onChange={(event) => setValues((current) => pairFromDriver(current, event.target.value, { buses, drivers }))}><option value="">Unassigned</option>{drivers.filter((item) => item.isActive || String(item.id) === values.driverId).map((item) => <option key={item.id} value={item.id}>{item.fullName}</option>)}</select></Field>
    </div>
    <Field label="Departure"><input type="datetime-local" required value={values.departureAt} onChange={(event) => update('departureAt', event.target.value)} /></Field>
    {error && <div className="alert error" role="alert">{error}</div>}
    <div className="modal-actions"><button type="button" className="secondary-button" onClick={onClose}>Cancel</button><button type="submit" disabled={busy}>{busy ? 'Saving…' : 'Save changes'}</button></div>
  </form></div>;
}

function CancelTripDialog({ trip, busy, onClose, onCancel }) {
  const [reason, setReason] = useState('');
  return <div className="modal-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) onClose(); }}><form className="record-modal" role="dialog" aria-modal="true" aria-labelledby="cancel-title" onSubmit={(event) => { event.preventDefault(); onCancel(reason.trim()); }}>
    <div className="modal-heading"><div><p className="eyebrow">TRIP OPERATIONS</p><h2 id="cancel-title">Cancel trip · {trip.routeName || trip.routeCode}</h2></div><button className="icon-button" type="button" aria-label="Close" onClick={onClose}>×</button></div>
    <p>This records a cancellation reason and keeps existing Trip Intent history. Passengers who joined get a notification that the trip was cancelled. You can restore the trip later.</p>
    <Field label="Reason"><textarea required maxLength="500" rows="4" value={reason} onChange={(event) => setReason(event.target.value)} /></Field>
    <div className="modal-actions"><button type="button" className="secondary-button" onClick={onClose}>Keep trip</button><button className="danger-button" type="submit" disabled={busy || !reason.trim()}>{busy ? 'Cancelling…' : 'Confirm cancellation'}</button></div>
  </form></div>;
}

function LoginPage({ onSignedIn, notice }) {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const submit = async (event) => {
    event.preventDefault();
    setBusy(true); setError('');
    try {
      const response = await fetch(`${API_URL}/api/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password }) });
      const text = await response.text();
      const data = parseBody(text);
      if (!response.ok) throw new Error(data?.detail || (response.status >= 500 ? 'The server hit an error. Make sure the database migrations and --seed-test-users were run, then try again.' : `Sign-in failed (${response.status}).`));
      if (data.role !== 'Admin') throw new Error('This account is not an administrator. Passengers and drivers use the mobile app.');
      currentSession = data;
      saveSession(data);
      onSignedIn(data);
    } catch (reason) {
      setError(reason instanceof TypeError ? 'The server could not be reached. Is the API running?' : reason.message);
    } finally { setBusy(false); }
  };
  return <main className="login-page"><form className="login-card" onSubmit={submit}>
    <p className="eyebrow">UWAY ADMIN PORTAL</p>
    <h1>Sign in</h1>
    <p className="muted">Use your administrator account to manage routes, trips and reports.</p>
    {notice && <div className="alert error" role="alert">{notice}</div>}
    <label className="field"><span>Email</span><input type="email" autoComplete="username" required value={email} onChange={(event) => setEmail(event.target.value)} /></label>
    <label className="field"><span>Password</span><input type="password" autoComplete="current-password" required value={password} onChange={(event) => setPassword(event.target.value)} /></label>
    {error && <div className="alert error" role="alert">{error}</div>}
    <button className="primary-button" type="submit" disabled={busy || !email || !password}>{busy ? 'Signing in…' : 'Sign in'}</button>
  </form></main>;
}

function App() {
  const [session, setSession] = useState(currentSession);
  const [notice, setNotice] = useState('');
  useEffect(() => {
    const expired = () => { currentSession = null; saveSession(null); setSession(null); setNotice('Your session has ended. Please sign in again.'); };
    window.addEventListener('uway-auth-expired', expired);
    return () => window.removeEventListener('uway-auth-expired', expired);
  }, []);
  const signOut = () => { currentSession = null; saveSession(null); setNotice(''); setSession(null); };
  return session
    ? <Dashboard session={session} onSignOut={signOut} />
    : <LoginPage notice={notice} onSignedIn={(next) => { setNotice(''); setSession(next); }} />;
}

createRoot(document.getElementById('root')).render(<React.StrictMode><App /></React.StrictMode>);
