import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:mucplay/locator.dart';
import 'package:mucplay/providers/theme_provider.dart';
import 'package:mucplay/services/audio_handler.dart';
import 'package:mucplay/settings/widgets/settings_card.dart';
import 'package:mucplay/settings/widgets/settings_section_header.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class PlayerThemeSettingsScreen extends StatelessWidget {
  const PlayerThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ThemeProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text("Design & Farben")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsSectionHeader(title: "Hintergrund", subtitle: ""),
          SettingsCard(
            child: SwitchListTile(
              title: const Text(
                "Akzentfarbe als Hintergrund nutzen, wenn kein Cover vorhanden",
              ),
              // Optional: Erklärung anzeigen, warum es aus ist
              subtitle: provider.isMonochrome
                  ? Text(
                      "Deaktiviert im Monochrom-Modus",
                      style: TextStyle(color: Theme.of(context).disabledColor),
                    )
                  : null,

              // 1. ZWANGS-AUS: Wenn Monochrom an ist, zeigen wir immer "false" (aus) an.
              // Ansonsten nehmen wir den echten Wert.
              value: provider.isMonochrome
                  ? false
                  : provider.useAccentColorPlayer,

              // 2. DEAKTIVIEREN: Wenn Monochrom an ist, setzen wir onChanged auf null.
              // Das graut den Switch automatisch aus und verhindert Klicks.
              onChanged: provider.isMonochrome
                  ? null
                  : (val) {
                      provider.setUseAccentColorPlayer(val);
                    },
            ),
          ),
          SizedBox(height: 24),
          SettingsSectionHeader(title: "HOMESCREEN WIDGET", subtitle: ""),
          SettingsCard(
            child: Column(
              children: [
                Center(
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
                _buildWidgetPreview(context, provider),
                const SizedBox(height: 30),
                ListTile(
                  title: const Text("Farbschema"),
                  subtitle: Text(_getWidgetModeText(provider)),
                  trailing: DropdownButton<String>(
                    value: _getCurrentMode(provider),
                    underline: Container(),
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
                        _updateWidgetNow(); // Widget sofort neu laden
                      }
                    },
                  ),
                ),

                // Farbwähler anzeigen, wenn "Benutzerdefiniert" gewählt ist
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- HILFSMETHODEN ---

  Widget _buildWidgetPreview(BuildContext context, ThemeProvider provider) {
    // Farben ermitteln (Logik analog zu audio_handler.dart)
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

    // Kontrast
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
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Fake Cover / Icon
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: contentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.music_note, color: contentColor),
          ),
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
                ), // Fake Titel
                const SizedBox(height: 6),
                Container(
                  height: 8,
                  width: 50,
                  color: contentColor.withOpacity(0.5),
                ), // Fake Artist
              ],
            ),
          ),
          // Fake Buttons
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

  void _updateWidgetNow() {
    try {
      final handler = locator<AudioHandler>();
      // Casten auf deine Klasse, da updateWidget dort public ist
      if (handler is AudioPlayerHandler) {
        handler.updateWidget();
      }
    } catch (e) {
      print("Konnte Widget nicht aktualisieren: $e");
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
              // Einfache Konfiguration:
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
                _updateWidgetNow(); // Sofort aktualisieren
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
