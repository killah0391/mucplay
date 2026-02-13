package com.example.mucplay // <--- Dein Package prüfen!

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Bundle
import android.view.KeyEvent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import android.graphics.BitmapFactory
import android.view.View
import java.io.File
import android.content.ComponentName
import android.os.Build

class MusicWidgetProvider : HomeWidgetProvider() {

    // --- NEU: Diese Methode wird gefeuert, wenn der Nutzer das Widget vergrößert/verkleinert ---
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)

        // Wir laden die Flutter-Daten und erzwingen ein Update des Widgets
        val widgetData = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId), widgetData)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->

            // --- NEU: Größe des Widgets auslesen ---
            val options = appWidgetManager.getAppWidgetOptions(widgetId)
            val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)

            // Ein 1-zeiliges Widget hat meist ca. 40-70dp.
            // Ab 100dp gehen wir davon aus, dass der Nutzer es groß gezogen hat.
            val isTall = minHeight >= 100

            // Layout basierend auf der Größe wählen (Schalter-Einstellungen werden ignoriert)
            val layoutId = if (isTall) {
                R.layout.widget_music_vertical
            } else {
                R.layout.widget_music
            }

            val views = RemoteViews(context.packageName, layoutId).apply {

                // 1. Daten laden
                val title = widgetData.getString("title", "Kein Titel")
                val artist = widgetData.getString("artist", "Unbekannt")
                val isPlaying = widgetData.getBoolean("isPlaying", false)

                // 2. Farben laden
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
                setTextViewText(R.id.widget_title, title)
                setTextViewText(R.id.widget_artist, artist)

                // 3. Cover Bild laden
                val showCover = widgetData.getBoolean("show_cover", true)
                val coverPath = widgetData.getString("cover_path", null)

                if (showCover) {
                    setViewVisibility(R.id.widget_album_art, View.VISIBLE)
                    var bitmapSet = false

                    if (coverPath != null) {
                        val imgFile = File(coverPath)
                        if (imgFile.exists()) {
                            val bitmap = BitmapFactory.decodeFile(imgFile.absolutePath)
                            if (bitmap != null) {
                                setImageViewBitmap(R.id.widget_album_art, bitmap)
                                setInt(R.id.widget_album_art, "setColorFilter", 0)
                                bitmapSet = true
                            }
                        }
                    }

                    if (!bitmapSet) {
                        setImageViewResource(R.id.widget_album_art, R.drawable.ic_music_note)
                        val safeColor = if (onColor != 0) onColor else -1
                        setInt(R.id.widget_album_art, "setColorFilter", safeColor)
                    }
                } else {
                    setViewVisibility(R.id.widget_album_art, View.GONE)
                }

                // --- 4. SHUFFLE / REPEAT LOGIK ---
                // Wird nur konfiguriert, wenn das vertikale Layout (isTall) aktiv ist
                if (layoutId == R.layout.widget_music_vertical) {

                    // Buttons immer sichtbar machen im großen Widget
                    setViewVisibility(R.id.btn_shuffle, View.VISIBLE)
                    setViewVisibility(R.id.btn_repeat, View.VISIBLE)

                    // Status laden
                    val shuffleActive = widgetData.getBoolean("shuffle_active", false)
                    val repeatMode = widgetData.getString("repeat_mode", "none")

                    val activeColor = onColor

                    // Shuffle-Button
                    setInt(R.id.btn_shuffle, "setColorFilter", activeColor)
                    setInt(R.id.btn_shuffle, "setImageAlpha", if (shuffleActive) 255 else 77)

                    // Repeat-Button
                    when (repeatMode) {
                        "one" -> {
                            setImageViewResource(R.id.btn_repeat, R.drawable.ic_repeat_one)
                            setInt(R.id.btn_repeat, "setColorFilter", activeColor)
                            setInt(R.id.btn_repeat, "setImageAlpha", 255)
                        }
                        "all" -> {
                            setImageViewResource(R.id.btn_repeat, R.drawable.ic_repeat)
                            setInt(R.id.btn_repeat, "setColorFilter", activeColor)
                            setInt(R.id.btn_repeat, "setImageAlpha", 255)
                        }
                        else -> {
                            setImageViewResource(R.id.btn_repeat, R.drawable.ic_repeat)
                            setInt(R.id.btn_repeat, "setColorFilter", activeColor)
                            setInt(R.id.btn_repeat, "setImageAlpha", 77)
                        }
                    }

                    // Click Listener
                    setOnClickPendingIntent(
                        R.id.btn_shuffle,
                        getMediaButtonIntent(context, KeyEvent.KEYCODE_MEDIA_FAST_FORWARD)
                    )

                    setOnClickPendingIntent(
                        R.id.btn_repeat,
                        getMediaButtonIntent(context, KeyEvent.KEYCODE_MEDIA_REWIND)
                    )
                }

                // 5. Play / Pause
                if (isPlaying) {
                    setImageViewResource(R.id.btn_play, R.drawable.ic_pause)
                } else {
                    setImageViewResource(R.id.btn_play, R.drawable.ic_play)
                }

                // 6. Click Listener Controls
                setOnClickPendingIntent(R.id.btn_play, getMediaButtonIntent(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))
                setOnClickPendingIntent(R.id.btn_next, getMediaButtonIntent(context, KeyEvent.KEYCODE_MEDIA_NEXT))
                setOnClickPendingIntent(R.id.btn_prev, getMediaButtonIntent(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS))

                // App Öffnen Listener
                val intent = Intent(context, MainActivity::class.java)
                intent.action = Intent.ACTION_MAIN
                intent.addCategory(Intent.CATEGORY_LAUNCHER)
                intent.flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP

                val openAppPendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.widget_root, openAppPendingIntent)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun getMediaButtonIntent(context: Context, keyCode: Int): PendingIntent {
        val intent = Intent(Intent.ACTION_MEDIA_BUTTON)
        intent.component = ComponentName(context, "com.ryanheise.audioservice.AudioService")
        intent.putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            PendingIntent.getForegroundService(
                context,
                keyCode,
                intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
        } else {
            PendingIntent.getService(
                context,
                keyCode,
                intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
        }
    }
}
