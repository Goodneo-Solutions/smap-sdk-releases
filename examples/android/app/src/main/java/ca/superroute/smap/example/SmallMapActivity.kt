package ca.superroute.smap.example

import android.app.Activity
import android.os.Bundle
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import ca.superroute.smap.SMap
import ca.superroute.smap.SMapOptions
import org.maplibre.android.geometry.LatLng

/** A small map in a screen that scrolls, with cooperative gestures (G36): one finger scrolls, two move the map. */
class SmallMapActivity : Activity() {
    private lateinit var map: SMap

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        map = SMap(this, SMapOptions(center = LatLng(43.6532, -79.3832), zoom = 12.0, cooperativeGestures = true))
        map.onCreate(savedInstanceState)
        val d = resources.displayMetrics.density
        val column = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; setPadding((16 * d).toInt(), (48 * d).toInt(), (16 * d).toInt(), 0) }
        fun text(n: Int) = TextView(this).apply { text = (1..n).joinToString("\n") { "Line $it of the page around the map." }; textSize = 16f }
        column.addView(text(12))
        column.addView(map, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, (300 * d).toInt()))
        column.addView(text(40))
        setContentView(ScrollView(this).apply { addView(column) })
    }

    override fun onStart() { super.onStart(); map.onStart() }
    override fun onResume() { super.onResume(); map.onResume() }
    override fun onPause() { map.onPause(); super.onPause() }
    override fun onStop() { map.onStop(); super.onStop() }
    override fun onDestroy() { map.onDestroy(); super.onDestroy() }
}
