import 'dart:io';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:mucplay/models/song_model.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart'; // Wichtig!

class TagEditorService {
  static Future<bool> saveTags({
    required SongModel song,
    required String newTitle,
    required String newArtist,
    required String newAlbum,
    required String newYear,
    required String newGenre,
  }) async {
    final String inputPath = song.path;

    // 1. Sicheren Temp-Pfad im App-Cache nutzen (vermeidet Permission/Pfad Probleme)
    final Directory tempDir = await getTemporaryDirectory();
    final String ext = p.extension(inputPath);
    final String tempPath = p.join(
      tempDir.path,
      "temp_${DateTime.now().millisecondsSinceEpoch}$ext",
    );

    // 2. FFmpeg Befehl
    final List<String> command = [
      "-y",
      "-i", inputPath,
      "-metadata", "title=$newTitle",
      "-metadata", "artist=$newArtist",
      "-metadata", "album=$newAlbum",
      "-metadata", "date=$newYear", // M4A/MP3 nutzen oft 'date' für das Jahr
      "-metadata", "genre=$newGenre",
      "-c", "copy",
      tempPath,
    ];

    print("Starte FFmpeg Tagging...");

    final session = await FFmpegKit.executeWithArguments(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      try {
        final File originalFile = File(inputPath);
        final File tempFile = File(tempPath);

        // 3. Datei sicher ersetzen (Copy & Delete statt Rename, falls Partitionen unterschiedlich sind)
        if (await tempFile.exists()) {
          // Löschen
          if (await originalFile.exists()) {
            await originalFile.delete();
          }
          // Kopieren (sicherer als rename über Partitionsgrenzen)
          await tempFile.copy(inputPath);
          // Temp aufräumen
          await tempFile.delete();

          return true;
        } else {
          print("Temp Datei wurde nicht erstellt.");
          return false;
        }
      } catch (e) {
        print("Fehler beim Dateitausch: $e");
        return false;
      }
    } else {
      print("FFmpeg Fehler.");
      // Logs ausgeben zur Diagnose
      final logs = await session.getAllLogs();
      for (var log in logs) {
        print("FFmpeg Log: ${log.getMessage()}");
      }
      return false;
    }
  }
}
