import 'dart:io';
import 'dart:typed_data'; // Für Uint8List
import 'package:audiotags/audiotags.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffprobe_kit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart'; // Wichtig für Speicherort
import 'package:permission_handler/permission_handler.dart';
import '../locator.dart';
import '../models/song_model.dart';
import 'package:crypto/crypto.dart'; // Für Hash-Namen
import 'dart:convert'; // Für utf8

class LibraryService {
  final Box<SongModel> _songBox = locator<Box<SongModel>>();

  final List<String> _allowedExtensions = [
    '.mp3',
    '.m4a',
    '.wma',
    '.aac',
    '.flac',
    '.wav',
    '.ogg',
  ];

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.audio,
        Permission.manageExternalStorage,
      ].request();

      return statuses[Permission.audio]?.isGranted == true ||
          statuses[Permission.storage]?.isGranted == true ||
          statuses[Permission.manageExternalStorage]?.isGranted == true;
    }
    return true;
  }

  Future<String?> pickFolder() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    return selectedDirectory;
  }

  Future<int> scanFolder(String folderPath, int minDurationSec) async {
    final dir = Directory(folderPath);
    if (!await dir.exists()) return 0;

    final appDir = await getApplicationDocumentsDirectory();
    final coversDir = Directory(p.join(appDir.path, 'covers'));
    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
    }

    int newSongsCount = 0;
    // recursive: true sorgt dafür, dass auch Unterordner gescannt werden
    List<FileSystemEntity> files = dir.listSync(recursive: true);

    for (var entity in files) {
      if (entity is File) {
        String extension = p.extension(entity.path).toLowerCase();
        if (_allowedExtensions.contains(extension)) {
          // Wir prüfen hier noch nicht die Datenbank, da sich Metadaten geändert haben könnten
          // oder die Dauer-Einstellung geändert wurde.
          bool added = await _processAndSaveSong(
            entity,
            coversDir,
            minDurationSec,
          );
          if (added) newSongsCount++;
        }
      }
    }
    return newSongsCount;
  }

  // NEU: Beobachtet Ordner auf Änderungen
  Stream<FileSystemEvent> watchFolder(String folderPath) {
    final dir = Directory(folderPath);
    // recursive: true bedeutet, auch Unterordner werden beobachtet
    return dir.watch(events: FileSystemEvent.all, recursive: true);
  }

  Future<bool> _processAndSaveSong(
    File file,
    Directory coversDir,
    int minDurationSec,
  ) async {
    try {
      // 1. Versuch: AudioTags (Schnell, aber schwach bei AAC)
      Tag? tag;
      try {
        tag = await AudioTags.read(file.path);
      } catch (_) {}

      // Variablen initialisieren
      int durationMs = (tag?.duration ?? 0) * 1000;
      String title = tag?.title ?? p.basenameWithoutExtension(file.path);
      String artist = tag?.trackArtist ?? "Unknown Artist";
      String album = tag?.album ?? "Unknown Album";
      String genre = tag?.genre ?? "Unknown";
      int? year = tag?.year;

      // 2. Versuch: FFprobe Fallback (Wenn AudioTags versagt oder Dauer 0 ist)
      // AAC/M4A Dateien haben oft Dauer 0 bei AudioTags
      if (durationMs == 0 || tag == null) {
        try {
          // FFprobe Session starten
          final session = await FFprobeKit.getMediaInformation(file.path);
          final info = session.getMediaInformation();

          if (info != null) {
            // Dauer holen (kommt als String in Sekunden, z.B. "234.56")
            final durationStr = info.getDuration();
            if (durationStr != null) {
              final double durationSec = double.tryParse(durationStr) ?? 0;
              if (durationSec > 0) {
                durationMs = (durationSec * 1000).round();
              }
            }

            // Metadaten holen (Tags)
            final tags = info.getTags(); // Gibt eine Map<String, String> zurück
            if (tags != null) {
              // FFprobe Tags sind Case-Insensitive, meistens aber klein geschrieben
              // Wir nutzen '??=' damit wir existierende AudioTags-Werte nicht überschreiben, falls sie doch da waren
              if (title == p.basenameWithoutExtension(file.path)) {
                title = tags['title'] ?? tags['TITLE'] ?? title;
              }
              if (artist == "Unknown Artist") {
                artist = tags['artist'] ?? tags['ARTIST'] ?? artist;
              }
              if (album == "Unknown Album") {
                album = tags['album'] ?? tags['ALBUM'] ?? album;
              }
              if (genre == "Unknown") {
                genre = tags['genre'] ?? tags['GENRE'] ?? genre;
              }
              if (year == null) {
                // Jahr parsen (oft im 'date' Feld)
                final dateStr =
                    tags['date'] ??
                    tags['DATE'] ??
                    tags['year'] ??
                    tags['YEAR'];
                if (dateStr != null) {
                  year = int.tryParse(
                    dateStr.split('-')[0],
                  ); // Falls Format "2023-01-01"
                }
              }
            }
          }
        } catch (e) {
          print("FFprobe Fehler bei ${file.path}: $e");
        }
      }

      // Filter: Ist der Song zu kurz?
      int durationSec = (durationMs / 1000).round();
      if (durationSec > 0 && durationSec < minDurationSec) {
        if (_songBox.containsKey(file.path)) {
          await _songBox.delete(file.path);
        }
        return false;
      }

      // Cover extrahieren (Das macht AudioTags eigentlich ganz gut, FFprobe für Bilder ist komplexer)
      // Wenn AudioTags hier fehlschlägt, lassen wir das Cover leer oder nutzen AudioTags nur dafür.
      String? artUri;
      if (tag?.pictures != null && tag!.pictures.isNotEmpty) {
        artUri = await _extractAndSaveCover(
          tag.pictures.first,
          artist,
          album,
          coversDir,
        );
      }

      // Daten Retten (History, Favoriten)
      List<DateTime> existingHistory = [];
      bool existingFavorite = false;

      if (_songBox.containsKey(file.path)) {
        final oldSong = _songBox.get(file.path);
        if (oldSong != null) {
          existingHistory = List.from(oldSong.playHistory);
          existingFavorite = oldSong.isFavorite;
        }
      }

      final song = SongModel(
        path: file.path,
        title: title,
        artist: artist,
        album: album,
        durationMs: durationMs,
        format: SongModel.getFormatFromPath(file.path),
        isFavorite: existingFavorite,
        artUri: artUri,
        year: year,
        genre: genre,
        trackNumber: tag
            ?.trackNumber, // FFprobe Tracknummer ist oft komplex ("1/12"), lassen wir hier einfach
        playHistory: existingHistory,
      );

      await _songBox.put(file.path, song);
      return true;
    } catch (e) {
      print("Kritischer Fehler bei ${file.path}: $e");

      // Fallback Speicherung
      List<DateTime> existingHistory = [];
      bool existingFavorite = false;
      if (_songBox.containsKey(file.path)) {
        final oldSong = _songBox.get(file.path);
        if (oldSong != null) {
          existingHistory = List.from(oldSong.playHistory);
          existingFavorite = oldSong.isFavorite;
        }
      }

      final song = SongModel(
        path: file.path,
        title: p.basenameWithoutExtension(file.path),
        artist: "Unknown",
        album: "Unknown",
        durationMs: 0,
        format: SongModel.getFormatFromPath(file.path),
        artUri: null,
        year: null,
        genre: "Unknown",
        trackNumber: null,
        isFavorite: existingFavorite,
        playHistory: existingHistory,
      );
      await _songBox.put(file.path, song);
      return true;
    }
  }

  // Speichert das Bild effizient ab. Wenn Artist+Album gleich sind,
  // nutzen wir das gleiche Bild, um Speicherplatz zu sparen.
  Future<String?> _extractAndSaveCover(
    Picture picture,
    String artist,
    String album,
    Directory coversDir,
  ) async {
    try {
      // Einzigartigen Dateinamen generieren (basierend auf Album & Artist)
      // Das verhindert, dass wir das gleiche Cover 20x speichern
      final String id = md5.convert(utf8.encode("$artist-$album")).toString();
      final File coverFile = File(p.join(coversDir.path, '$id.jpg'));

      // Wenn das Bild schon existiert, müssen wir es nicht neu schreiben
      if (await coverFile.exists()) {
        return coverFile.path;
      }

      // Bild speichern
      await coverFile.writeAsBytes(picture.bytes);
      return coverFile.path;
    } catch (e) {
      print("Konnte Cover nicht speichern: $e");
      return null;
    }
  }

  Future<void> clearLibrary() async {
    await _songBox.clear();
    // Optional: Auch Cover-Ordner leeren, um Müll zu vermeiden
  }

  // Future<void> libraryView() async {

  // }
}
