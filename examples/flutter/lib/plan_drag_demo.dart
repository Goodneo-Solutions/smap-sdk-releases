// A test page for the plan editor's long-press drag on a device: `flutter run -t lib/plan_drag_demo.dart`.
//
// Two routes are drawn on the map; the plan calls are answered on the device by a stand-in Open Platform (no
// credentials needed for the plan). Long-press a stop and drag it onto a stop of the other route: the editor's
// dropStop moves it, and the page lists every call and change. Each line is also printed with the prefix PLANDEMO
// (with the stops' positions on the screen in physical pixels), so a script can drive and read the page.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smap_flutter/smap_flutter.dart';

const String token = String.fromEnvironment('SMAP_TOKEN');
const String apiKey = String.fromEnvironment('SMAP_API_KEY');
const String baseUrl = String.fromEnvironment('SMAP_BASE_URL', defaultValue: 'https://tile.srsr.ca');

void main() => runApp(const MaterialApp(home: PlanDragDemo()));

class PlanDragDemo extends StatefulWidget {
  const PlanDragDemo({super.key});

  @override
  State<PlanDragDemo> createState() => _PlanDragDemoState();
}

class _PlanDragDemoState extends State<PlanDragDemo> {
  static const center = LatLng(43.6532, -79.3832);
  static const stops = {
    'a': LatLng(43.6532, -79.4032),
    'b': LatLng(43.6632, -79.4032),
    'c': LatLng(43.6532, -79.3632),
    'd': LatLng(43.6632, -79.3632),
  };

  final GlobalKey _mapKey = GlobalKey();
  final List<String> _log = [];
  SMapPlanEditing? _editing;

  void _say(String line) {
    debugPrint('PLANDEMO $line');
    if (mounted) setState(() => _log.insert(0, line));
  }

  // The stand-in Open Platform: a snapshot, and every plan call answered with the routes as sent.
  late final http.Client _platform = MockClient((req) async {
    final body = req.body.isEmpty ? <String, dynamic>{} : jsonDecode(req.body) as Map<String, dynamic>;
    final call = req.url.path.replaceFirst('/v1/plan/', '');
    final extra = call == 'move' ? ' stops=${body['stops']} vehicle=${body['vehicle_id']} position=${body['position']}' : '';
    _say('call ${req.method} $call$extra');
    if (call == 'matrix') return http.Response(jsonEncode({'data': {'matrix': 'm1'}}), 200, headers: {'content-type': 'application/json'});
    if (req.method == 'DELETE') return http.Response('', 204);
    return http.Response(
      jsonEncode({
        'data': {
          'routes': <Object>[],
          'summary': {'routes': 2, 'tasks': 4, 'distance_meters': 12345, 'duration_seconds': 1800, 'violations': 0, 'unreachable_legs': 0},
        },
      }),
      200,
      headers: {'content-type': 'application/json', 'x-plan-matrix': 'used'},
    );
  });

  Future<void> _onReady(SMapController map) async {
    final editing = map.planEditor(SMapPlanEditorOptions(
      credentials: const SMapPlanCredentials.key('smk_demo'),
      baseUrl: 'https://open.example',
      httpClient: _platform,
      plan: SMapPlan(
        vehicles: [
          {'id': 'v1', 'start': {'lat': 43.6432, 'lng': -79.4032}},
          {'id': 'v2', 'start': {'lat': 43.6432, 'lng': -79.3632}},
        ],
        jobs: [
          for (final e in stops.entries) {'id': e.key, 'location': {'lat': e.value.latitude, 'lng': e.value.longitude}},
        ],
        routes: [
          SMapPlanRoute('v1', ['a', 'b']),
          SMapPlanRoute('v2', ['c', 'd']),
        ],
      ),
    ));
    _editing = editing;
    editing.editor.addListener((e) {
      if (e is SMapPlanChange) {
        final routes = (editing.editor.plan?.routes ?? const <SMapPlanRoute>[]).map((r) => '${r.vehicleId}=${r.stops.join(',')}').join(' ');
        _say('change ${e.kind} pending=${e.pending} $routes');
      }
    });
    await Future<void>.delayed(const Duration(seconds: 3));
    await _positions(map);
  }

  Future<void> _positions(SMapController map) async {
    final box = _mapKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !mounted) return;
    final ratio = MediaQuery.of(context).devicePixelRatio;
    final origin = box.localToGlobal(Offset.zero);
    for (final e in stops.entries) {
      // The map answers in logical pixels; adb taps take physical ones.
      final p = map.toScreen(e.value);
      final x = ((origin.dx + p.dx) * ratio).round();
      final y = ((origin.dy + p.dy) * ratio).round();
      _say('stop ${e.key} at $x $y');
    }
  }

  @override
  void dispose() {
    _editing?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(
          children: [
            Expanded(
              child: SMap(
                key: _mapKey,
                options: SMapOptions(
                  baseUrl: baseUrl,
                  token: token.isEmpty ? null : token,
                  apiKey: apiKey.isEmpty ? null : apiKey,
                  center: center,
                  zoom: 12,
                ),
                onReady: _onReady,
              ),
            ),
            SizedBox(
              height: 160,
              child: ListView(
                padding: const EdgeInsets.all(8),
                children: [for (final l in _log) Text(l, style: const TextStyle(fontSize: 12))],
              ),
            ),
          ],
        ),
      );
}
