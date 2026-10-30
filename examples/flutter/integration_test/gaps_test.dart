import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smap_flutter/smap_flutter.dart';

/// The map gaps G15–G37 on the native map of the device (Android or iOS): every call goes over the channel to the
/// native SDK and its answers come back. Run with `flutter test integration_test/gaps_test.dart -d <device>`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<SMapController> pumpMap(WidgetTester tester, List<Object> errors, {SMapOptions? options}) async {
    final c = SMapController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          height: 600,
          child: SMap(
            controller: c,
            options: options ?? const SMapOptions(center: LatLng(43.6532, -79.3832), zoom: 11, language: 'en'),
            onError: errors.add,
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

  Future<T> settle<T>(WidgetTester tester, Future<T> f, {int seconds = 40}) async {
    T? out;
    Object? error;
    var done = false;
    final t = Stopwatch()..start();
    f.then((v) {
      out = v;
      done = true;
    }, onError: (Object e) {
      error = e;
      done = true;
    });
    await waitFor(tester, () => done, seconds: seconds);
    debugPrint('settled in ${t.elapsedMilliseconds} ms');
    if (error != null) throw error!;
    if (!done) throw StateError('no answer in $seconds s');
    return out as T;
  }

  testWidgets('G15-G18: fitting, the camera, events, project and unproject', (tester) async {
    final errors = <Object>[];
    final c = await pumpMap(tester, errors);
    expect(c.isReady, isTrue);
    final ends = <SMapEvent>[];
    c.on(SMapEventType.moveEnd, ends.add);
    await tester.pump(const Duration(milliseconds: 300));
    await c.jumpTo(const SMapCameraOptions(center: LatLng(45.5, -73.56), zoom: 9, bearing: 20));
    await waitFor(tester, () => ends.isNotEmpty);
    expect(ends, isNotEmpty, reason: 'moveend came from the native map');
    final center = await settle(tester, c.getCenter());
    expect(center.latitude, closeTo(45.5, 1e-3));
    expect(await settle(tester, c.getZoom()), closeTo(9, 0.01));
    expect(await settle(tester, c.getBearing()), closeTo(20, 0.5));
    final bounds = (await settle(tester, c.getBounds()))!;
    expect(bounds.southwest.latitude, lessThan(45.5));
    expect(bounds.northeast.latitude, greaterThan(45.5));
    final p = (await settle(tester, c.project(const LatLng(45.5, -73.56))))!;
    expect(p.dx, closeTo(180, 2));
    expect(p.dy, closeTo(300, 2));
    final back = (await settle(tester, c.unproject(p)))!;
    expect(back.longitude, closeTo(-73.56, 1e-4));
    await c.fitBounds([-79.6, 43.5, -79.1, 43.9], options: const SMapFitOptions(duration: Duration.zero, bearing: 0));
    await tester.pump(const Duration(seconds: 1));
    final fitted = (await settle(tester, c.getBounds()))!;
    expect(fitted.southwest.longitude, lessThan(-79.55));
    expect(fitted.northeast.longitude, greaterThan(-79.15));
    await c.zoomIn(duration: Duration.zero);
    await c.resize();
    await tester.pump(const Duration(milliseconds: 500));
    expect(errors, isEmpty);
  });

  testWidgets('G19-G24: states, featuresAt, tooltips, moving and changing one feature, headings', (tester) async {
    final errors = <Object>[];
    final c = await pumpMap(tester, errors);
    final taps = <String>[];
    await c.addPoints(
      'stops',
      const [
        SMapPoint(43.6532, -79.3832, properties: {'id': 'a', 'heading': 90}),
        SMapPoint(43.70, -79.30, properties: {'id': 'b', 'heading': 0}),
      ],
      SMapPointOptions(
        idProperty: 'id',
        radius: 14,
        colorValue: SMapValue<String>.of((p) => p['id'] == 'a' ? '#e11d48' : '#2563eb'),
        states: const {'selected': SMapPointLook(color: '#111827', radius: 18)},
        tooltip: SMapTooltip.template('{id}'),
        onDoubleClick: (f, e) {},
      ),
    );
    c.onTap('stops', (p, _) => taps.add('${p['id']}'));
    await c.jumpTo(const SMapCameraOptions(center: LatLng(43.6532, -79.3832), zoom: 13, bearing: 0));
    await tester.pump(const Duration(seconds: 2));
    c.setFeatureState('stops', 'a', {'selected': true});
    expect(c.featureState('stops', 'a'), {'selected': true});
    final at = (await settle(tester, c.project(const LatLng(43.6532, -79.3832))))!;
    var found = <SMapFeatureAt>[];
    await waitFor(tester, () {
      c.featuresAt(at).then((f) => found = f);
      return found.isNotEmpty;
    });
    expect(found.first.layer, 'stops');
    expect(found.first.feature.key, 'a');
    expect(found.first.feature.properties.keys.where((k) => k.startsWith('__smap_')), isEmpty);
    await c.openTooltip('stops', 'a');
    await c.closeTooltip();
    expect(await settle(tester, c.openFeaturePopup('stops', 'a')), isTrue);
    await waitFor(tester, () => taps.isNotEmpty);
    expect(taps, ['a']);
    await c.moveFeature('stops', 'b', const LatLng(43.66, -79.37), duration: const Duration(milliseconds: 800), easing: Curves.easeInOut);
    await c.updateFeature('stops', 'a', {'heading': 180});
    await tester.pump(const Duration(seconds: 2));
    expect(c.toGeoJSON('stops')['features'][1]['geometry']['coordinates'], [-79.37, 43.66]);
    c.removeFeatureState('stops', 'a');
    await c.addCustomMarkers(
      'cars',
      const [SMapPoint(43.65, -79.39, properties: {'id': 'c1', 'heading': 45})],
      SMapCustomMarkerOptions(
        builder: (_) => const SizedBox(width: 24, height: 24, child: ColoredBox(color: Colors.orange)),
        idProperty: 'id',
        rotation: const SMapValue<double>.property('heading'),
      ),
    );
    await c.moveFeature('cars', 'c1', const LatLng(43.655, -79.385), duration: const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));
    expect(c.toGeoJSON('cars')['features'][0]['geometry']['coordinates'], [-79.385, 43.655]);
    await tester.pump(const Duration(milliseconds: 500));
    expect(errors, isEmpty);
  });

  testWidgets('G25-G37: images, glyphs, circles, arrows, labels, heat map, model colour, export, texts, search', (tester) async {
    final errors = <Object>[];
    final c = await pumpMap(tester, errors);
    final png = await settle(tester, c.export());
    expect(png.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47], reason: 'a PNG from the native map');
    await c.addImage('arrow', png, pixelRatio: 2);
    expect(c.hasImage('arrow'), isTrue);
    await c.addGlyphImage('star', const SMapGlyph('★', background: '#2563eb', color: '#ffffff', sdf: false));
    await c.addPoints('icons', const [SMapPoint(43.65, -79.38, properties: {'rank': 2})],
        const SMapPointOptions(icon: 'star', label: 'rank', allowOverlap: true, priority: SMapValue<double>.property('rank')));
    await c.addCircles('zones', const [SMapPoint(43.65, -79.38, properties: {'radius': 500})],
        const SMapCircleOptions(area: SMapPolygonOptions(fill: '#16a34a', hoverState: true, states: {'hover': SMapPolygonLook(fill: '#15803d')})));
    await c.addLines('route', const [SMapLine([LatLng(43.6, -79.4), LatLng(43.7, -79.3)], properties: {'name': 'R'})],
        const SMapLineOptions(arrows: SMapLineArrows(share: 0.15), label: 'name', labelSize: SMapValue<double>.constant(14)));
    await c.addHeatmap('heat', const [SMapPoint(43.65, -79.38)], const SMapHeatmapOptions(blur: 10, minOpacity: 0.3));
    await tester.pump(const Duration(seconds: 2));
    final jpeg = await settle(tester, c.export(options: const SMapExportOptions(format: SMapExportFormat.jpeg, pixelRatio: 1)));
    expect(jpeg.sublist(0, 2), [0xFF, 0xD8], reason: 'a JPEG');
    await c.addCustomMarkers('m', const [SMapPoint(43.65, -79.38)],
        SMapCustomMarkerOptions(builder: (_) => const SizedBox(width: 20, height: 20, child: ColoredBox(color: Colors.red))));
    await tester.pump(const Duration(milliseconds: 500));
    final withMarkers = await settle(tester, c.export(options: const SMapExportOptions(format: SMapExportFormat.jpeg)));
    expect(withMarkers.sublist(0, 2), [0xFF, 0xD8], reason: 'the markers drawn over the picture, then JPEG');
    expect(await settle(tester, c.sdkText('noResults')), 'No results');
    await c.setLanguage('fr');
    expect(await settle(tester, c.sdkText('gestureMobile')), isNot('Use two fingers to move the map'));
    c.addSearchTool('find', SMapSearchOptions(search: (q) async => [const SMapSearchResult('Toronto', position: LatLng(43.65, -79.38))]));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(EditableText), findsOneWidget);
    final tool = c.drawTool(SMapDrawOptions(measure: true, allowSelfIntersection: false, snapLayers: const ['route']));
    await tool.start('line');
    await tool.cancel();
    await tool.destroy();
    expect(SMapGeo.area(SMapGeo.circle([-79.38, 43.65], 100)), closeTo(31416, 400));
    await tester.pump(const Duration(milliseconds: 500));
    expect(errors, isEmpty, reason: '$errors');
    expect(Uint8List.fromList(png).length, greaterThan(1000));
  });

  testWidgets('G32 / G36: a refused map tells why once; cooperative gestures start', (tester) async {
    final errors = <Object>[];
    final c = SMapController();
    final events = <SMapEvent>[];
    await tester.pumpWidget(MaterialApp(
      home: ListView(children: [
        const SizedBox(height: 200),
        SizedBox(
          height: 300,
          child: SMap(
            controller: c,
            onCreated: (m) => m.on(SMapEventType.unavailable, events.add),
            options: const SMapOptions(
              center: LatLng(43.65, -79.38),
              zoom: 11,
              language: 'en',
              token: 'not-a-token',
              cooperativeGestures: true,
              nodes: ['https://tile.srsr.ca'],
            ),
            onError: errors.add,
          ),
        ),
        const SizedBox(height: 800),
      ]),
    ));
    await waitFor(tester, () => events.isNotEmpty, seconds: 40);
    expect(events.length, 1);
    expect(c.unavailable, isNotNull);
    expect(events.single.reason, anyOf(SMapUnavailableReason.forbidden, SMapUnavailableReason.unreachable));
  });
}
