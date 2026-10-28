import { useEffect, useRef, useState } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import './active-trips-monitor.css';

export default function ActiveTripsMonitor({ trips, api }) {
  const mapElement = useRef(null);
  const mapRef = useRef(null);
  const markerLayers = useRef(new Map());
  const [records, setRecords] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const activeTrips = trips.filter((trip) => trip.status === 'Started');

  async function refresh() {
    setLoading(true);
    setError('');
    const results = await Promise.all(activeTrips.map(async (trip) => {
      const [locationResult, capacityResult] = await Promise.allSettled([
        api(`/api/trips/${trip.id}/location`),
        api(`/api/trips/${trip.id}/capacity`),
      ]);
      return {
        trip,
        location: locationResult.status === 'fulfilled' ? locationResult.value : null,
        capacity: capacityResult.status === 'fulfilled' ? capacityResult.value : null,
        error: capacityResult.status === 'rejected' ? capacityResult.reason.message : '',
      };
    }));
    setRecords(results);
    setLoading(false);
  }

  useEffect(() => {
    refresh();
    const timer = window.setInterval(refresh, 15000);
    return () => window.clearInterval(timer);
    // The active set changes only when the trip list refreshes.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeTrips.map((trip) => trip.id).join('|')]);

  useEffect(() => {
    if (!mapElement.current || records.length === 0) return undefined;
    const map = L.map(mapElement.current, { scrollWheelZoom: true });
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap contributors</a>',
    }).addTo(map);
    mapRef.current = map;
    requestAnimationFrame(() => map.invalidateSize());
    return () => {
      map.remove();
      mapRef.current = null;
      markerLayers.current.clear();
    };
  }, [records.length > 0]);

  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;
    markerLayers.current.forEach((layer) => layer.removeFrom(map));
    markerLayers.current.clear();
    const points = [];
    records.forEach(({ trip, location, capacity }) => {
      if (!location || !Number.isFinite(Number(location.latitude)) || !Number.isFinite(Number(location.longitude))) return;
      const point = [Number(location.latitude), Number(location.longitude)];
      const marker = L.circleMarker(point, {
        radius: 9,
        color: '#ffffff',
        weight: 3,
        fillColor: '#176b66',
        fillOpacity: 1,
      }).bindPopup(`<strong>${escapeHtml(trip.routeName || trip.routeCode)}</strong><br>${escapeHtml(trip.fleetNumber || 'Bus not assigned')}<br>${escapeHtml(capacity?.capacityStatus || 'Capacity unavailable')}`);
      marker.addTo(map);
      markerLayers.current.set(trip.id, marker);
      points.push(point);
    });
    if (points.length === 1) map.setView(points[0], 15);
    else if (points.length > 1) map.fitBounds(L.latLngBounds(points).pad(0.18), { maxZoom: 15 });
  }, [records]);

  const alerts = records.filter(({ capacity }) => capacity && (
    ['NearlyFull', 'Full', 'OverCapacity'].includes(capacity.capacityStatus) ||
    capacity.driverNearlyFullReportedAtUtc));

  return (
    <div className="active-monitor">
      <div className="monitor-heading">
        <div><h3>Active trip monitor</h3><p>Latest driver GPS and rule-based capacity. Refreshes every 15 seconds.</p></div>
        <button type="button" className="secondary-button" onClick={refresh} disabled={loading}>{loading ? 'Refreshing…' : 'Refresh now'}</button>
      </div>
      {error && <p className="monitor-error" role="alert">{error}</p>}
      {activeTrips.length === 0 ? (
        <div className="monitor-empty">There are no in-progress trips to monitor.</div>
      ) : (
        <>
          <div className="monitor-map" ref={mapElement} aria-label="Map of active trip locations" />
          <div className="monitor-list">
            {records.map(({ trip, location, capacity, error: recordError }) => (
              <article className="monitor-trip" key={trip.id}>
                <div className="monitor-trip-title"><strong>{trip.routeName || trip.routeCode}</strong><span className="badge inprogress">In progress</span></div>
                <p>{trip.fleetNumber || 'Bus not assigned'} · {trip.driverName || 'Driver not assigned'}</p>
                <div className="monitor-metrics">
                  <span><b>{capacity?.expectedRiderCount ?? '—'}</b> expected riders</span>
                  <span><b>{capacity ? `${capacity.expectedRiderCount} / ${capacity.busCapacity}` : '—'}</b> capacity</span>
                  <span className={`capacity-${(capacity?.capacityStatus || 'unknown').toLowerCase()}`}>{capacity?.capacityStatus || recordError || 'Loading capacity'}</span>
                </div>
                {location ? <small>Location updated {new Date(location.timestampUtc).toLocaleTimeString()}</small> : <small>No GPS location has been received yet.</small>}
              </article>
            ))}
          </div>
          <div className="monitor-alerts">
            <h4>Capacity alerts</h4>
            {alerts.length === 0 ? <p>No near-full, full, or over-capacity trips reported.</p> : alerts.map(({ trip, capacity }) => (
              <p key={trip.id}><strong>{trip.routeName || trip.routeCode}</strong> · {capacity.capacityStatus} · {capacity.expectedRiderCount} expected of {capacity.busCapacity}{capacity.driverNearlyFullReportedAtUtc ? ' · Driver report received' : ''}</p>
            ))}
          </div>
        </>
      )}
      <p className="monitor-footnote">Location is the latest point saved by the assigned driver. The map does not simulate movement. This project API does not yet expose driver communications or general reports.</p>
    </div>
  );
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (character) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[character]));
}
