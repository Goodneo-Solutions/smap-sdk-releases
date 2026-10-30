// One screen: colour scheme and language switchers, 2,000 clustered points, a line, an extruded area, a 3D
// buildings toggle, and map tools (zoom, compass, scale and a legend) shown or hidden from the tools control. Put a map key that allows this app (ca.superroute.smap.rnexample) in SMAP_KEY.
//
// 1.5.0 (G15–G37): zones with hover and selected looks (a double tap selects, a long press reports), circles in
// metres with a hover look, a truck turned to its heading and moved every second, an app image named `arrow` (the
// basemap has one too), an SDF pin in per-feature colours and a glyph badge, arrows at a share of the route, labels
// with priority, a tinted model, a heat map with blur and minimum opacity, the drawing tool measuring and snapping to
// the stops, a search over the app's own places, Fit and Picture buttons, and a small map with cooperative gestures
// in a scrolling screen. Set SELF_CHECK_URL to have the app check the 1.5.0 calls and post the results there (JS logs
// do not reach a console on a device).
import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Image, Modal, Pressable, SafeAreaView, ScrollView, StyleSheet, Text, View } from 'react-native';
import {
  Circles, Data, Lines, Points, Polygons, SMap, SearchTool, StyleLayer, Tool, geo, styles as FLAVORS,
  type MapFeature, type SMapHandle, type SearchResult, type StyleFlavor,
} from '@superrouteca/smap-react-native';
import { selfCheck } from './selfCheck';

const BLUE_WATER = { water: { color: '#9cc0e6' }, pois: { visible: false } };

const PARKS_OUTLINE = { id: 'parks-outline', type: 'line', source: 'basemap', 'source-layer': 'landuse',
  filter: ['==', ['get', 'kind'], 'park'], paint: { 'line-color': '#15803d', 'line-width': 1.5 } };

const KML = '<?xml version="1.0" encoding="UTF-8"?><kml xmlns="http://www.opengis.net/kml/2.2"><Document>'
  + '<Placemark><name>Union</name><Point><coordinates>-79.3806,43.6453</coordinates></Point></Placemark></Document></kml>';

const SMAP_KEY = '';
/** Where the self-check posts its results (e.g. http://localhost:8765/ with adb reverse); empty: no check. */
const SELF_CHECK_URL = '';

// A white arrow (an SDF-friendly shape) as base64 PNG, added under the name `arrow`, which the basemap's sprite has too.
const ARROW = 'iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAASklEQVR4nO3NuwkAMAwDUe+/tNOkMoTIHxUC3wD3zDap/KYJeEgLiPNxhAq85mMIFfjN2wgVQOdlhApk52mEClTnMEIFunMI2WIHKJeFl7tO4Y0AAAAASUVORK5CYII=';

const ZONES = {
  type: 'FeatureCollection' as const,
  features: [
    { type: 'Feature' as const, properties: { code: 'Z1', name: 'West', color: '#8b5cf6' }, geometry: { type: 'Polygon', coordinates: [[[-79.45, 43.66], [-79.41, 43.66], [-79.41, 43.69], [-79.45, 43.69], [-79.45, 43.66]]] } },
    { type: 'Feature' as const, properties: { code: 'Z2', name: 'East', color: '#0ea5e9' }, geometry: { type: 'Polygon', coordinates: [[[-79.36, 43.66], [-79.32, 43.66], [-79.32, 43.69], [-79.36, 43.69], [-79.36, 43.66]]] } },
  ],
};

const DEPOTS = [
  { id: 'd1', name: 'North depot', rank: 3, color: '#dc2626', radius_m: 800, lng: -79.39, lat: 43.70 },
  { id: 'd2', name: 'South depot', rank: 1, color: '#16a34a', radius_m: 500, lng: -79.40, lat: 43.635 },
];

