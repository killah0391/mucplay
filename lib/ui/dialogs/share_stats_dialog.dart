import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mucplay/models/song_model.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

class ShareStatsDialog extends StatefulWidget {
  final List<SongModel> songs;
  final String period;

  const ShareStatsDialog({
    super.key,
    required this.songs,
    required this.period,
  });

  @override
  State<ShareStatsDialog> createState() => _ShareStatsDialogState();
}

class _ShareStatsDialogState extends State<ShareStatsDialog> {
  final ScreenshotController _screenshotController = ScreenshotController();

  // Standardfarbe (kann angepasst werden)
  Color _selectedColor = Colors.blueAccent;

  // Liste der wählbaren Farben
  final List<Color> _colors = [
    Colors.blueAccent,
    Colors.redAccent,
    Colors.purpleAccent,
    Colors.greenAccent,
    Colors.orangeAccent,
    Colors.tealAccent,
    Colors.pinkAccent,
    Colors.black,
  ];

  bool _isSharing = false;

  Future<void> _shareImage() async {
    setState(() => _isSharing = true);
    try {
      // 1. Widget als Bild (Uint8List) rendern
      final Uint8List? imageBytes = await _screenshotController.capture();

      if (imageBytes != null) {
        // 2. Temporäre Datei erstellen
        final directory = await getTemporaryDirectory();
        final imagePath = await File(
          '${directory.path}/mucplay_stats.png',
        ).create();
        await imagePath.writeAsBytes(imageBytes);

        // 3. Teilen Dialog öffnen
        // WICHTIG: share_plus 10.0+ nutzt XFile
        await Share.shareXFiles([
          XFile(imagePath.path),
        ], text: 'Meine Top Songs ($widget.period) auf MucPlay! 🎵');
      }
    } catch (e) {
      print("Fehler beim Teilen: $e");
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Wir nehmen nur die Top 5 für das Bild, damit es übersichtlich bleibt
    final topSongs = widget.songs.take(5).toList();

    return AlertDialog(
      backgroundColor: Colors.grey[900],
      contentPadding: const EdgeInsets.all(16),
      title: const Text(
        "Statistik teilen",
        style: TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- DIE KARTE (Wird gescreenshotted) ---
            Screenshot(
              controller: _screenshotController,
              child: Container(
                width: 300,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_selectedColor, _selectedColor.withOpacity(0.6)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        const Icon(
                          Icons.bar_chart,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "MEINE TOP SONGS",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                              Text(
                                widget.period.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white30, height: 30),

                    // Song Liste
                    ...topSongs.asMap().entries.map((entry) {
                      final index = entry.key + 1;
                      final song = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          children: [
                            Text(
                              "$index",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    song.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 16),
                    // Footer
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "MucPlay",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // --- FARBAUSWAHL ---
            const Text(
              "Farbe wählen",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: _colors.map((color) {
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: _selectedColor == color
                          ? Border.all(color: Colors.white, width: 2)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Abbrechen", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton.icon(
          onPressed: _isSharing ? null : _shareImage,
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedColor,
            foregroundColor: Colors.white,
          ),
          icon: _isSharing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.share),
          label: const Text("Teilen"),
        ),
      ],
    );
  }
}
