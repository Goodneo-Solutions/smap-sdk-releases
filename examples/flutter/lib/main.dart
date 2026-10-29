import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smap_flutter/smap_flutter.dart';

/// Pass a token at build time: `flutter run --dart-define=SMAP_TOKEN=sm1....`
/// (an app normally gets it from its own server through `getToken`).
const String token = String.fromEnvironment('SMAP_TOKEN');

/// Or a map key whose allowlist names this app: `--dart-define=SMAP_API_KEY=smk_...`.
const String apiKey = String.fromEnvironment('SMAP_API_KEY');
const String baseUrl = String.fromEnvironment('SMAP_BASE_URL', defaultValue: 'https://tile.srsr.ca');

/// Where the example keeps the hidden map tools (the SDK keeps no state itself).
const String toolsKey = 'smap-example-hidden-tools';
late final SharedPreferences prefs;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  prefs = await SharedPreferences.getInstance();
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'sMap demo',
        theme: ThemeData(colorSchemeSeed: const Color(0xFF2563EB), useMaterial3: true),
        home: const DemoScreen(),
      );
}

class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  static const center = LatLng(43.6532, -79.3832);
  static const languages = ['en', 'fr', 'de', 'es', 'zh-Hans', 'ja'];

  SMapController? _map;
  SMapStyle _style = SMapStyle.light;
  String _language = 'en';
  bool _buildings = false;

  /// 2,000 points scattered around the centre (same every run).
  List<SMapPoint> _points() {
    final random = math.Random(7);
    return List.generate(2000, (i) {
      final r = 0.25 * math.sqrt(random.nextDouble());
      final a = random.nextDouble() * 2 * math.pi;
      return SMapPoint(
        center.latitude + r * math.sin(a) * 0.72,
        center.longitude + r * math.cos(a),
        properties: {'name': 'Stop ${i + 1}', 'color': const ['#e11d48', '#2563eb', '#16a34a', '#f97316'][i % 4]},
      );
    });
  }

  Future<void> _onReady(SMapController map) async {
    _map = map;
    await map.addPolygons(
      'block',
      [
        const SMapPolygon([
          [LatLng(43.6418, -79.3871), LatLng(43.6418, -79.3833), LatLng(43.6440, -79.3833), LatLng(43.6440, -79.3871)],
        ], properties: {'name': 'Tower block', 'height': 180}),
      ],
      const SMapPolygonOptions(fill: '#f97316', extrude: SMapExtrude(height: 'height')),
    );
    await map.addLines(
      'route',
      [
        const SMapLine([
          LatLng(43.6455, -79.3807),
          LatLng(43.6532, -79.3832),
          LatLng(43.6629, -79.3957),
          LatLng(43.6677, -79.3948),
        ], properties: {'name': 'Route 1'}),
      ],
      const SMapLineOptions(color: '#16a34a', width: 5, label: 'name'),
    );
    final points = _points();
    // Clusters as a ring of the stops' colours; a finger resting on a stop shows its name.
    await map.addPoints(
      'stops',
      points,
      SMapPointOptions(
        cluster: true,
        clusterRing: const SMapClusterRing('color'),
        label: 'name',
        zIndex: 1,
        tooltip: SMapTooltip.template('{name}'),
      ),
    );
    await map.addHeatmap('density', points.take(400).toList(), const SMapHeatmapOptions(radius: 18, opacity: 0.6));
    await map.setTerrain(const SMapTerrain(
      tiles: ['https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png'],
      attribution: 'Terrain: Mapzen / AWS',
    ));
    // Tiles painted by the app.
    await map.addCanvasTiles('grid', (canvas, z, x, y, size) {
      canvas.drawRect(Offset.zero & Size(size, size), Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0x80333333));
      final text = TextPainter(text: TextSpan(text: '$z/$x/$y', style: const TextStyle(fontSize: 11, color: Colors.black)), textDirection: TextDirection.ltr)..layout();
      text.paint(canvas, const Offset(6, 4));
    }, opacity: 0.6);
    await map.setVisible('grid', false);
    // 3D trucks (a sample glTF model of the Khronos glTF samples, CC-BY 4.0 Cesium), turned to their heading.
    await map.addModels(
      'trucks3d',
      const [
        SMapPoint(43.6555, -79.3880, properties: {'id': 't1', 'bearing': 0}),
        SMapPoint(43.6555, -79.3820, properties: {'id': 't2', 'bearing': 90}),
      ],
      const SMapModelOptions(
        model: 'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/CesiumMilkTruck/glTF-Binary/CesiumMilkTruck.glb',
        size: SMapValue.constant(40),
        heading: SMapValue.property('bearing', 0),
        idProperty: 'id',
      ),
    );
    // Three vans as Flutter widgets: a long press drags one.
    await map.addCustomMarkers(
      'vans',
      const [
        SMapPoint(43.6532, -79.3832, properties: {'id': 'v1', 'name': 'Van 1', 'color': 0xFFE11D48}),
        SMapPoint(43.6600, -79.4000, properties: {'id': 'v2', 'name': 'Van 2', 'color': 0xFF2563EB}),
        SMapPoint(43.6450, -79.3700, properties: {'id': 'v3', 'name': 'Van 3', 'color': 0xFF16A34A}),
      ],
      SMapCustomMarkerOptions(
        idProperty: 'id',
        anchor: SMapAnchor.bottom,
        builder: (p) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: Color(p['color'] as int), borderRadius: BorderRadius.circular(6)),
          child: Text('${p['name']}', style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
        onTap: (f) => _say('${f.properties['name']}'),
        drag: SMapDrag(
          draggable: const SMapValue.constant(true),
          onDragEnd: (f, e) => _say('${f.properties['name']}: ${e.lat.toStringAsFixed(5)}, ${e.lng.toStringAsFixed(5)}'),
        ),
      ),
    );
    map.drawTool(SMapDrawOptions(
      toolbar: SMapToolPosition.bottomRight,
      onChange: (e) => _say('${e.type}: ${(e.features['features'] as List).length} shapes'),
    ));
    map.onTap('stops', (properties, position) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${properties['name']}')));
    });
    map.onTap('route', (properties, position) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${properties['name']}')));
    });
  }

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
  }

  void _onError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('sMap'),
        actions: [
          DropdownButton<String>(
            value: _language,
            underline: const SizedBox.shrink(),
            items: [for (final l in languages) DropdownMenuItem(value: l, child: Text(l))],
            onChanged: (l) {
              if (l == null) return;
              setState(() => _language = l);
              _map?.setLanguage(l);
            },
          ),
          const SizedBox(width: 8),
          Row(children: [
            const Text('3D'),
            Switch(
              value: _buildings,
              onChanged: (on) {
                setState(() => _buildings = on);
                _map?.setBuildings3D(on);
              },
            ),
          ]),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<SMapStyle>(
              segments: [for (final s in SMapStyle.values) ButtonSegment(value: s, label: Text(s.name))],
              selected: {_style},
              showSelectedIcon: false,
              onSelectionChanged: (set) {
                setState(() => _style = set.first);
                _map?.setStyle(set.first);
              },
            ),
          ),
          Expanded(
            child: SMap(
              options: SMapOptions(
                baseUrl: baseUrl,
                token: token.isEmpty ? null : token,
                apiKey: apiKey.isEmpty ? null : apiKey,
                style: _style,
                language: _language,
                center: center,
                zoom: 11,
                tools: SMapToolsOptions(
                  hidden: (prefs.getStringList(toolsKey) ?? const []).toSet(),
                  onChange: (change) => prefs.setStringList(toolsKey, change.hidden),
                ),
              ),
              tools: [
                SMapTool.kind('zoom', SMapToolKind.zoom),
                SMapTool.kind('compass', SMapToolKind.compass),
                SMapTool.kind('scale', SMapToolKind.scale),
                SMapTool.layerSwitcher(
                  'layers',
                  const SMapLayersTool(
                    base: [
                      SMapLayersBase(id: 'streets', label: 'Streets'),
                      SMapLayersBase(
                        id: 'satellite',
                        label: 'Satellite',
                        imagery: SMapBaseImagery(
                          tiles: ['https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'],
                          maxZoom: 19,
                          attribution: 'Tiles © Esri',
                        ),
                      ),
                    ],
                    overlays: [
                      SMapLayersOverlay(id: 'density', label: 'Heat map', layers: ['density']),
                      SMapLayersOverlay(id: 'grid', label: 'Tile grid', layers: ['grid'], visible: false),
                    ],
                  ),
                ),
                // Data layers as tools: the stops, and the route with the block.
                SMapTool.layers('stops', const ['stops'], label: 'Stops'),
                SMapTool.layers('route', const ['route', 'block'], label: 'Route'),
                SMapTool(
                  id: 'legend',
                  label: 'Legend',
                  position: SMapToolPosition.bottomLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                    child: const Text('Green: route · Orange: block', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
              onReady: _onReady,
              onError: _onError,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => _map?.fitLayer('stops'),
        tooltip: 'Show all stops',
        child: const Icon(Icons.fit_screen),
      ),
    );
  }
}
