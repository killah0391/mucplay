import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mucplay/models/song_model.dart';
import 'package:mucplay/providers/library_provider.dart';
import 'package:provider/provider.dart';

class AlbumArtWidget extends StatelessWidget {
  final SongModel song;
  final double size;
  final double borderRadius;
  final bool withShadow;
  final bool isAlbum;
  final bool isMiniPlayer;
  final bool allowOverlay;
  // NEU: Wenn true, wird kein Hintergrund gezeichnet (für GlassmorphicContainer)
  final bool transparentBackground;

  const AlbumArtWidget({
    super.key,
    required this.song,
    this.size = 50,
    this.borderRadius = 8,
    this.withShadow = false,
    this.isAlbum = false,
    this.isMiniPlayer = false,
    this.allowOverlay = true,
    this.transparentBackground = false, // Standard: Zeichne Hintergrund
  });

  @override
  Widget build(BuildContext context) {
    final libraryProvider = Provider.of<LibraryProvider>(context);

    // --- 1. Prüfen, ob Song spielt ---
    bool isPlayingThis = false;
    final currentId = libraryProvider.currentSongId;
    // ... (Deine Logik hier bleibt gleich) ...
    if (currentId != null) {
      if (isAlbum) {
        try {
          final playingSong = libraryProvider.songs.firstWhere(
            (s) => s.path == currentId,
          );

          isPlayingThis =
              playingSong.album == song.album &&
              playingSong.artist == song.artist;
        } catch (_) {
          isPlayingThis = false;
        }
      } else {
        isPlayingThis = currentId == song.path;
      }
    }

    // --- Logik Definition ---
    final bool showOverlay =
        isPlayingThis && !isAlbum && !isMiniPlayer && allowOverlay;
    final bool shouldShowPlaceholderIcon =
        isMiniPlayer || !showOverlay || !isPlayingThis;

    // --- 2. Content laden ---
    Widget content;
    if (song.artUri != null && File(song.artUri!).existsSync()) {
      content = Image.file(
        File(song.artUri!),
        fit: BoxFit.cover,
        width: size,
        height: size,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) =>
            _buildPlaceholderIcon(context, showIcon: shouldShowPlaceholderIcon),
      );
    } else {
      content = _buildPlaceholderIcon(
        context,
        showIcon: shouldShowPlaceholderIcon,
      );
    }

    // --- 3. UI Bauen ---
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        // WICHTIG: Wenn transparentBackground an ist, Farbe auf transparent setzen
        // Sonst Theme.cardColor nutzen
        color: transparentBackground
            ? Colors.transparent
            : Theme.of(context).cardColor,
        boxShadow: withShadow
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: content,
          ),

          if (showOverlay)
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withAlpha(160),
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              child: Center(
                child: Icon(
                  Icons.bar_chart,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: size * 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderIcon(BuildContext context, {bool showIcon = true}) {
    final colorScheme = Theme.of(context).colorScheme;

    final iconColor = isMiniPlayer
        ? colorScheme.primary
        : colorScheme.onPrimary;

    // WICHTIG: Hintergrundlogik anpassen
    Color bgColor;
    if (transparentBackground) {
      // Im FullPlayer (Glas) -> Komplett transparent, damit Glas wirkt
      bgColor = Colors.transparent;
    } else if (isMiniPlayer) {
      bgColor = colorScheme.onPrimary;
    } else {
      bgColor = colorScheme.primary;
    }

    return Container(
      color: bgColor,
      child: Center(
        child: showIcon
            ? Icon(
                isAlbum ? Icons.album : Icons.music_note,
                color:
                    iconColor, // Im Glas-Container ist das Icon dann weiß (onPrimary)
                size: size * 0.5,
              )
            : null,
      ),
    );
  }
}
