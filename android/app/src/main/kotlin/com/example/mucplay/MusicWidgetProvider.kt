package com.example.mucplay // <--- Dein Package prüfen!

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.KeyEvent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import android.graphics.BitmapFactory
import android.view.View
import java.io.File

class MusicWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_music).apply {

                // 1. Daten laden
                val title = widgetData.getString("title", "Kein Titel")
                val artist = widgetData.getString("artist", "Unbekannt")
                val isPlaying = widgetData.getBoolean("isPlaying", false)

                // 2. Farben laden (Long -> Int Konvertierung nicht vergessen!)
                val colorLong = widgetData.getLong("widgetColor", 0xFF1E1E1E)
                val onColorLong = widgetData.getLong("widgetOnColor", 0xFFFFFFFF)
                val artistColorLong = widgetData.getLong("widgetArtistColor", 0xFFCCCCCC)

                // Umwandeln
                val color = colorLong.toInt()
                val onColor = onColorLong.toInt()
                val artistColor = artistColorLong.toInt()

                // Farben setzen
                setInt(R.id.widget_background, "setColorFilter", color)
                setTextColor(R.id.widget_title, onColor)
                setTextColor(R.id.widget_artist, artistColor)

                // Icons färben
                setInt(R.id.btn_prev, "setColorFilter", onColor)
                setInt(R.id.btn_play, "setColorFilter", onColor)
                setInt(R.id.btn_next, "setColorFilter", onColor)

                // 6. Inhalt setzen
                setTextViewText(R.id.widget_title, title)
                setTextViewText(R.id.widget_artist, artist)

// 2. Pfad zum Bild lesen (wird von Flutter gesendet)
val showCover = widgetData.getBoolean("show_cover", true)
val coverPath = widgetData.getString("cover_path", null)

if (showCover) {
    // Sichtbar machen
    setViewVisibility(R.id.widget_album_art, View.VISIBLE)

    var bitmapSet = false


    if (coverPath != null) {
        val imgFile = File(coverPath)
        if (imgFile.exists()) {
            val bitmap = BitmapFactory.decodeFile(imgFile.absolutePath)
            if (bitmap != null) {
                setImageViewBitmap(R.id.widget_album_art, bitmap)
                // WICHTIG: Wenn ein echtes Bild da ist, KEINE Farbe darüberlegen (Filter nullen)
                setInt(R.id.widget_album_art, "setColorFilter", 0)
                bitmapSet = true
            }
        }
    }


    if (!bitmapSet) {
        // 1. Icon setzen
        setImageViewResource(R.id.widget_album_art, R.drawable.ic_music_note)

        // 2. Färben: Wir nehmen die 'onColor' (die Farbe für Text/Titel),
        // da diese garantiert auf dem Hintergrund lesbar ist.
        // WICHTIG: "setColorFilter" erwartet oft ARGB.
        // Falls onColor 0 ist (passiert manchmal bei Fehlern), nimm Weiß als Fallback.

        val safeColor = if (onColor != 0) onColor else -1 // -1 ist Weiß (0xFFFFFFFF)

        setInt(R.id.widget_album_art, "setColorFilter", safeColor)

        // Alternative für manche Android-Versionen, falls setInt zickt:
        // setInt(R.id.widget_album_art, "setImageAlpha", 255) // Sicherstellen, dass es nicht transparent ist
    }

} else {
    // Ausblenden
    setViewVisibility(R.id.widget_album_art, View.GONE)
}

                if (isPlaying) {
                    setImageViewResource(R.id.btn_play, R.drawable.ic_pause)
                } else {
                    setImageViewResource(R.id.btn_play, R.drawable.ic_play)
                }

                // 7. Click Listener
                setOnClickPendingIntent(R.id.btn_play, getMediaButtonIntent(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
                setOnClickPendingIntent(R.id.btn_next, getMediaButtonIntent(context, KeyEvent.KEYCODE_MEDIA_NEXT))
                setOnClickPendingIntent(R.id.btn_prev, getMediaButtonIntent(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS))

                val intent = Intent(context, MainActivity::class.java)
                intent.action = Intent.ACTION_MAIN
                intent.addCategory(Intent.CATEGORY_LAUNCHER)
                // Diese Flags sind entscheidend bei singleTask:
                intent.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP

                val openAppPendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                setOnClickPendingIntent(R.id.widget_title, openAppPendingIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun getMediaButtonIntent(context: Context, keyCode: Int): PendingIntent {
        val intent = Intent(Intent.ACTION_MEDIA_BUTTON)
        intent.setPackage(context.packageName)
        intent.putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))

        return PendingIntent.getBroadcast(
            context,
            keyCode,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }
}
