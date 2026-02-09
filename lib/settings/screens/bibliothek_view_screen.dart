import 'package:flutter/material.dart';
import 'package:mucplay/providers/library_provider.dart';
import 'package:mucplay/settings/widgets/settings_card.dart';
import 'package:mucplay/settings/widgets/settings_radio_tile.dart';
import 'package:mucplay/settings/widgets/settings_section_header.dart';
import 'package:provider/provider.dart';

class BibliothekViewScreen extends StatelessWidget {
  const BibliothekViewScreen({super.key});

  // Hilfsfunktion für schöne Namen
  String _getTabName(String key) {
    switch (key) {
      case 'songs':
        return 'Titel';
      case 'playlists':
        return 'Playlists';
      case 'albums':
        return 'Alben';
      case 'artists':
        return 'Interpreten';
      case 'genres':
        return 'Genres';
      case 'years':
        return 'Jahre';
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bibliothek Anzeige')),
      body: Consumer<LibraryProvider>(
        builder: (context, provider, child) {
          // 1. Aktuelle Reihenfolge laden
          final fullOrder = provider.tabOrder;

          // 2. Filtern: Playlists nur anzeigen, wenn Modus == 'tab'
          final visibleItems = List<String>.from(fullOrder);
          if (provider.playlistNavigationMode == 'nav') {
            visibleItems.remove('playlists');
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SettingsSectionHeader(title: "Playlists", subtitle: ""),
                SettingsCard(
                  child: RadioGroup<String>(
                    groupValue: provider.playlistNavigationMode,
                    onChanged: (val) {
                      if (val != null) {
                        provider.setPlaylistNavigationMode(val);
                      }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            right: 16,
                            left: 16,
                            top: 16,
                          ),
                          child: Text(
                            "Anzeige der Playlists", // Kurz und klar
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(
                            left: 16,
                            right: 16,
                            bottom: 16,
                          ),
                          child: Text(
                            "Wähle den Anzeigeort für deine Playlists", // Kurz und klar
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withAlpha(128),
                            ),
                          ),
                        ),
                        SettingsRadioTile(
                          title: "Untere Navigation",
                          value: "nav",
                        ),
                        SettingsRadioTile(
                          title: "Bibliothek (Tab)",
                          value: "tab",
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                const SettingsSectionHeader(title: "Tabs", subtitle: ""),

                SettingsCard(
                  child: SwitchListTile(
                    title: Text(
                      "Wischen zwischen Tabs",
                      style: TextStyle(fontSize: 18),
                    ),
                    subtitle: Text(
                      "Zwischen Ansichten in der Bibliothek wischen",
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha(128),
                      ),
                    ),
                    value: provider.libraryTabMode,
                    onChanged: (val) {
                      provider.setLibraryTabMode(val);
                    },
                  ),
                ),

                const SizedBox(height: 8),

                // DRAG AND DROP LISTE
                // Wir nutzen SettingsCard für den Hintergrund, aber ohne Padding innen,
                // damit die Items schön aussehen.
                Padding(
                  padding: const EdgeInsets.only(left: 4.0, right: 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: Theme.of(
                        context,
                      ).cardColor, // Hintergrund wie SettingsCard
                      child: ReorderableListView(
                        header: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Tabs neu anordnen",
                                style: TextStyle(fontSize: 18),
                              ),
                              Text(
                                "Zum verschieben gedrückt halten",
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withAlpha(128),
                                ),
                              ),
                            ],
                          ),
                        ),
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        // ProxyDecorator sorgt für Transparenz beim Ziehen
                        proxyDecorator: (child, index, animation) {
                          return Material(
                            color: Colors.transparent,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).cardColor.withOpacity(0.9),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: child,
                            ),
                          );
                        },
                        children: [
                          for (final key in visibleItems)
                            ListTile(
                              key: ValueKey(key),
                              title: Text(
                                _getTabName(key),
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.color,
                                ),
                              ),
                              leading: const Icon(
                                Icons.drag_handle,
                                color: Colors.grey,
                              ),
                              tileColor: Colors.transparent,
                            ),
                        ],
                        onReorder: (oldIndex, newIndex) {
                          if (oldIndex < newIndex) {
                            newIndex -= 1;
                          }

                          // Liste lokal ändern
                          final item = visibleItems.removeAt(oldIndex);
                          visibleItems.insert(newIndex, item);

                          // Wenn 'playlists' ausgeblendet war, müssen wir es wieder
                          // in die Liste integrieren, bevor wir speichern, damit es nicht verloren geht.
                          List<String> newFullOrder = List.from(visibleItems);

                          if (provider.playlistNavigationMode == 'nav') {
                            // Einfach ans Ende hängen (oder an alter Stelle lassen, hier einfacher: Ende)
                            // Da es eh ausgeblendet ist, ist die Position egal.
                            if (!newFullOrder.contains('playlists')) {
                              newFullOrder.add('playlists');
                            }
                          }

                          // Speichern
                          provider.setTabOrder(newFullOrder);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
