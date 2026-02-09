import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mucplay/locator.dart';
import 'package:mucplay/models/playlist_model.dart';
import 'package:mucplay/models/song_model.dart';

class PlaylistProvider extends ChangeNotifier {
  final Box<PlaylistModel> _playlistBox = locator<Box<PlaylistModel>>();
  final Box<SongModel> _songBox = locator<Box<SongModel>>();
  String? _activePlaylistName;

  List<PlaylistModel> get playlists => _playlistBox.values.toList();
  String? get activePlaylistName => _activePlaylistName;

  // --- ACTIONS ---

  void setActivePlaylist(String? name) {
    if (_activePlaylistName != name) {
      _activePlaylistName = name;
      notifyListeners();
    }
  }

  // 1. Neue Playlist erstellen (optional direkt mit Songs)
  Future<void> createPlaylist(
    String name, {
    List<SongModel>? initialSongs,
  }) async {
    final newPlaylist = PlaylistModel(
      name: name,
      songPaths: initialSongs?.map((s) => s.path).toList() ?? [],
      createdAt: DateTime.now(),
    );
    await _playlistBox.add(newPlaylist);
    notifyListeners();
  }

  // 2. Playlist löschen
  Future<void> deletePlaylist(PlaylistModel playlist) async {
    await playlist.delete();
    notifyListeners();
  }

  // 3. Playlist umbenennen
  Future<void> renamePlaylist(PlaylistModel playlist, String newName) async {
    playlist.name = newName;
    await playlist.save();
    notifyListeners();
  }

  // 4. Songs hinzufügen (Check auf Duplikate optional)
  Future<void> addSongsToPlaylist(
    PlaylistModel playlist,
    List<SongModel> songs,
  ) async {
    for (var song in songs) {
      if (!playlist.songPaths.contains(song.path)) {
        playlist.songPaths.add(song.path);
      }
    }
    await playlist.save();
    notifyListeners();
  }

  // 5. Songs entfernen
  Future<void> removeSongsFromPlaylist(
    PlaylistModel playlist,
    List<SongModel> songsToRemove,
  ) async {
    final pathsToRemove = songsToRemove.map((s) => s.path).toSet();
    playlist.songPaths.removeWhere((path) => pathsToRemove.contains(path));
    await playlist.save();
    notifyListeners();
  }

  // --- HELPER ---

  // Wandelt die gespeicherten Pfade zurück in echte Song-Objekte um
  List<SongModel> getSongsForPlaylist(PlaylistModel playlist) {
    // Wir holen alle Songs aus der SongBox, die in der Playlist-Pfadliste stehen
    // Reihenfolge beibehalten ist wichtig!
    final List<SongModel> result = [];

    // Map für schnellen Zugriff erstellen
    final allSongsMap = {for (var s in _songBox.values) s.path: s};

    for (String path in playlist.songPaths) {
      if (allSongsMap.containsKey(path)) {
        result.add(allSongsMap[path]!);
      }
    }
    return result;
  }
}
