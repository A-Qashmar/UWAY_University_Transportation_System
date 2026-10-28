import { useEffect, useMemo, useRef, useState } from 'react';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import './stops-source-map.css';

const SOURCE_URL = '/data/UWAY_stops_coordinates.geojson';
const PALETTE = ['#2369a8', '#24836a', '#bc7b16', '#7650a5', '#c34f54'];

function colorForGroup(index) {
  return PALETTE[index % PALETTE.length];
}

function makeTooltip(feature, color) {
  const properties = feature.properties || {};
  const element = document.createElement('div');
  element.className = 'source-stop-tooltip';

  const name = document.createElement('strong');
  name.textContent = properties.name_en || properties.name_ar || 'Unnamed point';
  name.style.borderLeftColor = color;
  element.append(name);

  if (properties.name_ar && properties.name_en) {
    const arabicName = document.createElement('span');
    arabicName.dir = 'rtl';
    arabicName.textContent = properties.name_ar;
    element.append(arabicName);
  }

  const group = document.createElement('small');
  group.textContent = properties.source_group || 'Source group not provided';
  element.append(group);
  return element;
}

export default function StopsSourceMap() {
  const mapElement = useRef(null);
  const mapRef = useRef(null);
  const layersRef = useRef(new Map());
  const [features, setFeatures] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [selected, setSelected] = useState(null);
  const [visibleGroups, setVisibleGroups] = useState(null);

  useEffect(() => {
    const controller = new AbortController();

    fetch(SOURCE_URL, { signal: controller.signal })
      .then((response) => {
        if (!response.ok) throw new Error('The supplied stop map file could not be loaded.');
        return response.json();
      })
      .then((collection) => {
        if (collection?.type !== 'FeatureCollection' || !Array.isArray(collection.features)) {
          throw new Error('The stop map file is not a valid GeoJSON FeatureCollection.');
        }

        const validFeatures = collection.features.filter((feature) => {
          const coordinates = feature?.geometry?.coordinates;
          return feature?.geometry?.type === 'Point' &&
            Array.isArray(coordinates) &&
            coordinates.length >= 2 &&
            Number.isFinite(coordinates[0]) &&
            Number.isFinite(coordinates[1]) &&
            coordinates[0] >= -180 && coordinates[0] <= 180 &&
            coordinates[1] >= -90 && coordinates[1] <= 90;
        });

        if (validFeatures.length !== collection.features.length) {
          throw new Error('Some GeoJSON points have invalid geometry or coordinates.');
        }

        setFeatures(validFeatures);
        setVisibleGroups(new Set(validFeatures.map((feature) =>
          feature.properties?.source_group || 'Source group not provided')));
      })
      .catch((reason) => {
        if (reason.name !== 'AbortError') setError(reason.message);
      })
      .finally(() => setLoading(false));

    return () => controller.abort();
  }, []);

  const groups = useMemo(() => {
    const names = [...new Set(features.map((feature) =>
      feature.properties?.source_group || 'Source group not provided'))];
    return names.map((name, index) => ({
      name,
      color: colorForGroup(index),
      count: features.filter((feature) =>
        (feature.properties?.source_group || 'Source group not provided') === name).length,
    }));
  }, [features]);

  useEffect(() => {
    if (!mapElement.current || features.length === 0) return undefined;

    const map = L.map(mapElement.current, { scrollWheelZoom: true });
    mapRef.current = map;
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap contributors</a>',
    }).addTo(map);

    const groupLayers = new Map();
    const bounds = [];

    features.forEach((feature, index) => {
      const properties = feature.properties || {};
      const group = properties.source_group || 'Source group not provided';
      const groupIndex = groups.findIndex((item) => item.name === group);
      const color = colorForGroup(groupIndex < 0 ? 0 : groupIndex);
      const [longitude, latitude] = feature.geometry.coordinates;
      const marker = L.circleMarker([latitude, longitude], {
        radius: 7,
        color: '#ffffff',
        weight: 2,
        fillColor: color,
        fillOpacity: 0.92,
      });

      if (!groupLayers.has(group)) groupLayers.set(group, L.layerGroup());
      marker.addTo(groupLayers.get(group));
      marker.bindTooltip(makeTooltip(feature, color), { direction: 'top', sticky: true });
      marker.on('click', () => selectFeature(feature, index));
      bounds.push([latitude, longitude]);
    });

    groupLayers.forEach((layer) => layer.addTo(map));
    layersRef.current = groupLayers;
    map.fitBounds(L.latLngBounds(bounds).pad(0.06), { maxZoom: 14 });
    requestAnimationFrame(() => map.invalidateSize());

    return () => {
      map.remove();
      mapRef.current = null;
      layersRef.current = new Map();
    };
  }, [features, groups]);

  useEffect(() => {
    if (!mapRef.current || !visibleGroups) return;
    layersRef.current.forEach((layer, group) => {
      if (visibleGroups.has(group)) layer.addTo(mapRef.current);
      else mapRef.current.removeLayer(layer);
    });
  }, [visibleGroups, groups]);

  function toggleGroup(name) {
    setVisibleGroups((current) => {
      if (!current) return current;
      const next = new Set(current);
      if (next.has(name)) next.delete(name);
      else next.add(name);
      return next;
    });
  }

  function selectFeature(feature, index) {
    setSelected({ feature, index });
    const [longitude, latitude] = feature.geometry.coordinates;
    if (mapRef.current) mapRef.current.flyTo([latitude, longitude], Math.max(mapRef.current.getZoom(), 14));
  }

  if (loading) return <p className="source-map-state">Loading the supplied stop coordinates…</p>;
  if (error) return <div className="source-map-state source-map-error" role="alert">{error}</div>;

  const selectedFeature = selected?.feature;
  const selectedCoordinates = selectedFeature?.geometry?.coordinates;

  return (
    <div className="source-map-wrap">
      <p className="source-map-note">
        User-provided map points for review. They are shown with their original names, coordinates,
        and source groups; no road lines or route order are inferred.
      </p>

      <div className="source-map-layout">
        <div className="source-map-main">
          <div className="source-map-legend" aria-label="Filter source groups">
            {groups.map((group) => {
              const active = visibleGroups?.has(group.name);
              return (
                <button
                  className={active ? 'source-map-filter active' : 'source-map-filter'}
                  key={group.name}
                  type="button"
                  aria-pressed={Boolean(active)}
                  onClick={() => toggleGroup(group.name)}
                >
                  <span style={{ backgroundColor: group.color }} />
                  {group.name}
                  <small>{group.count}</small>
                </button>
              );
            })}
          </div>
          <label className="source-map-select">
            <span>Choose a point</span>
            <select
              value={selected?.index ?? ''}
              onChange={(event) => {
                const index = Number(event.target.value);
                if (Number.isInteger(index) && features[index]) selectFeature(features[index], index);
              }}
            >
              <option value="">Select a source point…</option>
              {features.map((feature, index) => (
                <option key={index} value={index}>
                  {feature.properties?.name_en || feature.properties?.name_ar || 'Unnamed point'}
                  {' · '}
                  {feature.properties?.source_group || 'Source group not provided'}
                  {' · '}
                  {index + 1}
                </option>
              ))}
            </select>
          </label>
          <div className="source-map-canvas" ref={mapElement} aria-label="Map of supplied University City bus stop points" />
          <div className="source-map-attribution">
            Map tiles &copy; OpenStreetMap contributors. Stop names and coordinates are from the supplied UWAY GeoJSON.
          </div>
        </div>

        <aside className="source-map-details" aria-live="polite">
          <span className="source-map-count">{features.length} mapped points</span>
          {selectedFeature ? (
            <>
              <h3>{selectedFeature.properties?.name_en || selectedFeature.properties?.name_ar || 'Unnamed point'}</h3>
              {selectedFeature.properties?.name_ar && selectedFeature.properties?.name_en &&
                <p className="source-map-arabic" dir="rtl">{selectedFeature.properties.name_ar}</p>}
              <dl>
                <dt>Source group</dt>
                <dd>{selectedFeature.properties?.source_group || 'Not provided'}</dd>
                <dt>Source order label</dt>
                <dd>{selectedFeature.properties?.source_order ?? 'Not provided'} · informational only</dd>
                <dt>Latitude</dt>
                <dd>{selectedCoordinates[1]}</dd>
                <dt>Longitude</dt>
                <dd>{selectedCoordinates[0]}</dd>
              </dl>
              {selectedFeature.properties?.description &&
                <p className="source-map-description">{selectedFeature.properties.description}</p>}
            </>
          ) : (
            <p className="source-map-hint">Select a map point to inspect its original name, group, and coordinates.</p>
          )}
        </aside>
      </div>
    </div>
  );
}
