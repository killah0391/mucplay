import 'package:hive/hive.dart';

part 'playlist_model.g.dart';

@HiveType(typeId: 1) // ID 0 ist schon für SongModel vergeben
class PlaylistModel extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  List<String> songPaths;

  @HiveField(2)
  DateTime createdAt;

  PlaylistModel({
    required this.name,
    required this.songPaths,
    required this.createdAt,
  });
}
