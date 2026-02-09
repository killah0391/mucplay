import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../locator.dart';
import '../models/song_model.dart';
import '../services/library_service.dart';
import '../models/album_model.dart';

class LibraryProvider extends ChangeNotifier {
  final LibraryService _libraryService = locator<LibraryService>();
  final AudioHandler _audioHandler = locator<AudioHandler>();
  final Box<SongModel> _songBox = locator<Box<SongModel>>();
  final Box _settingsBox = locator<Box>(instanceName: 'settings');

  List<SongModel> _songs = [];
  bool _isScanning = false;
  String? _currentSongId;
  bool _isPlaying = false;

  final List<StreamSubscription> _watchers = [];

  // NEU: Timer für Debouncing (Verzögerung)
  Timer? _watcherTimer;

  // Getter
  List<SongModel> get songs => _songs;
  bool get isScanning => _isScanning;
  String? get currentSongId => _currentSongId;
  bool get isPlaying => _isPlaying;
  bool get statisticsMode =>
      _settingsBox.get('statisticsMode', defaultValue: false);
  bool get libraryTabMode =>
      _settingsBox.get('libraryTabMode', defaultValue: false);
  List<String> get tabOrder => List<String>.from(
    _settingsBox.get(
      'tabOrder',
      defaultValue: [
        'songs',
        'playlists',
        'albums',
        'artists',
        'genres',
        'years',
      ],
    ),
  );

  int get minDuration => _settingsBox.get('minDuration', defaultValue: 30);
  List<String> get scanPaths =>
      List<String>.from(_settingsBox.get('scanPaths', defaultValue: []));
  String get playlistNavigationMode =>
      _settingsBox.get('playlistNavigationMode', defaultValue: 'tab');
  // bool get statisticsMode =>
  //     _settingsBox.get('statisticsMode', defaultValue: false);

  LibraryProvider() {
    _loadSongsFromHive();
    _initAudioListeners();
    _initWatchers();

    _songBox.listenable().addListener(() {
      notifyListeners();
    });
  }

  void _loadSongsFromHive() {
    _songs = _songBox.values.toList();
    _songs.sort((a, b) => a.title.compareTo(b.title));
    notifyListeners();
  }

  void setTabOrder(List<String> newOrder) {
    _settingsBox.put('tabOrder', newOrder);
    notifyListeners();
  }

  void _initAudioListeners() {
    // (Wie vorher)
    MediaItem? lastMediaItem;
    PlaybackState? lastPlaybackState;
    void updateState() {
      final bool playing = lastPlaybackState?.playing ?? false;
      final String? currentId = lastMediaItem?.id;
      bool hasChanged = false;
      if (_currentSongId != currentId) {
        _currentSongId = currentId;
        hasChanged = true;
      }
      if (_isPlaying != playing) {
        _isPlaying = playing;
        hasChanged = true;
      }
      if (hasChanged) notifyListeners();
    }

    _audioHandler.mediaItem.listen((item) {
      lastMediaItem = item;
      updateState();
    });
    _audioHandler.playbackState.listen((state) {
      lastPlaybackState = state;
      updateState();
    });
  }

  List<SongModel> get recentlyPlayedSongs {
    final playedSongs = _songs.where((s) => s.playHistory.isNotEmpty).toList();

    playedSongs.sort((a, b) {
      // Neuestes Datum vergleichen
      return b.playHistory.last.compareTo(a.playHistory.last);
    });

    return playedSongs.take(20).toList(); // Limit auf 20
  }

  List<SongModel> getMostPlayedSongs(DateTime cutoffDate) {
    // Map erstellen: Song -> Anzahl Plays NACH dem Stichtag
    final Map<SongModel, int> playCounts = {};

    for (var song in _songs) {
      // Zähle Einträge, die NACH dem cutoffDate liegen
      int count = song.playHistory
          .where((date) => date.isAfter(cutoffDate))
          .length;

      if (count > 0) {
        playCounts[song] = count;
      }
    }

    // Sortieren nach Anzahl (absteigend)
    final sortedList = playCounts.keys.toList()
      ..sort((a, b) => playCounts[b]!.compareTo(playCounts[a]!));

    return sortedList.take(10).toList(); // Top 10
  }

  Future<void> pickAndScanFolder() async {
    bool hasPerms = await _libraryService.requestPermissions();
    if (!hasPerms) return;
    String? folder = await _libraryService.pickFolder();
    if (folder == null) return;
    await addFolder(folder);
  }

