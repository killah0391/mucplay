import 'dart:io';
import 'dart:typed_data';
import 'package:audiotags/audiotags.dart';
import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import '../models/song_model.dart';

class AlbumArtService {
  // Singleton Pattern (damit wir Instanzen sparen)
  static final AlbumArtService _instance = AlbumArtService._internal();
  factory AlbumArtService() => _instance;
  AlbumArtService._internal();

  /// Holt den Pfad zum gecachten Cover-Bild.
  /// Wenn es noch nicht existiert, wird es extrahiert.
  Future<File?> getAlbumArt(SongModel song) async {
    try {
      // 1. Eindeutigen Dateinamen generieren (basierend auf Album & Artist)
      // Wir nutzen MD5, um Sonderzeichen in Pfaden zu vermeiden.
      final uniqueKey = "${song.album}_${song.artist}";
      final bytes = utf8.encode(uniqueKey);
      final digest = md5.convert(bytes);
      final fileName = "cover_$digest.jpg";

      // 2. Cache Verzeichnis holen
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');

      // 3. Check: Existiert das Bild schon?
      if (await file.exists()) {
        return file; // Super, direkt zurückgeben!
      }

      // 4. Wenn nicht: Aus der Audio-Datei extrahieren
      final tag = await AudioTags.read(song.path);
      final pictures = tag?.pictures;

      if (pictures != null && pictures.isNotEmpty) {
        final Picture picture = pictures.first;
        final Uint8List imageBytes = picture.bytes;

        // 5. Speichern für das nächste Mal
        await file.writeAsBytes(imageBytes);
        return file;
      }

      return null; // Kein Bild in der Datei gefunden
    } catch (e) {
      // Fehler beim Extrahieren (z.B. korrupte Datei)
      return null;
    }
  }
}
