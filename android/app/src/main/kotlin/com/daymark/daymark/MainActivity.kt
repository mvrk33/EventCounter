package com.daymark.app

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "daymark/widget_actions"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pinWidget" -> result.success(requestPinWidget(this))
                else -> result.notImplemented()
            }
        }
    }

    private fun requestPinWidget(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return false
        }
        val appWidgetManager = context.getSystemService(AppWidgetManager::class.java)
        val provider = ComponentName(context, DayMarkWidgetProvider::class.java)

        if (!appWidgetManager.isRequestPinAppWidgetSupported) {
            return false
        }
        return appWidgetManager.requestPinAppWidget(provider, null, null)
    }
}
