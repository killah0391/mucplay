package com.example.mucplay // <--- Dein Package

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import com.ryanheise.audioservice.AudioServiceActivity

// WICHTIG: Erbt jetzt von AudioServiceActivity statt FlutterActivity
class MainActivity: AudioServiceActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleWidgetConfiguration()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleWidgetConfiguration()
    }

    private fun handleWidgetConfiguration() {
        val intent = intent
        val extras = intent.extras

        if (extras != null) {
            val appWidgetId = extras.getInt(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID
            )

            if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                // 1. Android sagen: "Alles OK, Widget darf bleiben"
                val resultValue = Intent()
                resultValue.putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                setResult(Activity.RESULT_OK, resultValue)

                // 2. Intent manipulieren, damit home_widget ihn erkennt
                // Wir setzen die Action auf LAUNCH, damit Flutter denkt, das Widget wurde geklickt
                intent.action = "es.antonborri.home_widget.action.LAUNCH"
                intent.data = android.net.Uri.parse("mucplay://settings/widget")

                // Intent aktualisieren (Wichtig für onNewIntent in Flutter)
                setIntent(intent)
            }
        }
    }
}
