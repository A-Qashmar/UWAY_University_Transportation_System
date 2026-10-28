import { useEffect, useRef, useState } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import './trip-detail.css';

const pinSvg = (color, glyph) => `<svg width="34" height="42" viewBox="0 0 34 42" xmlns="http://www.w3.org/2000/svg"><path d="M17 41C17 41 2 26 2 15a15 15 0 0 1 30 0c0 11-15 26-15 26z" fill="${color}" stroke="#fff" stroke-width="2"/><circle cx="17" cy="15" r="8" fill="#fff"/>${glyph}</svg>`;
const stopGlyph = (c) => `<circle cx="17" cy="11" r="2" fill="${c}"/><path d="M13.5 20v-5.5a3.5 3.5 0 0 1 7 0V20" stroke="${c}" stroke-width="2" fill="none" stroke-linecap="round"/>`;
const capGlyph = (c) => `<path d="M17 9l-7 3.5 7 3.5 7-3.5L17 9zM13 15v3c0 1 2 2 4 2s4-1 4-2v-3" fill="${c}" stroke="${c}" stroke-width="1" stroke-linejoin="round"/>`;
const stopIcon = () => L.divIcon({ className: 'uway-pin', html: pinSvg('#176b66', stopGlyph('#176b66')), iconSize: [34, 42], iconAnchor: [17, 41], popupAnchor: [0, -38] });
const campusIcon = () => L.divIcon({ className: 'uway-pin', html: pinSvg('#b98c34', capGlyph('#b98c34')), iconSize: [34, 42], iconAnchor: [17, 41], popupAnchor: [0, -38] });
const busIcon = () => L.divIcon({
  className: 'uway-bus',
  html: '<div class="halo"></div><div class="badge"><svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="3" width="16" height="14" rx="3"/><path d="M4 11h16M8 21v-4M16 21v-4"/><circle cx="8" cy="14" r=".6" fill="#fff"/><circle cx="16" cy="14" r=".6" fill="#fff"/></svg></div>',
  iconSize: [56, 56], iconAnchor: [28, 28], popupAnchor: [0, -24],
});

const POLL_MS = 5000;

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (ch) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]));
}

function formatDate(value) {
  return value ? new Date(value).toLocaleString() : '—';
}

