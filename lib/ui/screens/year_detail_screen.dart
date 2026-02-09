import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:mucplay/locator.dart';
import 'package:mucplay/models/song_model.dart';
import 'package:mucplay/providers/library_provider.dart';
import 'package:mucplay/ui/widgets/song_tile.dart';
import 'package:provider/provider.dart';

class YearDetailScreen extends StatelessWidget {
  final int year;
  final List<SongModel> songs;

  const YearDetailScreen({super.key, required this.year, required this.songs});

  @override
  Widget build(BuildContext context) {
    final audioHandler = locator<AudioHandler>();
    final title = year == 0 ? "Unbekanntes Jahr" : year.toString();

    // Generiere eine deterministische Farbe basierend auf dem Jahr
    // Damit hat 2023 immer die gleiche Farbe, 2022 eine andere etc.
    final colorSeed = (year * 123456789).abs();
    final baseColor = Colors.primaries[colorSeed % Colors.primaries.length];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Consumer<LibraryProvider>(
        builder: (context, provider, child) {
          return CustomScrollView(
            slivers: [
              // --- HEADER ---
              SliverAppBar(
                expandedHeight: 200.0,
                pinned: true,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                backgroundColor: Theme.of(context).colorScheme.primary,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                    onPressed: () {
                      provider.playSong(songs, 0);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.shuffle, color: Colors.white),
                    onPressed: () async {
                      await provider.playSong(songs, 0);
                      audioHandler.setShuffleMode(AudioServiceShuffleMode.all);
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                    ),
                  ),
                  centerTitle: true,
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [baseColor.withOpacity(0.8), Colors.black87],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        year == 0 ? "?" : "$year",
                        style: TextStyle(
                          fontSize: 80,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // --- SONG LISTE ---
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final song = songs[index];
                  final isCurrent = provider.currentSongId == song.path;

                  return SongTile(
                    song: song,
                    isCurrent: isCurrent,
                    onTap: () {
                      // Spiele nur die Songs dieses Jahres ab
                      provider.playSong(songs, index);
                    },
                  );
                }, childCount: songs.length),
              ),

              // Platzhalter für MiniPlayer
              StreamBuilder<MediaItem?>(
                stream: audioHandler.mediaItem,
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    return const SliverToBoxAdapter(
                      child: SizedBox(height: 100),
                    );
                  }
                  return const SliverToBoxAdapter(child: SizedBox(height: 16));
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
