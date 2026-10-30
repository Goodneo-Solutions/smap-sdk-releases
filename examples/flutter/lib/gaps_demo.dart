import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:smap_flutter/smap_flutter.dart';

import 'main.dart' show apiKey, baseUrl, token;

/// The 1.5.0 calls (G15–G37): a fitted view, zones with selected and hover looks, a moving truck with a heading,
/// a double tap and a long press on a feature, icons in colour, a glyph, circles in metres, measuring with snapping,
/// the map's picture, a tinted model, a soft heat map, arrows by share, labels by priority, a search over the app's
/// places, and a small map with cooperative gestures in a scrolling screen.
class GapsDemoScreen extends StatefulWidget {
  const GapsDemoScreen({super.key});

  @override
  State<GapsDemoScreen> createState() => _GapsDemoScreenState();
}

class _GapsDemoScreenState extends State<GapsDemoScreen> {
  static const center = LatLng(43.6532, -79.3832);
  static const places = [
    ('CN Tower', LatLng(43.6426, -79.3871)),
    ('Union Station', LatLng(43.6453, -79.3806)),
    ('Royal Ontario Museum', LatLng(43.6677, -79.3948)),
    ('Distillery District', LatLng(43.6503, -79.3596)),
    ('High Park', LatLng(43.6465, -79.4637)),
  ];

  SMapController? _map;
  Timer? _drive;
  String? _selected;
  String _figures = '';

