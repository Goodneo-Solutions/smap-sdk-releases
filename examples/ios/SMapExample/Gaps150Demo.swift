import SwiftUI
import UIKit
import CoreLocation
import SMap
import MapLibre

// MARK: - 1.5.0 (G25–G37)

extension DemoScreen {
    /// The drawing tool of the demo, for the checks.
    @MainActor static var drawTool: SMapDrawTool?

    /// The app's image named `arrow` (the collision case: the basemap's sprite has an `arrow` too) beside the sprite's
    /// own `aerodrome`, depots in an SDF drop coloured per depot with labels by priority, a glyph image, circles in metres
    /// with a hover look, and an address search over a few places.
    func addGaps150(_ map: SMapView) {
        map.addImage("arrow", Self.arrow())
        map.addImage("drop", Self.drop(), options: SMapImageOptions(sdf: true))
        map.addGlyphImage("glyph-h", SMapGlyph(text: "H", font: .boldSystemFont(ofSize: 15), color: "#ffffff", background: "#dc2626"))
        var appArrow = SMapPointOptions(icon: "arrow", zIndex: 4)
        appArrow.iconAnchor = .center
        var sprite = SMapPointOptions(icon: "aerodrome", zIndex: 4)
        sprite.iconAnchor = .center
        var depots = SMapPointOptions(icon: "drop", label: "name", zIndex: 4)
        depots.idProperty = "id"
        depots.iconColor = .property("color", default: "#111827")
        depots.priority = .property("rank", default: 0)
        depots.allowOverlap = false
        depots.labelSize = .property("size", default: 12)
        var reach = SMapPolygonOptions(fill: UIColor(smapHex: "#7c3aed"), opacity: 0.18)
        reach.idProperty = "id"
        reach.hoverState = true
        reach.states = ["hover": SMapPolygonLook(opacity: 0.4)]
        reach.outlineDash = .constant([2, 2])
        reach.tooltip = .template("{name}: {radius} m")
        do {
            try map.addPoints("app-arrow", [SMapPoint(lat: Self.appArrowAt.latitude, lng: Self.appArrowAt.longitude, properties: ["name": "The app's arrow"])], options: appArrow)
            try map.addPoints("sprite-icon", [SMapPoint(lat: 43.6455, lng: -79.3890, properties: ["name": "The sprite's aerodrome"])], options: sprite)
            try map.addPoints("depots", [SMapPoint(lat: Self.depotAt.latitude, lng: Self.depotAt.longitude, properties: ["id": "d1", "name": "North depot", "color": "#16a34a", "rank": 3, "size": 14]),
                                         SMapPoint(lat: 43.6426, lng: -79.3899, properties: ["id": "d2", "name": "Small depot", "color": "#f97316", "rank": 1]),
                                         SMapPoint(lat: 43.6425, lng: -79.3870, properties: ["id": "d3", "name": "East depot", "color": "#2563eb", "rank": 2])], options: depots)
            var glyph = SMapPointOptions(icon: "glyph-h", zIndex: 4)
            glyph.iconAnchor = .center
            try map.addPoints("hospital", [SMapPoint(lat: Self.glyphAt.latitude, lng: Self.glyphAt.longitude)], options: glyph)
            try map.addCircles("reach", data: .points([SMapPoint(lat: Self.circleAt.latitude, lng: Self.circleAt.longitude, properties: ["id": "r1", "name": "Depot reach", "radius": 150]),
                                                       SMapPoint(lat: 43.6418, lng: -79.3845, properties: ["id": "r2", "name": "Small reach", "radius": 90])]),
                               options: SMapCircleOptions(area: reach))
            let places = [("CN Tower", 43.6426, -79.3871), ("Union Station", 43.6453, -79.3806), ("Casa Loma", 43.6780, -79.4094), ("Toronto Island", 43.6205, -79.3780)]
            try map.addTool("search", search: SMapSearchOptions(search: { q in
                places.filter { $0.0.lowercased().contains(q.lowercased()) }.map { SMapSearchResult(label: $0.0, position: CLLocationCoordinate2D(latitude: $0.1, longitude: $0.2)) }
            }, onPick: { r in smapCheck("search pick \(r.label)") }), position: .topLeft)
        } catch {
            smapCheck("gaps150 error \(error)")
        }
        map.on(.unavailable) { e in
            smapCheck("unavailable reason=\(e.reason?.rawValue ?? "") error=\(e.error.map { "\($0)" } ?? "") notice=\(Self.texts(map).first { $0.contains("map") } ?? "none")")
        }
    }

