import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:mucplay/locator.dart';
import 'package:volume_controller/volume_controller.dart';
import '../models/song_model.dart';
import 'package:audio_session/audio_session.dart'
    hide AVAudioSessionCategory, AndroidAudioFocus;
import 'package:home_widget/home_widget.dart';

Future<AudioHandler> initAudioService() async {
  return await AudioService.init(
    builder: () => AudioPlayerHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.mucplay.app.channel.audio',
      androidNotificationChannelName: 'MucPlay Audio',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}

class AudioPlayerHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player1 = AudioPlayer();
  final AudioPlayer _player2 = AudioPlayer();
  late AudioPlayer _currentPlayer;

  final bool _crossfadeEnabled = true;
  final int _crossfadeDurationSec = 3;
  Timer? _crossfadeTimer;

  bool _isCrossfading = false;

  Duration _currentPosition = Duration.zero;
  List<MediaItem> _originalQueue = [];

  StreamSubscription? _noisySub;
  StreamSubscription? _interruptionSub;

  late Future<void> _initFuture;

  // --- DEBOUNCING VARIABLEN FÜR WIDGET UPDATES ---
  Timer? _shuffleUpdateDebounce;
  Timer? _repeatUpdateDebounce;
  DateTime _lastShuffleUpdate = DateTime.now();
  DateTime _lastRepeatUpdate = DateTime.now();
  static const _debounceMs = 300; // Millisekunden zuwarten vor Update

  AudioPlayerHandler() {
    _currentPlayer = _player1;
    _initPlayers();
    _initVolumeListener();
    _initAudioSession();

    _initFuture = _loadLastState();
  }

  static const _closeControl = MediaControl(
    androidIcon: 'drawable/ic_close',
    label: 'Schließen',
    action: MediaAction.stop,
  );

  // --- HILFSMETHODE: MediaItem erstellen ---
  MediaItem _createMediaItem(SongModel song) {
    return MediaItem(
      id: song.path,
      title: song.title,
      artist: song.artist,
      album: song.album,
      duration: Duration(milliseconds: song.durationMs),
      artUri: song.artUri != null ? Uri.file(song.artUri!) : null,
      extras: {'path': song.path, 'format': song.format},
    );
  }

  // --- LAST STATE LOADING (Warteschlange & Song) ---
  Future<void> _loadLastState() async {
    try {
      final settingsBox = locator<Box>(instanceName: 'settings');
      final lastPath = settingsBox.get('last_played_path') as String?;
      final lastPosMs = settingsBox.get('last_played_position') as int? ?? 0;

      // NEU: Queue laden
      final lastQueuePaths =
          (settingsBox.get('last_queue') as List?)?.cast<String>() ?? [];

      final songBox = locator<Box<SongModel>>();
      List<MediaItem> restoredQueue = [];

      // 1. Warteschlange rekonstruieren
      if (lastQueuePaths.isNotEmpty) {
        for (final path in lastQueuePaths) {
          // Song aus DB suchen (effizienter als einzeln)
          final song = songBox.values.firstWhere(
            (s) => s.path == path,
            orElse: () => SongModel(
              path: '',
              title: '',
              artist: '',
              album: '',
              durationMs: 0,
              format: '',
              genre: 'Unknown',
            ),
          );

          if (song.path.isNotEmpty) {
            restoredQueue.add(_createMediaItem(song));
          }
        }
      }

      // Fallback: Wenn Queue leer war, aber ein Song gespeichert ist -> Queue = [Song]
      if (restoredQueue.isEmpty && lastPath != null) {
        final song = songBox.values.firstWhere(
          (s) => s.path == lastPath,
          orElse: () => SongModel(
            path: '',
            title: '',
            artist: '',
            album: '',
            durationMs: 0,
            format: '',
            genre: 'Unknown',
          ),
        );
        if (song.path.isNotEmpty) {
          restoredQueue.add(_createMediaItem(song));
        }
      }

      // 2. Anwenden
      if (restoredQueue.isNotEmpty) {
        queue.add(restoredQueue); // Queue setzen

        // Richtigen Song in der Queue finden
        MediaItem? currentItem;
        if (lastPath != null) {
          currentItem = restoredQueue.firstWhere(
            (item) => item.id == lastPath,
            orElse: () => restoredQueue.first,
          );
        } else {
          currentItem = restoredQueue.first;
        }

        mediaItem.add(currentItem);
        _currentPosition = Duration(milliseconds: lastPosMs);

        // Player vorbereiten
        await _currentPlayer.setSource(
          DeviceFileSource(currentItem.extras!['path'] as String),
        );
        await _currentPlayer.seek(_currentPosition);

        // State senden (Index berechnen)
        final index = restoredQueue.indexOf(currentItem);

        playbackState.add(
          playbackState.value.copyWith(
            playing: false,
            processingState: AudioProcessingState.ready,
            updatePosition: _currentPosition,
            queueIndex: index, // Wichtig für Next/Prev Logik
            controls: [
              MediaControl.skipToPrevious,
              MediaControl.play,
              MediaControl.skipToNext,
              _closeControl,
            ],
            systemActions: const {
              MediaAction.seek,
              MediaAction.seekForward,
              MediaAction.seekBackward,
            },
            androidCompactActionIndices: const [0, 1, 2],
          ),
        );

        updateWidget();
      }
    } catch (e) {
      print("Fehler beim Laden des letzten Zustands: $e");
    }
  }

  // --- STATE SAVING (Warteschlange & Song) ---
  Future<void> _saveLastState() async {
    final settingsBox = locator<Box>(instanceName: 'settings');

    // 1. Aktuellen Song speichern
    final item = mediaItem.value;
    if (item != null) {
      final currentPath = item.extras?['path'];
      if (currentPath != null) {
        await settingsBox.put('last_played_path', currentPath);

        // Position nur speichern, wenn Player aktiv, sonst alte behalten
        try {
          final pos = await _currentPlayer.getCurrentPosition();
          if (pos != null) {
            await settingsBox.put('last_played_position', pos.inMilliseconds);
          } else {
            await settingsBox.put(
              'last_played_position',
              _currentPosition.inMilliseconds,
            );
          }
        } catch (_) {
          await settingsBox.put(
            'last_played_position',
            _currentPosition.inMilliseconds,
          );
        }
      }
    }

    // 2. Warteschlange speichern (NEU)
    // Wir speichern die Pfade (IDs) der aktuellen Queue
    if (queue.value.isNotEmpty) {
      final queuePaths = queue.value.map((i) => i.id).toList();
      await settingsBox.put('last_queue', queuePaths);
    }
  }

  // ... (InitPlayers, VolumeListener, AudioSession etc. bleiben gleich) ...
  void _initPlayers() {
    final AudioContext audioContext = AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playAndRecord,
        options: const {
          AVAudioSessionOptions.defaultToSpeaker,
          AVAudioSessionOptions.allowBluetooth,
          AVAudioSessionOptions.allowAirPlay,
        },
      ),
      android: AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: true,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.none,
      ),
    );

    _player1.setAudioContext(audioContext);
    _player2.setAudioContext(audioContext);

    _player1.onPlayerComplete.listen((_) => _onSongFinished(_player1));
    _player2.onPlayerComplete.listen((_) => _onSongFinished(_player2));

    _player1.onPositionChanged.listen((pos) {
      if (_currentPlayer == _player1) {
        _currentPosition = pos;
        _monitorCrossfade(pos);
      }
    });

    _player2.onPositionChanged.listen((pos) {
      if (_currentPlayer == _player2) {
        _currentPosition = pos;
        _monitorCrossfade(pos);
      }
    });

    _player1.onPlayerStateChanged.listen((state) {
      if (_currentPlayer == _player1) {
        _broadcastState(isPlaying: state == PlayerState.playing);
      }
    });
    _player2.onPlayerStateChanged.listen((state) {
      if (_currentPlayer == _player2) {
        _broadcastState(isPlaying: state == PlayerState.playing);
      }
    });

    _player1.onDurationChanged.listen((d) {
      if (_currentPlayer == _player1) _updateDuration(d);
    });
    _player2.onDurationChanged.listen((d) {
      if (_currentPlayer == _player2) _updateDuration(d);
    });
  }

  void _monitorCrossfade(Duration pos) {
    final item = mediaItem.value;
    if (item?.duration == null || !_crossfadeEnabled || _isCrossfading) return;
    final remaining = item!.duration! - pos;
    if (remaining.inSeconds <= _crossfadeDurationSec) {
      _isCrossfading = true;
      _recordPlayback();
      if (playbackState.value.repeatMode == AudioServiceRepeatMode.one) {
        final currentIndex = queue.value.indexWhere((i) => i.id == item.id);
        if (currentIndex != -1) _playIndex(currentIndex);
      } else {
        skipToNext();
      }
    }
  }

  void _updateDuration(Duration duration) {
    final currentItem = mediaItem.value;
    if (currentItem != null && duration.inMilliseconds > 0) {
      if (currentItem.duration != duration) {
        mediaItem.add(currentItem.copyWith(duration: duration));
      }
    }
  }

  void _initVolumeListener() {
    VolumeController.instance.addListener((volume) {
      if (volume == 0 && playbackState.value.playing) {
        pause();
      }
    });
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _noisySub?.cancel();
    _noisySub = session.becomingNoisyEventStream.listen((_) {
      print("Gerät getrennt -> PAUSE");
      pause();
    });
    _interruptionSub?.cancel();
    _interruptionSub = session.interruptionEventStream.listen((event) {
      if (event.begin) {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _currentPlayer.setVolume(0.5);
            break;
          case AudioInterruptionType.pause:
          case AudioInterruptionType.unknown:
            pause();
            break;
        }
      } else {
        switch (event.type) {
          case AudioInterruptionType.duck:
            _currentPlayer.setVolume(1.0);
            break;
          default:
            break;
        }
      }
    });
  }

  Future<void> _recordPlayback() async {
    final settingsBox = locator<Box>(instanceName: 'settings');
    final bool statsEnabled = settingsBox.get(
      'statisticsMode',
      defaultValue: false,
    );
    if (!statsEnabled) return;
    final currentItem = mediaItem.value;
    if (currentItem == null) return;
    final path = currentItem.extras?['path'];
    if (path == null) return;
    try {
      final songBox = locator<Box<SongModel>>();
      final song = songBox.values.firstWhere(
        (s) => s.path == path,
        orElse: () => throw Exception("Song nicht in DB gefunden"),
      );
      song.playHistory.add(DateTime.now());
      await song.save();
    } catch (e) {
      print("Konnte Playback-History nicht speichern: $e");
    }
  }

  // --- HIER NEU: Speichern beim Ändern der Queue ---
  @override
  Future<void> updateQueue(List<MediaItem> newQueue) async {
    if (playbackState.value.shuffleMode == AudioServiceShuffleMode.all) {
      await setShuffleMode(AudioServiceShuffleMode.none);
    }
    _originalQueue = List.from(newQueue);
    await super.updateQueue(newQueue);

    // Wichtig: Queue speichern!
    _saveLastState();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final currentMode = playbackState.value.shuffleMode;
    if (currentMode == shuffleMode) return;
    if (shuffleMode == AudioServiceShuffleMode.all) {
      if (queue.value.isNotEmpty) {
        _originalQueue = List.from(queue.value);
        final shuffled = List<MediaItem>.from(queue.value)..shuffle();
        final currentId = mediaItem.value?.id;
        if (currentId != null) {
          shuffled.removeWhere((item) => item.id == currentId);
          final currentItem = queue.value.firstWhere(
            (item) => item.id == currentId,
          );
          shuffled.insert(0, currentItem);
        }
        queue.add(shuffled);
      }
    } else {
      if (_originalQueue.isNotEmpty) {
        queue.add(List.from(_originalQueue));
      }
    }
    playbackState.add(
      playbackState.value.copyWith(
        shuffleMode: shuffleMode,
        updatePosition: _currentPosition,
      ),
    );

    // Wichtig: Queue (die jetzt geshuffelt ist) speichern
    _saveLastState();

    // Widget nur mit neuen Shuffle-Status updaten (nicht komplett neu zeichnen)
    await _updateWidgetShuffleState(shuffleMode);
  }

  @override
  Future<void> skipToNext() async {
    await _initFuture;
    if (queue.value.isEmpty) return;
    final currentIndex = queue.value.indexWhere(
      (item) => item.id == mediaItem.value?.id,
    );
    final nextIndex = (currentIndex + 1) % queue.value.length;
    await _playIndex(nextIndex);
  }

  @override
  Future<void> skipToPrevious() async {
    await _initFuture;
    if (_currentPosition.inSeconds > 3) {
      seek(Duration.zero);
    } else {
      final currentIndex = queue.value.indexWhere(
        (item) => item.id == mediaItem.value?.id,
      );
      int prevIndex = currentIndex > 0
          ? currentIndex - 1
          : queue.value.length - 1;
      await _playIndex(prevIndex);
    }
  }

  @override
  Future<void> play() async {
    await _initFuture;
    if (mediaItem.value == null) {
      if (queue.value.isNotEmpty) {
        await _playIndex(0);
        return;
      }
      return;
    }
    final session = await AudioSession.instance;
    await session.setActive(true);
    try {
      await _currentPlayer.resume();
    } catch (e) {
      if (queue.value.isNotEmpty) {
        final index = queue.value.indexWhere(
          (i) => i.id == mediaItem.value?.id,
        );
        if (index != -1) await _playIndex(index);
      }
      return;
    }
    _broadcastState(isPlaying: true);
    _saveLastState();
  }

  @override
  Future<void> pause() async {
    _crossfadeTimer?.cancel();
    _isCrossfading = false;
    final pos = await _currentPlayer.getCurrentPosition();
    if (pos != null) _currentPosition = pos;
    await _player1.pause();
    await _player2.pause();
    await _currentPlayer.setVolume(1.0);
    _saveLastState();
    _broadcastState(isPlaying: false);
  }

  @override
  Future<void> stop() async {
    await pause();
    super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _currentPlayer.seek(position);
    _currentPosition = position;
    _broadcastState();
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    final newQueue = queue.value..add(mediaItem);
    queue.add(newQueue);
    // Wichtig: Queue speichern!
    _saveLastState();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    await _playIndex(index);
  }

  Future<void> _playIndex(int index) async {
    _isCrossfading = false;
    _crossfadeTimer?.cancel();
    final item = queue.value[index];
    mediaItem.add(item);
    _currentPosition = Duration.zero;
    _broadcastState(isPlaying: true);
    _saveLastState();
    final String path = item.extras!['path'] as String;
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
      if (_crossfadeEnabled) {
        await _performCrossfade(path);
      } else {
        await _currentPlayer.stop();
        await _currentPlayer.setSource(DeviceFileSource(path));
        await _currentPlayer.seek(Duration.zero);
        await _currentPlayer.resume();
      }
      _broadcastState(isPlaying: true);
    } catch (e) {
      print("Fehler beim Abspielen von $path: $e");
    }
  }

  Future<void> _performCrossfade(String nextFilePath) async {
    final nextPlayer = (_currentPlayer == _player1) ? _player2 : _player1;
    final fadingPlayer = _currentPlayer;
    _currentPlayer = nextPlayer;
    try {
      await nextPlayer.stop();
      await nextPlayer.setVolume(0);
      await nextPlayer.setSource(DeviceFileSource(nextFilePath));
      await nextPlayer.seek(Duration.zero);
      await nextPlayer.resume();
      const steps = 20;
      final stepDuration = Duration(
        milliseconds: (_crossfadeDurationSec * 1000) ~/ steps,
      );
      double vol = 0.0;
      _crossfadeTimer?.cancel();
      _crossfadeTimer = Timer.periodic(stepDuration, (timer) {
        vol += 1.0 / steps;
        if (vol >= 1.0) {
          vol = 1.0;
          timer.cancel();
          fadingPlayer.stop();
        }
        nextPlayer.setVolume(vol);
        fadingPlayer.setVolume(1.0 - vol);
      });
    } catch (e) {
      print("Crossfade Fehler bei $nextFilePath: $e");
    }
  }

  void _onSongFinished(AudioPlayer player) {
    if (player == _currentPlayer) {
      _recordPlayback();
      _isCrossfading = false;
      if (playbackState.value.repeatMode == AudioServiceRepeatMode.one) {
        seek(Duration.zero);
        play();
      } else {
        skipToNext();
      }
    }
  }

  void _broadcastState({bool? isPlaying}) {
    // Aktuellen Index berechnen
    int queueIndex = 0;
    if (mediaItem.value != null && queue.value.isNotEmpty) {
      queueIndex = queue.value.indexWhere((i) => i.id == mediaItem.value!.id);
    }

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (isPlaying ?? playbackState.value.playing)
            MediaControl.pause
          else
            MediaControl.play,
          MediaControl.skipToNext,
          _closeControl,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 2],
        playing: isPlaying ?? playbackState.value.playing,
        updatePosition: _currentPosition,
        processingState: AudioProcessingState.ready,
        queueIndex: queueIndex, // Index mitgeben!
      ),
    );
    updateWidget();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    playbackState.add(
      playbackState.value.copyWith(
        repeatMode: repeatMode,
        updatePosition: _currentPosition,
      ),
    );

    // Widget nur mit neuem Repeat-Status updaten (nicht komplett neu zeichnen)
    await _updateWidgetRepeatState(repeatMode);
  }

  Future<void> playNext(List<MediaItem> items) async {
    final currentQueue = queue.value;
    final currentItem = mediaItem.value;
    if (currentQueue.isEmpty) {
      await updateQueue(items);
      await play();
      return;
    }
    final currentIndex = currentQueue.indexWhere(
      (i) => i.id == currentItem?.id,
    );
    final insertIndex = (currentIndex >= 0)
        ? currentIndex + 1
        : currentQueue.length;
    final newQueue = List<MediaItem>.from(currentQueue);
    newQueue.insertAll(insertIndex, items);
    queue.add(newQueue);
    if (playbackState.value.shuffleMode == AudioServiceShuffleMode.all) {
      final originalIndex = _originalQueue.indexWhere(
        (i) => i.id == currentItem?.id,
      );
      final originalInsertIndex = (originalIndex >= 0)
          ? originalIndex + 1
          : _originalQueue.length;
      _originalQueue.insertAll(originalInsertIndex, items);
    } else {
      _originalQueue = List.from(newQueue);
    }
    // Wichtig: Speichern
    _saveLastState();
  }

  void moveQueueItem(int oldIndex, int newIndex) {
    final newQueue = queue.value.toList();
    if (oldIndex < 0 ||
        oldIndex >= newQueue.length ||
        newIndex < 0 ||
        newIndex > newQueue.length) {
      return;
    }
    final item = newQueue.removeAt(oldIndex);
    newQueue.insert(newIndex, item);
    queue.add(newQueue);
    // Wichtig: Speichern
    _saveLastState();
  }

  // --- WIDGET UPDATE ---
  Future<void> updateWidget() async {
    final item = mediaItem.value;
    final playing = playbackState.value.playing;
    final settingsBox = locator<Box>(instanceName: 'settings');
    final String mode = settingsBox.get(
      'widget_color_mode',
      defaultValue: 'app',
    );
    final shuffleMode = playbackState.value.shuffleMode;
    final repeatMode = playbackState.value.repeatMode;

    // Speichere Shuffle- und Repeat-Status für das Widget
    await HomeWidget.saveWidgetData<bool>(
      'shuffle_active',
      shuffleMode == AudioServiceShuffleMode.all,
    );
    // Wir speichern den Namen des Enums ("none", "one", "all")
    await HomeWidget.saveWidgetData<String>('repeat_mode', repeatMode.name);
    int colorValue;
    int onColorValue;
    int artistColorValue;

    if (mode == 'custom') {
      colorValue = settingsBox.get(
        'widget_custom_color',
        defaultValue: 0xFF1E1E1E,
      );
      final brightness = ThemeData.estimateBrightnessForColor(
        Color(colorValue),
      );
      final bool isDark = brightness == Brightness.dark;
      onColorValue = isDark ? Colors.white.value : Colors.black.value;
      artistColorValue = isDark ? Colors.white70.value : Colors.black54.value;
    } else if (mode == 'app') {
      final int accentColorInt = settingsBox.get(
        'accent_color',
        defaultValue: 0xFF2196F3,
      );
      final bool forceBold = settingsBox.get(
        'force_bold_colors',
        defaultValue: false,
      );
      if (forceBold) {
        colorValue = accentColorInt;
        final brightness = ThemeData.estimateBrightnessForColor(
          Color(colorValue),
        );
        final bool isDark = brightness == Brightness.dark;
        onColorValue = isDark ? Colors.white.value : Colors.black.value;
        artistColorValue = isDark ? Colors.white70.value : Colors.black54.value;
      } else {
        final scheme = ColorScheme.fromSeed(
          seedColor: Color(accentColorInt),
          brightness: Brightness.dark,
        );
        colorValue = const Color(0xFF1E1E1E).value;
        onColorValue = scheme.primary.value;
        artistColorValue = scheme.primary.withOpacity(0.7).value;
      }
    } else {
      colorValue = 0xFF1E1E1E;
      onColorValue = Colors.white.value;
      artistColorValue = Colors.white70.value;
    }

    await HomeWidget.saveWidgetData<String>(
      'title',
      item?.title ?? 'Kein Titel',
    );
    await HomeWidget.saveWidgetData<String>(
      'artist',
      item?.artist ?? 'Unbekannt',
    );
    await HomeWidget.saveWidgetData<bool>('isPlaying', playing);
    await HomeWidget.saveWidgetData<int>('widgetColor', colorValue);
    await HomeWidget.saveWidgetData<int>('widgetOnColor', onColorValue);
    await HomeWidget.saveWidgetData<int>('widgetArtistColor', artistColorValue);
    await HomeWidget.saveWidgetData<bool>(
      'shuffle_active',
      shuffleMode == AudioServiceShuffleMode.all,
    );
    // Wir speichern den Namen des Enums ("none", "one", "all")
    await HomeWidget.saveWidgetData<String>('repeat_mode', repeatMode.name);

    if (item?.artUri != null && item!.artUri!.isScheme('file')) {
      await HomeWidget.saveWidgetData<String>(
        'cover_path',
        item.artUri!.toFilePath(),
      );
      await HomeWidget.saveWidgetData<bool>('show_cover', true);
    } else {
      await HomeWidget.saveWidgetData<String?>('cover_path', null);
      await HomeWidget.saveWidgetData<bool>('show_cover', true);
    }

    await HomeWidget.updateWidget(
      name: 'MusicWidgetProvider',
      androidName: 'MusicWidgetProvider',
    );
  }

  // --- OPTIMIERTE WIDGET UPDATES (nur Status, kein kompletter Redraw) ---
  Future<void> _updateWidgetShuffleState(
    AudioServiceShuffleMode shuffleMode,
  ) async {
    try {
      // Speichern (ohne zu warten)
      await HomeWidget.saveWidgetData<bool>(
        'shuffle_active',
        shuffleMode == AudioServiceShuffleMode.all,
      );

      // Debounce: Update nur wenn 300ms seit letztem Update vergangen sind
      _shuffleUpdateDebounce?.cancel();
      _shuffleUpdateDebounce = Timer(
        const Duration(milliseconds: _debounceMs),
        () async {
          final now = DateTime.now();
          final timeSinceLastUpdate = now
              .difference(_lastShuffleUpdate)
              .inMilliseconds;

          if (timeSinceLastUpdate >= _debounceMs) {
            _lastShuffleUpdate = now;
            print("DEBUG: Shuffle widget updated (debounce)");

            try {
              await HomeWidget.updateWidget(
                name: 'MusicWidgetProvider',
                androidName: 'MusicWidgetProvider',
              );
            } catch (e) {
              print("Fehler beim Shuffle Widget Update: $e");
            }
          }
        },
      );
    } catch (e) {
      print("Fehler beim Shuffle Widget Speichern: $e");
    }
  }

  Future<void> _updateWidgetRepeatState(
    AudioServiceRepeatMode repeatMode,
  ) async {
    try {
      // Speichern (ohne zu warten)
      await HomeWidget.saveWidgetData<String>('repeat_mode', repeatMode.name);

      // Debounce: Update nur wenn 300ms seit letztem Update vergangen sind
      _repeatUpdateDebounce?.cancel();
      _repeatUpdateDebounce = Timer(
        const Duration(milliseconds: _debounceMs),
        () async {
          final now = DateTime.now();
          final timeSinceLastUpdate = now
              .difference(_lastRepeatUpdate)
              .inMilliseconds;

          if (timeSinceLastUpdate >= _debounceMs) {
            _lastRepeatUpdate = now;
            print("DEBUG: Repeat widget updated (debounce)");

            try {
              await HomeWidget.updateWidget(
                name: 'MusicWidgetProvider',
                androidName: 'MusicWidgetProvider',
              );
            } catch (e) {
              print("Fehler beim Repeat Widget Update: $e");
            }
          }
        },
      );
    } catch (e) {
      print("Fehler beim Repeat Widget Speichern: $e");
    }
  }
}
