package com.burakaydogmus.ruya

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import android.graphics.Color
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import java.util.TimeZone

/**
 * RUYA home screen widgets.
 *
 * The app writes the text for today and the next weeks (one JSON entry per
 * local day, already localized) plus the user's widget options; this side only
 * picks today's entry, so the countdown stays right at midnight without the app
 * running. Scheduled updates (home_widget) and updatePeriodMillis redraw it.
 */
abstract class RuyaWidgetProvider(private val layoutId: Int, private val maxLines: Int) : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id -> appWidgetManager.updateAppWidget(id, render(context, widgetData)) }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        appWidgetManager.updateAppWidget(appWidgetId, render(context, HomeWidgetPlugin.getData(context)))
    }

    private fun render(context: Context, data: SharedPreferences): RemoteViews {
        val views = RemoteViews(context.packageName, layoutId)
        val day = todayEntry(data)

        // Theme
        val night = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
        val theme = data.getString("ruya_w_theme", "system") ?: "system"
        val dark = theme == "dark" || theme == "transparent" || (theme == "system" && night)
        val background = when {
            theme == "transparent" -> R.drawable.widget_bg_transparent
            dark -> R.drawable.widget_bg_dark
            else -> R.drawable.widget_bg_light
        }
        views.setInt(R.id.w_root, "setBackgroundResource", background)
        val fg = if (dark) Color.WHITE else Color.parseColor("#FF1C1B1F")
        val muted = if (dark) Color.parseColor("#CCFFFFFF") else Color.parseColor("#FF6B6870")

        // Countdown + ring
        views.setTextViewText(R.id.w_big, day?.optString("big", "–") ?: "–")
        views.setTextViewText(R.id.w_unit, day?.optString("unit", "") ?: "")
        views.setTextColor(R.id.w_big, fg)
        views.setTextColor(R.id.w_unit, muted)
        val showRing = data.getBoolean("ruya_w_ring", true)
        val max = day?.optInt("m", 0) ?: 0
        val progress = (day?.optInt("p", 0) ?: 0).coerceIn(0, maxOf(max, 0))
        val ringVisibility = if (showRing && max > 0) View.VISIBLE else View.INVISIBLE
        views.setViewVisibility(R.id.w_ring, ringVisibility)
        views.setViewVisibility(R.id.w_ring_track, ringVisibility)
        if (max > 0) {
            views.setProgressBar(R.id.w_ring_track, max, max, false)
            views.setProgressBar(R.id.w_ring, max, progress, false)
        }

        // Text lines (medium / large only)
        if (maxLines > 0) {
            val head = day?.optString("head", "") ?: data.getString("ruya_w_stale", "") ?: ""
            setLine(views, R.id.w_head, head, fg)
            val lines = listOf("phase", "cday", "next", "fert")
                .mapNotNull { key -> day?.optString(key, "")?.takeIf { it.isNotEmpty() } }
            val ids = listOf(R.id.w_line1, R.id.w_line2, R.id.w_line3, R.id.w_line4)
            ids.forEachIndexed { i, viewId ->
                if (i < maxLines) setLine(views, viewId, lines.getOrNull(i) ?: "", muted)
            }
        }
        // Companion (medium / large). In the medium widget it takes the ring's place.
        if (maxLines > 0) {
            val pet = companionDrawable(data.getString("ruya_w_pet", "") ?: "", day?.optString("pm", "") ?: "")
            if (pet != 0) {
                views.setImageViewResource(R.id.w_pet, pet)
                views.setViewVisibility(R.id.w_pet, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.w_pet, View.GONE)
            }
            if (layoutId == R.layout.widget_medium) {
                views.setViewVisibility(R.id.w_ring_box, if (pet != 0) View.GONE else View.VISIBLE)
            }
        }
        if (layoutId == R.layout.widget_large) {
            views.setTextViewText(R.id.w_title, data.getString("ruya_w_title", "RUYA"))
            views.setTextColor(R.id.w_title, fg)
        }

        // Taps: the whole widget opens the app, "+" opens today's log.
        views.setOnClickPendingIntent(
            R.id.w_root,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("ruya://widget/home")),
        )
        val quick = data.getBoolean("ruya_w_quick", true)
        views.setViewVisibility(R.id.w_quick, if (quick) View.VISIBLE else View.GONE)
        if (quick) {
            views.setOnClickPendingIntent(
                R.id.w_quick,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("ruya://widget/log")),
            )
        }
        return views
    }

    private fun setLine(views: RemoteViews, id: Int, text: String, color: Int) {
        views.setTextViewText(id, text)
        views.setTextColor(id, color)
        views.setViewVisibility(id, if (text.isEmpty()) View.GONE else View.VISIBLE)
    }

    /**
     * Picture for the companion: cozy or comforting when today's log says so,
     * otherwise sleepy at night and calm by day (same rule as the app).
     * Returns 0 when no companion should be shown.
     */
    private fun companionDrawable(pet: String, mood: String): Int {
        if (pet.isEmpty()) return 0
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        val state = when (mood) {
            "cozy", "comfort" -> mood
            else -> if (hour >= 22 || hour < 6) "sleep" else "idle"
        }
        return PET_DRAWABLES[pet]?.get(state) ?: 0
    }

    /** The entry for the current local day, or null if the app was not opened for weeks. */
    private fun todayEntry(data: SharedPreferences): JSONObject? {
        val raw = data.getString("ruya_w_days", null) ?: return null
        val now = System.currentTimeMillis()
        val today = (now + TimeZone.getDefault().getOffset(now)) / 86_400_000L
        return try {
            val days = JSONArray(raw)
            (0 until days.length()).map { days.getJSONObject(it) }.firstOrNull { it.optLong("d") == today }
        } catch (e: Exception) {
            null
        }
    }
}

