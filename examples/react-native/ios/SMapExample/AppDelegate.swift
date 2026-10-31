import UIKit
#if DEBUG
import Network
import UIKit.UIGestureRecognizerSubclass
#endif

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    #if DEBUG
    SMapTapsDriver.start()
    #endif
    return true
  }
}

#if DEBUG
/// The tap driver of the self-check's 1.5.5 checks (debug builds only), at http://localhost:8766 (POST JSON
/// `{"op", ...}`). The simulator takes no touches from the app's own code, so the map view is handed its tap as its
/// own tap recognizer reports one (`handleTap:`), and a row of the native chooser is chosen as a touch on it does (the
/// table's `didSelectRowAt`). Points are window points.
enum SMapTapsDriver {
  static let port: NWEndpoint.Port = 8766
  private static var listener: NWListener?

  static func start() {
    guard listener == nil, let l = try? NWListener(using: .tcp, on: port) else { return }
    l.newConnectionHandler = { c in
      c.start(queue: .main)
      receive(c, Data())
    }
    l.start(queue: .main)
    listener = l
  }

  private static func receive(_ c: NWConnection, _ buffer: Data) {
    c.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, done, error in
      var all = buffer
      if let data = data { all.append(data) }
      if let request = complete(all) {
        handle(request) { answer in
          let body = (try? JSONSerialization.data(withJSONObject: answer)) ?? Data("{}".utf8)
          var head = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
          c.send(content: Data(head.utf8) + body, completion: .contentProcessed { _ in c.cancel() })
        }
      } else if done || error != nil {
        c.cancel()
      } else {
        receive(c, all)
      }
    }
  }

  /// The JSON body of a complete request, or nil while more is to come.
  private static func complete(_ data: Data) -> [String: Any]? {
    guard let end = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
    let head = String(decoding: data[..<end.lowerBound], as: UTF8.self).lowercased()
    var length = 0
    for line in head.split(separator: "\r\n") where line.hasPrefix("content-length:") {
      length = Int(line.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)) ?? 0
    }
    let body = data[end.upperBound...]
    guard body.count >= length else { return nil }
    return (try? JSONSerialization.jsonObject(with: Data(body.prefix(length)))) as? [String: Any] ?? [:]
  }

  private static func handle(_ args: [String: Any], _ result: @escaping ([String: Any]) -> Void) {
    switch args["op"] as? String {
    case "tap":
      let p = CGPoint(x: (args["x"] as? NSNumber)?.doubleValue ?? 0, y: (args["y"] as? NSNumber)?.doubleValue ?? 0)
      guard let window = window(), let map = find(window, "SMapView") else { return result(["ok": false]) }
      map.perform(NSSelectorFromString("handleTap:"), with: DriverTap(p, in: window))
      result(["ok": true])
    case "rows":
      result(["ok": true, "rows": chooser().map(rows) ?? []])
    case let op? where op == "choose" || op == "dismiss":
      let text = args["text"] as? String ?? ""
      let also = args["also"] as? String
      waitForRow(text, tries: 40) { list in
        guard let list = list else { return result(["ok": false, "rows": chooser().map(rows) ?? []]) }
        let all = rows(list)
        if let also = also, !all.contains(also) { return result(["ok": false, "rows": all]) }
        if op == "choose", let row = all.firstIndex(of: text) {
          list.tableView.delegate?.tableView?(list.tableView, didSelectRowAt: IndexPath(row: row, section: 0))
        } else if let pc = list.presentationController {
          list.dismiss(animated: false) { pc.delegate?.presentationControllerDidDismiss?(pc) }
        }
        result(["ok": true, "rows": all])
      }
    default:
      result(["ok": false, "error": "unknown op"])
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
#endif
