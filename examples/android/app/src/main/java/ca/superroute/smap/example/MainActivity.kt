package ca.superroute.smap.example

import android.app.Activity
import android.graphics.Color
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.widget.AdapterView
import android.widget.Button
import android.widget.ArrayAdapter
import android.widget.LinearLayout
import android.widget.Spinner
import android.widget.Switch
import android.widget.TextView
import android.widget.Toast
import ca.superroute.smap.SMap
import ca.superroute.smap.SMapAnchor
import ca.superroute.smap.SMapCluster
import ca.superroute.smap.SMapClusterRing
import ca.superroute.smap.SMapCustomMarkerOptions
import ca.superroute.smap.SMapDragOptions
import ca.superroute.smap.SMapFeatureValue
import ca.superroute.smap.SMapHeatmapOptions
import ca.superroute.smap.SMapTooltip
import ca.superroute.smap.SMapDrawOptions
import ca.superroute.smap.SMapModelOptions
import ca.superroute.smap.SMapTerrain
import ca.superroute.smap.SMapBaseImagery
import ca.superroute.smap.SMapLayersBase
import ca.superroute.smap.SMapLayersOverlay
import ca.superroute.smap.SMapLayersTool
import ca.superroute.smap.SMapExtrude
import ca.superroute.smap.SMapFlavor
import ca.superroute.smap.SMapLine
import ca.superroute.smap.SMapLineOptions
import ca.superroute.smap.SMapOfflineRegion
import ca.superroute.smap.SMapOptions
import ca.superroute.smap.SMapPoint
import ca.superroute.smap.SMapPointOptions
import ca.superroute.smap.SMapPolygon
import ca.superroute.smap.SMapPolygonOptions
import ca.superroute.smap.SMapToolKind
import ca.superroute.smap.SMapToolPosition
import ca.superroute.smap.SMapToolsOptions
import ca.superroute.smap.SMapValue
import ca.superroute.smap.SMapEventType
import ca.superroute.smap.SMapFitOptions
import ca.superroute.smap.SMapLineLook
import ca.superroute.smap.SMapPolygonLook
import ca.superroute.smap.SMapRotationAlignment
import ca.superroute.smap.SMapCircleOptions
import ca.superroute.smap.SMapExportOptions
import ca.superroute.smap.SMapExportView
import ca.superroute.smap.SMapGlyph
import ca.superroute.smap.SMapImageOptions
import ca.superroute.smap.SMapLineArrows
import ca.superroute.smap.SMapPointLook
import ca.superroute.smap.SMapSearchOptions
import ca.superroute.smap.SMapSearchResult
import ca.superroute.smap.SMapGeo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import org.maplibre.android.geometry.LatLng
import kotlin.random.Random

/**
 * One screen: colour scheme, language, 2,000 clustered points, a line, an extruded area, 3D buildings, and map tools
 * (zoom, compass, scale and a legend) shown or hidden from the tools control, the hidden ones kept in the app's own
 * preferences.
 */
private val ROUTE_COLORS = listOf("#e11d48", "#2563eb", "#16a34a", "#f97316")
private const val CHECK = "SMapCheck"

class MainActivity : Activity() {
    private lateinit var map: SMap
    private var legend: View? = null
    private var draw: ca.superroute.smap.SMapDrawTool? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    /** The offline example: downtown Toronto to street level, in the scheme and language shown. */
    private fun downtown() = SMapOfflineRegion("toronto-downtown", -79.42, 43.63, -79.35, 43.68, maxZoom = 15, style = map.styleName, language = map.language)

    private val languages = listOf("en", "fr", "de", "es", "zh-Hans", "zh-Hant", "ja")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val token = BuildConfig.SMAP_TOKEN.ifEmpty { null }
        map = SMap(
            this,
            SMapOptions(
                token = token,
                baseUrl = BuildConfig.SMAP_BASE_URL.ifEmpty { SMapOptions.DEFAULT_BASE_URL },
                apiKey = BuildConfig.SMAP_API_KEY.ifEmpty { null },
                style = SMapFlavor.LIGHT,
                center = LatLng(43.6532, -79.3832),
                zoom = 11.0,
                onError = { e -> runOnUiThread { Toast.makeText(this, e.message, Toast.LENGTH_SHORT).show() } },
                tools = SMapToolsOptions(hidden = savedTools(), onChange = { change -> saveTools(change.hidden) }),
            ),
        )
        map.onCreate(savedInstanceState)