  Future<void> playSong(List<SongModel> playlist, int index) async {
    final mediaItems = playlist
        .map(
          (song) => MediaItem(
            id: song.path,
            album: song.album,
            title: song.title,
            artist: song.artist,
            duration: Duration(milliseconds: song.durationMs),
            artUri: song.artUri != null ? Uri.file(song.artUri!) : null,
            extras: {'path': song.path, 'format': song.format},
          ),
        )
        .toList();
    await _audioHandler.updateQueue(mediaItems);
    await _audioHandler.skipToQueueItem(index);
    await _audioHandler.play();
  }

  void setMinDuration(int seconds) {
    _settingsBox.put('minDuration', seconds);
    notifyListeners();
    rescanLibrary();
  }

  void reloadSongs() {
    _loadSongsFromHive();
  }

  Future<void> addFolder(String path) async {
    List<String> currentPaths = scanPaths;
    if (!currentPaths.contains(path)) {
      currentPaths.add(path);
      await _settingsBox.put('scanPaths', currentPaths);
      _initWatchers();
      await _scanPath(path);
    }
  }

  Future<void> removeFolder(String path) async {
    List<String> currentPaths = scanPaths;
    if (currentPaths.contains(path)) {
      currentPaths.remove(path);
      await _settingsBox.put('scanPaths', currentPaths);
      final songsToRemove = _songBox.values
          .where((s) => s.path.startsWith(path))
          .map((s) => s.key)
          .toList();
      await _songBox.deleteAll(songsToRemove);
      _loadSongsFromHive();
      _initWatchers();
    }
  }

  void _initWatchers() {
    for (var sub in _watchers) {
      sub.cancel();
    }
    _watchers.clear();

    for (String path in scanPaths) {
      try {
        final stream = _libraryService.watchFolder(path);
        final sub = stream.listen((event) {
          _handleFileSystemEvent(event);
        });
        _watchers.add(sub);
      } catch (e) {
        print("Fehler beim Watchen von $path: $e");
      }
    }
  }

  // NEU: Mit Timer (Debounce) Logik
  void _handleFileSystemEvent(FileSystemEvent event) {
    if (event.isDirectory) return;

    // Laufenden Timer abbrechen (resetten), wenn ein neues Event kommt
    if (_watcherTimer?.isActive ?? false) {
      _watcherTimer!.cancel();
    }

    // Warte 500ms Stille, bevor wir wirklich scannen
    _watcherTimer = Timer(const Duration(milliseconds: 500), () async {
      print("Verarbeite FileSystemEvent: ${event.type} für ${event.path}");

      if (event.type == FileSystemEvent.delete) {
        if (_songBox.containsKey(event.path)) {
          await _songBox.delete(event.path);
          _loadSongsFromHive();
        }
      } else {
        // Create / Modify
        // Wir scannen den Elternordner, um sicherzugehen
        final parentDir = File(event.path).parent.path;
        await _libraryService.scanFolder(parentDir, minDuration);
        _loadSongsFromHive();
      }
    });
  }

  Future<void> rescanLibrary() async {
    _isScanning = true;
    notifyListeners();
    for (String path in scanPaths) {
      await _scanPath(path);
    }
    await _cleanupLibrary(); // Deine Cleanup Methode
    _isScanning = false;
    _loadSongsFromHive();
  }

  Future<void> _scanPath(String path) async {
    await _libraryService.scanFolder(path, minDuration);
  }

  Future<void> _cleanupLibrary() async {
    // ... (Code aus dem vorherigen Schritt übernehmen) ...
    // Siehe vorherige Nachricht für den Inhalt
    final List<dynamic> keysToDelete = [];
    final List<String> currentScanPaths = scanPaths;
    final allSongs = _songBox.values.toList();
    for (var song in allSongs) {
      final File file = File(song.path);
      if (!await file.exists()) {
        keysToDelete.add(song.key);
        continue;
      }
      bool isInAllowedFolder = false;
      for (String rootPath in currentScanPaths) {
        if (song.path.startsWith(rootPath)) {
          isInAllowedFolder = true;
          break;
        }
      }
      if (!isInAllowedFolder) {
        keysToDelete.add(song.key);
      }
    }
    if (keysToDelete.isNotEmpty) {
      await _songBox.deleteAll(keysToDelete);
    }
  }

