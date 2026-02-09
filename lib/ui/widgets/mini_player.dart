import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:mucplay/models/song_model.dart';
import 'package:mucplay/ui/widgets/album_art_widget.dart';
import 'package:mucplay/ui/widgets/smart_text.dart';
import '../../locator.dart';

class MiniPlayer extends StatelessWidget {
  // Flag, ob Buttons klickbar sein sollen (optional, hier lassen wir sie immer an)
  final bool isInteractive;

  const MiniPlayer({super.key, this.isInteractive = true});

  @override
  Widget build(BuildContext context) {
    final audioHandler = locator<AudioHandler>();

    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        if (mediaItem == null) return const SizedBox.shrink();

        final currentSong = SongModel(
          path: mediaItem.extras?['path'] ?? '',
          title: mediaItem.title,
          artist: mediaItem.artist ?? 'Unbekannt',
          album: mediaItem.album ?? 'Unbekannt',
          durationMs: mediaItem.duration?.inMilliseconds ?? 0,
          format: mediaItem.extras?['format'] ?? '',
          // WICHTIG: Uri zu Dateipfad konvertieren
          artUri: mediaItem.artUri?.toFilePath(),
          year: mediaItem.extras?['year'] ?? 0,
          genre: mediaItem.genre ?? 'Unbekannt',
        );

        // KEIN GESTURE DETECTOR MEHR (macht der MainScreen)
        // KEIN MARGIN MEHR (füllt den Container aus)
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color:
              Colors.transparent, // Hintergrundfarbe kommt vom Parent Container
          alignment: Alignment.center,
          child: Row(
            children: [
              // 1. Cover Art
              SizedBox(
                width: 50,
                height: 50,
                child: AlbumArtWidget(song: currentSong, isMiniPlayer: true),
              ),
              const SizedBox(width: 12),

              // 2. Titel & Artist
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SmartText(
                      mediaItem.title,
                      Theme.of(context).colorScheme.onPrimary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mediaItem.artist ?? "Unknown",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Controls
              if (isInteractive) ...[
                IconButton(
                  icon: Icon(
                    Icons.skip_previous,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  onPressed: audioHandler.skipToPrevious,
                ),
                StreamBuilder<PlaybackState>(
                  stream: audioHandler.playbackState,
                  builder: (context, stateSnapshot) {
                    final playing = stateSnapshot.data?.playing ?? false;
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: StreamBuilder<Duration>(
                            stream: AudioService.position,
                            initialData:
                                audioHandler.playbackState.value.position,
                            builder: (context, posSnapshot) {
                              final position =
                                  posSnapshot.data ?? Duration.zero;
                              final duration =
                                  mediaItem.duration ?? Duration.zero;
                              double progress = 0.0;
                              if (duration.inMilliseconds > 0) {
                                progress =
                                    (position.inMilliseconds /
                                            duration.inMilliseconds)
                                        .clamp(0.0, 1.0);
                              }
                              return CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation(
                                  Theme.of(context).colorScheme.onPrimary,
                                ),
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.onPrimary.withAlpha(64),
                              );
                            },
                          ),
                        ),
                        IconButton(
                          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                          color: Theme.of(context).colorScheme.onPrimary,
                          iconSize: 20,
                          onPressed: playing
                              ? audioHandler.pause
                              : audioHandler.play,
                        ),
                      ],
                    );
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.skip_next,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  onPressed: audioHandler.skipToNext,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
