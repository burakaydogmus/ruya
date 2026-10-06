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

/** 2×2. Keeps Menstrudel's class name so widgets placed by older versions keep working. */
class HomeScreenWidgetProvider : RuyaWidgetProvider(R.layout.widget_small, maxLines = 0)

/** 4×2. */
class RuyaWidgetMedium : RuyaWidgetProvider(R.layout.widget_medium, maxLines = 3)

/** 4×3. */
class RuyaWidgetLarge : RuyaWidgetProvider(R.layout.widget_large, maxLines = 4)
