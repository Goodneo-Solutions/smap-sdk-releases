// One screen: colour scheme and language switchers, 2,000 clustered points, a line, an extruded area and a 3D
// buildings toggle, basemap overrides, a style layer on the basemap, a KML file and map tools (zoom, full screen,
// scale and a legend) shown or hidden from the tools control, the hidden ones kept in this browser. Set VITE_SMAP_KEY (a map key that allows this site) or VITE_SMAP_TOKEN before `npm run dev`.
import { useMemo, useRef, useState } from 'react';
import { Data, Lines, Points, Polygons, SMap, StyleLayer, Tool } from '@superrouteca/smap-react';

const FLAVORS = ['light', 'white', 'grayscale', 'dark', 'black'];
const LANGUAGES = ['en', 'fr', 'de', 'es', 'zh-Hans'];
const CENTER = [-79.3832, 43.6532];

function randomPoints(n) {
  const points = [];
  for (let i = 0; i < n; i++) {
    points.push({ id: i, name: 'Stop ' + (i + 1), lng: CENTER[0] + (Math.random() - 0.5) * 0.6, lat: CENTER[1] + (Math.random() - 0.5) * 0.4 });
  }
  return points;
}

const ROUTE = {
  type: 'Feature',
  properties: { name: 'Route' },
  geometry: { type: 'LineString', coordinates: [[-79.46, 43.64], [-79.41, 43.65], [-79.38, 43.66], [-79.33, 43.67]] },
};

const AREA = {
  type: 'Feature',
  properties: { name: 'Depot', height: 120 },
  geometry: { type: 'Polygon', coordinates: [[[-79.39, 43.641], [-79.385, 43.641], [-79.385, 43.645], [-79.39, 43.645], [-79.39, 43.641]]] },
};

const TOOLS_KEY = 'smap-example-tools';
function savedTools() {
  try { return JSON.parse(localStorage.getItem(TOOLS_KEY) || '[]'); } catch (e) { return []; }
}
function saveTools(event) {
  try { localStorage.setItem(TOOLS_KEY, JSON.stringify(event.hidden)); } catch (e) { /* storage unavailable */ }
}

const BLUE_WATER = { water: { color: '#9cc0e6' }, pois: { visible: false } };

const PARKS_OUTLINE = { id: 'parks-outline', type: 'line', source: 'basemap', 'source-layer': 'landuse',
  filter: ['==', ['get', 'kind'], 'park'], paint: { 'line-color': '#15803d', 'line-width': 1.5 } };

const KML = `<?xml version="1.0" encoding="UTF-8"?><kml xmlns="http://www.opengis.net/kml/2.2"><Document>
<Placemark><name>Union</name><Point><coordinates>-79.3806,43.6453</coordinates></Point></Placemark>
</Document></kml>`;

export default function App() {
  const map = useRef(null);
  const [flavor, setFlavor] = useState('light');
  const [language, setLanguage] = useState('en');
  const [buildings, setBuildings] = useState(false);
  const [blue, setBlue] = useState(false);
  const [tapped, setTapped] = useState('');
  const points = useMemo(() => randomPoints(2000), []);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div style={{ display: 'flex', gap: 8, padding: 8, alignItems: 'center', flexWrap: 'wrap' }}>
        <select value={flavor} onChange={(e) => setFlavor(e.target.value)}>
          {FLAVORS.map((f) => <option key={f} value={f}>{f}</option>)}
        </select>
        <select value={language} onChange={(e) => setLanguage(e.target.value)}>
          {LANGUAGES.map((l) => <option key={l} value={l}>{l}</option>)}
        </select>
        <label><input type="checkbox" checked={buildings} onChange={(e) => setBuildings(e.target.checked)} /> 3D buildings</label>
        <label><input type="checkbox" checked={blue} onChange={(e) => setBlue(e.target.checked)} /> Basemap overrides</label>
        <button type="button" onClick={() => map.current?.fitLayer('stops')}>Fit points</button>
        <span>{tapped}</span>
      </div>
      <div style={{ flex: 1 }}>
        <SMap
          ref={map}
          apiKey={import.meta.env.VITE_SMAP_KEY || undefined}
          token={import.meta.env.VITE_SMAP_TOKEN || undefined}
          style={flavor}
          language={language}
          center={CENTER}
          zoom={11}
          buildings3D={buildings}
          basemap={blue ? BLUE_WATER : undefined}
          tools={{ hidden: savedTools() }}
          onToolsChange={saveTools}
        >
          <Tool id="zoom" kind="navigation" options={{ showCompass: false }} />
          <Tool id="fullscreen" kind="fullscreen" />
          <Tool id="scale" kind="scale" />
          <Tool id="legend" label="Legend" position="bottom-left"
            style={{ background: '#fff', padding: '6px 10px', borderRadius: 6, font: '12px sans-serif' }}>
            <span style={{ color: '#16a34a' }}>━</span> Route · <span style={{ color: '#f97316' }}>■</span> Depot
          </Tool>
          <StyleLayer layer={PARKS_OUTLINE} slot="labels" />
          <Data id="kml" data={KML} format="kml" onTap={(p) => setTapped(String(p.name))} />
          <Points id="stops" data={points} options={{ cluster: true, label: 'name', zIndex: 2 }}
            onTap={(p) => setTapped(String(p.name))} />
          <Lines id="route" data={ROUTE} options={{ color: '#16a34a', width: 5, zIndex: 1 }} />
          <Polygons id="depot" data={AREA} options={{ fill: '#f97316', extrude: { height: 'height' } }} />
        </SMap>
      </div>
    </div>
  );
}
