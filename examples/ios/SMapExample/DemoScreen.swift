import SwiftUI
import CoreLocation
import SMap

/// One screen: colour scheme and language switchers, 2,000 clustered points, a line, an extruded area, a 3D buildings
/// toggle, and map tools (zoom, compass, scale and a legend) shown or hidden from the tools control, the hidden ones
/// kept in the app's own defaults. 1.5.0: zones with hover and selected looks (tap, double tap and long press), lines
/// whose width and dash differ per line, two arrows moved every second towards their heading, and a Fit button. G25–G37:
/// an app image named `arrow` (the basemap's sprite has one too) beside the sprite's `aerodrome`, depots in an SDF drop
/// coloured per depot with labels by priority, a glyph image, circles in metres with a hover look, arrows every 15 % of
/// the route, a heat map with blur and minimum opacity, trucks tinted per driver, the drawing tool measuring, refusing
/// self-crossing shapes and snapping to the zones and lanes, an address search over a few places, an Export button
/// showing the picture, and a small map with cooperative gestures in a scrolling screen.
///
/// Set `SMAP_TOKEN` (and optionally `SMAP_BASE_URL`) in the scheme's environment variables to use your own access. The
/// checks of the 1.5.0 calls are logged with the prefix `SMapCheck` (and posted to `SMAP_LOG_URL` when it is set).
struct DemoScreen: View {
    @StateObject private var controller = SMapController()
    @State private var style: SMapStyle = .light
    @State private var language = "en"
    @State private var buildings = false
    @State private var tapped = ""
    @State private var offlineLabel = "Keep offline"
    @State private var exported: UIImage?
    @State private var showExport = false
    @State private var showSmallMap = false

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
                    addGaps(map)
                    addGaps150(map)
                    addTools(map)
                    Task { @MainActor in await map.ready(); check(map); check150(map) }
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
            HStack {
                Button(offlineLabel) { toggleOffline() }
                    .buttonStyle(.bordered)
                // Fit the view to the zones, the lanes and the route together (G15).
                Button("Fit") { controller.map?.fitLayer(["route", "zones", "lanes"], options: SMapFitOptions(maxZoom: 16)) }
                    .buttonStyle(.bordered)
                // The map as a picture with a legend in its corner (G29).
                Button("Export") {
                    guard let map = controller.map else { return }
                    Task { @MainActor in
                        exported = try? await map.export(options: SMapExportOptions(include: [SMapExportView(Self.legend(), corner: .topLeft)]))
                        showExport = exported != nil
                    }
                }
                .buttonStyle(.bordered)
                Button("Small map") { showSmallMap = true }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .disabled(!controller.isReady)
        .sheet(isPresented: $showExport) {
            VStack {
                if let image = exported { Image(uiImage: image).resizable().scaledToFit() }
                Button("Close") { showExport = false }.padding()
            }
        }
        .sheet(isPresented: $showSmallMap) { SmallMapScreen() }
        // SMAP_SMALL_MAP=1 opens the small map at start (the simulator run checks it).
        .onAppear { if ProcessInfo.processInfo.environment["SMAP_SMALL_MAP"] == "1" { DispatchQueue.main.asyncAfter(deadline: .now() + 16) { showSmallMap = true } } }
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
            // The drawing tool measures, refuses self-crossing shapes and snaps to the zones and lanes (G28).
            var draw = SMapDrawOptions(toolbar: .bottomRight) { e in tapped = "\(e.type): \((e.features["features"] as? [Any])?.count ?? 0) shapes" }
            draw.measure = .on
            draw.allowSelfIntersection = false
            draw.snapLayers = ["zones", "lanes"]
            draw.style = { props, _ in (props["kind"] as? String) == "planned" ? SMapDrawStyle(color: "#7c3aed", dash: [2, 1]) : nil }
            draw.onDrawing = { e in smapCheck(String(format: "drawing %@ valid=%@ length=%.0f area=%.0f", e.mode, e.valid ? "true" : "false", e.length, e.area)) }
            Self.drawTool = map.drawTool(draw)
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
            // Arrowheads at 15, 30, … 90 % of the route at every zoom (G34).
            line.arrows = SMapLineArrows(share: 0.15, size: 16)
            var named = route
            named.properties = ["name": "Route 7"]
            try map.addLines("route", [named], options: line)
            // Clusters as a ring of the routes' colours; a finger resting on a stop shows its name.
            var stops = SMapPointOptions(cluster: SMapCluster(ring: SMapClusterRing(property: "color")), zIndex: 2)
            stops.tooltip = .template("{name}")
            try map.addPoints("stops", points, options: stops)
            // A soft edge and faint spots still showing (G33).
            var heat = SMapHeatmapOptions(radius: 18, opacity: 0.6)
            heat.blur = 8
            heat.minOpacity = 0.25
            try map.addHeatmap("density", data: .points(Array(points.prefix(400))), options: heat)
            try map.setTerrain(SMapTerrain(tiles: ["https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png"], attribution: "Terrain: Mapzen / AWS"))
            try map.addCanvasTiles("grid", opacity: 0.6) { ctx, z, x, y, size in
                ctx.setStrokeColor(UIColor(white: 0.2, alpha: 0.5).cgColor)
                ctx.stroke(CGRect(x: 0, y: 0, width: size, height: size))
                ("\(z)/\(x)/\(y)" as NSString).draw(at: CGPoint(x: 6, y: 4), withAttributes: [.font: UIFont.systemFont(ofSize: 11)])
            }
            // 3D trucks (a sample glTF model of the Khronos glTF samples, CC-BY 4.0 Cesium), turned to their heading.
            // Each truck tinted in its driver's colour (G30): the model has no tint* material, so every material is.
            var trucks = SMapModelOptions(model: "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/CesiumMilkTruck/glTF-Binary/CesiumMilkTruck.glb",
                                          size: .constant(40), heading: .property("bearing", default: 0), idProperty: "id")
            trucks.color = .property("color", default: nil)
            try map.addModels("trucks3d", data: .points([SMapPoint(lat: 43.6555, lng: -79.3880, properties: ["id": "t1", "bearing": 0, "color": "#ef4444"]),
                                                         SMapPoint(lat: 43.6555, lng: -79.3820, properties: ["id": "t2", "bearing": 90])]),
                              options: trucks)
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

// MARK: - 1.5.0 (G15–G24)

/// Logs a check of the 1.5.0 calls (prefix SMapCheck), and posts it to SMAP_LOG_URL when that is set.
func smapCheck(_ text: String) {
    NSLog("SMapCheck %@", text)
    guard let url = ProcessInfo.processInfo.environment["SMAP_LOG_URL"].flatMap(URL.init(string:)) else { return }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = Data(text.utf8)
    URLSession.shared.dataTask(with: request).resume()
}

extension DemoScreen {
    /// Zones with hover and selected looks and a dashed outline per zone (a tap selects one, a double tap and a long
    /// press name it), lines whose width and dash differ per line, a fleet of two arrows moved every second towards
    /// their heading, and pins with an image each.
    func addGaps(_ map: SMapView) {
        func square(_ lat: Double, _ lng: Double, _ d: Double) -> [CLLocationCoordinate2D] {
            [.init(latitude: lat, longitude: lng), .init(latitude: lat, longitude: lng + d), .init(latitude: lat + d, longitude: lng + d), .init(latitude: lat + d, longitude: lng)]
        }
        var zones = SMapPolygonOptions(opacity: 0.25)
        zones.idProperty = "code"
        zones.fillValue = .property("color", default: "#64748b")
        zones.outlineDash = .computed { ($0["open"] as? Bool) == true ? nil : [2, 2] }
        zones.states = ["hover": SMapPolygonLook(opacity: 0.45), "selected": SMapPolygonLook(outline: "#111827", outlineWidth: 3)]
        zones.hoverState = true
        zones.tooltip = .template("Zone {code}")
        zones.onDoubleClick = { f, _ in tapped = "Double tap \(f.key)"; smapCheck("dblclick \(f.key)") }
        zones.onContextMenu = { f, _ in tapped = "Long press \(f.key)"; smapCheck("contextmenu \(f.key)") }
        var lanes = SMapLineOptions(color: UIColor(smapHex: "#334155"))
        lanes.widthValue = .property("w", default: 4)
        lanes.dashValue = .property("dash", default: nil)
        lanes.sortProperty = "rank"
        lanes.states = ["selected": SMapLineLook(color: "#dc2626")]
        var fleet = SMapPointOptions(icon: "truck-arrow", zIndex: 3)
        fleet.iconAnchor = .center
        fleet.idProperty = "id"
        fleet.rotation = .property("course", default: 0)
        fleet.tooltip = .template("{name}")
        var pins = SMapPointOptions(zIndex: 3)
        pins.iconProperty = "image"
        pins.idProperty = "id"
        do {
            try map.addPolygons("zones", [SMapPolygon(square(43.670, -79.420, 0.012), properties: ["code": "Z1", "color": "#0ea5e9", "open": true]),
                                          SMapPolygon(square(43.670, -79.405, 0.012), properties: ["code": "Z2", "color": "#f59e0b", "open": false])], options: zones)
            try map.addLines("lanes", [SMapLine([.init(latitude: 43.660, longitude: -79.430), .init(latitude: 43.660, longitude: -79.390)], properties: ["w": 3, "dash": [2, 1], "rank": 1]),
                                       SMapLine([.init(latitude: 43.664, longitude: -79.430), .init(latitude: 43.664, longitude: -79.390)], properties: ["w": 7, "rank": 2])], options: lanes)
            map.registerImage(Self.arrow(), name: "truck-arrow")
            map.registerImage(Self.pin("#e11d48"), name: "pin-red")
            map.registerImage(Self.pin("#2563eb"), name: "pin-blue")
            try map.addPoints("fleet", [SMapPoint(lat: 43.655, lng: -79.410, properties: ["id": "a", "course": 45, "name": "Truck A"]),
                                        SMapPoint(lat: 43.652, lng: -79.400, properties: ["id": "b", "course": 180, "name": "Truck B"])], options: fleet)
            try map.addPoints("pins", [SMapPoint(lat: 43.6475, lng: -79.415, properties: ["id": "p1", "image": "pin-red"]),
                                       SMapPoint(lat: 43.6475, lng: -79.405, properties: ["id": "p2", "image": "pin-blue"])], options: pins)
        } catch {
            tapped = error.localizedDescription
        }
        map.onTap("zones") { p, _ in
            let code = "\(p["code"] ?? "")"
            let on = (try? map.featureState("zones", code)["selected"] as? Bool) != true
            try? map.removeFeatureState("zones", nil, "selected")
            if on { try? map.setFeatureState("zones", code, ["selected": true]) }
            tapped = "Zone \(code)\(on ? " selected" : "")"
            smapCheck("tap \(code) selected=\(on)")
        }
        // Every second each truck goes 150 m on along its heading, eased over the second.
        var course = ["a": 45.0, "b": 180.0]
        var at = ["a": CLLocationCoordinate2D(latitude: 43.655, longitude: -79.410), "b": CLLocationCoordinate2D(latitude: 43.652, longitude: -79.400)]
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak map] _ in
            MainActor.assumeIsolated {
                guard let map = map else { return }
                for id in ["a", "b"] {
                    let c = (course[id]! + Double.random(in: -20...20)).truncatingRemainder(dividingBy: 360)
                    course[id] = c
                    let p = at[id]!
                    let next = CLLocationCoordinate2D(latitude: p.latitude + 0.00135 * cos(c * .pi / 180),
                                                      longitude: p.longitude + 0.00135 * sin(c * .pi / 180) / cos(p.latitude * .pi / 180))
                    at[id] = next
                    try? map.updateFeature("fleet", id, ["course": c])
                    try? map.moveFeature("fleet", id, to: next, duration: 1)
                }
            }
        }
        map.on(.moveEnd) { e in smapCheck(String(format: "moveend zoom=%.2f", e.zoom ?? 0)) }
        map.on(.zoomEnd) { e in smapCheck(String(format: "zoomend zoom=%.2f", e.zoom ?? 0)) }
        map.on(.click) { e in
            let hits = e.point.map { map.featuresAt($0) } ?? []
            smapCheck("click at \(e.position.map { String(format: "%.5f,%.5f", $0.latitude, $0.longitude) } ?? "") features=\(hits.map { "\($0.layer):\($0.feature.key)" })")
        }
        map.on(.doubleClick) { e in smapCheck("map dblclick prevented=\(e.defaultPrevented)") }
        map.on(.contextMenu) { e in smapCheck("map contextmenu at \(e.point.map { "\(Int($0.x)),\(Int($0.y))" } ?? "")") }
        map.on(.mouseMove) { e in smapCheck("mousemove \(e.point.map { "\(Int($0.x)),\(Int($0.y))" } ?? "")") }
    }