export default function TripDetailPage({ trip, routes, api, actions, onBack }) {
  const [passengers, setPassengers] = useState({ count: 0, passengers: [] });
  const [passengersError, setPassengersError] = useState('');
  const [capacity, setCapacity] = useState(null);
  const [location, setLocation] = useState(null);
  const [locationNote, setLocationNote] = useState('');
  const [showFollow, setShowFollow] = useState(false);
  const followRef = useRef(true);
  const busSeenRef = useRef(false);
  const mapElement = useRef(null);
  const mapRef = useRef(null);
  const layerRef = useRef(null);

  const route = trip ? routes.find((item) => item.id === trip.routeId) : null;
  // A women's trip does not use men-only stops (and the other way round).
  const stops = route ? route.stops.filter((stop) => !stop.audience || !trip?.audience || stop.audience === trip.audience) : [];
  const started = trip?.status === 'Started' && !trip?.cancelledAtUtc;

  // Passengers who joined this trip, and capacity while it can still run.
  useEffect(() => {
    if (!trip) return undefined;
    let active = true;
    const load = async () => {
      try {
        const result = await api(`/api/trips/${trip.id}/passengers`);
        if (active) { setPassengers(result); setPassengersError(''); }
      } catch (reason) {
        if (active) setPassengersError(reason.message);
      }
      if (trip.status !== 'Finished' && !trip.cancelledAtUtc) {
        try {
          const result = await api(`/api/trips/${trip.id}/capacity`);
          if (active) setCapacity(result);
        } catch { if (active) setCapacity(null); }
      } else if (active) setCapacity(null);
    };
    load();
    const timer = window.setInterval(load, 20000);
    return () => { active = false; window.clearInterval(timer); };
  }, [trip?.id, trip?.status, trip?.cancelledAtUtc]);

  // Live bus location, like the passengers see it.
  useEffect(() => {
    if (!trip || !started) { setLocation(null); setLocationNote(''); return undefined; }
    let active = true;
    const load = async () => {
      try {
        const result = await api(`/api/trips/${trip.id}/location`);
        if (!active) return;
        setLocation(result);
        setLocationNote(result ? '' : 'The driver has not sent a location yet.');
      } catch (reason) {
        if (active) setLocationNote(reason.message);
      }
    };
    load();
    const timer = window.setInterval(load, POLL_MS);
    return () => { active = false; window.clearInterval(timer); };
  }, [trip?.id, started]);

  // Map: route line, stops and the bus.
  useEffect(() => {
    if (!mapElement.current) return undefined;
    const map = L.map(mapElement.current, { scrollWheelZoom: true });
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap contributors</a>',
    }).addTo(map);
    mapRef.current = map;
    layerRef.current = L.layerGroup().addTo(map);
    requestAnimationFrame(() => map.invalidateSize());
    return () => { map.remove(); mapRef.current = null; layerRef.current = null; };
  }, [Boolean(trip)]);

  // The map follows the bus like a delivery app; touching the map pauses that.
  useEffect(() => {
    const element = mapElement.current;
    if (!element) return undefined;
    const pause = () => { followRef.current = false; setShowFollow(true); };
    element.addEventListener('pointerdown', pause);
    element.addEventListener('wheel', pause, { passive: true });
    return () => { element.removeEventListener('pointerdown', pause); element.removeEventListener('wheel', pause); };
  }, [Boolean(trip)]);

  useEffect(() => {
    const map = mapRef.current;
    const layer = layerRef.current;
    if (!map || !layer) return;
    layer.clearLayers();
    const points = [];
    const line = stops.filter((stop) => stop.latitude != null && stop.longitude != null)
      .sort((a, b) => a.order - b.order);
    // One pin per spot: stops a few metres apart would pile up.
    const shown = [];
    line.forEach((stop) => {
      const point = [Number(stop.latitude), Number(stop.longitude)];
      points.push(point);
      if (shown.some((other) => map.distance(other.point, point) < 30)) return;
      shown.push({ stop, point });
    });
    shown.forEach(({ stop, point }) => {
      L.marker(point, { icon: /^UOS\b/i.test(stop.name) ? campusIcon() : stopIcon() })
        .bindPopup(`<strong>${escapeHtml(stop.name)}</strong>`).addTo(layer);
    });
    if (line.length > 1) L.polyline(points, { color: '#176b66', weight: 3, opacity: 0.45 }).addTo(layer);
    const hasBus = location && Number.isFinite(Number(location.latitude)) && Number.isFinite(Number(location.longitude));
    if (hasBus) {
      const bus = [Number(location.latitude), Number(location.longitude)];
      L.marker(bus, { icon: busIcon(), zIndexOffset: 1000 })
        .bindPopup(`<strong>${escapeHtml(trip?.fleetNumber || 'Bus')}</strong><br>Updated ${escapeHtml(formatDate(location.timestampUtc))}`)
        .addTo(layer);
      if (!busSeenRef.current) {
        busSeenRef.current = true;
        followRef.current = true;
        setShowFollow(false);
        map.setView(bus, 17);
      } else if (followRef.current) {
        map.panTo(bus, { animate: true });
      }
      return;
    }
    busSeenRef.current = false;
    if (points.length === 1) map.setView(points[0], 15);
    else if (points.length > 1) map.fitBounds(L.latLngBounds(points).pad(0.15), { maxZoom: 16 });
    else map.setView([25.3, 55.45], 11);
  }, [route?.id, stops.length, location?.timestampUtc, location?.latitude, location?.longitude]);

  const followBus = () => {
    const map = mapRef.current;
    if (!map || !location) return;
    followRef.current = true;
    setShowFollow(false);
    map.setView([Number(location.latitude), Number(location.longitude)], 17);
  };

  if (!trip) {
    return <div className="trip-page"><button type="button" className="secondary-button" onClick={onBack}>← Back to trips</button><p className="muted">This trip no longer exists.</p></div>;
  }

  const cancelled = Boolean(trip.cancelledAtUtc);
  const audienceLabel = trip.audience === 'F' ? 'Women' : trip.audience === 'M' ? 'Men' : 'Not set';
  const phone = trip.driverPhone ? String(trip.driverPhone).replace(/[^\d+]/g, '') : '';

  return (
    <div className="trip-page">
      <div className="trip-page-head">
        <button type="button" className="secondary-button" onClick={onBack}>← Back to trips</button>
        <div className="trip-page-title">
          <h2>{trip.routeName || trip.routeCode}</h2>
          <div className="trip-page-badges">
            {cancelled
              ? <span className="pill pill-cancelled"><i />Cancelled</span>
              : <span className={`pill pill-${trip.status.toLowerCase()}`}><i />{trip.status}</span>}
            {!cancelled && trip.delayMinutes > 0 && <span className="pill pill-delayed"><i />Delayed {trip.delayMinutes} min</span>}
            <span className={`badge audience-${trip.audience || 'none'}`}>{audienceLabel}</span>
          </div>
        </div>
        <div className="trip-page-actions">{actions(trip)}</div>
      </div>

      {(cancelled || trip.delayMinutes > 0) && (
        <div className={`trip-alert ${cancelled ? 'trip-alert-cancelled' : 'trip-alert-delayed'}`}>
          {cancelled
            ? `Cancelled${trip.cancellationReason ? ` · ${trip.cancellationReason}` : ''}. Passengers who joined were notified.`
            : `Delayed ${trip.delayMinutes} min${trip.delayReason ? ` · ${trip.delayReason}` : ''}`}
        </div>
      )}

      <div className="trip-info-grid">
        <div className="info-card"><span>Departure</span><strong>{formatDate(trip.departureAtUtc)}</strong></div>
        <div className="info-card"><span>Bus</span><strong>{trip.fleetNumber || 'Unassigned'}</strong></div>
        <div className="info-card">
          <span>Driver</span>
          <strong>{trip.driverName || 'Unassigned'}</strong>
          {trip.driverName && (phone
            ? <a className="call-button" href={`tel:${phone}`} aria-label={`Call ${trip.driverName}`}>
                <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d="M22 16.9v3a2 2 0 0 1-2.2 2 19.8 19.8 0 0 1-8.6-3.1 19.5 19.5 0 0 1-6-6A19.8 19.8 0 0 1 2.1 4.2 2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7c.1 1 .4 1.9.7 2.8a2 2 0 0 1-.5 2.1L8.1 9.9a16 16 0 0 0 6 6l1.3-1.3a2 2 0 0 1 2.1-.4c.9.3 1.8.6 2.8.7a2 2 0 0 1 1.7 2z" /></svg>
                Call {trip.driverPhone}
              </a>
            : <small className="muted">No phone number saved for this driver.</small>)}
        </div>
        <div className="info-card"><span>Passengers joined</span><strong>{passengers.count}</strong>{capacity && <small>Capacity: {capacity.capacityStatus}{capacity.busCapacity ? ` · ${capacity.busCapacity} seats` : ''}</small>}</div>
      </div>

      <section className="trip-block">
        <h3>{started ? 'Live location' : 'Route map'}</h3>
        <div className="trip-map-wrap"><div className="trip-map" ref={mapElement} aria-label="Trip map" />{showFollow && location && <button type="button" className="follow-bus" onClick={followBus}>Follow bus</button>}</div>
        <p className="muted map-note">
          {started
            ? (locationNote || `Bus position refreshes every ${POLL_MS / 1000} seconds.`)
            : trip.status === 'Finished' ? 'This trip has finished.' : cancelled ? 'This trip is cancelled.' : 'Live tracking starts when the trip starts.'}
        </p>
      </section>

      <section className="trip-block">
        <h3>Passengers who joined ({passengers.count})</h3>
        {passengersError && <p className="monitor-error" role="alert">{passengersError}</p>}
        <div className="table-wrap"><table><thead><tr><th>Name</th><th>Email</th><th>Drop-off</th><th>Joined</th></tr></thead><tbody>
          {passengers.passengers.map((person) => <tr key={person.passengerId}>
            <td>{person.fullName || <span className="muted">No profile</span>}</td>
            <td>{person.email ? <a href={`mailto:${person.email}`}>{person.email}</a> : <span className="muted">{person.passengerId}</span>}</td>
            <td>{person.dropOffStopName || '—'}</td>
            <td>{formatDate(person.joinedAtUtc)}</td>
          </tr>)}
          {passengers.passengers.length === 0 && <tr><td colSpan="4" className="empty-cell">No passenger has joined this trip yet.</td></tr>}
        </tbody></table></div>
      </section>

      <section className="trip-block">
        <h3>Route stops</h3>
        <ol className="stop-list">{stops.slice().sort((a, b) => a.order - b.order).map((stop) => <li key={stop.id}>{stop.name}</li>)}</ol>
      </section>
    </div>
  );
}
