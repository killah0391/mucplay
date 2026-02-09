import 'package:flutter/material.dart';

import 'package:mucplay/providers/selection_provider.dart';
import 'package:mucplay/ui/utils/song_options.dart';
import 'package:mucplay/ui/widgets/album_art_widget.dart';
import 'package:mucplay/ui/widgets/smart_text.dart';
import 'package:provider/provider.dart';
import '../../models/song_model.dart';

class SongTile extends StatelessWidget {
  final SongModel song;
  final VoidCallback onTap;
  final bool isCurrent;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final GestureLongPressCallback? onLongPress;

  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.isCurrent = false,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onLongPress,
  });

  // NEU: Hilfsfunktion für die Zeitformatierung (mm:ss)
  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final selectionProvider = Provider.of<SelectionProvider>(context);
    // final isPlaying = libraryProvider.isPlaying; // Wird aktuell nicht genutzt
    final isSelected = selectionProvider.isSelected(song);
    final isSelectionMode = selectionProvider.isSelectionMode;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final int themeMode = isDark ? 64 : 32;

    return ListTile(
      onTap: () {
        if (isSelectionMode) {
          selectionProvider.toggleSong(song);
        } else {
          onTap();
        }
      },
      onLongPress:
          onLongPress ??
          () {
            if (!isSelectionMode) {
              selectionProvider.startSelection(song);
            }
          },
      // isThreeLine: true,
      tileColor: isCurrent
          ? Theme.of(context).colorScheme.primary.withAlpha(themeMode)
          : null,
      leading:
          leading ??
          SizedBox(
            width: 50,
            height: 50,
            child: isSelectionMode
                ? Checkbox(
                    value: isSelected,
                    activeColor: Theme.of(context).colorScheme.primary,
                    onChanged: (val) => selectionProvider.toggleSong(song),
                  )
                : AlbumArtWidget(song: song, size: 50, borderRadius: 8),
          ),
      title: Row(
        children: [
          Expanded(
            child: isCurrent
                ? SmartText(
                    song.title,
                    isCurrent ? Theme.of(context).colorScheme.onSurface : null,
                  )
                : Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent
                          ? Theme.of(context).colorScheme.onSurface
                          : null,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatDuration(song.durationMs),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
              fontSize: 12, // Etwas kleiner, damit es dezent wirkt
            ),
          ),
        ],
      ),

      subtitle:
          subtitle ??
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  song.format,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: isCurrent
                    ? SmartText(
                        "${song.artist} • ${song.album}",
                        Theme.of(context).colorScheme.onSurface.withAlpha(128),
                      )
                    : Text(
                        "${song.artist} • ${song.album}",
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withAlpha(128),
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
      trailing:
          trailing ??
          IconButton(
            icon: Icon(Icons.more_vert),
            onPressed: () {
              songOptions(context, song);
            },
          ),
    );
  }
}
