package com.example.mucplay

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.net.Uri
import android.os.Bundle

class WidgetConfigActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 1. Erfolg an Android melden
        val appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        val resultValue = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        setResult(RESULT_OK, resultValue)

        // 2. MainActivity mit Spezial-Signal öffnen
        val mainIntent = Intent(this, MainActivity::class.java)

        // Wir nutzen Standard-Launch Parameter, damit die App sauber in den Vordergrund kommt
        mainIntent.action = Intent.ACTION_MAIN
        mainIntent.addCategory(Intent.CATEGORY_LAUNCHER)

        // WICHTIG: Das Signal für die MainActivity!
        mainIntent.putExtra("navigate_to_settings", true)

        mainIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)

        startActivity(mainIntent)
        finish()
    }
}
