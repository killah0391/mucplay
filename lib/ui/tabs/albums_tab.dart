import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:mucplay/locator.dart';
import 'package:provider/provider.dart';
import '../../providers/library_provider.dart';
import '../screens/album_detail_screen.dart';

class AlbumsTab extends StatelessWidget {
  const AlbumsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final audioHandler = locator<AudioHandler>();
    final currentSong = audioHandler.mediaItem.value;
    return Consumer<LibraryProvider>(
      builder: (context, provider, child) {
        final albums = provider.albums;

        if (albums.isEmpty) {
          return const Center(
            child: Text(
              "Keine Alben gefunden",
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return GridView.builder(
          padding: EdgeInsets.only(
            top: 16,
            left: 16,
            right: 16,
            bottom: currentSong != null ? 100 : 16,
          ),
          // Grid Layout: 2 Spalten
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio:
                0.75, // Format der Kacheln (etwas höher als breit)
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            return GestureDetector(
              onTap: () {
                // Navigation zur Detailansicht
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AlbumDetailScreen(album: album),
                  ),
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- COVER BILD ---
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[800],
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        image: album.artUri != null
                            ? DecorationImage(
                                image: FileImage(File(album.artUri!)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: album.artUri == null
                          ? const Icon(
                              Icons.album,
                              size: 50,
                              color: Colors.white54,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // --- TEXT INFOS ---
                  Text(
                    album.name == '' ? 'Unknown' : album.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    album.artist == '' ? 'Unknown' : album.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(128),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