        // The bar above the map, so the map's top corners (where the tools sit) stay in view.
        val root = LinearLayout(this)
        root.orientation = LinearLayout.VERTICAL
        root.addView(controls(), LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))
        root.addView(map, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))
        setContentView(root)

        addLayers()
        addGaps()
        addGaps150()
        addTools()
        map.ready { Toast.makeText(this, "Map ready", Toast.LENGTH_SHORT).show(); check() }
    }

    private fun controls(): View {
        val bar = LinearLayout(this)
        bar.orientation = LinearLayout.HORIZONTAL
        bar.setBackgroundColor(Color.argb(220, 255, 255, 255))
        val pad = (8 * resources.displayMetrics.density).toInt()
        bar.setPadding(pad, pad * 4, pad, pad)

        val flavors = Spinner(this)
        flavors.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, SMapFlavor.entries.map { it.id })
        flavors.onItemSelectedListener = selected { position ->
            val flavor = SMapFlavor.entries[position]
            if (flavor != map.flavor) map.setStyle(flavor)
        }
        bar.addView(flavors)

        val langs = Spinner(this)
        langs.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, languages)
        langs.onItemSelectedListener = selected { position ->
            if (languages[position] != map.language) map.setLanguage(languages[position])
        }
        bar.addView(langs)

        @Suppress("DEPRECATION")
        val buildings = Switch(this)
        buildings.text = getString(R.string.buildings_3d)
        buildings.setOnCheckedChangeListener { _, on -> map.setBuildings3D(on) }
        bar.addView(buildings)

        // Select the stops and vans inside a box drawn on the map.
        val select = Button(this)
        select.text = "Select"
        select.setOnClickListener {
            map.selectArea(layers = listOf("stops", "vans")) { r ->
                val n = r?.features?.values?.sumOf { it.size } ?: return@selectArea
                Toast.makeText(this, "$n selected", Toast.LENGTH_SHORT).show()
            }
        }
        bar.addView(select)

        // Keep the downtown area on the device, then switch between it and the map service.
        val offline = Button(this)
        offline.text = getString(R.string.offline_download)
        offline.setOnClickListener {
            if (map.offlineRegionInUse != null) {
                map.useOnline()
                offline.text = getString(R.string.offline_show)
                return@setOnClickListener
            }
            scope.launch {
                try {
                    if (map.offline.get("toronto-downtown") == null) {
                        var shown = -1
                        val info = map.offline.download(downtown()) { done, total ->
                            val percent = (done * 100 / total.coerceAtLeast(1)).toInt()
                            if (percent / 10 != shown / 10) {
                                shown = percent
                                runOnUiThread { offline.text = getString(R.string.offline_progress, percent) }
                            }
                        }
                        Toast.makeText(this@MainActivity, getString(R.string.offline_ready, info.tiles.toInt(), (info.bytes shr 20).toInt()), Toast.LENGTH_LONG).show()
                    }
                    if (map.useOfflineRegion("toronto-downtown")) offline.text = getString(R.string.offline_online)
                } catch (e: Exception) {
                    offline.text = getString(R.string.offline_download)
                    Toast.makeText(this@MainActivity, e.message, Toast.LENGTH_LONG).show()
                }
            }
        }
        bar.addView(offline)

        // Fit the view to the route, the zones and the block together (G15).
        val fit = Button(this)
        fit.text = "Fit"
        fit.setOnClickListener { map.fitLayer(listOf("route", "zones", "block"), SMapFitOptions(maxZoom = 16.0)) }
        bar.addView(fit)

        // The map as a picture with the legend in its corner (G29), shown in a dialog.
        val export = Button(this)
        export.text = "Export"
        export.setOnClickListener {
            scope.launch {
                try {
                    val picture = map.export(SMapExportOptions(include = listOfNotNull(legend?.let { SMapExportView(it, SMapToolPosition.TOP_RIGHT) })))
                    val bytes = map.exportBytes(SMapExportOptions(format = ca.superroute.smap.SMapExportFormat.JPEG, quality = 0.8f))
                    Log.i(CHECK, "export ${picture.width}x${picture.height} jpeg=${bytes.size} bytes")
                    val image = android.widget.ImageView(this@MainActivity).apply { setImageBitmap(picture); adjustViewBounds = true }
                    android.app.AlertDialog.Builder(this@MainActivity).setView(image).setPositiveButton("OK", null).show()
                } catch (e: Exception) {
                    Toast.makeText(this@MainActivity, e.message, Toast.LENGTH_LONG).show()
                }
            }
        }
        bar.addView(export)

        // A small map in a screen that scrolls (G36).
        val small = Button(this)
        small.text = "Small map"
        small.setOnClickListener { startActivity(android.content.Intent(this, SmallMapActivity::class.java)) }
        bar.addView(small)
        return bar
    }

    private fun selected(block: (Int) -> Unit) = object : AdapterView.OnItemSelectedListener {
        override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) = block(position)
        override fun onNothingSelected(parent: AdapterView<*>?) = Unit
    }

    private fun addTools() {
        map.addTool("zoom", SMapToolKind.ZOOM)
        map.addTool("compass", SMapToolKind.COMPASS)
        map.addTool("scale", SMapToolKind.SCALE)
        val pad = (8 * resources.displayMetrics.density).toInt()
        val legend = TextView(this).apply {
            text = getString(R.string.legend)
            setBackgroundColor(Color.WHITE)
            setPadding(pad, pad / 2, pad, pad / 2)
        }
        this.legend = legend
        map.addTool("legend", legend, getString(R.string.legend_label), SMapToolPosition.BOTTOM_LEFT)
        // Drawing zones (toolbar bottom right); the result is shown as a message.
        // Measuring while drawing, no self-crossing, snapping to the zones and lanes, dashed exclusions (G28).
        draw = map.drawTool(SMapDrawOptions(toolbar = SMapToolPosition.BOTTOM_RIGHT, onChange = { e ->
            Toast.makeText(this, "${e.type}: ${e.features.getAsJsonArray("features").size()} shapes", Toast.LENGTH_SHORT).show()
        }, measure = true, allowSelfIntersection = false, snapLayers = listOf("zones", "lanes"),
            style = { p, _ -> if (p["kind"] == "exclusion") ca.superroute.smap.SMapDrawStyle(color = "#dc2626", dash = listOf(2f, 2f), fillOpacity = 0.1f) else null },
            onDrawing = { e -> Log.i(CHECK, "drawing ${e.mode} length=%.0f area=%.0f valid=${e.valid}".format(e.length, e.area)) }))
        // The address search over the app's own places (G35).
        val places = listOf("Union Station" to LatLng(43.6453, -79.3806), "Queen's Park" to LatLng(43.6629, -79.3957), "Queens Quay" to LatLng(43.6397, -79.3800), "Kensington Market" to LatLng(43.6547, -79.4005))
        map.addTool("find", SMapSearchOptions(
            search = { text -> kotlinx.coroutines.delay(150); places.filter { it.first.contains(text, ignoreCase = true) }.map { SMapSearchResult(it.first, position = it.second) } },
            onPick = { r -> Log.i(CHECK, "search picked ${r.label}") },
        ), position = SMapToolPosition.TOP_RIGHT)
        map.addTool("layers", SMapLayersTool(
            base = listOf(
                SMapLayersBase("streets", "Streets"),
                SMapLayersBase("satellite", "Satellite", imagery = SMapBaseImagery(listOf("https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"), maxZoom = 19f, attribution = "Tiles © Esri")),
            ),
            overlays = listOf(SMapLayersOverlay("density", "Heat map", listOf("density")), SMapLayersOverlay("grid", "Tile grid", listOf("grid"), visible = false)),
        ))

        // The stops layer as a tool: its toggle hides and shows the points.
        map.addTool("stops", "stops", getString(R.string.stops_label))
    }

    private fun savedTools(): Set<String> =
        getSharedPreferences("smap-example", MODE_PRIVATE).getStringSet("hidden-tools", emptySet()) ?: emptySet()

    private fun saveTools(hidden: List<String>) {
        getSharedPreferences("smap-example", MODE_PRIVATE).edit().putStringSet("hidden-tools", hidden.toSet()).apply()
    }

    private fun addLayers() {
        val random = Random(7)
        val points = (1..2000).map { i ->
            SMapPoint(
                lat = 43.65 + random.nextDouble(-0.25, 0.25),
                lng = -79.38 + random.nextDouble(-0.4, 0.4),
                properties = mapOf("name" to "Stop $i", "color" to ROUTE_COLORS[i % ROUTE_COLORS.size]),
            )
        }
        // Clusters drawn as a ring of the routes' colours; a finger resting on a stop shows its name.
        map.addPoints("stops", points, SMapPointOptions(
            cluster = SMapCluster(ring = SMapClusterRing("color")), label = "name", zIndex = 2,
            tooltip = SMapTooltip.template("{name}"),
        ))
        map.onTap("stops") { properties, _ ->
            Toast.makeText(this, properties["name"].toString(), Toast.LENGTH_SHORT).show()
        }

        map.addLines(
            "route",
            listOf(SMapLine(listOf(LatLng(43.6426, -79.3871), LatLng(43.6532, -79.3832), LatLng(43.6677, -79.3948), LatLng(43.6890, -79.3940)), mapOf("name" to "Route 7"))),
            SMapLineOptions(color = "#f97316", width = 5f, zIndex = 1, label = "name", arrows = SMapLineArrows(share = 0.15f, color = "#7c2d12"), labelSize = SMapFeatureValue.of(13f)),
        )
        map.addHeatmap("density", points.take(400), SMapHeatmapOptions(radius = 18f, opacity = 0.6f, zIndex = 0, blur = 10f, minOpacity = 0.25f))
        // Hillshading from public elevation tiles, and a grid the app draws itself.
        map.setTerrain(SMapTerrain(listOf("https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png"), attribution = "Terrain: Mapzen / AWS"))
        map.addCanvasTiles("grid", opacity = 0.6) { canvas, z, x, y, size ->
            val paint = android.graphics.Paint().apply { color = Color.argb(140, 30, 41, 59); style = android.graphics.Paint.Style.STROKE; strokeWidth = 1f; textSize = 11f }
            canvas.drawRect(0f, 0f, size.toFloat(), size.toFloat(), paint)
            paint.style = android.graphics.Paint.Style.FILL
            canvas.drawText("$z/$x/$y", 6f, 16f, paint)
        }
        // 3D trucks (a sample glTF model of the Khronos glTF samples, CC-BY 4.0 Cesium), turned to their heading.
        map.addModels(
            "trucks3d",
            listOf(
                SMapPoint(43.6555, -79.3880, mapOf("id" to "t1", "bearing" to 0, "driver_color" to "#e11d48")),
                SMapPoint(43.6555, -79.3820, mapOf("id" to "t2", "bearing" to 90, "driver_color" to "#2563eb")),
            ),
            SMapModelOptions(
                model = "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/CesiumMilkTruck/glTF-Binary/CesiumMilkTruck.glb",
                size = SMapFeatureValue.of(40.0),
                heading = SMapFeatureValue.property("bearing", 0.0),
                idProperty = "id",
                color = SMapFeatureValue.property("driver_color"),
            ),
        )
        // Three vans as the app's own views: a long press drags one.
        map.addCustomMarkers(
            "vans",
            listOf(
                SMapPoint(43.6532, -79.3832, mapOf("id" to "v1", "name" to "Van 1", "color" to "#e11d48")),
                SMapPoint(43.6600, -79.4000, mapOf("id" to "v2", "name" to "Van 2", "color" to "#2563eb")),
                SMapPoint(43.6450, -79.3700, mapOf("id" to "v3", "name" to "Van 3", "color" to "#16a34a")),
            ),
            SMapCustomMarkerOptions(
                render = { p -> vanView(p["name"].toString(), p["color"].toString()) },
                anchor = SMapAnchor.BOTTOM,
                idProperty = "id",
                tooltip = SMapTooltip.template("{name}"),
                onTap = { f -> Toast.makeText(this, f.properties["name"].toString(), Toast.LENGTH_SHORT).show() },
                drag = SMapDragOptions(
                    draggable = SMapFeatureValue.of(true),
                    onDragEnd = { f, e -> Toast.makeText(this, "${f.properties["name"]}: %.5f, %.5f".format(e.position.latitude, e.position.longitude), Toast.LENGTH_SHORT).show() },
                ),
            ),
        )

        map.addPolygons(
            "block",
            listOf(
                SMapPolygon(
                    listOf(listOf(LatLng(43.6450, -79.3950), LatLng(43.6450, -79.3880), LatLng(43.6500, -79.3880), LatLng(43.6500, -79.3950))),
                    mapOf("height" to 180),
                ),
            ),
            SMapPolygonOptions(fill = "#7c3aed", opacity = 0.7f, extrude = SMapExtrude(height = SMapValue.property("height"))),
        )
    }

    /**
     * The 1.5.0 calls (G15–G24): zones with hover and selected looks and a dashed outline per zone (a tap selects
     * one, a double tap and a long press name it), lines whose width and dash differ per line, and a fleet of two
     * arrows moved every second towards their heading.
     */
    private fun addGaps() {
        fun square(lat: Double, lng: Double, d: Double) = listOf(listOf(LatLng(lat, lng), LatLng(lat, lng + d), LatLng(lat + d, lng + d), LatLng(lat + d, lng)))
        map.addPolygons(
            "zones",
            listOf(
                SMapPolygon(square(43.670, -79.420, 0.012), mapOf("code" to "Z1", "color" to "#0ea5e9", "open" to true)),
                SMapPolygon(square(43.670, -79.405, 0.012), mapOf("code" to "Z2", "color" to "#f59e0b", "open" to false)),
            ),
            SMapPolygonOptions(
                idProperty = "code", fillValue = SMapFeatureValue.property("color", "#64748b"), opacity = 0.25f,
                outlineDash = SMapFeatureValue.computed { p -> if (p["open"] == true) null else listOf(2f, 2f) },
                states = mapOf("hover" to SMapPolygonLook(opacity = 0.45f), "selected" to SMapPolygonLook(outline = "#111827", outlineWidth = 3f)),
                hoverState = true, tooltip = SMapTooltip.template("Zone {code}"),
                onDoubleClick = { f, _ -> Toast.makeText(this, "Double tap ${f.key}", Toast.LENGTH_SHORT).show(); Log.i(CHECK, "dblclick ${f.key}") },
                onContextMenu = { f, _ -> Toast.makeText(this, "Long press ${f.key}", Toast.LENGTH_SHORT).show(); Log.i(CHECK, "contextmenu ${f.key}") },
            ),
        )
        map.onTap("zones") { p, _ ->
            val code = p["code"].toString()
            val on = map.featureState("zones", code)["selected"] != true
            map.removeFeatureState("zones", name = "selected")
            if (on) map.setFeatureState("zones", code, mapOf("selected" to true))
            Log.i(CHECK, "tap $code selected=$on")
        }
        map.addLines(
            "lanes",
            listOf(
                SMapLine(listOf(LatLng(43.660, -79.430), LatLng(43.660, -79.390)), mapOf("w" to 3, "dash" to listOf(2, 1), "rank" to 1)),
                SMapLine(listOf(LatLng(43.664, -79.430), LatLng(43.664, -79.390)), mapOf("w" to 7, "rank" to 2)),
            ),
            SMapLineOptions(color = "#334155", widthValue = SMapFeatureValue.property("w", 4f), dashValue = SMapFeatureValue.property("dash"), sortProperty = "rank",
                states = mapOf("selected" to SMapLineLook(color = "#dc2626"))),
        )
        map.addImage("arrow", arrow())
        map.addPoints(
            "fleet",
            listOf(
                SMapPoint(43.655, -79.410, mapOf("id" to "a", "course" to 45, "name" to "Truck A")),
                SMapPoint(43.652, -79.400, mapOf("id" to "b", "course" to 180, "name" to "Truck B")),
            ),
            SMapPointOptions(icon = "arrow", iconAnchor = SMapAnchor.CENTER, idProperty = "id", rotation = SMapFeatureValue.property("course", 0f),
                rotationAlignment = SMapRotationAlignment.MAP, tooltip = SMapTooltip.template("{name}"), zIndex = 3),
        )
        // Every second each truck goes 150 m on along its heading, eased over the second.
        val handler = android.os.Handler(mainLooper)
        val course = mutableMapOf("a" to 45.0, "b" to 180.0)
        val at = mutableMapOf("a" to LatLng(43.655, -79.410), "b" to LatLng(43.652, -79.400))
        handler.post(object : Runnable {
            override fun run() {
                for (id in listOf("a", "b")) {
                    val c = (course[id]!! + Random.nextDouble(-20.0, 20.0)).mod(360.0)
                    course[id] = c
                    val p = at[id]!!
                    val next = LatLng(p.latitude + 0.00135 * Math.cos(Math.toRadians(c)), p.longitude + 0.00135 * Math.sin(Math.toRadians(c)) / Math.cos(Math.toRadians(p.latitude)))
                    at[id] = next
                    map.updateFeature("fleet", id, mapOf("course" to c))
                    map.moveFeature("fleet", id, next, durationMillis = 1000)
                }
                handler.postDelayed(this, 1000)
            }
        })
        map.on(SMapEventType.MOVE_END) { e -> Log.i(CHECK, "moveend zoom=%.2f".format(e.zoom)) }
        map.on(SMapEventType.ZOOM_END) { e -> Log.i(CHECK, "zoomend zoom=%.2f".format(e.zoom)) }
        map.on(SMapEventType.CLICK) { e ->
            val hits = map.featuresAt(e.point!!)
            Log.i(CHECK, "click at ${e.position} features=${hits.map { "${it.layer}:${it.feature.key}" }}")
        }
        map.on(SMapEventType.DOUBLE_CLICK) { e -> Log.i(CHECK, "map dblclick prevented=${e.defaultPrevented}") }
        map.on(SMapEventType.CONTEXT_MENU) { e -> Log.i(CHECK, "map contextmenu at ${e.point}") }
    }

    /**
     * The 1.5.0 calls G25–G37: an SDF image in each point's colour, a glyph image, circles in metres with a hover
     * look, labels with priority, the unavailable event, and a few geometry answers in the log.
     */
    private fun addGaps150() {
        map.addImage("drop", sdfDrop(), SMapImageOptions(sdf = true))
        map.addGlyphImage("star", SMapGlyph("★", sizeDp = 18f, color = "#ffffff", background = "#0ea5e9"))
        map.addPoints(
            "depots",
            listOf(
                SMapPoint(43.6480, -79.4150, mapOf("id" to "d1", "c" to "#16a34a", "rank" to 1, "name" to "Depot West")),
                SMapPoint(43.6480, -79.4100, mapOf("id" to "d2", "c" to "#9333ea", "rank" to 3, "name" to "Depot Centre")),
                SMapPoint(43.6480, -79.4050, mapOf("id" to "d3", "c" to "#ea580c", "rank" to 2, "name" to "Depot East")),
            ),
            SMapPointOptions(icon = "drop", iconColor = SMapFeatureValue.property("c", "#111827"), iconAnchor = SMapAnchor.BOTTOM, idProperty = "id",
                label = "name", priority = SMapFeatureValue.property("rank", 0f), allowOverlap = false, zIndex = 4,
                states = mapOf("selected" to SMapPointLook(iconColor = "#dc2626"))),
        )
        map.addPoints("hq", listOf(SMapPoint(43.6440, -79.4100, mapOf("name" to "HQ"))), SMapPointOptions(icon = "star", iconAnchor = SMapAnchor.CENTER, zIndex = 4))
        map.addCircles(
            "fences",
            listOf(
                SMapPoint(43.6480, -79.4150, mapOf("id" to "d1", "radius_m" to 300)),
                SMapPoint(43.6480, -79.4050, mapOf("id" to "d3", "radius_m" to 450)),
            ),
            SMapCircleOptions(radius = SMapFeatureValue.property("radius_m"), area = SMapPolygonOptions(fill = "#2563eb", opacity = 0.15f, outline = "#2563eb",
                outlineDash = SMapFeatureValue.of(listOf(2f, 2f)), idProperty = "id", hoverState = true, states = mapOf("hover" to SMapPolygonLook(opacity = 0.3f)),
                tooltip = SMapTooltip.template("Fence {id}"))),
        )
        map.onTap("fences") { p, _ -> Log.i(CHECK, "fence tap ${p["id"]}") }
        map.on(SMapEventType.UNAVAILABLE) { e -> Log.i(CHECK, "unavailable ${e.reason?.webName}") }
        val zone = SMapGeo.circle(doubleArrayOf(-79.41, 43.648), 300.0)
        Log.i(CHECK, "geo area=%.0f centroid=${SMapGeo.centroid(zone)!!.toList()} selfIntersects=${SMapGeo.selfIntersects(zone)}".format(SMapGeo.area(zone)))
    }

    // An SDF drop (alpha falls off over a few pixels at its edge), drawn in each point's iconColor.
    private fun sdfDrop(): Bitmap {
        val size = 64
        val b = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.BLACK; maskFilter = android.graphics.BlurMaskFilter(4f, android.graphics.BlurMaskFilter.Blur.NORMAL) }
        val c = Canvas(b)
        c.drawCircle(size / 2f, size * 0.38f, size * 0.3f, paint)
        c.drawPath(Path().apply { moveTo(size * 0.25f, size * 0.5f); lineTo(size / 2f, size * 0.95f); lineTo(size * 0.75f, size * 0.5f); close() }, paint)
        b.density = 2 * android.util.DisplayMetrics.DENSITY_DEFAULT
        return b
    }

    // The checks the emulator run reads from the log (tag SMapCheck).
    private fun check() {
        map.fitLayer(listOf("zones", "lanes", "fleet"), SMapFitOptions(durationMillis = 0, maxZoom = 14.0))
        Log.i(CHECK, "fit center=${map.getCenter()} zoom=%.2f bounds=${map.getBounds()}".format(map.getZoom()))
        map.setFeatureState("zones", "Z2", mapOf("selected" to true))
        Log.i(CHECK, "state Z2=${map.featureState("zones", "Z2")}")
        mapView().postDelayed({
            val p = map.project(LatLng(43.676, -79.399))!!
            Log.i(CHECK, "project=$p unproject=${map.unproject(p)}")
            Log.i(CHECK, "featuresAt Z2=${map.featuresAt(p).map { "${it.layer}:${it.feature.key}:${it.feature.properties["code"]}" }}")
            Log.i(CHECK, "tap point for Z1 x=%.0f y=%.0f".format(map.project(LatLng(43.676, -79.414))!!.x, map.project(LatLng(43.676, -79.414))!!.y))
            map.openTooltip("zones", "Z1")
            Log.i(CHECK, "popup=${map.openFeaturePopup("zones", "Z1")}")
        }, 1500)
        // The 1.5.0 checks (G25–G37) the emulator run reads from the log.
        mapView().postDelayed({ check150() }, 6000)
        // A moving truck is found where it is drawn now.
        mapView().postDelayed({
            val a = map.toGeoJSON("fleet").features()!!.first { it.getStringProperty("id") == "a" }.geometry() as org.maplibre.geojson.Point
            val p = map.project(LatLng(a.latitude(), a.longitude()))!!
            Log.i(CHECK, "truck a at $p featuresAt=${map.featuresAt(p).map { "${it.layer}:${it.feature.key}" }}")
        }, 4200)
    }

    // Taps on the map as a finger would make them.
    private fun tapAt(at: LatLng) {
        val p = map.project(at) ?: return
        val t = android.os.SystemClock.uptimeMillis()
        for ((dt, action) in listOf(0L to android.view.MotionEvent.ACTION_DOWN, 60L to android.view.MotionEvent.ACTION_UP)) {
            val e = android.view.MotionEvent.obtain(t, t + dt, action, p.x, p.y, 0)
            map.dispatchTouchEvent(e)
            e.recycle()
        }
    }

    private fun findViews(v: View, out: MutableList<View> = ArrayList()): List<View> {
        out += v
        if (v is ViewGroup) for (i in 0 until v.childCount) findViews(v.getChildAt(i), out)
        return out
    }

    private fun check150() {
        // G28: a bow tie refused, then a valid triangle with its figures.
        val d = draw ?: return
        d.start("polygon")
        val corners = listOf(LatLng(43.630, -79.440), LatLng(43.660, -79.400), LatLng(43.630, -79.400), LatLng(43.660, -79.440))
        corners.forEachIndexed { i, c -> mapView().postDelayed({ tapAt(c) }, 400L * (i + 1)) }
        mapView().postDelayed({ d.finish(); Log.i(CHECK, "draw after bow tie: ${d.getAll().getAsJsonArray("features").size()} shapes") }, 2400)
        mapView().postDelayed({ d.cancel(); d.start("line"); listOf(LatLng(43.636, -79.432), LatLng(43.636, -79.426), LatLng(43.632, -79.426)).forEachIndexed { i, c -> mapView().postDelayed({ tapAt(c) }, 400L * (i + 1)) } }, 2800)
        mapView().postDelayed({ d.finish(); Log.i(CHECK, "draw line: ${d.getAll().getAsJsonArray("features").size()} shapes label=${findViews(map).filterIsInstance<TextView>().firstOrNull { Regex("^(r )?[0-9.,]+ (k?m²?)").containsMatchIn(it.text) }?.text}") }, 4800)
        // G35: the search field asked for "que".
        mapView().postDelayed({
            val field = findViews(map).filterIsInstance<android.widget.EditText>().firstOrNull()
            Log.i(CHECK, "search hint=${field?.hint}")
            field?.setText("que")
        }, 5200)
        scope.launch {
            kotlinx.coroutines.delay(5500)
            var rows: List<CharSequence> = emptyList()
            for (i in 0 until 40) {
                rows = findViews(map).filterIsInstance<TextView>().filter { it !is android.widget.EditText && it.isShown && it.text.startsWith("Que") }.map { it.text }
                if (rows.isNotEmpty()) break
                kotlinx.coroutines.delay(250)
            }
            Log.i(CHECK, "search rows=$rows")
            findViews(map).filterIsInstance<TextView>().firstOrNull { it.isShown && it.text == "Queens Quay" }?.performClick()
        }
        // G29: the map as a picture.
        mapView().postDelayed({
            scope.launch {
                val picture = map.export(SMapExportOptions(include = listOfNotNull(legend?.let { SMapExportView(it, SMapToolPosition.TOP_RIGHT) })))
                val png = map.exportBytes()
                Log.i(CHECK, "export ${picture.width}x${picture.height} png=${png.size} bytes center=${map.getCenter()}")
                try { java.io.File(filesDir, "export.png").writeBytes(png) } catch (e: Exception) { Log.i(CHECK, "export file ${e.message}") }
            }
        }, 9500)
    }

    private fun mapView(): View = map.mapView

    private fun arrow(): Bitmap {
        val d = resources.displayMetrics.density
        val size = (28 * d).toInt()
        val b = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val c = Canvas(b)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.parseColor("#7c3aed") }
        val path = Path().apply { moveTo(size / 2f, 0f); lineTo(size.toFloat(), size.toFloat()); lineTo(size / 2f, size * 0.7f); lineTo(0f, size.toFloat()); close() }
        c.drawPath(path, paint)
        return b
    }

    private fun vanView(name: String, color: String): View = TextView(this).apply {
        text = name
        setTextColor(Color.WHITE)
        textSize = 12f
        setPadding(16, 6, 16, 6)
        background = android.graphics.drawable.GradientDrawable().apply { cornerRadius = 12f; setColor(Color.parseColor(color)) }
    }

    override fun onStart() { super.onStart(); map.onStart() }
    override fun onResume() { super.onResume(); map.onResume() }
    override fun onPause() { map.onPause(); super.onPause() }
    override fun onStop() { map.onStop(); super.onStop() }
    override fun onLowMemory() { super.onLowMemory(); map.onLowMemory() }
    override fun onSaveInstanceState(outState: Bundle) { super.onSaveInstanceState(outState); map.onSaveInstanceState(outState) }
    override fun onDestroy() { scope.cancel(); map.onDestroy(); super.onDestroy() }
}
