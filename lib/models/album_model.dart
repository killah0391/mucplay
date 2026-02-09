import 'song_model.dart';

class AlbumModel {
  final String name;
  final String artist;
  String? artUri; // Cover Bild Pfad
  final List<SongModel> songs;

  AlbumModel({
    required this.name,
    required this.artist,
    this.artUri,
    required this.songs,
  });
}
