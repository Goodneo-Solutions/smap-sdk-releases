import Flutter
import UIKit
import UIKit.UIGestureRecognizerSubclass

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // The tap driver of the integration tests, in debug builds only (unoptimised: the Runner defines no DEBUG flag).
    if _isDebugAssertConfiguration(), let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SMapTapsDriver") {
      SMapTapsDriver.register(registrar.messenger())
    }
  }
}

/// The tap driver of `integration_test/taps_test.dart` (registered in debug builds only). The simulator takes no touches from a
/// test, so the map view is handed its tap as its own tap recognizer reports one (`handleTap:`), and a row of the
/// native chooser is chosen as a touch on it does (the table's `didSelectRowAt`).
enum SMapTapsDriver {
  static func register(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "smap_example/taps_driver", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "tap":
        let p = CGPoint(x: (args["x"] as? NSNumber)?.doubleValue ?? 0, y: (args["y"] as? NSNumber)?.doubleValue ?? 0)
        guard let window = window(), let map = find(window, "SMapView") else { return result(["ok": false]) }
        map.perform(NSSelectorFromString("handleTap:"), with: DriverTap(p, in: window))
        result(["ok": true])
      case "rows":
        result(["ok": true, "rows": chooser().map(rows) ?? []])
      case "choose", "dismiss":
        let text = args["text"] as? String ?? ""
        let also = args["also"] as? String
        waitForRow(text, tries: 40) { list in
          guard let list = list else { return result(["ok": false, "rows": chooser().map(rows) ?? []]) }
          let all = rows(list)
          if let also = also, !all.contains(also) { return result(["ok": false, "rows": all]) }
          if call.method == "choose", let row = all.firstIndex(of: text) {
            list.tableView.delegate?.tableView?(list.tableView, didSelectRowAt: IndexPath(row: row, section: 0))
          } else if let pc = list.presentationController {
            list.dismiss(animated: false) { pc.delegate?.presentationControllerDidDismiss?(pc) }
          }
          result(["ok": true, "rows": all])
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  static func window() -> UIWindow? {
    let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }
    return windows.first { $0.isKeyWindow } ?? windows.first
  }

  static func find(_ view: UIView, _ name: String) -> UIView? {
    if String(describing: type(of: view)) == name { return view }
    for sub in view.subviews { if let v = find(sub, name) { return v } }
    return nil
  }

  /// The table of the presented chooser, if one is shown.
  static func chooser() -> UITableViewController? {
    var top = window()?.rootViewController
    while let next = top?.presentedViewController {
      if let list = next as? UITableViewController, !next.isBeingDismissed { return list }
      top = next
    }
    return nil
  }

  static func rows(_ list: UITableViewController) -> [String] {
    let tv = list.tableView!
    let n = list.tableView(tv, numberOfRowsInSection: 0)
    // The rows on screen (a chooser shows up to six and a half).
    return (0..<n).compactMap { tv.cellForRow(at: IndexPath(row: $0, section: 0))?.textLabel?.text }
  }

  static func waitForRow(_ text: String, tries: Int, _ done: @escaping (UITableViewController?) -> Void) {
    if let list = chooser(), rows(list).contains(text) { return done(list) }
    if tries <= 0 { return done(nil) }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { waitForRow(text, tries: tries - 1, done) }
  }
}

/// A finished tap at a point of the window.
final class DriverTap: UITapGestureRecognizer {
  private let point: CGPoint
  private weak var window: UIWindow?

  init(_ point: CGPoint, in window: UIWindow) {
    self.point = point
    self.window = window
    super.init(target: nil, action: nil)
  }

  override var state: UIGestureRecognizer.State {
    get { .ended }
    set {}
  }

  override func location(in view: UIView?) -> CGPoint {
    guard let view = view, let window = window else { return point }
    return window.convert(point, to: view)
  }
}
