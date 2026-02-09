import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:mucplay/locator.dart';
import 'package:mucplay/providers/playlist_provider.dart';
import 'package:provider/provider.dart';
import '../../models/album_model.dart';
import '../../providers/library_provider.dart';
import '../widgets/song_tile.dart';

class AlbumDetailScreen extends StatelessWidget {
  final AlbumModel album;

  const AlbumDetailScreen({super.key, required this.album});

  @override
  Widget build(BuildContext context) {
    final audioHandler = locator<AudioHandler>();
    final currentSong = audioHandler.mediaItem.value;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Consumer<LibraryProvider>(
        builder: (context, provider, child) {
          return CustomScrollView(
            slivers: [
              // --- APP BAR MIT COVER ---
              SliverAppBar(
                surfaceTintColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                actions: [
                  IconButton(
                    onPressed: () {
                      // audioHandler.setShuffleMode(AudioServiceShuffleMode.all);
                      provider.playSong(album.songs, 0);
                    },
                    icon: Icon(Icons.play_arrow), // <-- Change color
                  ),
                  IconButton(
                    onPressed: () {
                      // audioHandler.setShuffleMode(AudioServiceShuffleMode.all);
                      provider.playSong(album.songs, 0);
                      audioHandler.setShuffleMode(AudioServiceShuffleMode.all);
                    },
                    icon: Icon(Icons.shuffle), // <-- Change color
                  ),
                ],
                expandedHeight: 250.0, // Höhe des Covers
                floating: true,
                pinned: true, // Leiste bleibt oben sichtbar
                backgroundColor: Theme.of(context).colorScheme.surface,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  title: Text(
                    album.name,
                    style: const TextStyle(
                      color: Colors.white,
                      shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Hintergrundbild
                      if (album.artUri != null)
                        Image.file(File(album.artUri!), fit: BoxFit.cover)
                      else
                        Container(
                          color: Theme.of(context).colorScheme.primary,
                          child: const Icon(
                            Icons.album,
                            size: 100,
                            color: Colors.white24,
                          ),
                        ),

                      // Verlauf für bessere Lesbarkeit
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black54],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- LISTE DER SONGS ---
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final song = album.songs[index];
                  final isCurrent = provider.currentSongId == song.path;

                  return SongTile(
                    song: song,
                    isCurrent: isCurrent,
                    onTap: () {
                      // Wichtig: Wir übergeben hier die Liste des ALBUMS, nicht alle Songs
                      context.read<PlaylistProvider>().setActivePlaylist(null);
                      provider.playSong(album.songs, index);
                    },
                  );
                }, childCount: album.songs.length),
              ),

              // Platzhalter unten, damit der MiniPlayer nichts verdeckt
              SliverToBoxAdapter(
                child: SizedBox(height: currentSong != null ? 100 : 16),
              ),
            ],
          );
        },
      ),
    );
  }
}
