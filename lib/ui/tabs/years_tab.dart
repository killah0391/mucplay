import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:mucplay/locator.dart';
import 'package:mucplay/providers/library_provider.dart';
import 'package:mucplay/ui/screens/year_detail_screen.dart';
import 'package:provider/provider.dart';

class YearsTab extends StatelessWidget {
  const YearsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final audioHandler = locator<AudioHandler>();

    return Consumer<LibraryProvider>(
      builder: (context, provider, child) {
        final yearsList = provider.years;

        if (yearsList.isEmpty) {
          return const Center(
            child: Text(
              "Keine Jahresdaten gefunden",
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        // Padding unten für MiniPlayer beachten
        return StreamBuilder<MediaItem?>(
          stream: audioHandler.mediaItem,
          builder: (context, snapshot) {
            final hasPlayer = snapshot.data != null;

            return GridView.builder(
              padding: EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                bottom: hasPlayer ? 100 : 16,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, // 3 Spalten für Jahre sieht gut aus
                childAspectRatio: 1.0, // Quadratisch
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: yearsList.length,
              itemBuilder: (context, index) {
                final entry = yearsList[index];
                final year = entry.key;
                final songs = entry.value;

                // Farbe generieren (gleiche Logik wie DetailScreen)
                final colorSeed = (year * 123456789).abs();
                final baseColor =
                    Colors.primaries[colorSeed % Colors.primaries.length];

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            YearDetailScreen(year: year, songs: songs),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          baseColor.withOpacity(0.7),
                          baseColor.withOpacity(0.3),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          year == 0 ? "?" : "$year",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${songs.length} Titel",
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                          ),
                        ),
                      ],
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
}
