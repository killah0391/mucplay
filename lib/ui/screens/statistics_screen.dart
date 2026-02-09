import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mucplay/models/song_model.dart';
import 'package:mucplay/providers/library_provider.dart';
import 'package:mucplay/ui/dialogs/share_stats_dialog.dart';
import 'package:mucplay/ui/widgets/song_tile.dart';
import 'package:provider/provider.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  int _selectedPeriodIndex = 0;

  final List<String> _periodLabels = ["Woche", "Monat", "Jahr", "Gesamt"];

  DateTime _getStartDate(int index) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (index) {
      case 0:
        return today.subtract(Duration(days: now.weekday - 1));
      case 1:
        return DateTime(now.year, now.month, 1);
      case 2:
        return DateTime(now.year, 1, 1);
      case 3:
        return DateTime(2000);
      default:
        return today;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LibraryProvider>(
      builder: (context, provider, child) {
        final recent = provider.recentlyPlayedSongs;
        final cutoffDate = _getStartDate(_selectedPeriodIndex);
        final mostPlayed = provider.getMostPlayedSongs(cutoffDate);

        // ÄNDERUNG 1: Column statt ListView als Haupt-Container
        return Column(
          children: [
            const SizedBox(height: 20), // Abstand oben
            // --- ZULETZT GEHÖRT (Feststehender Bereich) ---
            if (recent.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                // align left wrapper
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    "Zuletzt gehört",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: recent.length,
                  itemBuilder: (context, index) {
                    final song = recent[index];
                    return _buildRecentCard(context, song, provider);
                  },
                ),
              ),
              const SizedBox(height: 30),
            ],

            // --- HEADER AM HÄUFIGSTEN (Feststehender Bereich) ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    "Am häufigsten",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.ios_share,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    tooltip: "Statistik teilen",
                    onPressed: () {
                      if (mostPlayed.isNotEmpty) {
                        showDialog(
                          context: context,
                          builder: (context) => ShareStatsDialog(
                            songs: mostPlayed,
                            period: _periodLabels[_selectedPeriodIndex],
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Keine Daten zum Teilen vorhanden."),
                          ),
                        );
                      }
                    },
                  ),
                  const Spacer(),
                  ToggleButtons(
                    constraints: const BoxConstraints(
                      minHeight: 30,
                      minWidth: 40,
                    ),
                    isSelected: List.generate(
                      4,
                      (i) => i == _selectedPeriodIndex,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.grey,
                    selectedColor: Theme.of(context).colorScheme.onPrimary,
                    fillColor: Theme.of(context).colorScheme.primary,
                    onPressed: (index) {
                      setState(() {
                        _selectedPeriodIndex = index;
                      });
                    },
                    children: const [
                      Text("Wo", style: TextStyle(fontSize: 12)),
                      Text("Mo", style: TextStyle(fontSize: 12)),
                      Text("Ja", style: TextStyle(fontSize: 12)),
                      Icon(Icons.all_inclusive, size: 16),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 5),

            // --- LISTE (Scrollbarer Bereich) ---
            // ÄNDERUNG 2: Expanded nutzen, damit die Liste den Restplatz nimmt
            Expanded(
              child: mostPlayed.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          _getEmptyMessage(_selectedPeriodIndex),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  : ListView.builder(
                      // ÄNDERUNG 3: shrinkWrap und Physics-Sperre entfernt
                      // ÄNDERUNG 4: Padding unten (100) hinzugefügt
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: mostPlayed.length,
                      itemBuilder: (context, index) {
                        final song = mostPlayed[index];
                        final plays = _getPlayCountForDisplay(song, cutoffDate);

                        return SongTile(
                          song: song,
                          isCurrent: provider.currentSongId == song.path,
                          onLongPress: () {},
                          onTap: () => provider.playSong(mostPlayed, index),
                          leading: Container(
                            width: 50,
                            alignment: Alignment.center,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(50),
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 1,
                                ),
                                child: Text(
                                  "$plays",
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          trailing: const SizedBox.shrink(),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  String _getEmptyMessage(int index) {
    switch (index) {
      case 0:
        return "Diese Woche noch nichts gehört.";
      case 1:
        return "Diesen Monat noch nichts gehört.";
      case 2:
        return "Dieses Jahr noch nichts gehört.";
      default:
        return "Noch keine Daten vorhanden.";
    }
  }

  Widget _buildRecentCard(
    BuildContext context,
    SongModel song,
    LibraryProvider provider,
  ) {
    return GestureDetector(
      onTap: () => provider.playSong([song], 0),
      child: Container(
        width: 120,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[800],
                image: song.artUri != null
                    ? DecorationImage(
                        image: FileImage(File(song.artUri!)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: song.artUri == null
                  ? const Center(
                      child: Icon(
                        Icons.music_note,
                        size: 40,
                        color: Colors.white24,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getPlayCountForDisplay(SongModel song, DateTime cutoff) {
    return song.playHistory.where((date) => date.isAfter(cutoff)).length;
  }
}
