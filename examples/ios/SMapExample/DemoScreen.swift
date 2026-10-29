import SwiftUI
import CoreLocation
import SMap

/// One screen: colour scheme and language switchers, 2,000 clustered points, a line, an extruded area, a 3D buildings
/// toggle, and map tools (zoom, compass, scale and a legend) shown or hidden from the tools control, the hidden ones
/// kept in the app's own defaults.
///
/// Set `SMAP_TOKEN` (and optionally `SMAP_BASE_URL`) in the scheme's environment variables to use your own access.
struct DemoScreen: View {
    @StateObject private var controller = SMapController()
    @State private var style: SMapStyle = .light
    @State private var language = "en"
    @State private var buildings = false
    @State private var tapped = ""
    @State private var offlineLabel = "Keep offline"

    private static let languages = ["en", "fr", "de", "es", "zh-Hans"]
    private static let toronto = CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832)

    private var options: SMapOptions {
        let env = ProcessInfo.processInfo.environment
        var o = SMapOptions(style: .light, language: "en", center: Self.toronto, zoom: 11)
        if let base = env["SMAP_BASE_URL"].flatMap(URL.init(string:)) { o.baseURL = base }
        if let token = env["SMAP_TOKEN"], !token.isEmpty { o.token = token }
        if let key = env["SMAP_API_KEY"], !key.isEmpty { o.apiKey = key }
        // A start view for checks, e.g. SMAP_VIEW=43.6555,-79.385,17,55 (lat, lng, zoom, tilt).
        if let v = env["SMAP_VIEW"]?.split(separator: ",").compactMap({ Double($0) }), v.count >= 3 {
            o.center = CLLocationCoordinate2D(latitude: v[0], longitude: v[1]); o.zoom = v[2]
            if v.count > 3 { o.pitch = v[3] }
        }
        o.tools = SMapToolsOptions(hidden: Set(UserDefaults.standard.stringArray(forKey: Self.toolsKey) ?? []),
                                   onChange: { UserDefaults.standard.set($0.hidden, forKey: Self.toolsKey) })
        return o
    }

    private static let toolsKey = "smap-example-hidden-tools"

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                SMapSwiftUIView(options: options, controller: controller) { map in
                    map.onError = { error in tapped = "\(error)"; NSLog("sMap example: %@", "\(error)") }
                    if let v = ProcessInfo.processInfo.environment["SMAP_VIEW"]?.split(separator: ",").compactMap({ Double($0) }), v.count > 3 {
                        let camera = map.mapView.camera
                        camera.pitch = v[3]
                        map.mapView.setCamera(camera, animated: false)
                    }
                    addDemoLayers(map)
                    addTools(map)
                }
                .ignoresSafeArea(edges: .top)
                if !tapped.isEmpty {
                    Text(tapped)
                        .font(.footnote)
                        .padding(8)
                        .background(Color(.systemBackground).opacity(0.9))
                        .cornerRadius(6)
                        .padding(12)
                        .padding(.bottom, 24)
                }
            }
            controls
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            Picker("Style", selection: $style) {
                ForEach(SMapStyle.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: style) { controller.map?.setStyle($0) }

            HStack {
                Picker("Language", selection: $language) {
                    ForEach(Self.languages, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .onChange(of: language) { controller.map?.setLanguage($0) }
                Spacer()
                Toggle("3D buildings", isOn: $buildings)
                    .fixedSize()
                    .onChange(of: buildings) { controller.map?.setBuildings3D($0) }
            }
            // Keep downtown Toronto on the device, then switch between it and the map service.
            Button(offlineLabel) { toggleOffline() }
                .buttonStyle(.bordered)
        }
        .padding()
        .disabled(!controller.isReady)
    }

    private func toggleOffline() {
        guard let map = controller.map else { return }
        if map.offlineRegionInUse != nil {
            map.useOnline()
            offlineLabel = "Show offline"
            return
        }
        guard #available(iOS 15.0, *) else { return }
        Task { @MainActor in
            do {
                if map.offline.get("toronto-downtown") == nil {
                    let region = try SMapOfflineRegion(id: "toronto-downtown", west: -79.42, south: 43.63, east: -79.35, north: 43.68,
                                                       maxZoom: 15, style: .scheme(style), language: language)
                    let info = try await map.offline.download(region) { done, total in
                        let percent = Int(done * 100 / max(total, 1))
                        Task { @MainActor in offlineLabel = "Downloading \(percent) %" }
                    }
                    tapped = "Downloaded: \(info.tiles) tiles, \(info.bytes >> 20) MB"
                }
                if map.useOfflineRegion("toronto-downtown") { offlineLabel = "Show online" }
            } catch {
                offlineLabel = "Keep offline"
                tapped = error.localizedDescription
            }
        }
    }

    private func addTools(_ map: SMapView) {
        let legend = UILabel()
        legend.text = "  Green: route · Orange: block  "
        legend.font = .systemFont(ofSize: 12)
        legend.backgroundColor = .white
        legend.layer.cornerRadius = 6
        legend.layer.masksToBounds = true
        do {
            try map.addTool("zoom", kind: .zoom)
            try map.addTool("compass", kind: .compass)
            try map.addTool("scale", kind: .scale)
            try map.addTool("legend", view: legend, label: "Legend", position: .bottomLeft)
            try map.addTool("layers", layers: SMapLayersTool(
                base: [.init(id: "streets", label: "Streets"),
                       .init(id: "satellite", label: "Satellite", imagery: SMapBaseImagery(tiles: ["https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"], maxZoom: 19, attribution: "Tiles © Esri"))],
                overlays: [.init(id: "density", label: "Heat map", layers: ["density"]), .init(id: "grid", label: "Tile grid", layers: ["grid"], visible: false)]))
            _ = map.drawTool(SMapDrawOptions(toolbar: .bottomRight) { e in tapped = "\(e.type): \((e.features["features"] as? [Any])?.count ?? 0) shapes" })
        } catch {
            tapped = error.localizedDescription
        }
    }

    private func addDemoLayers(_ map: SMapView) {
        var generator = SeededGenerator(seed: 42)
        let points = (0..<2000).map { i in
            SMapPoint(lat: Self.toronto.latitude + Double.random(in: -0.12...0.12, using: &generator),
                      lng: Self.toronto.longitude + Double.random(in: -0.2...0.2, using: &generator),
                      properties: ["name": "Stop \(i + 1)", "color": ["#e11d48", "#2563eb", "#16a34a", "#f97316"][i % 4]])
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
            try map.addPolygons("block", [block], options: SMapPolygonOptions(fill: UIColor(smapHex: "#f97316"), extrude: SMapExtrude(height: .property("height"))))
            var line = SMapLineOptions(color: UIColor(smapHex: "#16a34a"), width: 5, zIndex: 1)
            line.label = "name"
            var named = route
            named.properties = ["name": "Route 7"]
            try map.addLines("route", [named], options: line)
            // Clusters as a ring of the routes' colours; a finger resting on a stop shows its name.
            var stops = SMapPointOptions(cluster: SMapCluster(ring: SMapClusterRing(property: "color")), zIndex: 2)
            stops.tooltip = .template("{name}")
            try map.addPoints("stops", points, options: stops)
            try map.addHeatmap("density", data: .points(Array(points.prefix(400))), options: SMapHeatmapOptions(radius: 18, opacity: 0.6))
            try map.setTerrain(SMapTerrain(tiles: ["https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png"], attribution: "Terrain: Mapzen / AWS"))
            try map.addCanvasTiles("grid", opacity: 0.6) { ctx, z, x, y, size in
                ctx.setStrokeColor(UIColor(white: 0.2, alpha: 0.5).cgColor)
                ctx.stroke(CGRect(x: 0, y: 0, width: size, height: size))
                ("\(z)/\(x)/\(y)" as NSString).draw(at: CGPoint(x: 6, y: 4), withAttributes: [.font: UIFont.systemFont(ofSize: 11)])
            }
            // 3D trucks (a sample glTF model of the Khronos glTF samples, CC-BY 4.0 Cesium), turned to their heading.
            try map.addModels("trucks3d", data: .points([SMapPoint(lat: 43.6555, lng: -79.3880, properties: ["id": "t1", "bearing": 0]),
                                                         SMapPoint(lat: 43.6555, lng: -79.3820, properties: ["id": "t2", "bearing": 90])]),
                              options: SMapModelOptions(model: "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/CesiumMilkTruck/glTF-Binary/CesiumMilkTruck.glb",
                                                        size: .constant(40), heading: .property("bearing", default: 0), idProperty: "id"))
            // Three vans as the app's own views: a long press drags one.
            let vans = [("v1", "Van 1", "#e11d48", 43.6532, -79.3832), ("v2", "Van 2", "#2563eb", 43.66, -79.40), ("v3", "Van 3", "#16a34a", 43.645, -79.37)]
                .map { SMapPoint(lat: $0.3, lng: $0.4, properties: ["id": $0.0, "name": $0.1, "color": $0.2]) }
            try map.addCustomMarkers("vans", data: .points(vans), options: SMapCustomMarkerOptions(
                anchor: .bottom, idProperty: "id",
                onTap: { f in tapped = f.properties["name"] as? String ?? "" },
                tooltip: .template("{name}"),
                drag: SMapDragOptions(draggable: .constant(true), onDragEnd: { f, e in tapped = String(format: "%@: %.5f, %.5f", f.properties["name"] as? String ?? "", e.lat, e.lng) })
            ) { p in
                let l = UILabel()
                l.text = "  \(p["name"] as? String ?? "")  "
                l.textColor = .white
                l.font = .systemFont(ofSize: 12)
                l.backgroundColor = UIColor(smapHex: p["color"] as? String ?? "#000000")
                l.layer.cornerRadius = 6
                l.layer.masksToBounds = true
                return l
            })
        } catch {
            tapped = error.localizedDescription
        }
        map.onTap("stops") { properties, coordinate in
            tapped = String(format: "%@ (%.5f, %.5f)", properties["name"] as? String ?? "", coordinate.latitude, coordinate.longitude)
        }
        map.onTap("block") { properties, _ in
            tapped = "Block, \(properties["height"] ?? "") m"
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
