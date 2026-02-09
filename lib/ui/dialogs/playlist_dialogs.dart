import 'package:flutter/material.dart';
import 'package:mucplay/models/playlist_model.dart';
import 'package:mucplay/models/song_model.dart';
import 'package:mucplay/providers/playlist_provider.dart';
import 'package:mucplay/providers/selection_provider.dart';
import 'package:provider/provider.dart';

// Dialog zum Auswählen oder Erstellen
void showAddToPlaylistDialog(BuildContext context, List<SongModel> songsToAdd) {
  showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          "Zur Playlist hinzufügen",
          style: TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Consumer<PlaylistProvider>(
            builder: (context, provider, child) {
              final playlists = provider.playlists;
              final selectionProvider = Provider.of<SelectionProvider>(context);
              return ListView(
                shrinkWrap: true,
                children: [
                  // 1. NEUE ERSTELLEN
                  ListTile(
                    leading: const Icon(Icons.add, color: Colors.blueAccent),
                    title: const Text(
                      "Neue Playlist erstellen",
                      style: TextStyle(color: Colors.blueAccent),
                    ),
                    onTap: () {
                      Navigator.pop(ctx); // Schließt Auswahl-Dialog

                      // WICHTIG: Wir übergeben 'context' (den vom Screen), nicht 'ctx' (den vom geschlossenen Dialog)
                      showCreatePlaylistNameDialog(
                        context,
                        initialSongs: songsToAdd,
                        selectionProvider: selectionProvider,
                      );
                    },
                  ),
                  const Divider(color: Colors.grey),

                  // 2. BESTEHENDE PLAYLISTEN
                  if (playlists.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text(
                        "Keine Playlisten vorhanden",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),

                  ...playlists.map(
                    (pl) => ListTile(
                      leading: const Icon(
                        Icons.playlist_play,
                        color: Colors.white,
                      ),
                      title: Text(
                        pl.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        "${pl.songPaths.length} Songs",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      onTap: () {
                        // Referenzen sichern VOR dem Schließen
                        final messenger = ScaffoldMessenger.of(context);

                        provider.addSongsToPlaylist(pl, songsToAdd);

                        selectionProvider.clearSelection();

                        Navigator.pop(ctx);

                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              "${songsToAdd.length} Songs zu '${pl.name}' hinzugefügt",
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Abbrechen"),
          ),
        ],
      );
    },
  );
}

// Dialog zur Namenseingabe (für neue Playlist)
void showCreatePlaylistNameDialog(
  BuildContext parentContext, {
  List<SongModel>? initialSongs,
  SelectionProvider? selectionProvider,
}) {
  final controller = TextEditingController();

  showDialog(
    context: parentContext,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text("Neue Playlist", style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        autofocus: true,
        decoration: const InputDecoration(
          hintText: "Name der Playlist",
          hintStyle: TextStyle(color: Colors.white54),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.grey),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text("Abbrechen"),
        ),
        ElevatedButton(
          onPressed: () {
            if (controller.text.isNotEmpty) {
              // 1. Provider und Messenger sichern, SOLANGE der Dialog noch offen ist
              // Wir nutzen 'dialogContext', da dieser garantiert aktiv ist.
              final provider = dialogContext.read<PlaylistProvider>();
              // Für den Messenger nutzen wir den parentContext oder dialogContext (sicherer ist der parentContext für SnackBar)
              final messenger = ScaffoldMessenger.of(dialogContext);

              final name = controller.text;

              // 2. Aktion ausführen
              provider.createPlaylist(name, initialSongs: initialSongs);

              // 3. Dialog schließen
              Navigator.pop(dialogContext);

              // 4. Auswahl aufheben
              selectionProvider!.clearSelection();

              // 4. SnackBar anzeigen (mit dem gesicherten Messenger-Objekt)
              messenger.showSnackBar(
                SnackBar(content: Text("Playlist '$name' erstellt")),
              );
            }
          },
          child: const Text("Erstellen"),
        ),
      ],
    ),
  );
}

// Öffentliche Funktion zum Umbenennen
void showRenamePlaylistDialog(BuildContext context, PlaylistModel playlist) {
  final controller = TextEditingController(text: playlist.name);

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text(
        "Playlist umbenennen",
        style: TextStyle(color: Colors.white),
      ),
      content: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        autofocus: true,
        decoration: const InputDecoration(
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.grey),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text("Abbrechen"),
        ),
        ElevatedButton(
          onPressed: () {
            if (controller.text.isNotEmpty) {
              // Gleiches Prinzip: Erst Zugriff, dann Pop
              final provider = ctx.read<PlaylistProvider>();
              provider.renamePlaylist(playlist, controller.text);
              Navigator.pop(ctx);
            }
          },
          child: const Text("Speichern"),
        ),
      ],
    ),
  );
}
