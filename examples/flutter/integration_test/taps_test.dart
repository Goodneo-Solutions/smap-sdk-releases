import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:smap_flutter/smap_flutter.dart';

/// 1.5.5 on the native map of the device: a tap beside a point answers that point and not its neighbour, two piled
/// points open the native chooser and the chosen row reaches the Dart tap handler, a layer with overlap off answers
/// its top point, and `tapTolerance` reaches the native map.
///
/// The taps come from outside the Flutter test, since the native chooser is not a Flutter widget:
/// - Android (emulator): real touches through adb and the chooser's rows found with uiautomator, by
///   `tools/android_taps_driver.py` on the computer (`--dart-define=SMAP_TAPS_DRIVER=http://10.0.2.2:8765`).
/// - iOS (simulator): the example app's debug driver channel (`ios/Runner/AppDelegate.swift`), which hands the map
///   view a tap at a point and chooses a row of the presented chooser as a touch on it does.
/// Without a driver (Android with no SMAP_TAPS_DRIVER) the tests are skipped.
const _driverUrl = String.fromEnvironment('SMAP_TAPS_DRIVER');

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Real touches from adb reach the app (and through it the platform view).
  binding.shouldPropagateDevicePointerEvents = true;
  final hasDriver = Platform.isIOS || _driverUrl.isNotEmpty;

  Future<void> waitFor(WidgetTester tester, bool Function() done, {int seconds = 20}) async {
    final end = DateTime.now().add(Duration(seconds: seconds));
    while (!done() && DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<T> settle<T>(WidgetTester tester, Future<T> f, {int seconds = 40}) async {
    T? out;
    Object? error;
    var done = false;
    f.then((v) {
      out = v;
      done = true;
    }, onError: (Object e) {
      error = e;
      done = true;
    });
    await waitFor(tester, () => done, seconds: seconds);
    if (error != null) throw error!;
    if (!done) throw StateError('no answer in $seconds s');
    return out as T;
  }

  Future<Map<String, dynamic>> drive(WidgetTester tester, String op, [Map<String, Object?> args = const {}]) {
    Future<Map<String, dynamic>> run() async {
      if (Platform.isIOS) {
        final r = await const MethodChannel('smap_example/taps_driver').invokeMethod<Object?>(op, args);
        return Map<String, dynamic>.from((r as Map?) ?? const {});
      }
      final client = HttpClient();
      try {
        final req = await client.postUrl(Uri.parse(_driverUrl));
        final body = utf8.encode(jsonEncode({'op': op, ...args}));
        req.headers.contentType = ContentType.json;
        req.contentLength = body.length;
        req.add(body);
        final res = await req.close();
        return jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, dynamic>;
      } finally {
        client.close();
      }
    }

    return settle(tester, run());
  }

  late Offset origin;
  late Offset middle;

  Future<SMapController> pumpMap(WidgetTester tester, {double tapTolerance = defaultTapTolerance}) async {
    final c = SMapController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            height: 600,
            child: SMap(
              // A new native map for every test (its options are read when it is created).
              key: UniqueKey(),
              controller: c,
              options: SMapOptions(
                center: const LatLng(43.6532, -79.3832),
                zoom: 14,
                language: 'en',
                tapTolerance: tapTolerance,
              ),
            ),
          ),
        ),
      ),
    ));
    await waitFor(tester, () => c.isReady, seconds: 40);
    expect(c.isReady, isTrue);
    origin = tester.getTopLeft(find.byType(SMap));
    middle = const Offset(180, 300);
    return c;
  }

  // A point dx, dy logical pixels from the map's middle.
  Future<SMapPoint> at(WidgetTester tester, SMapController c, double dx, double dy, String name) async {
    final p = (await settle(tester, c.unproject(middle + Offset(dx, dy))))!;
    return SMapPoint(p.latitude, p.longitude, properties: {'name': name});
  }

  // A tap dx, dy logical pixels from the map's middle.
  Future<void> tap(WidgetTester tester, double dx, double dy) async {
    final g = origin + middle + Offset(dx, dy);
    final k = Platform.isIOS ? 1.0 : tester.view.devicePixelRatio;
    await drive(tester, 'tap', {'x': g.dx * k, 'y': g.dy * k});
  }

  // Until [count] taps were answered (the map answers a tap after the double-tap time), then a while longer.
  Future<void> answered(WidgetTester tester, List<String> taps, int count) async {
    await waitFor(tester, () => taps.length >= count, seconds: 8);
    await tester.pump(const Duration(milliseconds: 1500));
  }

  Future<void> drawn(WidgetTester tester, SMapController c, List<Offset> points) async {
    final end = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(end)) {
      var all = true;
      for (final p in points) {
        if ((await settle(tester, c.featuresAt(middle + p))).isEmpty) {
          all = false;
          break;
        }
      }
      if (all) return;
      await tester.pump(const Duration(milliseconds: 300));
    }
    fail('the layers were not drawn');
  }

  testWidgets('1.5.5: precise taps, the native chooser of piled points, overlap off', (tester) async {
    final c = await pumpMap(tester);
    final taps = <String>[];
    // Two circles 30 px apart (centres), radius 10 + stroke 1.5: 7 px of empty map between them.
    await c.addPoints('near', [await at(tester, c, -60, -150, 'A'), await at(tester, c, -30, -150, 'B')],
        SMapPointOptions(radius: 10, color: '#2563eb'));
    c.onTap('near', (p, _) => taps.add('near:${p['name']}'));
    // Two circles on one spot; the rows are named by the Dart label function.
    await c.addPoints('pile', [await at(tester, c, 0, 0, 'First'), await at(tester, c, 0, 0, 'Second')],
        SMapPointOptions(color: '#16a34a', overlap: SMapOverlap(label: (f) => 'Row ${f.properties['name']}')));
    c.onTap('pile', (p, _) => taps.add('pile:${p['name']}:${p.containsKey('__smap_overlapLabel')}'));
    // Two circles on one spot of a layer that does not pile: the top one (drawn last) answers.
    await c.addPoints('off', [await at(tester, c, 0, 150, 'Low'), await at(tester, c, 0, 150, 'High')],
        const SMapPointOptions(color: '#e11d48', overlap: SMapOverlap(enabled: false)));
    c.onTap('off', (p, _) => taps.add('off:${p['name']}'));
    await drawn(tester, c, const [Offset(-60, -150), Offset(-30, -150), Offset(0, 0), Offset(0, 150)]);
    final before = c.camera;

    // 1.5 px beside A's edge, 5.5 px beside B's: A. Then the other way round: B.
    await tap(tester, -60 + 13, -150);
    await answered(tester, taps, 1);
    expect(taps, ['near:A']);
    taps.clear();
    await tap(tester, -60 + 17, -150);
    await answered(tester, taps, 1);
    expect(taps, ['near:B']);
    taps.clear();
    // 14 px above both: nothing.
    await tap(tester, -45, -150 - 25);
    await answered(tester, taps, 0);
    expect(taps, isEmpty);

    // The pile: the chooser opens with both rows, nothing answers until a row is chosen.
    await tap(tester, 0, 0);
    final chosen = await drive(tester, 'choose', {'text': 'Row Second', 'also': 'Row First'});
    expect(chosen['ok'], isTrue, reason: 'the native chooser listed "Row Second" and "Row First": $chosen');
    await answered(tester, taps, 1);
    expect(taps, ['pile:Second:false'], reason: 'the chosen row reached the Dart handler, hidden properties stripped');
    taps.clear();
    // Dismissed: nothing.
    await tap(tester, 0, 0);
    final dismissed = await drive(tester, 'dismiss', {'text': 'Row First'});
    expect(dismissed['ok'], isTrue);
    await answered(tester, taps, 0);
    expect(taps, isEmpty);

    // Overlap off: the top point answers directly, no chooser.
    await tap(tester, 0, 150);
    await answered(tester, taps, 1);
    expect(taps, ['off:High']);
    final rows = await drive(tester, 'rows');
    expect((rows['rows'] as List).where((r) => r == 'Low' || r == 'High' || r == '1' || r == '2'), isEmpty);

    // The camera never moved.
    expect(c.camera.target.latitude, closeTo(before.target.latitude, 1e-9));
    expect(c.camera.target.longitude, closeTo(before.target.longitude, 1e-9));
    expect(c.camera.zoom, closeTo(before.zoom, 1e-9));
  }, skip: !hasDriver);

  testWidgets('1.5.5: tapTolerance reaches the native map', (tester) async {
    final c = await pumpMap(tester, tapTolerance: 24);
    final taps = <String>[];
    // Radius 6 + stroke 1.5.
    await c.addPoints('one', [await at(tester, c, 0, 0, 'P')], const SMapPointOptions(radius: 6, color: '#2563eb'));
    c.onTap('one', (p, _) => taps.add('one:${p['name']}'));
    await drawn(tester, c, const [Offset.zero]);
    // 18 px beside the edge: within 24, not within the default 6.
    await tap(tester, 7.5 + 18, 0);
    await answered(tester, taps, 1);
    expect(taps, ['one:P']);
    taps.clear();
    // 30 px beside the edge: nothing.
    await tap(tester, 7.5 + 30, 0);
    await answered(tester, taps, 0);
    expect(taps, isEmpty);
  }, skip: !hasDriver);
}
