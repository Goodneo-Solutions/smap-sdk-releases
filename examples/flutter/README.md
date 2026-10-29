# smap_flutter example

One screen: colour scheme and language switchers, 2,000 clustered points, a line, an extruded area and a 3D
buildings switch.

```sh
flutter run --dart-define=SMAP_TOKEN=sm1.… [--dart-define=SMAP_BASE_URL=https://tile.srsr.ca]
```

`lib/plan_drag_demo.dart` is a test page for the plan editor's long-press drag on a device: two routes, the plan
calls answered on the device (no plan credentials needed). Long-press a stop, drag it onto a stop of the other
route and let go; the page lists the calls and changes, and prints them with the prefix `PLANDEMO`.

```sh
flutter run -t lib/plan_drag_demo.dart [--dart-define=SMAP_TOKEN=sm1.…]
```
