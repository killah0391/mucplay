package com.example.mucplay

import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
// WICHTIG: Dies ist der korrekte Import für moderne Flutter Apps & audio_service
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: AudioServiceActivity() {
    private val CHANNEL = "com.example.mucplay/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine) // <--- WICHTIG: super aufrufen!
        // Hier werden Plugins registriert. Fehlt super(), funktionieren Plugins wie audio_service nicht.
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleWidgetAction(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // WICHTIG: Intent an Flutter weiterleiten (für Deep Links & Widgets)
        flutterEngine?.activityControlSurface?.onNewIntent(intent)
        handleWidgetAction(intent)
    }

    private fun handleWidgetAction(intent: Intent) {
        // Prüfen, ob das Signal von unserer WidgetConfigActivity kommt
        val shouldOpenSettings = intent.getBooleanExtra("navigate_to_settings", false)

        // ODER ob es (theoretisch) direkt vom System käme (Fallback)
        val isSystemConfigure = AppWidgetManager.ACTION_APPWIDGET_CONFIGURE == intent.action

        if (shouldOpenSettings || isSystemConfigure) {

            // Nachricht an Flutter senden
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, CHANNEL).invokeMethod("openSettings", null)
            }

            // Optional: Extra entfernen, damit es beim Rotieren nicht nochmal feuert
            intent.removeExtra("navigate_to_settings")
        }
    }
}
