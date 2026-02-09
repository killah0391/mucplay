import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:mucplay/models/song_model.dart';
import 'package:mucplay/services/audio_handler.dart';

import 'package:mucplay/ui/widgets/album_art_widget.dart';
import 'package:mucplay/ui/widgets/smart_text.dart';

void queuePopup(BuildContext context, AudioHandler audioHandler) {
  showModalBottomSheet(
    backgroundColor: Colors.transparent,
    context: context,
    isScrollControlled: true, // Ermöglicht volle Höhe falls nötig
    builder: (context) {
      // 1. Stream für die Liste (Queue)
      return StreamBuilder<List<MediaItem>>(
        stream: audioHandler.queue,
        builder: (context, queueSnapshot) {
          final queue = queueSnapshot.data ?? [];

          // 2. Stream für den aktuellen Song (um Index zu finden)
          return StreamBuilder<MediaItem?>(
            stream: audioHandler.mediaItem,
            builder: (context, mediaSnapshot) {
              final currentItem = mediaSnapshot.data;

              // Index und Anzahl berechnen
              int currentIndex = 0;
              if (currentItem != null) {
                // Wir suchen den Index (+1 für "menschliche" Zählung)
                currentIndex =
                    queue.indexWhere((item) => item.id == currentItem.id) + 1;
              }
              final int totalCount = queue.length;

              // Titel generieren
              final String title = totalCount > 0
                  ? 'Warteschlange ($currentIndex/$totalCount)'
                  : 'Warteschlange';

              return ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16.0),
                ),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.75,
                  child: Scaffold(
                    appBar: AppBar(
                      title: Text(title), // HIER steht jetzt z.B. "7/20"
                      centerTitle: true,
                      automaticallyImplyLeading: false,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      elevation: 0,
                      toolbarHeight: 60.0,
                      actions: [
                        StreamBuilder<PlaybackState>(
                          stream: audioHandler.playbackState,
                          builder: (context, snapshot) {
                            final mode =
                                snapshot.data?.shuffleMode ??
                                AudioServiceShuffleMode.none;
                            final isShuffle =
                                mode == AudioServiceShuffleMode.all;

                            return IconButton(
                              icon: Icon(
                                Icons.shuffle,
                                color: isShuffle
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurface.withAlpha(128),
                              ),
                              onPressed: () {
                                final newMode = isShuffle
                                    ? AudioServiceShuffleMode.none
                                    : AudioServiceShuffleMode.all;
                                audioHandler.setShuffleMode(newMode);
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    // Der Body nutzt jetzt direkt die "queue" Variable von oben
                    body: ReorderableListView.builder(
                      // Wichtig für Performance bei ReorderableListView
                      buildDefaultDragHandles: true,

                      // Funktion, die beim Verschieben aufgerufen wird
                      onReorder: (int oldIndex, int newIndex) {
                        // Flutter Eigenheit: Wenn man nach unten verschiebt, erhöht sich der Index um 1
                        // da das Item erst entfernt wird. Das müssen wir korrigieren:
                        if (oldIndex < newIndex) {
                          newIndex -= 1;
                        }

                        // Zugriff auf deine Custom Methode im Handler
                        if (audioHandler is AudioPlayerHandler) {
                          audioHandler.moveQueueItem(oldIndex, newIndex);
                        }
                      },

                      // Optional: Design des gezogenen Items anpassen (ProxyDecorator)
                      proxyDecorator: (child, index, animation) {
                        return Material(
                          color: Colors.transparent,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).cardColor.withOpacity(0.9),
                              // borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: child,
                          ),
                        );
                      },

                      itemCount: queue.length,
                      itemBuilder: (context, i) {
                        final item = queue[i];
                        final song = SongModel(
                          path: item.extras?['path'] ?? '',
                          title: item.title,
                          artist: item.artist ?? 'Unbekannt',
                          album: item.album ?? 'Unbekannt',
                          durationMs: item.duration?.inMilliseconds ?? 0,
                          format: item.extras?['format'] ?? '',
                          artUri: item.artUri?.toFilePath(),
                          year: item.extras?['year'] ?? 0,
                          genre: item.genre ?? 'Unbekannt',
                        );
                        final isCurrent = currentItem?.id == item.id;
                        final bool isDark =
                            Theme.of(context).brightness == Brightness.dark;
                        final int themeMode = isDark ? 64 : 32;
                        String _formatDuration(int milliseconds) {
                          final duration = Duration(milliseconds: milliseconds);
                          final minutes = duration.inMinutes;
                          final seconds = duration.inSeconds
                              .remainder(60)
                              .toString()
                              .padLeft(2, '0');
                          return "$minutes:$seconds";
                        }

                        return ListTile(
                          // WICHTIG: Key muss eindeutig sein für ReorderableListView!
                          key: ValueKey(item.id),

                          selected: isCurrent,
                          selectedTileColor: Theme.of(
                            context,
                          ).colorScheme.primary.withAlpha(themeMode),

                          // Wenn ein Song spielt, zeigen wir den Equalizer,
                          // sonst das "Drag Handle" Icon (optional, aber userfreundlich)
                          tileColor: isCurrent
                              ? Theme.of(
                                  context,
                                ).colorScheme.primary.withAlpha(themeMode)
                              : null,
                          leading: SizedBox(
                            width: 50,
                            height: 50,
                            child: AlbumArtWidget(
                              song: song,
                              size: 50,
                              borderRadius: 8,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: isCurrent
                                    ? SmartText(
                                        item.title,
                                        isCurrent
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onSurface
                                            : null,
                                      )
                                    : Text(
                                        item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: isCurrent
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.onSurface
                                              : null,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDuration(song.durationMs),
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withAlpha(128),
                                  fontSize:
                                      12, // Etwas kleiner, damit es dezent wirkt
                                ),
                              ),
                            ],
                          ),

                          subtitle: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  song.format,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: isCurrent
                                    ? SmartText(
                                        "${song.artist} • ${song.album}",
                                        Theme.of(
                                          context,
                                        ).colorScheme.onSurface.withAlpha(128),
                                      )
                                    : Text(
                                        "${song.artist} • ${song.album}",
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withAlpha(128),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                              ),

                              // --- NEU: DAUER ANZEIGE ---
                              // const SizedBox(width: 8),
                              // Text(
                              //   _formatDuration(song.durationMs),
                              //   style: TextStyle(
                              //     color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
                              //     fontSize: 12, // Etwas kleiner, damit es dezent wirkt
                              //   ),
                              // ),

                              // ---------------------------
                              // if (song.year.toString() != 'null' &&
                              //     song.year != null &&
                              //     song.year != 0) ...[
                              //   // const SizedBox(width: 8),
                              //   Text(
                              //     "${song.year}", // Kleiner Punkt zur Trennung
                              //     style: TextStyle(
                              //       color: Theme.of(
                              //         context,
                              //       ).colorScheme.onSurface.withAlpha(128),
                              //       fontSize: 12,
                              //     ),
                              //   ),
                              // ],
                            ],
                          ),
                          trailing: Icon(
                            Icons.drag_handle, // Zeigt an, dass man ziehen kann
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.5),
                          ),
                          onTap: () {
                            audioHandler.skipToQueueItem(i);
                          },
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    },
  );
}