    static let appArrowAt = CLLocationCoordinate2D(latitude: 43.6455, longitude: -79.3905)
    static let glyphAt = CLLocationCoordinate2D(latitude: 43.6455, longitude: -79.3875)
    static let depotAt = CLLocationCoordinate2D(latitude: 43.6424, longitude: -79.3912)
    static let circleAt = CLLocationCoordinate2D(latitude: 43.6440, longitude: -79.3840)

    /// The labels shown over the map (the unavailable notice, the gesture hint, the measure label).
    static func texts(_ map: SMapView) -> [String] {
        var out: [String] = []
        func walk(_ v: UIView) {
            if let l = v as? UILabel, !l.isHidden, l.alpha > 0, let t = l.text, !t.isEmpty { out.append(t) }
            v.subviews.forEach(walk)
        }
        walk(map)
        return out
    }

    /// The checks of G25–G37 the simulator run reads from the log (prefix SMapCheck).
    func check150(_ map: SMapView) {
        // After the checks of G15–G24 (the last at 4.2 s): a view of the G25–G37 features.
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            map.jumpTo(SMapCameraOptions(center: CLLocationCoordinate2D(latitude: 43.6440, longitude: -79.3880), zoom: 15, bearing: 0, pitch: 0))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 9) {
            Task { @MainActor in
                let style = map.mapView.style
                smapCheck(String(format: "camera150 center=%.4f,%.4f zoom=%.2f size=%.0fx%.0f", map.centerCoordinate.latitude, map.centerCoordinate.longitude, map.zoom, map.bounds.width, map.bounds.height))
                smapCheck("images arrow=\(map.hasImage("arrow")) engine=\(style?.image(forName: SMapImages.engineId("arrow")) != nil) sprite arrow=\(style?.image(forName: "arrow") != nil)")
                for id in ["app-arrow", "sprite-icon", "depots", "hospital"] {
                    let layer = style?.layer(withIdentifier: "smap-\(id)-points") as? MLNSymbolStyleLayer
                    let drawn = !map.mapView.visibleFeatures(in: map.mapView.bounds, styleLayerIdentifiers: ["smap-\(id)-points"]).isEmpty
                    smapCheck("icon \(id) image=\(layer?.iconImageName.description ?? "none") drawn=\(drawn)")
                }
                smapCheck("depots iconColor=\((style?.layer(withIdentifier: "smap-depots-points") as? MLNSymbolStyleLayer)?.iconColor.description ?? "none")")
                smapCheck("depot labels=\(map.mapView.visibleFeatures(in: map.mapView.bounds, styleLayerIdentifiers: ["smap-depots-labels"]).compactMap { $0.attributes["name"] as? String })")
                smapCheck("route arrows layer=\(style?.layer(withIdentifier: "smap-route-arrows") != nil) drawn=\(map.mapView.visibleFeatures(in: map.mapView.bounds, styleLayerIdentifiers: ["smap-route-arrows"]).count) image sdf=\(style?.image(forName: "smap-arrowhead")?.renderingMode == .alwaysTemplate)")
                smapCheck("circles drawn=\(!map.mapView.visibleFeatures(in: map.mapView.bounds, styleLayerIdentifiers: ["smap-reach-fill"]).isEmpty) features=\((try? map.toGeoJSON("reach")["features"] as? [Any])??.count ?? 0)")
                if let c = map.project(Self.circleAt) {
                    smapCheck("circle featuresAt=\(map.featuresAt(c, layers: ["reach"]).map { "\($0.layer):\($0.feature.key)" })")
                }
                await exportCheck(map)
                drawCheck(map)
                searchCheck(map)
                let pans = (map.mapView.gestureRecognizers ?? []).compactMap { $0 as? UIPanGestureRecognizer }.filter { type(of: $0) == UIPanGestureRecognizer.self }
                smapCheck("pans minTouches=\(pans.map(\.minimumNumberOfTouches)) unavailable=\(map.unavailable?.rawValue ?? "none")")
            }
        }
    }

    /// The exported picture: its size, the app's purple arrow where it is drawn (never the sprite's grey one), the red
    /// glyph disc, the legend in its corner, the PNG and JPEG data.
    @MainActor
    func exportCheck(_ map: SMapView) async {
        do {
            let image = try await map.export(options: SMapExportOptions(pixelRatio: 1, include: [SMapExportView(Self.legend(), corner: .topLeft)]))
            func px(_ c: CLLocationCoordinate2D, dy: CGFloat = 0) -> String {
                guard let p = map.project(c) else { return "none" }
                return Self.rgba(image, Int(p.x), Int(p.y + dy))
            }
            smapCheck("export size=\(Int(image.size.width))x\(Int(image.size.height)) scale=\(image.scale)")
            // The app's arrow is purple (#7c3aed), the glyph's disc red (#dc2626), the north depot's drop green (#16a34a, its
            // centre 19 points above its tip), the circle's middle tinted purple.
            smapCheck("export app arrow px=\(px(Self.appArrowAt, dy: 6)) glyph px=\(px(Self.glyphAt, dy: -5)) depot px=\(px(Self.depotAt, dy: -19)) circle px=\(px(Self.circleAt)) legend px=\(Self.rgba(image, 14, 14))")
            smapCheck("export background px=\(Self.rgba(image, Int(image.size.width) / 2, Int(image.size.height) - 60))")
            let png = try await map.exportData()
            let jpeg = try await map.exportData(options: SMapExportOptions(format: .jpeg, quality: 0.8))
            smapCheck("export png=\(png.count) bytes \(png.prefix(4).map { String(format: "%02x", $0) }.joined()) jpeg=\(jpeg.count) bytes \(jpeg.prefix(2).map { String(format: "%02x", $0) }.joined())")
            if let j = UIImage(data: jpeg, scale: map.window?.screen.scale ?? 3), let p = map.project(Self.glyphAt) {
                smapCheck("export jpeg \(j.cgImage?.width ?? 0)x\(j.cgImage?.height ?? 0) alpha=\(j.cgImage?.alphaInfo.rawValue ?? 99) glyph px=\(Self.rgba(j, Int(p.x), Int(p.y - 5)))")
            }
            if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                try? png.write(to: dir.appendingPathComponent("export.png"))
                try? jpeg.write(to: dir.appendingPathComponent("export.jpg"))
                smapCheck("export written \(dir.appendingPathComponent("export.png").path)")
            }
        } catch {
            smapCheck("export error \(error)")
        }
    }

    /// The drawing tool without touches: a shape set and selected shows its figures; a style per shape.
    @MainActor
    func drawCheck(_ map: SMapView) {
        guard let tool = Self.drawTool else { return }
        tool.set(["type": "FeatureCollection", "features": [
            ["type": "Feature", "id": "plan", "properties": ["kind": "planned"], "geometry": ["type": "Polygon", "coordinates": [[[-79.402, 43.638], [-79.396, 43.638], [-79.396, 43.641], [-79.402, 43.641], [-79.402, 43.638]]]]],
        ]])
        tool.select("plan")
        smapCheck("draw measure=\(Self.texts(map).first { $0.contains("km²") || $0.contains("m²") } ?? "none") dashed layer=\(map.mapView.style?.layers.contains { $0.identifier.hasSuffix("-line-dash0") } ?? false)")
        tool.setProperties("plan", ["kind": "built"])
        smapCheck("draw setProperties kind=\(((tool.get("plan")?["properties"] as? [String: Any])?["kind"] as? String) ?? "")")
        tool.undo()
        smapCheck("draw undo kind=\(((tool.get("plan")?["properties"] as? [String: Any])?["kind"] as? String) ?? "")")
    }

    /// The search tool driven as a person would: text typed, the list read, a row tapped.
    @MainActor
    func searchCheck(_ map: SMapView) {
        func find<T: UIView>(_ v: UIView, _ type: T.Type) -> [T] { ((v as? T).map { [$0] } ?? []) + v.subviews.flatMap { find($0, type) } }
        guard let field = find(map, UITextField.self).first else { smapCheck("search field none"); return }
        smapCheck("search placeholder=\(field.placeholder ?? "")")
        field.text = "station"
        field.sendActions(for: .editingChanged)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let rows = find(map, UIButton.self).filter { $0.title(for: .normal) == "Union Station" }
            smapCheck("search rows=\(rows.count)")
            rows.first?.sendActions(for: .touchUpInside)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                smapCheck(String(format: "search camera=%.4f,%.4f zoom=%.1f field=%@", map.centerCoordinate.latitude, map.centerCoordinate.longitude, map.zoom, field.text ?? ""))
            }
        }
    }

    static func rgba(_ image: UIImage, _ x: Int, _ y: Int) -> String {
        guard let cg = image.cgImage else { return "none" }
        let s = Int(image.scale)
        var out = [UInt8](repeating: 0, count: 4)
        guard let ctx = CGContext(data: &out, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return "none" }
        ctx.draw(cg, in: CGRect(x: -x * s, y: y * s - cg.height + 1, width: cg.width, height: cg.height))
        return String(format: "#%02x%02x%02x/%d", out[0], out[1], out[2], out[3])
    }

    static func legend() -> UIView {
        let l = UILabel(frame: CGRect(x: 0, y: 0, width: 150, height: 22))
        l.text = "  Toronto · sMap demo"
        l.font = .systemFont(ofSize: 12)
        l.textColor = .white
        l.backgroundColor = UIColor(smapHex: "#0f766e")
        return l
    }

    /// A drop drawn in black: an SDF image (G25), coloured per depot by iconColor.
    static func drop() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 22, height: 30)).image { ctx in
            let path = UIBezierPath(arcCenter: CGPoint(x: 11, y: 11), radius: 9, startAngle: .pi * 0.8, endAngle: .pi * 0.2, clockwise: true)
            path.addLine(to: CGPoint(x: 11, y: 28))
            path.close()
            ctx.cgContext.setShadow(offset: .zero, blur: 2, color: UIColor.black.cgColor)
            UIColor.black.setFill()
            path.fill()
        }
    }
}