/** Explicit references so resource shrinking keeps every picture. */
private val PET_DRAWABLES: Map<String, Map<String, Int>> = mapOf(
    "pamuk" to mapOf("idle" to R.drawable.pet_pamuk_idle, "sleep" to R.drawable.pet_pamuk_sleep,
        "cozy" to R.drawable.pet_pamuk_cozy, "comfort" to R.drawable.pet_pamuk_comfort),
    "fistik" to mapOf("idle" to R.drawable.pet_fistik_idle, "sleep" to R.drawable.pet_fistik_sleep,
        "cozy" to R.drawable.pet_fistik_cozy, "comfort" to R.drawable.pet_fistik_comfort),
    "tarcin" to mapOf("idle" to R.drawable.pet_tarcin_idle, "sleep" to R.drawable.pet_tarcin_sleep,
        "cozy" to R.drawable.pet_tarcin_cozy, "comfort" to R.drawable.pet_tarcin_comfort),
    "lokum" to mapOf("idle" to R.drawable.pet_lokum_idle, "sleep" to R.drawable.pet_lokum_sleep,
        "cozy" to R.drawable.pet_lokum_cozy, "comfort" to R.drawable.pet_lokum_comfort),
    "mehtap" to mapOf("idle" to R.drawable.pet_mehtap_idle, "sleep" to R.drawable.pet_mehtap_sleep,
        "cozy" to R.drawable.pet_mehtap_cozy, "comfort" to R.drawable.pet_mehtap_comfort),
    "boncuk" to mapOf("idle" to R.drawable.pet_boncuk_idle, "sleep" to R.drawable.pet_boncuk_sleep,
        "cozy" to R.drawable.pet_boncuk_cozy, "comfort" to R.drawable.pet_boncuk_comfort),
)

/** 2×2. Keeps Menstrudel's class name so widgets placed by older versions keep working. */
class HomeScreenWidgetProvider : RuyaWidgetProvider(R.layout.widget_small, maxLines = 0)

/** 4×2. */
class RuyaWidgetMedium : RuyaWidgetProvider(R.layout.widget_medium, maxLines = 3)

/** 4×3. */
class RuyaWidgetLarge : RuyaWidgetProvider(R.layout.widget_large, maxLines = 4)
