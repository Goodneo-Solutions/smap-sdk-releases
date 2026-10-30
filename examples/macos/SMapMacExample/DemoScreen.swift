import SwiftUI
import AppKit
import CoreLocation
import SMapMac

/// One window: colour scheme and language switchers, 2,000 clustered points, a line, an extruded area and a
/// 3D buildings toggle; and the 1.5.0 calls (G15–G37): a fitted view, vans with a hover look, a selected van and a
/// double click, a van moving every second with its heading (an app image named `arrow`), SDF icons in colours per
/// feature, a glyph, circles in metres, arrows by share, labels with priority, a heat map with blur, measuring with
/// snapping, the search tool over the app's own places and an export button.
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
            Button("Fit") { controller.map?.fitLayer(["vans", "zones"], options: SMapFitOptions(padding: SMapPadding(60))) }
            Button("Export") { exportPicture() }
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
        addGapDemos(map)
    }

    // MARK: 1.5.0 (G15–G37)

    private static let vans: [String: Any] = ["type": "FeatureCollection", "features": [
        ["type": "Feature", "properties": ["id": "van-1", "name": "Van 1", "status": "late", "rank": 2], "geometry": ["type": "Point", "coordinates": [-79.395, 43.655]]],
        ["type": "Feature", "properties": ["id": "van-2", "name": "Van 2", "status": "on time", "rank": 1], "geometry": ["type": "Point", "coordinates": [-79.37, 43.648]]],
        ["type": "Feature", "properties": ["id": "van-3", "name": "Van 3", "status": "on time", "rank": 3], "geometry": ["type": "Point", "coordinates": [-79.36, 43.664]]],
    ]]

    private func addGapDemos(_ map: SMapMacView) {
        // The app's own image named `arrow`, the name the basemap's sprite also has: the map draws the app's (G25).
        let arrow = NSImage(size: NSSize(width: 24, height: 24), flipped: true) { r in
            let path = NSBezierPath()
            path.move(to: NSPoint(x: r.midX, y: 2)); path.line(to: NSPoint(x: r.maxX - 4, y: r.maxY - 3))
            path.line(to: NSPoint(x: r.midX, y: r.maxY - 8)); path.line(to: NSPoint(x: 4, y: r.maxY - 3)); path.close()
            NSColor.black.setFill(); path.fill()
            return true
        }
        map.addImage("arrow", arrow, options: SMapImageOptions(sdf: true))
        map.addGlyphImage("depot", SMapGlyph(text: "D", font: .boldSystemFont(ofSize: 14), color: "#ffffff", background: "#7c3aed"))
        do {
            // Vans: SDF arrows in a colour per status, a heading, a hover look, a selected look and a double click (G19–G25).
            var vans = SMapPointOptions(icon: "arrow", label: "name")
            vans.idProperty = "id"
            vans.iconColor = .computed { ($0["status"] as? String) == "late" ? "#dc2626" : "#16a34a" }
            vans.rotation = .property("heading", default: 0)
            vans.states = ["hover": SMapPointLook(iconColor: "#2563eb"), "selected": SMapPointLook(iconColor: "#111827")]
            vans.hoverState = true
            vans.priority = .property("rank", default: 0)
            vans.allowOverlap = true
            vans.onDoubleClick = { f, _ in
                try? map.removeFeatureState("vans", nil, "selected")
                try? map.setFeatureState("vans", f.key, ["selected": true])
                tapped = "\(f.properties["name"] ?? "") selected"
            }
            vans.onContextMenu = { f, _ in tapped = "Right click on \(f.properties["name"] ?? "")" }
            vans.zIndex = 4
            try map.addPoints("vans", data: .geoJSONObject(Self.vans), options: vans)
            try map.addPoints("depot", [SMapPoint(lat: 43.64, lng: -79.40)], options: SMapPointOptions(icon: "depot", zIndex: 4))

            // Circles of 400 m with a hover look (G26), arrows at every 15 % of the route (G34), a heat map with blur (G33).
            var zones = SMapCircleOptions(radius: .constant(400))
            zones.area.idProperty = "id"
            zones.area.states = ["hover": SMapPolygonLook(opacity: 0.45)]
            zones.area.hoverState = true
            zones.area.fill = NSColor(smapHex: "#0891b2")
            try map.addCircles("zones", data: .geoJSONObject(Self.vans), options: zones)
            var arrows = SMapLineOptions(color: NSColor(smapHex: "#16a34a"), width: 5, zIndex: 1)
            arrows.arrows = SMapLineArrows(share: 0.15)
            try map.addLines("route", [SMapLine([CLLocationCoordinate2D(latitude: 43.6426, longitude: -79.3871),
                                                 CLLocationCoordinate2D(latitude: 43.6515, longitude: -79.3800),
                                                 CLLocationCoordinate2D(latitude: 43.6629, longitude: -79.3957),
                                                 CLLocationCoordinate2D(latitude: 43.6677, longitude: -79.3948)])], options: arrows)
            var heat = SMapHeatmapOptions(radius: 18)
            heat.blur = 12
            heat.minOpacity = 0.3
            try map.addHeatmap("heat", data: .geoJSONObject(Self.vans), options: heat)

            // The search tool over the app's own places (G35).
            let places: [(String, CLLocationCoordinate2D)] = [("Union Station", .init(latitude: 43.6453, longitude: -79.3806)),
                                                               ("City Hall", .init(latitude: 43.6534, longitude: -79.3841)),
                                                               ("Distillery District", .init(latitude: 43.6503, longitude: -79.3596))]
            try map.addTool("search", search: SMapSearchOptions(search: { text in
                places.filter { $0.0.localizedCaseInsensitiveContains(text) }.map { SMapSearchResult(label: $0.0, position: $0.1) }
            }, onPick: { tapped = "Found \($0.label)" }, minChars: 2))
        } catch {
            tapped = error.localizedDescription
        }
        // Measuring with snapping to the vans (G28).
        var draw = SMapDrawOptions(toolbar: .bottomLeft)
        draw.measure = .on
        draw.snapLayers = ["vans"]
        draw.allowSelfIntersection = false
        _ = map.drawTool(draw)

        map.on(.unavailable) { e in tapped = "The map is unavailable: \(e.reason?.rawValue ?? "")" }
        map.fitLayer(["vans", "zones"], options: SMapFitOptions(padding: SMapPadding(60)))

        // Van 1 drives every second, turned the way it goes (G23, G24).
        var heading = 0.0
        var at = CLLocationCoordinate2D(latitude: 43.655, longitude: -79.395)
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak map] _ in
            MainActor.assumeIsolated {
                guard let map = map else { return }
                heading = (heading + 20).truncatingRemainder(dividingBy: 360)
                at = CLLocationCoordinate2D(latitude: at.latitude + 0.0006 * cos(heading * .pi / 180), longitude: at.longitude + 0.0008 * sin(heading * .pi / 180))
                try? map.updateFeature("vans", "van-1", ["heading": heading])
                try? map.moveFeature("vans", "van-1", to: at, duration: 0.9)
            }
        }
    }

    /// The map's picture in a dialog (G29).
    private func exportPicture() {
        guard let map = controller.map else { return }
        Task { @MainActor in
            do {
                let image = try await map.export()
                let alert = NSAlert()
                alert.messageText = "The map as a picture"
                let view = NSImageView(image: image)
                view.frame = NSRect(x: 0, y: 0, width: 480, height: 480 * image.size.height / max(1, image.size.width))
                alert.accessoryView = view
                alert.runModal()
            } catch {
                tapped = error.localizedDescription
            }
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