    /// The checks the simulator run reads from the log (prefix SMapCheck).
    func check(_ map: SMapView) {
        map.fitLayer(["zones", "lanes", "fleet", "pins"], options: SMapFitOptions(maxZoom: 14, duration: 0))
        smapCheck(String(format: "fit center=%.5f,%.5f zoom=%.2f bearing=%.1f pitch=%.1f", map.centerCoordinate.latitude, map.centerCoordinate.longitude, map.zoom, map.bearing, map.pitch))
        if let b = map.visibleBounds { smapCheck(String(format: "bounds sw=%.4f,%.4f ne=%.4f,%.4f", b.sw.latitude, b.sw.longitude, b.ne.latitude, b.ne.longitude)) }
        try? map.setFeatureState("zones", "Z2", ["selected": true])
        smapCheck("state Z2=\((try? map.featureState("zones", "Z2")) ?? [:])")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard let p = map.project(CLLocationCoordinate2D(latitude: 43.676, longitude: -79.399)) else { return }
            let back = map.unproject(p)
            smapCheck(String(format: "project=%.1f,%.1f unproject=%.5f,%.5f", p.x, p.y, back?.latitude ?? 0, back?.longitude ?? 0))
            smapCheck("featuresAt Z2=\(map.featuresAt(p).map { "\($0.layer):\($0.feature.key):\($0.feature.properties["code"] ?? "")" })")
            for (name, lat, lng) in [("Z1", 43.676, -79.414), ("Z2", 43.676, -79.399), ("pin p1", 43.6475, -79.415), ("map", 43.640, -79.360)] {
                if let q = map.project(CLLocationCoordinate2D(latitude: lat, longitude: lng)) {
                    let w = map.window.map { map.convert(q, to: $0) } ?? q
                    smapCheck(String(format: "screen point for %@ x=%.0f y=%.0f", name, w.x, w.y))
                }
            }
            for id in ["p1", "p2"] {
                guard let q = map.project(id == "p1" ? CLLocationCoordinate2D(latitude: 43.6475, longitude: -79.415) : CLLocationCoordinate2D(latitude: 43.6475, longitude: -79.405)) else { continue }
                smapCheck("pins \(id) drawn=\(!map.mapView.visibleFeatures(in: CGRect(x: q.x - 12, y: q.y - 30, width: 24, height: 32), styleLayerIdentifiers: ["smap-pins-points"]).isEmpty) featuresAt=\(map.featuresAt(CGPoint(x: q.x, y: q.y - 12)).map { "\($0.layer):\($0.feature.key)" })")
            }
            smapCheck("fleet drawn=\(!map.mapView.visibleFeatures(in: map.mapView.bounds, styleLayerIdentifiers: ["smap-fleet-points", "smap-fleet-moving-points"]).isEmpty)")
            try? map.openTooltip("zones", "Z1")
            let tip = map.mapView.subviews.flatMap(\.subviews).compactMap { $0 as? UILabel }.first { !$0.isHidden && ($0.text ?? "").hasPrefix("Zone") }
            smapCheck("tooltip=\(tip?.text ?? "hidden")")
            smapCheck("popup=\((try? map.openFeaturePopup("zones", "Z1")) ?? false)")
        }
        // A moving truck is found where it is drawn now.
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.2) {
            guard let fc = try? map.toGeoJSON("fleet"), let a = (fc["features"] as? [[String: Any]])?.first(where: { ($0["properties"] as? [String: Any])?["id"] as? String == "a" }),
                  let c = (a["geometry"] as? [String: Any])?["coordinates"] as? [Double], let p = map.project(CLLocationCoordinate2D(latitude: c[1], longitude: c[0])) else { return }
            smapCheck("truck a at \(Int(p.x)),\(Int(p.y)) featuresAt=\(map.featuresAt(p).map { "\($0.layer):\($0.feature.key)" }) moving=\(map.mapView.style?.source(withIdentifier: "smap-fleet-moving") != nil)")
        }
    }

    static func arrow() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 28, height: 28)).image { _ in
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 14, y: 0)); path.addLine(to: CGPoint(x: 28, y: 28)); path.addLine(to: CGPoint(x: 14, y: 19.6)); path.addLine(to: CGPoint(x: 0, y: 28))
            path.close()
            UIColor(smapHex: "#7c3aed").setFill()
            path.fill()
        }
    }

    static func pin(_ color: String) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 24, height: 32)).image { _ in
            let path = UIBezierPath(arcCenter: CGPoint(x: 12, y: 12), radius: 11, startAngle: .pi * 0.8, endAngle: .pi * 0.2, clockwise: true)
            path.addLine(to: CGPoint(x: 12, y: 32))
            path.close()
            UIColor(smapHex: color).setFill()
            path.fill()
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(x: 7, y: 7, width: 10, height: 10)).fill()
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
