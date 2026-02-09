import 'package:flutter/material.dart';
import 'package:mucplay/models/playlist_model.dart';
import 'package:mucplay/providers/library_provider.dart';
import 'package:mucplay/providers/playlist_provider.dart';
import 'package:mucplay/providers/selection_provider.dart';
import 'package:mucplay/ui/dialogs/playlist_dialogs.dart';
import 'package:mucplay/ui/widgets/song_tile.dart';
import 'package:provider/provider.dart';

class PlaylistDetailScreen extends StatelessWidget {
  final PlaylistModel playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    // SelectionProvider hier nutzen, um Löschen zu ermöglichen
    final selectionProvider = Provider.of<SelectionProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: selectionProvider.isSelectionMode
          ? null // Wenn selektiert wird, zeigt der MainScreen die SelectionBar (oder wir bauen hier eine custom AppBar)
          : AppBar(
              title: Text(playlist.name),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => showRenamePlaylistDialog(context, playlist),
                ),
                IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () {
                    final songs = context
                        .read<PlaylistProvider>()
                        .getSongsForPlaylist(playlist);
                    if (songs.isNotEmpty) {
                      context.read<PlaylistProvider>().setActivePlaylist(
                        playlist.name,
                      );
                      context.read<LibraryProvider>().playSong(songs, 0);
                    }
                  },
                ),
              ],
            ),
      // Wenn wir im Selection Mode sind, zeigen wir hier unten eine Leiste zum "Entfernen aus Playlist"
      bottomNavigationBar: selectionProvider.isSelectionMode
          ? Container(
              color: Colors.redAccent,
              height: 60,
              child: InkWell(
                onTap: () {
                  context.read<PlaylistProvider>().removeSongsFromPlaylist(
                    playlist,
                    selectionProvider.selectedSongs,
                  );
                  selectionProvider.clearSelection();
                },
                child: const Center(
                  child: Text(
                    "Aus Playlist entfernen",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            )
          : null,

      body: Consumer<PlaylistProvider>(
        builder: (context, provider, child) {
          // Songs auflösen
          final songs = provider.getSongsForPlaylist(playlist);
          final currentSongId = context.watch<LibraryProvider>().currentSongId;

          if (songs.isEmpty) {
            return const Center(
              child: Text(
                "Playlist ist leer",
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return SongTile(
                song: song,
                isCurrent: currentSongId == song.path,
                onTap: () {
                  // Entweder selektieren oder abspielen
                  if (selectionProvider.isSelectionMode) {
                    selectionProvider.toggleSong(song);
                  } else {
                    context.read<PlaylistProvider>().setActivePlaylist(
                      playlist.name,
                    );
                    context.read<LibraryProvider>().playSong(songs, index);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