  Future<void> deleteSongs(List<SongModel> songsToDelete) async {
    final currentItem = _audioHandler.mediaItem.value;
    final currentQueue = _audioHandler.queue.value;

    // 1. Prüfen: Ist der aktuell spielende Song betroffen?
    final bool isPlayingDeletedSong =
        currentItem != null &&
        songsToDelete.any((s) => s.path == currentItem.id);

    // 2. Queue bereinigen (Liste der Songs, die ÜBRIG bleiben)
    final newQueue = currentQueue.where((item) {
      return !songsToDelete.any((s) => s.path == item.id);
    }).toList();

    // 3. Player-Entscheidung: Stop oder Skip?
    if (isPlayingDeletedSong) {
      // Wo sind wir gerade?
      final currentIndex = currentQueue.indexWhere(
        (i) => i.id == currentItem!.id,
      );

      // GIBT ES NACHFOLGER?
      // Wir prüfen, ob nach der aktuellen Position noch irgendein Song kommt,
      // der NICHT gelöscht wird.
      bool hasNextSong = false;
      if (currentIndex >= 0 && currentIndex < currentQueue.length - 1) {
        final upcomingSongs = currentQueue.sublist(currentIndex + 1);
        // Gibt es einen Überlebenden?
        hasNextSong = upcomingSongs.any(
          (item) => !songsToDelete.any((del) => del.path == item.id),
        );
      }

      // ENTSCHEIDUNG
      if (!hasNextSong || newQueue.isEmpty) {
        // Queue ist leer ODER aktueller Song war der letzte "gültige" -> Player schließen
        print("Letzter Song gelöscht -> Player schließen");
        await _audioHandler.stop();
      } else {
        // Es kommt noch was -> Nächsten Song abspielen
        print("Lösche aktuellen Song -> Springe zum Nächsten");
        await _audioHandler.skipToNext();
      }
    }

    // 4. Queue aktualisieren (nur wenn wir nicht gestoppt haben)
    // Wenn gestoppt wurde, hat stop() die Queue eh schon geleert.
    if (_audioHandler.playbackState.value.processingState !=
        AudioProcessingState.idle) {
      if (currentQueue.length != newQueue.length) {
        await _audioHandler.updateQueue(newQueue);
      }
    }

    // 5. Physisch Löschen & Datenbank bereinigen
    final List<dynamic> keysToDelete = [];
    for (var song in songsToDelete) {
      try {
        final file = File(song.path);
        if (await file.exists()) {
          await file.delete();
        }
        keysToDelete.add(song.path);
      } catch (e) {
        print("Fehler beim Löschen von ${song.path}: $e");
      }
    }

    if (keysToDelete.isNotEmpty) {
      await _songBox.deleteAll(keysToDelete);
      _loadSongsFromHive();
    }
  }

  List<AlbumModel> get albums {
    final Map<String, AlbumModel> albumMap = {};

    for (var song in _songs) {
      // Wir nutzen Albumname + Artist als Schlüssel, damit "Greatest Hits"
      // von verschiedenen Künstlern nicht vermischt werden.
      final key = "${song.album}_${song.artist}";

      if (!albumMap.containsKey(key)) {
        albumMap[key] = AlbumModel(
          name: song.album,
          artist: song.artist,
          artUri: song.artUri, // Erstes Cover übernehmen
          songs: [],
        );
      }

      final album = albumMap[key]!;
      album.songs.add(song);

      // Falls das Album noch kein Cover hat, aber dieser Song eins hat -> übernehmen
      // (Manchmal haben nicht alle MP3s in einem Ordner ein Cover)
      if (album.artUri == null && song.artUri != null) {
        album.artUri = song.artUri;
      }
    }

    final list = albumMap.values.toList();
    // Sortieren: A-Z
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  List<MapEntry<int, List<SongModel>>> get years {
    final Map<int, List<SongModel>> yearMap = {};

    for (var song in _songs) {
      // Wenn Jahr null ist, ordnen wir es '0' (Unbekannt) zu
      final int y = song.year ?? 0;

      if (!yearMap.containsKey(y)) {
        yearMap[y] = [];
      }
      yearMap[y]!.add(song);
    }

    // Sortieren: Neueste Jahre zuerst
    final sortedKeys = yearMap.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // b compareTo a = absteigend

    // Unbekannt (0) ans Ende schieben, falls vorhanden
    if (sortedKeys.contains(0)) {
      sortedKeys.remove(0);
      sortedKeys.add(0);
    }

    return sortedKeys.map((k) => MapEntry(k, yearMap[k]!)).toList();
  }

  void setPlaylistNavigationMode(String mode) {
    _settingsBox.put('playlistNavigationMode', mode);
    notifyListeners();
  }

  void setLibraryTabMode(bool mode) {
    _settingsBox.put('libraryTabMode', mode);
    notifyListeners();
  }

  void setStatisticsMode(bool mode) {
    _settingsBox.put('statisticsMode', mode);
    notifyListeners();
  }
}
