import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:mucplay/locator.dart';
import 'package:mucplay/providers/library_provider.dart';
import 'package:mucplay/providers/playlist_provider.dart';
import 'package:mucplay/ui/dialogs/playlist_dialogs.dart';
import 'package:mucplay/ui/screens/playlist_detail_screen.dart'; // Erstellen wir gleich
import 'package:mucplay/ui/widgets/playlist_fab.dart';
import 'package:provider/provider.dart';

class PlaylistsTab extends StatelessWidget {
  const PlaylistsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final libraryProvider = Provider.of<LibraryProvider>(context);
    return Consumer<PlaylistProvider>(
      builder: (context, provider, child) {
        final playlists = provider.playlists;

        if (playlists.isEmpty) {
          return Stack(
            children: [
              // 1. Der Text (Perfekt zentriert im gesamten Bereich)
              const Center(
                child: Text(
                  "Keine Playlisten",
                  style: TextStyle(color: Colors.grey),
                ),
              ),

              // 2. Der FAB (Unten rechts positioniert)
              Positioned(
                // Padding Logik direkt hier im 'bottom' Property
                bottom: libraryProvider.currentSongId != null ? 108 : 16,
                right: 16,
                child: PlaylistFab(
                  onCreate: () {
                    showCreatePlaylistNameDialog(context);
                  },
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                // padding: const EdgeInsets.all(8),
                itemCount: playlists.length,
                itemBuilder: (context, index) {
                  final pl = playlists[index];
                  final bool isActive = provider.activePlaylistName == pl.name;
                  return ListTile(
                    leading: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[800],
                      ),
                      width: 50,
                      height: 50,
                      // color: Colors.grey[800],
                      child: libraryProvider.isPlaying && isActive
                          ? Icon(Icons.equalizer, color: Colors.white)
                          : Icon(Icons.queue_music, color: Colors.white54),
                    ),
                    title: Text(
                      pl.name,
                      style: TextStyle(
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    subtitle: Text(
                      "${pl.songPaths.length} Titel",
                      style: TextStyle(
                        color: isActive
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withAlpha(196)
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withAlpha(128),
                      ),
                    ),
                    trailing: PopupMenuButton(
                      icon: Icon(
                        Icons.more_vert,
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text("Löschen"),
                        ),
                      ],
                      onSelected: (val) {
                        if (val == 'delete') {
                          provider.deletePlaylist(pl);
                        }
                      },
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => PlaylistDetailScreen(playlist: pl),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    top: 16,
                    right: 16,
                    left: 16,
                    bottom: libraryProvider.currentSongId != null ? 108 : 16,
                  ),
                  child: PlaylistFab(
                    onCreate: () {
                      showCreatePlaylistNameDialog(context);
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
