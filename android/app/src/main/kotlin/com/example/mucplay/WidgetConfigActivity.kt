package com.example.mucplay

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.net.Uri
import android.os.Bundle

class WidgetConfigActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 1. Dem System sagen: "Konfiguration erfolgreich" (WICHTIG gegen Fehler!)
        val appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        val resultValue = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        setResult(RESULT_OK, resultValue)

        // 2. Deine App öffnen und zu den Settings leiten
        val mainIntent = Intent(this, MainActivity::class.java)
        mainIntent.action = Intent.ACTION_VIEW
        mainIntent.data = Uri.parse("mucplay://settings") // Das Signal für Flutter

        // Diese Flags verhindern den schwarzen Bildschirm in der Haupt-App
        mainIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)

        startActivity(mainIntent)

        // 3. Diese Helfer-Activity sofort wieder schließen
        finish()
    }
}
