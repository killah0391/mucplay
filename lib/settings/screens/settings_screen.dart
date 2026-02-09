import 'package:flutter/material.dart';
import 'package:mucplay/providers/theme_provider.dart';
import 'package:mucplay/settings/screens/bibliothek_view_screen.dart';
import 'package:mucplay/settings/screens/folder_management_screen.dart';
import 'package:mucplay/settings/screens/player_theme_settings_screen.dart';
import 'package:mucplay/settings/screens/statistics_settings_screen.dart';
import 'package:mucplay/settings/screens/theme_settings_screen.dart';
import 'package:mucplay/settings/widgets/settings_card.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final surfaceColor = themeProvider.currentThemeMode == "amoled"
        ? Theme.of(context).scaffoldBackgroundColor
        : Theme.of(context).colorScheme.surface;
    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        title: Text('Einstellungen'),
        backgroundColor: surfaceColor,
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          _buildCategoryHeader(context, "BIBLIOTHEK"),
          _buildSettingsTile(
            context,
            icon: Icons.folder_open,
            title: "Musik-Quellen verwalten",
            subtitle: "Ordner auswählen und scannen",
            targetScreen: FolderManagementScreen(),
          ),
          // _buildCategoryHeader(context, "Oberfläche"),
          _buildSettingsTile(
            context,
            icon: Icons.view_carousel,
            title: "Anzeige",
            subtitle: "Erscheinungsbild der Bibliothek",
            targetScreen: BibliothekViewScreen(),
          ),
          _buildCategoryHeader(context, "DARSTELLUNG"),
          _buildSettingsTile(
            context,
            icon: Icons.color_lens,
            title: "Design & Farben",
            subtitle: "Theme, Akzentfarbe, Amoled Modus",
            targetScreen: ThemeSettingsScreen(),
          ),
          _buildSettingsTile(
            context,
            icon: Icons.play_arrow,
            title: "Player",
            subtitle: "Darstellung des Players anpassen",
            targetScreen: PlayerThemeSettingsScreen(),
          ),
          _buildCategoryHeader(context, "EXTRAS"),
          _buildSettingsTile(
            context,
            icon: Icons.color_lens,
            title: "Statistiken",
            subtitle: "Aktivieren/Deaktivieren der Statistiken",
            targetScreen: StatisticsScreen(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget targetScreen,
  }) {
    return SettingsCard(
      // color: Colors.blueAccent.withAlpha(32),
      // margin: const EdgeInsets.only(bottom: 12),
      // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.onSurface),
        title: Text(
          title,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withAlpha(96),
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => targetScreen),
          );
        },
      ),
    );
  }
}
