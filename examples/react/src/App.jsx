// One screen: colour scheme and language switchers, 2,000 clustered points, a line, an extruded area and a 3D
// buildings toggle, basemap overrides, a style layer on the basemap, a KML file and map tools (zoom, full screen,
// scale and a legend) shown or hidden from the tools control, the hidden ones kept in this browser. 1.5.0 (G15-G37):
// a selected stop drawn by its state and hovered stops, a cluster click listing its stops, circles in metres, a truck
// image of your own turned to its heading, arrows by share, a search box over the stops, a measuring drawing tool,
// fitting, the picture of the map and cooperative gestures. Set VITE_SMAP_KEY (a map key that allows this site) or VITE_SMAP_TOKEN before `npm run dev`.
import { useMemo, useRef, useState } from 'react';
import {
  Circles, Data, DrawTool, Lines, MapImage, Points, Polygons, SearchTool, SMap, StyleLayer, Tool,
} from '@superrouteca/smap-react';

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

// A truck drawn on a canvas, pointing north, turned by each van's course.
function truckImage() {
  const c = document.createElement('canvas');
  c.width = 48; c.height = 48;
  const g = c.getContext('2d');
  g.fillStyle = '#1d4ed8';
  g.beginPath(); g.moveTo(24, 4); g.lineTo(40, 44); g.lineTo(24, 36); g.lineTo(8, 44); g.closePath(); g.fill();
  return c;
}

const VANS = [
  { id: 'v1', lng: -79.40, lat: 43.66, course: 45 },
  { id: 'v2', lng: -79.36, lat: 43.65, course: 200 },
];

const ZONES = [
  { id: 'z1', name: 'North', lng: -79.39, lat: 43.68, metres: 1500 },
  { id: 'z2', name: 'East', lng: -79.33, lat: 43.66, metres: 900 },
];

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
  const [selected, setSelected] = useState(null);
  const [measure, setMeasure] = useState('');
  const [unavailable, setUnavailable] = useState('');
  const points = useMemo(() => randomPoints(2000), []);
  const truck = useMemo(() => truckImage(), []);

  const searchStops = (text) => points
    .filter((p) => p.name.toLowerCase().includes(text.toLowerCase()))
    .slice(0, 8)
    .map((p) => ({ label: p.name, lngLat: [p.lng, p.lat], id: p.id }));

  const savePicture = async () => {
    const url = await map.current?.toDataURL({ pixelRatio: 2 });
    if (url) { const a = document.createElement('a'); a.href = url; a.download = 'map.png'; a.click(); }
  };

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
        <button type="button" onClick={() => map.current?.fitBounds([[-79.46, 43.64], [-79.33, 43.69]], { padding: 30, duration: 800 })}>Fit downtown</button>
        <button type="button" onClick={savePicture}>Save picture</button>
        <span>{tapped}</span>
        <span>{measure}</span>
        <span style={{ color: '#b91c1c' }}>{unavailable}</span>
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
          cooperativeGestures
          onUnavailable={(e) => setUnavailable('Map unavailable: ' + e.reason)}
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
          <SearchTool id="search" label="Search stops" position="top-right" placeholder="Stop name" minChars={1}
            search={searchStops} onPick={(r) => setSelected(r.id)} />
          <MapImage id="truck" image={truck} pixelRatio={2} />
          <Circles id="zones" data={ZONES} options={{ radius: { property: 'metres' }, fill: '#0ea5e9', opacity: 0.15,
            outline: '#0369a1', outlineDash: [2, 2], tooltip: '{name}' }} />
          <Points id="stops" data={points}
            options={{ idProperty: 'id', cluster: true, label: 'name', zIndex: 2, hoverState: true,
              states: { hover: { radius: 8 }, selected: { color: '#dc2626', radius: 9 } } }}
            featureStates={selected === null ? undefined : { [selected]: { selected: true } }}
            onTap={(p) => { setTapped(String(p.name)); setSelected(p.id); }}
            onClusterClick={async (cluster) => {
              const leaves = await cluster.leaves(3);
              setTapped(cluster.count + ' stops: ' + leaves.map((f) => f.properties.name).join(', ') + '…');
            }}
            onContextMenu={() => setSelected(null)} />
          <Points id="vans" data={VANS} options={{ icon: 'truck', iconSize: 0.6, rotation: { property: 'course' }, zIndex: 3 }} />
          <Lines id="route" data={ROUTE} options={{ color: '#16a34a', width: 5, zIndex: 1, arrows: { spacing: '20%' } }} />
          <DrawTool toolbar="bottom-right" measure modes={['line', 'polygon', 'circle']}
            onDrawing={(e) => setMeasure(Math.round(e.length) + ' m' + (e.area ? ', ' + Math.round(e.area) + ' m²' : ''))} />
          <Polygons id="depot" data={AREA} options={{ fill: '#f97316', extrude: { height: 'height' } }} />
        </SMap>
      </div>
    </div>
  );
}