/// A small map in a scrolling screen (G36): one finger scrolls the screen, two move the map, with a hint.
struct SmallMapScreen: View {
    @Environment(\.dismiss) private var dismiss

    private var options: SMapOptions {
        var o = SMapOptions(style: .light, language: "fr", center: CLLocationCoordinate2D(latitude: 43.6532, longitude: -79.3832), zoom: 12)
        if let token = ProcessInfo.processInfo.environment["SMAP_TOKEN"], !token.isEmpty { o.token = token }
        o.cooperativeGestures = true
        return o
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Button("Close") { dismiss() }
                Text("A delivery address").font(.title2)
                ForEach(0..<6) { i in Text("Line \(i + 1) of the page around the map.").foregroundColor(.secondary) }
                SMapSwiftUIView(options: options, controller: SMapController()) { map in
                    Task { @MainActor in
                        await map.ready()
                        let pans = (map.mapView.gestureRecognizers ?? []).compactMap { $0 as? UIPanGestureRecognizer }.filter { type(of: $0) == UIPanGestureRecognizer.self }
                        smapCheck("small map pans minTouches=\(pans.map(\.minimumNumberOfTouches))")
                    }
                }
                .frame(height: 220)
                .cornerRadius(10)
                ForEach(0..<12) { i in Text("More of the page, line \(i + 1).").foregroundColor(.secondary) }
            }
            .padding()
        }
    }
}