const PLACES: SearchResult[] = [
  { label: 'CN Tower', lngLat: [-79.3871, 43.6426] },
  { label: 'Union Station', lngLat: [-79.3806, 43.6453] },
  { label: 'High Park', bounds: [-79.4730, 43.6380, -79.4560, 43.6560] },
  { label: 'Toronto Islands', bounds: [-79.3950, 43.6150, -79.3500, 43.6330] },
];

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
  const [selected, setSelected] = useState<string | null>(null);
  const [picture, setPicture] = useState<string | null>(null);
  const [small, setSmall] = useState(false);
  const truck = useRef({ lng: -79.41, lat: 43.65, course: 60 });
  // A truck moved every second, turned to its heading.
  useEffect(() => {
    const t = setInterval(() => {
      const m = map.current;
      if (!m) { return; }
      const v = truck.current;
      v.course = (v.course + 25) % 360;
      v.lng += Math.sin((v.course * Math.PI) / 180) * 0.004;
      v.lat += Math.cos((v.course * Math.PI) / 180) * 0.003;
      void m.moveFeature('fleet', 'truck', [v.lng, v.lat], { duration: 1000 });
      void m.updateFeature('fleet', 'truck', { course: v.course });
    }, 1000);
    return () => clearInterval(t);
  }, []);
  if (small) { return <SmallMap onBack={() => setSmall(false)} />; }

  return (
    <SafeAreaView style={ui.screen}>
      <View style={ui.bar}>
        {FLAVORS.map((f) => <Chip key={f} label={f} on={f === flavor} onPress={() => setFlavor(f)} />)}
      </View>
      <View style={ui.bar}>
        {LANGUAGES.map((l) => <Chip key={l} label={l} on={l === language} onPress={() => setLanguage(l)} />)}
        <Chip label="3D" on={buildings} onPress={() => setBuildings(!buildings)} />
        <Chip label="Basemap" on={blue} onPress={() => setBlue(!blue)} />
        <Chip label="Fit" onPress={() => map.current?.fitLayer(['zones', 'depots'], { padding: 30 })} />
        <Chip label="Picture" onPress={() => { map.current?.export({ pixelRatio: 2 }).then(setPicture, (e: Error) => setTapped(e.message)); }} />
        <Chip label="Small map" onPress={() => setSmall(true)} />
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
        onUnavailable={(e) => setTapped('The map cannot be shown: ' + e.reason)}
        onReady={(m) => {
          m.addHeatmap('density', points.slice(0, 400), { radius: 18, opacity: 0.6, blur: 12, minOpacity: 0.3 });
          // Images: an app image named like a basemap one, an SDF pin coloured per feature, a glyph badge.
          void m.addImage('arrow', { base64: ARROW }, { pixelRatio: 1 }).then(() => {
            m.addPoints('fleet', [{ id: 'truck', course: truck.current.course, lng: truck.current.lng, lat: truck.current.lat }], {
              icon: 'arrow', iconAnchor: 'center', idProperty: 'id', rotation: { property: 'course', default: 0 }, zIndex: 5,
            });
          });
          void m.addImage('pin', { base64: ARROW }, { sdf: true }).then(() => {
            m.addPoints('depots', DEPOTS, {
              icon: 'pin', iconColor: { property: 'color', default: '#111827' }, idProperty: 'id', label: 'name',
              priority: { property: 'rank' }, allowOverlap: false, labelSize: (p: Record<string, unknown>) => 11 + Number(p.rank),
              onDblClick: (f: MapFeature) => setTapped('Double tap: ' + String(f.properties.name)),
            });
          });
          void m.addGlyphImage('star', { glyph: '★', color: '#ffffff', background: '#0ea5e9', size: 20 });
          if (SELF_CHECK_URL) { setTimeout(() => { void selfCheck(m, SELF_CHECK_URL).then((r) => setTapped(r)); }, 3000); }
          m.setTerrain({ tiles: ['https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png'], attribution: 'Terrain: Mapzen / AWS' });
          m.addCanvasTiles('tint', () => TILE, { opacity: 0.5 });
          m.setVisible('tint', false);
          m.addModels('trucks3d', [{ id: 't1', bearing: 0, tint: '#dc2626', lng: -79.388, lat: 43.6555 }, { id: 't2', bearing: 90, lng: -79.382, lat: 43.6555 }], {
            model: 'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/CesiumMilkTruck/glTF-Binary/CesiumMilkTruck.glb',
            size: 40, heading: { property: 'bearing', default: 0 }, idProperty: 'id', color: { property: 'tint' },
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
          m.drawTool({
            toolbar: 'bottom-right', measure: true, snapLayers: ['stops'], allowSelfIntersection: false,
            style: (p) => (p.kind === 'no-go' ? { color: '#dc2626', dash: [2, 2] } : null),
            onChange: (e) => setTapped(`${e.type}: ${e.features.features.length} shapes`),
            onDrawing: (e) => setTapped(`${e.mode}: ${Math.round(e.length)} m, ${Math.round(e.area)} m²${e.valid ? '' : ' (crosses itself)'}`),
          });
        }}
      >
        <Tool id="zoom" kind="zoom" />
        <Tool id="compass" kind="compass" />
        <Tool id="scale" kind="scale" />
        <SearchTool id="search" search={(text) => PLACES.filter((p) => p.label.toLowerCase().includes(text.toLowerCase()))}
          onPick={(r) => setTapped('Picked ' + r.label)} minChars={2} />
        <Tool id="layers" kind="layers"
          base={[{ id: 'streets', label: 'Streets' }, { id: 'satellite', label: 'Satellite', imagery: SATELLITE }]}
          overlays={[{ id: 'density', label: 'Heat map', layers: ['density'] }, { id: 'tint', label: 'Painted tiles', layers: ['tint'], visible: false }]} />
        <Tool id="legend" label="Legend" position="bottom-left">
          <Text style={ui.legend}>Green: route · Orange: depot</Text>
        </Tool>
        <Points id="stops" data={points} options={{ cluster: { ring: 'color' }, label: 'name', zIndex: 2, tooltip: '{name}' }} onTap={(p) => setTapped(String(p.name))} />
        <Lines id="route" data={ROUTE} options={{ color: '#16a34a', width: 5, zIndex: 1, label: 'name', arrows: { spacing: '15%' } }} />
        <Polygons id="zones" data={ZONES}
          options={{ idProperty: 'code', fill: { property: 'color', default: '#64748b' }, opacity: 0.25, hoverState: true, outlineDash: [2, 1],
            states: { hover: { opacity: 0.45 }, selected: { outline: '#111827', outlineWidth: 3, opacity: 0.5 } } }}
          featureStates={selected ? { [selected]: { selected: true } } : {}}
          onDblClick={(f) => setSelected(f.key === selected ? null : f.key)}
          onContextMenu={(f) => setTapped('Long press: ' + String(f.properties.name))} />
        <Circles id="reach" data={DEPOTS} options={{ radius: { property: 'radius_m' }, fill: '#f59e0b', opacity: 0.2, outline: '#b45309', hoverState: true, idProperty: 'id',
          states: { hover: { opacity: 0.4 } } }} onTap={(p) => setTapped(String(p.name) + ': ' + String(p.radius_m) + ' m')} />
        <Polygons id="depot" data={AREA} options={{ fill: '#f97316', extrude: { height: 'height' } }} />
        <StyleLayer layer={PARKS_OUTLINE} slot="labels" />
        <Data id="kml" data={KML} format="kml" onTap={(p) => setTapped(String(p.name))} />
      </SMap>
      <Text style={ui.status} numberOfLines={1}>{tapped}</Text>
      <Modal visible={!!picture} transparent animationType="fade" onRequestClose={() => setPicture(null)}>
        <Pressable style={ui.dialog} onPress={() => setPicture(null)}>
          {picture ? <Image source={{ uri: picture }} style={ui.picture} resizeMode="contain" /> : null}
          <Text style={ui.dialogText}>{picture ? `${Math.round((picture.length * 3) / 4 / 1024)} KB` : ''}</Text>
        </Pressable>
      </Modal>
    </SafeAreaView>
  );
}

/** A small map in a screen that scrolls: one finger scrolls the screen, two move the map (G36). */
function SmallMap({ onBack }: { onBack: () => void }) {
  return (
    <SafeAreaView style={ui.screen}>
      <ScrollView contentContainerStyle={{ padding: 16 }}>
        <Chip label="Back" onPress={onBack} />
        {[1, 2, 3].map((i) => <Text key={i} style={ui.para}>{'A paragraph of the page. '.repeat(12)}</Text>)}
        <View style={ui.small}>
          <SMap apiKey={SMAP_KEY || undefined} center={CENTER} zoom={12} cooperativeGestures containerStyle={{ flex: 1 }}>
            <Circles id="reach" data={DEPOTS} options={{ radius: { property: 'radius_m' }, fill: '#f59e0b', opacity: 0.25 }} />
          </SMap>
        </View>
        {[4, 5, 6].map((i) => <Text key={i} style={ui.para}>{'A paragraph of the page. '.repeat(12)}</Text>)}
        <Text style={ui.para}>{'Area of the West zone: ' + Math.round(geo.area(ZONES.features[0]) / 1e6 * 100) / 100 + ' km²'}</Text>
      </ScrollView>
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
  dialog: { flex: 1, backgroundColor: 'rgba(0,0,0,0.6)', alignItems: 'center', justifyContent: 'center', padding: 24 },
  picture: { width: '100%', height: '70%', backgroundColor: '#ffffff' },
  dialogText: { color: '#ffffff', marginTop: 8 },
  small: { height: 220, marginVertical: 16, borderRadius: 8, overflow: 'hidden' },
  para: { fontSize: 14, color: '#374151', marginVertical: 8 },
});
