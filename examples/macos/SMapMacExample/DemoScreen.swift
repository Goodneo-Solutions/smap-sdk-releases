import SwiftUI
import AppKit
import CoreLocation
import SMapMac

/// One window: colour scheme and language switchers, 2,000 clustered points, a line, an extruded area and a
/// 3D buildings toggle.
///
/// Set `SMAP_TOKEN` or `SMAP_API_KEY` (and optionally `SMAP_BASE_URL`) in the scheme's environment variables to use
/// your own access.
struct DemoScreen: View {
    @StateObject private var controller = SMapMacController()
    @State private var style: SMapStyle = .light
    @State private var language = "en"
    @State private var buildings = false
    @State private var tapped = ""

    private static let languages = ["en", "fr", "de", "es", "zh-Hans"]
    private static let toronto = CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832)

    private var options: SMapOptions {
        let env = ProcessInfo.processInfo.environment
        var o = SMapOptions(style: .light, language: "en", center: Self.toronto, zoom: 11)
        if let base = env["SMAP_BASE_URL"].flatMap(URL.init(string:)) { o.baseURL = base }
        if let token = env["SMAP_TOKEN"], !token.isEmpty { o.token = token }
        if let key = env["SMAP_API_KEY"], !key.isEmpty { o.apiKey = key }
        return o
    }

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            ZStack(alignment: .bottomLeading) {
                SMapMacSwiftUIView(options: options, controller: controller) { map in
                    addDemoLayers(map)
                }
                if !tapped.isEmpty {
                    Text(tapped)
                        .font(.callout)
                        .padding(8)
                        .background(Color(nsColor: .windowBackgroundColor).opacity(0.9))
                        .cornerRadius(6)
                        .padding(12)
                        .padding(.bottom, 24)
                }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 16) {
            Picker("Style", selection: $style) {
                ForEach(SMapStyle.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 420)
            .onChange(of: style) { controller.map?.setStyle($0) }

            Picker("Language", selection: $language) {
                ForEach(Self.languages, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 180)
            .onChange(of: language) { controller.map?.setLanguage($0) }

            Toggle("3D buildings", isOn: $buildings)
                .onChange(of: buildings) { controller.map?.setBuildings3D($0) }
            Spacer()
        }
        .padding(10)
        .disabled(!controller.isReady)
    }

    private func addDemoLayers(_ map: SMapMacView) {
        var generator = SeededGenerator(seed: 42)
        let points = (0..<2000).map { i in
            SMapPoint(lat: Self.toronto.latitude + Double.random(in: -0.12...0.12, using: &generator),
                      lng: Self.toronto.longitude + Double.random(in: -0.2...0.2, using: &generator),
                      properties: ["name": "Stop \(i + 1)"])
        }
        let route = SMapLine([
            CLLocationCoordinate2D(latitude: 43.6426, longitude: -79.3871),
            CLLocationCoordinate2D(latitude: 43.6515, longitude: -79.3800),
            CLLocationCoordinate2D(latitude: 43.6629, longitude: -79.3957),
            CLLocationCoordinate2D(latitude: 43.6677, longitude: -79.3948),
        ])
        let block = SMapPolygon([
            CLLocationCoordinate2D(latitude: 43.6440, longitude: -79.3800),
            CLLocationCoordinate2D(latitude: 43.6440, longitude: -79.3760),
            CLLocationCoordinate2D(latitude: 43.6465, longitude: -79.3760),
            CLLocationCoordinate2D(latitude: 43.6465, longitude: -79.3800),
        ], properties: ["height": 180])
        do {
            try map.addPolygons("block", [block], options: SMapPolygonOptions(fill: NSColor(smapHex: "#f97316"), extrude: SMapExtrude(height: .property("height"))))
            try map.addLines("route", [route], options: SMapLineOptions(color: NSColor(smapHex: "#16a34a"), width: 5, zIndex: 1))
            try map.addPoints("stops", points, options: SMapPointOptions(cluster: SMapCluster(), zIndex: 2))
        } catch {
            tapped = error.localizedDescription
        }
        map.onTap("stops") { properties, coordinate in
            tapped = String(format: "%@ (%.5f, %.5f)", properties["name"] as? String ?? "", coordinate.latitude, coordinate.longitude)
        }
        map.onTap("block") { properties, _ in
            tapped = "Block, \(properties["height"] ?? "") m"
        }
        map.onError = { error in
            tapped = error.localizedDescription
        }
    }
}

/// A small deterministic generator, so the demo points are the same on every run.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
