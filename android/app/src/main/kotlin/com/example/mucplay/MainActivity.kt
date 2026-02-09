package com.example.mucplay // <--- Dein Package

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity

class MainActivity: AudioServiceActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Check beim Kaltstart
        handleWidgetConfiguration(intent)
    }

    override fun onNewIntent(intent: Intent) {
        // 1. ZUERST den Intent prüfen und ggf. umschreiben
        handleWidgetConfiguration(intent)

        // 2. DANN den manipulierten Intent an das System/Plugins weitergeben
        super.onNewIntent(intent)
        setIntent(intent)
    }

    private fun handleWidgetConfiguration(intent: Intent) {
        val extras = intent.extras

        if (extras != null) {
            val appWidgetId = extras.getInt(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID
            )

            // Wenn es ein "Konfigurieren"-Aufruf von Android ist:
            if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {

                // A. Android Bescheid geben: "Widget ist OK"
                val resultValue = Intent()
                resultValue.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                setResult(Activity.RESULT_OK, resultValue)

                // B. Intent manipulieren ("Hack"), damit Flutter denkt, es sei ein Klick
                // Wir ändern die Action zu dem, was home_widget erwartet:
                intent.action = "es.antonborri.home_widget.action.LAUNCH"

                // Wir fügen unsere Settings-URI hinzu
                intent.data = android.net.Uri.parse("mucplay://settings/widget")
            }
        }
    }
}
