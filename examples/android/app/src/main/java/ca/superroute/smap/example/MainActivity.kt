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

class MainActivity : Activity() {
    private lateinit var map: SMap
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
        addTools()
        map.ready { Toast.makeText(this, "Map ready", Toast.LENGTH_SHORT).show() }
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
        map.addTool("legend", legend, getString(R.string.legend_label), SMapToolPosition.BOTTOM_LEFT)
        // Drawing zones (toolbar bottom right); the result is shown as a message.
        map.drawTool(SMapDrawOptions(toolbar = SMapToolPosition.BOTTOM_RIGHT, onChange = { e ->
            Toast.makeText(this, "${e.type}: ${e.features.getAsJsonArray("features").size()} shapes", Toast.LENGTH_SHORT).show()
        }))
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
            SMapLineOptions(color = "#f97316", width = 5f, zIndex = 1, label = "name"),
        )
        map.addHeatmap("density", points.take(400), SMapHeatmapOptions(radius = 18f, opacity = 0.6f, zIndex = 0))
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
                SMapPoint(43.6555, -79.3880, mapOf("id" to "t1", "bearing" to 0)),
                SMapPoint(43.6555, -79.3820, mapOf("id" to "t2", "bearing" to 90)),
            ),
            SMapModelOptions(
                model = "https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Assets/main/Models/CesiumMilkTruck/glTF-Binary/CesiumMilkTruck.glb",
                size = SMapFeatureValue.of(40.0),
                heading = SMapFeatureValue.property("bearing", 0.0),
                idProperty = "id",
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
