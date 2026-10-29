import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smap_flutter/smap_flutter.dart';

/// The Flutter SDK on the native map of the device (Android or iOS): the bridge both ways, with no screen reading.
/// Run with `flutter test integration_test -d <device>`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<SMapController> pumpMap(WidgetTester tester, {SMapOptions? options, List<Object>? errors}) async {
    final c = SMapController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          height: 600,
          child: SMap(
            controller: c,
            options: options ?? const SMapOptions(center: LatLng(43.6532, -79.3832), zoom: 11, language: 'en'),
            onError: errors?.add,
          ),
        ),
      ),
    ));
    final end = DateTime.now().add(const Duration(seconds: 40));
    while (!c.isReady && DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    return c;
  }

  Future<void> waitFor(WidgetTester tester, bool Function() done, {int seconds = 20}) async {
    final end = DateTime.now().add(Duration(seconds: seconds));
    while (!done() && DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('the native map starts, reports its camera and the style it loaded, and follows moves', (tester) async {
    final c = await pumpMap(tester);
    expect(c.isReady, isTrue, reason: 'ready from the native map');
    await waitFor(tester, () => c.slots().isNotEmpty);
    expect(c.slots(), isNotEmpty, reason: 'the style as loaded reached Dart');
    expect(c.camera.zoom, closeTo(11, 0.01));
    await c.moveCamera(target: const LatLng(45.5, -73.56), zoom: 9);
    await waitFor(tester, () => (c.camera.zoom - 9).abs() < 0.01);
    expect(c.camera.target.latitude, closeTo(45.5, 1e-4));
    // The Dart camera geometry puts the centre in the middle of the view.
    final mid = c.toScreen(c.camera.target);
    expect(mid.dx, closeTo(180, 1));
  });

  testWidgets('layers, drawn tiles, a drawing tool and selection go through without errors', (tester) async {
    final errors = <Object>[];
    final c = await pumpMap(tester, errors: errors);
    final tiles = <String>[];
    await c.addPoints(
      'stops',
      const [SMapPoint(43.65, -79.38, properties: {'name': 'A', 'color': '#e11d48'}), SMapPoint(43.66, -79.39)],
      SMapPointOptions(cluster: true, clusterRing: const SMapClusterRing('color'), tooltip: SMapTooltip.template('{name}')),
    );
    await c.addLines('route', const [SMapLine([LatLng(43.6, -79.4), LatLng(43.7, -79.3)], properties: {'name': 'R'})],
        const SMapLineOptions(label: 'name'));
    await c.addHeatmap('heat', const [SMapPoint(43.65, -79.38)]);
    await c.setTerrain(const SMapTerrain(tiles: ['https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png']));
    await c.setBaseImagery(const SMapBaseImagery(tiles: ['https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}']));
    await c.addCanvasTiles('grid', (canvas, z, x, y, size) => tiles.add('$z/$x/$y'));
    await waitFor(tester, () => tiles.isNotEmpty);
    expect(tiles, isNotEmpty, reason: 'the native map asked Dart to paint tiles');
    final events = <String>[];
    final tool = c.drawTool(SMapDrawOptions(
      features: {
        'type': 'FeatureCollection',
        'features': [
          {'type': 'Feature', 'id': 'p', 'properties': {}, 'geometry': {'type': 'Point', 'coordinates': [-79.38, 43.65]}},
        ],
      },
      onChange: (e) => events.add(e.type),
    ));
    await tool.start('polygon');
    await tool.cancel();
    await tool.delete('p');
    await waitFor(tester, () => events.isNotEmpty);
    expect(events, ['deleted']);
    expect((tool.getAll()['features'] as List), isEmpty);
    await tool.undo();
    await waitFor(tester, () => (tool.getAll()['features'] as List).isNotEmpty);
    expect((tool.getAll()['features'] as List).length, 1);
    await tool.destroy();
    await c.removeLayer('heat');
    await c.setVisible('route', false);
    await tester.pump(const Duration(seconds: 1));
    expect(errors, isEmpty);
  });

  testWidgets('two maps follow each other', (tester) async {
    final a = SMapController(), b = SMapController();
    await tester.pumpWidget(MaterialApp(
      home: Row(children: [
        SizedBox(width: 180, height: 400, child: SMap(controller: a, options: const SMapOptions(center: LatLng(43.65, -79.38), zoom: 11))),
        SizedBox(width: 180, height: 400, child: SMap(controller: b, options: const SMapOptions(center: LatLng(0, 0), zoom: 3))),
      ]),
    ));
    await waitFor(tester, () => a.isReady && b.isReady, seconds: 40);
    a.syncWith(b, offsetZoom: -1);
    await tester.pump(const Duration(seconds: 1));
    await a.moveCamera(target: const LatLng(48.85, 2.35), zoom: 12);
    await waitFor(tester, () => (b.camera.target.latitude - 48.85).abs() < 1e-3);
    expect(b.camera.target.latitude, closeTo(48.85, 1e-3));
    expect(b.camera.zoom, closeTo(11, 0.01));
  });
}