  @override
  void dispose() {
    _drive?.cancel();
    super.dispose();
  }

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
  }

  Future<void> _onReady(SMapController map) async {
    _map = map;
    // An app image named like a sprite image (the collision case): drawn as the app's, never the sprite's arrow.
    await map.addGlyphImage('arrow', const SMapGlyph('➤', size: 22, color: '#000000', sdf: true));
    await map.addGlyphImage('pin-p', const SMapGlyph('P', size: 16, color: '#ffffff', background: '#7c3aed'));
    await map.addPolygons(
      'zones',
      const [
        SMapPolygon([[LatLng(43.640, -79.400), LatLng(43.640, -79.385), LatLng(43.650, -79.385), LatLng(43.650, -79.400)]], properties: {'id': 'z1', 'name': 'West'}),
        SMapPolygon([[LatLng(43.640, -79.383), LatLng(43.640, -79.368), LatLng(43.650, -79.368), LatLng(43.650, -79.383)]], properties: {'id': 'z2', 'name': 'East'}),
      ],
      SMapPolygonOptions(
        idProperty: 'id',
        fill: '#2563eb',
        opacity: 0.25,
        outlineDash: const SMapValue<List<double>>.constant([2, 2]),
        hoverState: true,
        states: const {
          'hover': SMapPolygonLook(opacity: 0.4),
          'selected': SMapPolygonLook(fill: '#f97316', opacity: 0.5),
        },
        tooltip: SMapTooltip.template('{name}'),
        onDoubleClick: (f, e) => _say('Double tap: ${f.properties['name']}'),
        onContextMenu: (f, e) => _say('Long press: ${f.properties['name']}'),
      ),
    );
    map.onTap('zones', (p, _) {
      final id = '${p['id']}';
      if (_selected != null) map.removeFeatureState('zones', _selected!, 'selected');
      _selected = id;
      map.setFeatureState('zones', id, {'selected': true});
    });
    await map.addLines(
      'route',
      const [SMapLine([LatLng(43.6455, -79.3807), LatLng(43.6532, -79.3832), LatLng(43.6629, -79.3957), LatLng(43.6677, -79.3948)], properties: {'name': 'Route 1'})],
      const SMapLineOptions(color: '#16a34a', width: 5, label: 'name', arrows: SMapLineArrows(share: 0.15), labelSize: SMapValue<double>.constant(13)),
    );
    await map.addCircles(
      'reach',
      const [SMapPoint(43.6629, -79.3957, properties: {'radius': 400}), SMapPoint(43.6503, -79.3596, properties: {'radius': 250})],
      const SMapCircleOptions(area: SMapPolygonOptions(fill: '#16a34a', opacity: 0.2, hoverState: true, states: {'hover': SMapPolygonLook(opacity: 0.45)})),
    );
    await map.addPoints(
      'places',
      [for (final (i, p) in places.indexed) SMapPoint(p.$2.latitude, p.$2.longitude, properties: {'name': p.$1, 'rank': places.length - i})],
      SMapPointOptions(
        icon: 'arrow',
        iconColor: SMapValue<String>.of((p) => (p['rank'] as int) > 3 ? '#e11d48' : '#2563eb'),
        label: 'name',
        priority: const SMapValue<double>.property('rank'),
        allowOverlap: false,
      ),
    );
    await map.addPoints('parking', const [SMapPoint(43.6480, -79.3900)], const SMapPointOptions(icon: 'pin-p'));
    await map.addPoints(
      'truck',
      const [SMapPoint(43.6455, -79.3807, properties: {'id': 't', 'heading': 0})],
      const SMapPointOptions(idProperty: 'id', icon: 'arrow', iconSize: 1.4, iconAnchor: SMapAnchor.center, rotation: SMapValue<double>.property('heading')),
    );
    await map.addHeatmap(
      'heat',
      [for (var i = 0; i < 200; i++) SMapPoint(43.66 + math.sin(i) * 0.01, -79.41 + math.cos(i * 1.7) * 0.015)],
      const SMapHeatmapOptions(blur: 12, minOpacity: 0.3, radius: 16),
    );
    await map.addModels(
      'trucks3d',
      const [SMapPoint(43.6555, -79.3880, properties: {'id': 't1', 'tint': '#e11d48'}), SMapPoint(43.6555, -79.3820, properties: {'id': 't2', 'tint': '#2563eb'})],
      const SMapModelOptions(
        model: 'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/CesiumMilkTruck/glTF-Binary/CesiumMilkTruck.glb',
        size: SMapValue.constant(40),
        idProperty: 'id',
        color: SMapValue.property('tint'),
      ),
    );
    map.addSearchTool('search', SMapSearchOptions(
      search: (q) async => [
        for (final p in places)
          if (p.$1.toLowerCase().contains(q.toLowerCase())) SMapSearchResult(p.$1, position: p.$2),
      ],
      minChars: 2,
      onPick: (r) => _say(r.label),
    ));
    final route = const [LatLng(43.6455, -79.3807), LatLng(43.6532, -79.3832), LatLng(43.6629, -79.3957), LatLng(43.6677, -79.3948)];
    var step = 0;
    _drive = Timer.periodic(const Duration(seconds: 1), (_) {
      final a = route[step % (route.length - 1)], b = route[step % (route.length - 1) + 1];
      final t = (step % 4) / 4 + 0.25;
      final next = LatLng(a.latitude + (b.latitude - a.latitude) * t, a.longitude + (b.longitude - a.longitude) * t);
      final heading = math.atan2(b.longitude - a.longitude, b.latitude - a.latitude) * 180 / math.pi;
      map.updateFeature('truck', 't', {'heading': heading});
      map.moveFeature('truck', 't', next, duration: const Duration(milliseconds: 900));
      step++;
    });
    await _fit();
  }

  Future<void> _fit() => _map?.fitLayers(['zones', 'route', 'reach'], options: const SMapFitOptions(padding: SMapPadding.all(30))) ?? Future.value();

  void _measure() {
    final tool = _map?.drawTool(SMapDrawOptions(
      modes: const [SMapDrawShape.line, SMapDrawShape.polygon, SMapDrawShape.circle],
      measure: true,
      allowSelfIntersection: false,
      snapLayers: const ['route', 'zones'],
      toolbar: SMapToolPosition.bottomLeft,
    ));
    tool?.drawing.listen((e) {
      if (mounted) setState(() => _figures = '${e.mode}: ${e.length.toStringAsFixed(0)} m, ${e.area.toStringAsFixed(0)} m²${e.valid ? '' : ' (crosses itself)'}');
    });
  }

  Future<void> _export() async {
    final bytes = await _map?.export();
    if (bytes == null || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Image.memory(bytes),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final options = SMapOptions(
      baseUrl: baseUrl,
      token: token.isEmpty ? null : token,
      apiKey: apiKey.isEmpty ? null : apiKey,
      center: center,
      zoom: 12,
      language: 'en',
    );
    return Scaffold(
      appBar: AppBar(title: const Text('sMap 1.5.0'), actions: [
        IconButton(onPressed: _fit, icon: const Icon(Icons.fit_screen), tooltip: 'Fit'),
        IconButton(onPressed: _measure, icon: const Icon(Icons.straighten), tooltip: 'Measure'),
        IconButton(onPressed: _export, icon: const Icon(Icons.image), tooltip: 'Picture'),
      ]),
      body: ListView(children: [
        SizedBox(
          height: 460,
          child: SMap(
            options: options,
            onReady: _onReady,
            onError: (e) => _say('$e'),
            tools: [
              SMapTool.kind('zoom', SMapToolKind.zoom, position: SMapToolPosition.topRight),
              SMapTool.layerSwitcher(
                'layers',
                const SMapLayersTool(base: [
                  SMapLayersBase(label: 'Streets'),
                  SMapLayersBase(
                    label: 'Satellite',
                    imagery: SMapBaseImagery(
                      tiles: ['https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'],
                      attribution: 'Tiles © Esri',
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
        Padding(padding: const EdgeInsets.all(12), child: Text(_figures.isEmpty ? 'Measure: draw a line or an area.' : _figures)),
        const Padding(padding: EdgeInsets.all(12), child: Text('A small map in a scrolling screen: one finger scrolls the page, two move the map.')),
        SizedBox(height: 220, child: SMap(options: SMapOptions(baseUrl: baseUrl, token: token.isEmpty ? null : token, apiKey: apiKey.isEmpty ? null : apiKey, center: center, zoom: 13, cooperativeGestures: true))),
        const SizedBox(height: 600),
      ]),
    );
  }
}
