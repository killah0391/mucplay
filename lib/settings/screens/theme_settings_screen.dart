import 'package:flutter/material.dart';
import 'package:mucplay/providers/theme_provider.dart';
import 'package:mucplay/settings/widgets/settings_card.dart';
import 'package:mucplay/settings/widgets/settings_radio_tile.dart';
import 'package:mucplay/settings/widgets/settings_section_header.dart';
import 'package:provider/provider.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  final List<Color> accentColors = const [
    Colors.blueAccent,
    Colors.redAccent,
    Colors.greenAccent,
    Colors.orangeAccent,
    Colors.purpleAccent,
    Colors.pinkAccent,
    Colors.tealAccent,
    Colors.amberAccent,
    Colors.indigoAccent,
    Color.fromARGB(255, 20, 209, 209),
    Colors.limeAccent,
    Colors.lightBlueAccent,
    Colors.deepPurpleAccent,
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ThemeProvider>();

    // Prüfen, ob Farbeinstellungen deaktiviert werden sollen
    final bool disableColorSettings = provider.isMonochrome;
    final bool disableColorPicker =
        provider.isMonochrome || provider.useSystemColor;

    return Scaffold(
      appBar: AppBar(title: const Text("Design & Farben")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsSectionHeader(title: "THEME MODUS", subtitle: ""),
          SettingsCard(
            child: RadioGroup<String>(
              groupValue: provider.currentThemeMode,
              onChanged: (val) {
                if (val != null) provider.setThemeMode(val);
              },
              child: Column(
                children: [
                  SettingsRadioTile(
                    title: "System (Automatisch)",
                    value: "system",
                  ),
                  SettingsRadioTile(title: "Hell", value: "light"),
                  SettingsRadioTile(title: "Dunkel (Grau)", value: "dark"),
                  SettingsRadioTile(
                    title: "Amoled (Tiefschwarz)",
                    value: "amoled",
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          SettingsSectionHeader(title: "AKZENTFARBE", subtitle: ""),

          // 1. Monochrom Schalter (Override für alles)
          SettingsCard(
            child: SwitchListTile(
              title: Text(
                "Monochrom (Schwarz/Weiß)",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                "Deaktiviert alle bunten Akzentfarben",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(96),
                  fontSize: 12,
                ),
              ),
              value: provider.isMonochrome,
              activeColor: Colors.grey, // Neutraler Switch
              onChanged: (val) {
                provider.setMonochrome(val);
                // if (val == true && provider.useAccentColorPlayer) {
                //   provider.setUseAccentColorPlayer(false);
                // }
              },
            ),
          ),

          const SizedBox(height: 12),

          // 2. Systemfarben (Deaktiviert wenn Monochrom an ist)
          Opacity(
            opacity: disableColorSettings ? 0.5 : 1.0,
            child: AbsorbPointer(
              absorbing: disableColorSettings,
              child: SettingsCard(
                child: SwitchListTile(
                  title: Text(
                    "Systemfarben nutzen (Material You)",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    "Passt sich deinem Hintergrundbild an",
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(96),
                      fontSize: 12,
                    ),
                  ),
                  value: provider.useSystemColor,
                  activeColor: provider.useSystemColor
                      ? Theme.of(context).colorScheme.primary
                      : provider.currentAccentColor,
                  onChanged: (val) => provider.setUseSystemColor(val),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // 3. Farbauswahl (Deaktiviert wenn Monochrom ODER Systemfarben an)
          Opacity(
            opacity: disableColorPicker ? 0.5 : 1.0,
            child: AbsorbPointer(
              absorbing: disableColorPicker,
              child: SettingsCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: accentColors.map((color) {
                      final isSelected = provider.currentAccentColor == color;
                      return GestureDetector(
                        onTap: () => provider.setAccentColor(color),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected && !disableColorPicker
                                ? Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                    width: 3,
                                  )
                                : null,
                          ),
                          child: (isSelected && !disableColorPicker)
                              ? Icon(
                                  Icons.check,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          SettingsSectionHeader(title: "INTENSITÄT", subtitle: ""),

          // Kräftige Farben Switch (Auch bei Monochrom verfügbar für maximalen Kontrast)
          Opacity(
            opacity: disableColorPicker ? 0.5 : 1.0,
            child: AbsorbPointer(
              absorbing: disableColorPicker,
              child: SettingsCard(
                child: SwitchListTile(
                  title: Text(
                    "Kräftige Farben erzwingen",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    "Nutzt exakt die gewählte Farbe statt Tönen",
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(96),
                      fontSize: 12,
                    ),
                  ),
                  // Bei Monochrom ist der Switch grau, sonst hat er die Akzentfarbe
                  activeThumbColor: provider.currentAccentColor,
                  activeTrackColor: provider.isMonochrome ? Colors.grey : null,
                  value: provider.forceBoldColors,
                  onChanged: (val) {
                    provider.setForceBoldColors(val);
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),
          // Vorschau Bereich
          Center(
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: const Text("Vorschau Button"),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
