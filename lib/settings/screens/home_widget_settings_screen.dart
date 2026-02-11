import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:home_widget/home_widget.dart';
import 'package:mucplay/locator.dart';
import 'package:mucplay/providers/theme_provider.dart';
import 'package:mucplay/services/audio_handler.dart';
import 'package:mucplay/settings/widgets/settings_card.dart';
import 'package:provider/provider.dart';

// WICHTIG: Jetzt ein StatefulWidget!
class HomeWidgetSettingsScreen extends StatefulWidget {
  const HomeWidgetSettingsScreen({super.key});

  @override
  State<HomeWidgetSettingsScreen> createState() =>
      _HomeWidgetSettingsScreenState();
}

class _HomeWidgetSettingsScreenState extends State<HomeWidgetSettingsScreen> {
  // Variable für den Schalter
  bool _showWidgetCover = true;

  @override
  void initState() {
    super.initState();
    // Beim Start den gespeicherten Wert laden
    _loadWidgetSettings();
  }

  // Lädt die Einstellung "Cover anzeigen" aus den gespeicherten Widget-Daten
  Future<void> _loadWidgetSettings() async {
    try {
      final value = await HomeWidget.getWidgetData<bool>(
        'show_cover',
        defaultValue: true,
      );
      if (mounted) {
        setState(() {
          _showWidgetCover = value ?? true;
        });
      }
    } catch (e) {
      debugPrint("Fehler beim Laden der Widget-Settings: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ThemeProvider>();
    return Scaffold(
      // Transparenter Hintergrund für den "Overlay"-Look (optional, wie vorhin besprochen)
      backgroundColor: Colors.black.withOpacity(0.85),
      appBar: AppBar(
        title: const Text("Widget Einstellungen"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsCard(
            child: Column(
              children: [
                const Center(
                  child: Text(
                    "VORSCHAU",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Vorschau aktualisieren wir auch mit dem lokalen State
                _buildWidgetPreview(context, provider),
                const SizedBox(height: 30),

                // --- Farbschema ---
                ListTile(
                  title: const Text("Farbschema"),
                  subtitle: Text(_getWidgetModeText(provider)),
                  trailing: DropdownButton<String>(
                    value: _getCurrentMode(provider),
                    underline: Container(),
                    dropdownColor:
                        Colors.grey[900], // Damit man das Menü gut sieht
                    items: const [
                      DropdownMenuItem(
                        value: 'app',
                        child: Text("Wie App Akzent"),
                      ),
                      DropdownMenuItem(
                        value: 'dark',
                        child: Text("Dunkel (Standard)"),
                      ),
                      DropdownMenuItem(
                        value: 'custom',
                        child: Text("Benutzerdefiniert"),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        provider.setWidgetColorMode(val);
                        _updateWidgetNow();
                      }
                    },
                  ),
                ),

                // --- Farbwähler (nur bei Custom) ---
                if (provider.widgetColorMode == 'custom')
                  ListTile(
                    title: const Text("Farbe wählen"),
                    trailing: GestureDetector(
                      onTap: () => _showColorPicker(context, provider),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: provider.widgetCustomColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey),
                        ),
                      ),
                    ),
                  ),

                // --- Cover Schalter ---
                SwitchListTile(
                  title: const Text("Cover im Widget anzeigen"),
                  value: _showWidgetCover,
                  onChanged: (bool value) async {
                    setState(() {
                      _showWidgetCover = value;
                    });

                    // Speichern und Senden
                    await HomeWidget.saveWidgetData<bool>('show_cover', value);

                    // Widget sofort aktualisieren
                    _updateWidgetNow();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWidgetPreview(BuildContext context, ThemeProvider provider) {
    Color bgColor = const Color(0xFF1E1E1E);
    Color contentColor = Colors.white;

    if (provider.widgetColorMode == 'custom') {
      bgColor = provider.widgetCustomColor;
    } else if (provider.widgetColorMode == 'app') {
      bgColor = provider.currentAccentColor;
      if (!provider.forceBoldColors) {
        bgColor = ColorScheme.fromSeed(
          seedColor: bgColor,
          brightness: Brightness.dark,
        ).primary;
      }
    }

    if (ThemeData.estimateBrightnessForColor(bgColor) == Brightness.light) {
      contentColor = Colors.black;
    }

    return Container(
      width: 300,
      height: 90,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Dynamische Vorschau: Zeige Icon oder Platzhalter je nach Switch-State
          if (_showWidgetCover)
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: contentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.music_note, color: contentColor),
            )
          else
            // Wenn aus, ein leerer Container oder gar nichts (wie im echten Widget)
            const SizedBox(width: 0),

          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 10,
                  width: 80,
                  color: contentColor.withOpacity(0.8),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 8,
                  width: 50,
                  color: contentColor.withOpacity(0.5),
                ),
              ],
            ),
          ),
          Icon(Icons.skip_previous, color: contentColor),
          const SizedBox(width: 10),
          Icon(Icons.play_arrow, color: contentColor, size: 32),
          const SizedBox(width: 10),
          Icon(Icons.skip_next, color: contentColor),
        ],
      ),
    );
  }

  String _getWidgetModeText(ThemeProvider provider) {
    switch (provider.widgetColorMode) {
      case 'app':
        return "Nutzt die aktuelle Akzentfarbe der App";
      case 'custom':
        return "Wähle eine eigene Farbe";
      case 'dark':
      default:
        return "Dunkles Standard-Design";
    }
  }

  String _getCurrentMode(ThemeProvider provider) {
    return provider.widgetColorMode;
  }

  void _updateWidgetNow() async {
    try {
      // Spezieller Aufruf für HomeWidget Update
      await HomeWidget.updateWidget(
        name: 'MusicWidgetProvider',
        androidName: 'MusicWidgetProvider',
      );

      // Falls der AudioHandler auch Logik hat, diese auch triggern
      final handler = locator<AudioHandler>();
      if (handler is AudioPlayerHandler) {
        handler.updateWidget();
      }
    } catch (e) {
      debugPrint("Konnte Widget nicht aktualisieren: $e");
    }
  }

  void _showColorPicker(BuildContext context, ThemeProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        Color tempColor = provider.widgetCustomColor;
        return AlertDialog(
          title: const Text("Farbe wählen"),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: tempColor,
              onColorChanged: (color) {
                tempColor = color;
              },
              pickerAreaHeightPercent: 0.8,
              enableAlpha: false,
              displayThumbColor: true,
              paletteType: PaletteType.hsv,
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Abbrechen"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("Speichern"),
              onPressed: () {
                provider.setWidgetCustomColor(tempColor);
                _updateWidgetNow();
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
