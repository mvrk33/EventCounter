package com.mvrk.event_counter

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class EventCounterWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val data = HomeWidgetPlugin.getData(context)
        val knownIds = getKnownWidgetIds(data)
        var idsChanged = false

        for (appWidgetId in appWidgetIds) {
            val idStr = appWidgetId.toString()
            if (!knownIds.contains(idStr)) {
                // NEW widget — absorb pending config if Flutter set one up
                val pendingTitle = data.getString(PENDING_TITLE, null)
                if (pendingTitle != null) {
                    val editor = data.edit()
                    editor.putString(perKey(idStr, "title"),      pendingTitle)
                    editor.putInt   (perKey(idStr, "count_num"),  data.getInt(PENDING_COUNT_NUM, 0))
                    editor.putString(perKey(idStr, "count_unit"), data.getString(PENDING_COUNT_UNIT, "days") ?: "days")
                    editor.putString(perKey(idStr, "count_dir"),  data.getString(PENDING_COUNT_DIR, "left") ?: "left")
                    editor.putString(perKey(idStr, "emoji"),      data.getString(PENDING_EMOJI, "📅") ?: "📅")
                    editor.putBoolean(perKey(idStr, "transparent"), data.getBoolean(PENDING_TRANSPARENT, false))
                    editor.putString(perKey(idStr, "bg_color"),   data.getString(PENDING_BG_COLOR, "#CC5E6AD2") ?: "#CC5E6AD2")
                    editor.putBoolean(perKey(idStr, "show_emoji"), data.getBoolean(PENDING_SHOW_EMOJI, true))
                    editor.putBoolean(perKey(idStr, "show_title"), data.getBoolean(PENDING_SHOW_TITLE, true))
                    editor.putString(perKey(idStr, "text_color"), data.getString(PENDING_TEXT_COLOR, "#FFFFFFFF") ?: "#FFFFFFFF")
                    editor.putString(perKey(idStr, "event_mode"), "specific")
                    // Clear pending keys so the next widget addition starts fresh
                    clearPendingKeys(editor)
                    editor.apply()
                }
                knownIds.add(idStr)
                idsChanged = true
            }
            updateWidget(context, appWidgetManager, appWidgetId, data)
        }

        if (idsChanged) {
            data.edit().putString(KNOWN_IDS_KEY, knownIds.joinToString(",")).apply()
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        val data = HomeWidgetPlugin.getData(context)
        val knownIds = getKnownWidgetIds(data)
        val editor = data.edit()
        for (appWidgetId in appWidgetIds) {
            val idStr = appWidgetId.toString()
            knownIds.remove(idStr)
            listOf("title","count_num","count_unit","count_dir","emoji",
                   "transparent","bg_color","show_emoji","show_title",
                   "text_color","event_mode").forEach { field ->
                editor.remove(perKey(idStr, field))
            }
        }
        editor.putString(KNOWN_IDS_KEY, knownIds.joinToString(","))
        editor.apply()
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        updateWidget(context, appWidgetManager, appWidgetId, HomeWidgetPlugin.getData(context))
    }

    companion object {
        private const val KNOWN_IDS_KEY     = "known_widget_ids"
        private const val PENDING_TITLE      = "pending_w_title"
        private const val PENDING_COUNT_NUM  = "pending_w_count_num"
        private const val PENDING_COUNT_UNIT = "pending_w_count_unit"
        private const val PENDING_COUNT_DIR  = "pending_w_count_dir"
        private const val PENDING_EMOJI      = "pending_w_emoji"
        private const val PENDING_TRANSPARENT= "pending_w_transparent"
        private const val PENDING_BG_COLOR   = "pending_w_bg_color"
        private const val PENDING_SHOW_EMOJI = "pending_w_show_emoji"
        private const val PENDING_SHOW_TITLE = "pending_w_show_title"
        private const val PENDING_TEXT_COLOR = "pending_w_text_color"

        private fun perKey(widgetId: String, field: String) = "w_${widgetId}_$field"

        private fun getKnownWidgetIds(data: SharedPreferences): MutableSet<String> {
            val str = data.getString(KNOWN_IDS_KEY, "") ?: ""
            return if (str.isEmpty()) mutableSetOf() else str.split(",").toMutableSet()
        }

        private fun clearPendingKeys(editor: SharedPreferences.Editor) {
            editor.remove(PENDING_TITLE)
            editor.remove(PENDING_COUNT_NUM)
            editor.remove(PENDING_COUNT_UNIT)
            editor.remove(PENDING_COUNT_DIR)
            editor.remove(PENDING_EMOJI)
            editor.remove(PENDING_TRANSPARENT)
            editor.remove(PENDING_BG_COLOR)
            editor.remove(PENDING_SHOW_EMOJI)
            editor.remove(PENDING_SHOW_TITLE)
            editor.remove(PENDING_TEXT_COLOR)
        }

        /** Render a single widget instance, preferring per-widget keys, falling back to global. */
        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            data: SharedPreferences
        ) {
            val idStr = appWidgetId.toString()
            val hasPerWidget = data.contains(perKey(idStr, "title"))

            val title: String; val countNum: Int; val countUnit: String
            val countDir: String; val emoji: String; val transparent: Boolean
            val bgColorStr: String; val showEmojiCfg: Boolean
            val showTitleCfg: Boolean; val textColorStr: String

            if (hasPerWidget) {
                title        = data.getString(perKey(idStr, "title"),      "No events") ?: "No events"
                countNum     = data.getInt   (perKey(idStr, "count_num"),  0)
                countUnit    = data.getString(perKey(idStr, "count_unit"), "days") ?: "days"
                countDir     = data.getString(perKey(idStr, "count_dir"),  "left") ?: "left"
                emoji        = data.getString(perKey(idStr, "emoji"),      "📅") ?: "📅"
                transparent  = data.getBoolean(perKey(idStr, "transparent"), false)
                bgColorStr   = data.getString(perKey(idStr, "bg_color"),   "#CC5E6AD2") ?: "#CC5E6AD2"
                showEmojiCfg = data.getBoolean(perKey(idStr, "show_emoji"), true)
                showTitleCfg = data.getBoolean(perKey(idStr, "show_title"), true)
                textColorStr = data.getString(perKey(idStr, "text_color"), "#FFFFFFFF") ?: "#FFFFFFFF"
            } else {
                // Fallback: global keys written by pushEvents (existing / pre-update widgets)
                title        = data.getString("w_title",      "No events") ?: "No events"
                countNum     = data.getInt   ("w_count_num",  0)
                countUnit    = data.getString("w_count_unit", "days") ?: "days"
                countDir     = data.getString("w_count_dir",  "left") ?: "left"
                emoji        = data.getString("w_emoji",      "📅") ?: "📅"
                transparent  = data.getBoolean("w_transparent", false)
                bgColorStr   = data.getString("w_bg_color",   "#CC5E6AD2") ?: "#CC5E6AD2"
                showEmojiCfg = data.getBoolean("w_show_emoji", true)
                showTitleCfg = data.getBoolean("w_show_title", true)
                textColorStr = data.getString("w_text_color", "#FFFFFFFF") ?: "#FFFFFFFF"
            }

            val views = RemoteViews(context.packageName, R.layout.daymark_widget)

            views.setTextViewText(R.id.widget_count_number, if (countNum == 0) "🎉" else "$countNum")
            views.setTextViewText(
                R.id.widget_count_label,
                if (countNum == 0) "Today!" else "$countUnit $countDir"
            )
            views.setTextViewText(R.id.widget_title, title)
            views.setTextViewText(R.id.widget_emoji, emoji)

            val textColor = try { Color.parseColor(textColorStr) } catch (_: Exception) { Color.WHITE }
            views.setTextColor(R.id.widget_count_number, textColor)
            views.setTextColor(R.id.widget_count_label,  adjustAlpha(textColor, 0.80f))
            views.setTextColor(R.id.widget_title,        adjustAlpha(textColor, 0.70f))
            views.setTextColor(R.id.widget_emoji,        textColor)

            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minW = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 110)
            val minH = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110)
            val isSmall = minW < 130 || minH < 120
            val isTiny  = minW < 110 || minH < 90

            views.setViewVisibility(R.id.widget_emoji, if (showEmojiCfg && !isTiny)  View.VISIBLE else View.GONE)
            views.setViewVisibility(R.id.widget_title, if (showTitleCfg && !isSmall) View.VISIBLE else View.GONE)

            if (transparent) {
                views.setInt(R.id.widget_card, "setBackgroundColor", Color.TRANSPARENT)
            } else {
                val bgColor = try { Color.parseColor(bgColorStr) } catch (_: Exception) { Color.parseColor("#CC5E6AD2") }
                views.setInt(R.id.widget_card, "setBackgroundColor", bgColor)
            }

            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context, appWidgetId, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        /** Convenience overload that fetches SharedPreferences internally. */
        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            updateWidget(context, appWidgetManager, appWidgetId, HomeWidgetPlugin.getData(context))
        }

        private fun adjustAlpha(color: Int, factor: Float): Int {
            val alpha = (Color.alpha(color) * factor).toInt().coerceIn(0, 255)
            return Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color))
        }
    }
}
