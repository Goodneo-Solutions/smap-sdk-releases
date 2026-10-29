// One screen: colour scheme and language switchers, 2,000 clustered points, a line, an extruded area, a 3D
// buildings toggle, and map tools (zoom, compass, scale and a legend) shown or hidden from the tools control. Put a map key that allows this app (ca.superroute.smap.rnexample) in SMAP_KEY.
import React, { useMemo, useRef, useState } from 'react';
import { Pressable, SafeAreaView, StyleSheet, Text, View } from 'react-native';
import { Data, Lines, Points, Polygons, SMap, StyleLayer, Tool, styles as FLAVORS, type SMapHandle, type StyleFlavor } from '@superrouteca/smap-react-native';

const BLUE_WATER = { water: { color: '#9cc0e6' }, pois: { visible: false } };

const PARKS_OUTLINE = { id: 'parks-outline', type: 'line', source: 'basemap', 'source-layer': 'landuse',
  filter: ['==', ['get', 'kind'], 'park'], paint: { 'line-color': '#15803d', 'line-width': 1.5 } };

const KML = '<?xml version="1.0" encoding="UTF-8"?><kml xmlns="http://www.opengis.net/kml/2.2"><Document>'
  + '<Placemark><name>Union</name><Point><coordinates>-79.3806,43.6453</coordinates></Point></Placemark></Document></kml>';

const SMAP_KEY = '';

// A tile painted by the app: an orange square (any PNG, as base64), drawn at half opacity.
const TILE = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4WSz2HwAGbQKC0JqqYgAAAABJRU5ErkJggg==';

const VANS = [
  { id: 'v1', name: 'Van 1', color: '#e11d48', lng: -79.3832, lat: 43.6532 },
  { id: 'v2', name: 'Van 2', color: '#2563eb', lng: -79.40, lat: 43.66 },
  { id: 'v3', name: 'Van 3', color: '#16a34a', lng: -79.37, lat: 43.645 },
];

const SATELLITE = {
  tiles: ['https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'],
  maxZoom: 19,
  attribution: 'Tiles © Esri',
};

// The hidden tools, kept while the app runs (an app keeps them in its own storage; the map keeps no state).
let hiddenTools: string[] = [];
const LANGUAGES = ['en', 'fr', 'de', 'es', 'zh-Hans'];
const CENTER: [number, number] = [-79.3832, 43.6532];

function randomPoints(n: number) {
  const points = [];
  for (let i = 0; i < n; i++) {
    points.push({ id: i, name: 'Stop ' + (i + 1), color: ['#e11d48', '#2563eb', '#16a34a', '#f97316'][i % 4], lng: CENTER[0] + (Math.random() - 0.5) * 0.6, lat: CENTER[1] + (Math.random() - 0.5) * 0.4 });
  }
  return points;
}

const ROUTE = {
  type: 'Feature' as const,
  properties: { name: 'Route' },
  geometry: { type: 'LineString', coordinates: [[-79.46, 43.64], [-79.41, 43.65], [-79.38, 43.66], [-79.33, 43.67]] },
};

const AREA = {
  type: 'Feature' as const,
  properties: { name: 'Depot', height: 120 },
  geometry: { type: 'Polygon', coordinates: [[[-79.39, 43.641], [-79.385, 43.641], [-79.385, 43.645], [-79.39, 43.645], [-79.39, 43.641]]] },
};

function Chip({ label, on, onPress }: { label: string; on?: boolean; onPress: () => void }) {
  return (
    <Pressable onPress={onPress} style={[ui.chip, on && ui.chipOn]}>
      <Text style={[ui.chipText, on && ui.chipTextOn]}>{label}</Text>
    </Pressable>
  );
}

