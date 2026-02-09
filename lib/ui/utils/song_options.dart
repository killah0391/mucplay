import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:mucplay/models/song_model.dart';
import 'package:mucplay/providers/library_provider.dart';
import 'package:mucplay/providers/selection_provider.dart';
import 'package:mucplay/ui/dialogs/playlist_dialogs.dart';
import 'package:mucplay/ui/utils/delete_confirmation.dart';
import 'package:mucplay/ui/utils/tag_editor_dialog.dart';
import 'package:provider/provider.dart';
import 'package:mucplay/locator.dart';
import 'package:mucplay/services/audio_handler.dart'; // Wichtig für den Cast

void songOptions(
  BuildContext context,
  SongModel song, {
  bool playSong = true,
  bool deleteSong = true,
  bool playNext = true,
}) {
  showDialog(
    context: context,
    builder: (ctx) {
      final library = context.read<LibraryProvider>();
      final selectionProvider = context.read<SelectionProvider>();
      final audioHandler = locator<AudioHandler>();
      final currentSong = audioHandler.mediaItem.value;
      final isCurrentSongActive = audioHandler.mediaItem.value?.id == song.path;

      List<SongModel> targetSongs = [song];
      String title = song.title;

      if (selectionProvider.isSelectionMode &&
          selectionProvider.isSelected(song)) {
        final songPlural = selectionProvider.selectedCount > 1
            ? "Songs"
            : "Song";
        targetSongs = selectionProvider.selectedSongs;
        title = "${targetSongs.length} $songPlural ausgewählt";
      }

      return Dialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.maxFinite,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            ListView(
              padding: EdgeInsets.all(16),
              shrinkWrap: true,
              children: [
                // OPTION 1: ABSPIELEN
                if (playSong)
                  ListTile(
                    leading: Icon(
                      Icons.play_arrow,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    title: Text(
                      'Abspielen',
                      // style: TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      // Wir spielen die targetSongs Liste ab
                      library.playSong(targetSongs, 0);

                      // Auswahl nur löschen, wenn wir im Auswahlmodus waren
                      if (selectionProvider.isSelectionMode) {
                        selectionProvider.clearSelection();
                      }
                    },
                  ),

                // OPTION 2: ALS NÄCHSTES SPIELEN
                if (playNext && currentSong != null && !isCurrentSongActive)
                  ListTile(
                    leading: Icon(Icons.queue_music),
                    title: const Text(
                      'Als nächstes spielen',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);

                      // 1. targetSongs in MediaItems umwandeln
                      final List<MediaItem> itemsToQueue = targetSongs.map((s) {
                        return MediaItem(
                          id: s.path,
                          album: s.album,
                          title: s.title,
                          artist: s.artist,
                          duration: Duration(milliseconds: s.durationMs),
                          artUri: s.artUri != null ? Uri.file(s.artUri!) : null,
                          extras: {'path': s.path, 'format': s.format},
                        );
                      }).toList();

                      // 2. AudioHandler abrufen und casten
                      if (itemsToQueue.isNotEmpty) {
                        // final audioHandler = locator<AudioHandler>();
                        await (audioHandler as AudioPlayerHandler).playNext(
                          itemsToQueue,
                        );
                      }

                      // 3. Auswahl aufheben
                      if (selectionProvider.isSelectionMode) {
                        selectionProvider.clearSelection();
                      }
                    },
                  ),

                if (targetSongs.length == 1)
                  ListTile(
                    leading: const Icon(Icons.edit),
                    title: const Text('Tags bearbeiten'),
                    onTap: () {
                      Navigator.of(ctx).pop(); // Schließt das Options-Menü

                      // Öffnet den Tag Editor
                      showDialog(
                        context: context,
                        builder: (context) =>
                            TagEditorDialog(song: targetSongs.first),
                      );
                    },
                  ),

                ListTile(
                  leading: const Icon(Icons.playlist_add),
                  title: const Text('Zur Playlist hinzufügen'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    showAddToPlaylistDialog(context, targetSongs);
                  },
                ),

                if (deleteSong)
                  ListTile(
                    leading: const Icon(Icons.delete, color: Colors.redAccent),
                    title: const Text(
                      'Löschen',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      deleteConfirmation(context, targetSongs);
                    },
                  ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
