import 'package:hive/hive.dart';

part 'song_model.g.dart';

@HiveType(typeId: 0)
class SongModel extends HiveObject {
  @HiveField(0)
  final String path;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String artist;

  @HiveField(3)
  final String album;

  @HiveField(4)
  final int durationMs;

  @HiveField(5)
  bool isFavorite;

  @HiveField(6)
  final String format;

  @HiveField(7)
  final String? artUri;

  @HiveField(8) // NEU: Das Jahr
  final int? year;

  @HiveField(9, defaultValue: "Unknown")
  final String genre;

  @HiveField(10)
  final int? trackNumber;

  @HiveField(11, defaultValue: [])
  List<DateTime> playHistory;

  SongModel({
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    this.isFavorite = false,
    required this.format,
    this.artUri,
    this.year, // NEU: Im Konstruktor
    required this.genre,
    this.trackNumber,
    List<DateTime>? playHistory,
  }) : playHistory = playHistory ?? [];

  static String getFormatFromPath(String filePath) {
    return filePath.split('.').last.toUpperCase();
  }
}