export default function App() {
  const map = useRef<SMapHandle | null>(null);
  const [flavor, setFlavor] = useState<StyleFlavor>('light');
  const [language, setLanguage] = useState('en');
  const [buildings, setBuildings] = useState(false);
  const [blue, setBlue] = useState(false);
  const [tapped, setTapped] = useState('');
  const points = useMemo(() => randomPoints(2000), []);

  return (
    <SafeAreaView style={ui.screen}>
      <View style={ui.bar}>
        {FLAVORS.map((f) => <Chip key={f} label={f} on={f === flavor} onPress={() => setFlavor(f)} />)}
      </View>
      <View style={ui.bar}>
        {LANGUAGES.map((l) => <Chip key={l} label={l} on={l === language} onPress={() => setLanguage(l)} />)}
        <Chip label="3D" on={buildings} onPress={() => setBuildings(!buildings)} />
        <Chip label="Basemap" on={blue} onPress={() => setBlue(!blue)} />
        <Chip label="Fit" onPress={() => map.current?.fitLayer('stops')} />
      </View>
      <SMap
        ref={map}
        apiKey={SMAP_KEY || undefined}
        style={flavor}
        language={language}
        center={CENTER}
        zoom={11}
        buildings3D={buildings}
        basemap={blue ? BLUE_WATER : undefined}
        containerStyle={ui.map}
        onError={(e) => setTapped(e.message)}
        tools={{ hidden: hiddenTools }}
        onToolsChange={(e) => { hiddenTools = e.hidden; }}
        onReady={(m) => {
          m.addHeatmap('density', points.slice(0, 400), { radius: 18, opacity: 0.6 });
          m.setTerrain({ tiles: ['https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png'], attribution: 'Terrain: Mapzen / AWS' });
          m.addCanvasTiles('tint', () => TILE, { opacity: 0.5 });
          m.setVisible('tint', false);
          m.addModels('trucks3d', [{ id: 't1', bearing: 0, lng: -79.388, lat: 43.6555 }, { id: 't2', bearing: 90, lng: -79.382, lat: 43.6555 }], {
            model: 'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/CesiumMilkTruck/glTF-Binary/CesiumMilkTruck.glb',
            size: 40, heading: { property: 'bearing', default: 0 }, idProperty: 'id',
          });
          // Three vans as React views: a long press drags one.
          m.addCustomMarkers('vans', VANS, {
            idProperty: 'id',
            anchor: 'bottom',
            render: (p) => <Text style={[ui.van, { backgroundColor: String(p.color) }]}>{String(p.name)}</Text>,
            onTap: (f) => setTapped(String(f.properties.name)),
            draggable: true,
            onDragEnd: (f, e) => setTapped(`${f.properties.name}: ${e.lat.toFixed(5)}, ${e.lng.toFixed(5)}`),
          });
          m.drawTool({ toolbar: 'bottom-right', onChange: (e) => setTapped(`${e.type}: ${e.features.features.length} shapes`) });
        }}
      >
        <Tool id="zoom" kind="zoom" />
        <Tool id="compass" kind="compass" />
        <Tool id="scale" kind="scale" />
        <Tool id="layers" kind="layers"
          base={[{ id: 'streets', label: 'Streets' }, { id: 'satellite', label: 'Satellite', imagery: SATELLITE }]}
          overlays={[{ id: 'density', label: 'Heat map', layers: ['density'] }, { id: 'tint', label: 'Painted tiles', layers: ['tint'], visible: false }]} />
        <Tool id="legend" label="Legend" position="bottom-left">
          <Text style={ui.legend}>Green: route · Orange: depot</Text>
        </Tool>
        <Points id="stops" data={points} options={{ cluster: { ring: 'color' }, label: 'name', zIndex: 2, tooltip: '{name}' }} onTap={(p) => setTapped(String(p.name))} />
        <Lines id="route" data={ROUTE} options={{ color: '#16a34a', width: 5, zIndex: 1, label: 'name' }} />
        <Polygons id="depot" data={AREA} options={{ fill: '#f97316', extrude: { height: 'height' } }} />
        <StyleLayer layer={PARKS_OUTLINE} slot="labels" />
        <Data id="kml" data={KML} format="kml" onTap={(p) => setTapped(String(p.name))} />
      </SMap>
      <Text style={ui.status} numberOfLines={1}>{tapped}</Text>
    </SafeAreaView>
  );
}

const ui = StyleSheet.create({
  screen: { flex: 1, backgroundColor: '#ffffff' },
  bar: { flexDirection: 'row', flexWrap: 'wrap', paddingHorizontal: 8, paddingTop: 8, gap: 6 },
  chip: { paddingHorizontal: 10, paddingVertical: 6, borderRadius: 14, backgroundColor: '#e5e7eb' },
  chipOn: { backgroundColor: '#2563eb' },
  chipText: { color: '#111827', fontSize: 13 },
  chipTextOn: { color: '#ffffff' },
  map: { flex: 1, marginTop: 8 },
  status: { padding: 8, color: '#374151' },
  van: { color: '#ffffff', fontSize: 12, borderRadius: 6, overflow: 'hidden', paddingHorizontal: 6, paddingVertical: 2 },
  legend: { backgroundColor: '#ffffff', borderRadius: 6, paddingHorizontal: 8, paddingVertical: 4, fontSize: 12 },
});
