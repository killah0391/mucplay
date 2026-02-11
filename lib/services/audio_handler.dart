import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart'; // WICHTIG: Für ColorScheme & Colors
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

  // Subscriptions speichern
  StreamSubscription? _noisySub;
  StreamSubscription? _interruptionSub;

  AudioPlayerHandler() {
    _currentPlayer = _player1;
    _initPlayers();
    _initVolumeListener();
    _initAudioSession();
  }

  static const _closeControl = MediaControl(
    androidIcon: 'drawable/ic_close',
    label: 'Schließen',
    action: MediaAction.stop,
  );

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
          case AudioInterruptionType.pause:
            break;
          case AudioInterruptionType.unknown:
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

  @override
  Future<void> updateQueue(List<MediaItem> newQueue) async {
    if (playbackState.value.shuffleMode == AudioServiceShuffleMode.all) {
      await setShuffleMode(AudioServiceShuffleMode.none);
    }
    _originalQueue = List.from(newQueue);
    await super.updateQueue(newQueue);
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
  }

  @override
  Future<void> skipToNext() async {
    if (queue.value.isEmpty) return;
    final currentIndex = queue.value.indexWhere(
      (item) => item.id == mediaItem.value?.id,
    );
    final nextIndex = (currentIndex + 1) % queue.value.length;
    await _playIndex(nextIndex);
  }

  @override
  Future<void> skipToPrevious() async {
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
    final session = await AudioSession.instance;
    await session.setActive(true);

    await _currentPlayer.resume();
    _broadcastState(isPlaying: true);
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

    _broadcastState(isPlaying: false);
  }

  @override
  Future<void> stop() async {
    _crossfadeTimer?.cancel();
    _noisySub?.cancel();
    _interruptionSub?.cancel();

    final pos = await _currentPlayer.getCurrentPosition();
    if (pos != null) _currentPosition = pos;

    await _player1.pause();
    await _player2.pause();

    await _currentPlayer.setVolume(1.0);

    _broadcastState(isPlaying: false);

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

    final String path = item.extras!['path'] as String;

    try {
      final session = await AudioSession.instance;
      await session.setActive(true);

      if (_crossfadeEnabled) {
        await _performCrossfade(path);
      } else {
        await _currentPlayer.stop();
        await _currentPlayer.setSource(UrlSource(Uri.file(path).toString()));
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
      await nextPlayer.setSource(UrlSource(Uri.file(nextFilePath).toString()));
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
      ),
    );
    updateWidget(); // Update bei Statusänderung
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    playbackState.add(
      playbackState.value.copyWith(
        repeatMode: repeatMode,
        updatePosition: _currentPosition,
      ),
    );
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
  }

  // --- WIDGET UPDATE ---
  // In lib/services/audio_handler.dart

  Future<void> updateWidget() async {
    final item = mediaItem.value;
    final playing = playbackState.value.playing;

    final settingsBox = locator<Box>(instanceName: 'settings');

    final String mode = settingsBox.get(
      'widget_color_mode',
      defaultValue: 'app',
    );

    int colorValue;
    int onColorValue;
    int artistColorValue;

    if (mode == 'custom') {
      // 1. CUSTOM MODE
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
      // 2. APP MODE
      final int accentColorInt = settingsBox.get(
        'accent_color',
        defaultValue: 0xFF2196F3,
      );
      final bool forceBold = settingsBox.get(
        'force_bold_colors',
        defaultValue: false,
      );

      if (forceBold) {
        // OPTION AN (Kräftig): Hintergrund = Akzentfarbe
        colorValue = accentColorInt;

        final brightness = ThemeData.estimateBrightnessForColor(
          Color(colorValue),
        );
        final bool isDark = brightness == Brightness.dark;
        onColorValue = isDark ? Colors.white.value : Colors.black.value;
        artistColorValue = isDark ? Colors.white70.value : Colors.black54.value;
      } else {
        // OPTION AUS (Dezent): Hintergrund = Dunkelgrau, Icons = Akzentfarbe
        final scheme = ColorScheme.fromSeed(
          seedColor: Color(accentColorInt),
          brightness: Brightness.dark,
        );

        // FIX: Hintergrund ist dunkel (Surface), nicht Primary!
        colorValue = const Color(0xFF1E1E1E).value;

        // FIX: Icons sind farbig (Primary)
        onColorValue = scheme.primary.value;
        artistColorValue = scheme.primary.withOpacity(0.7).value;
      }
    } else {
      // 3. DARK / STANDARD
      colorValue = 0xFF1E1E1E;
      onColorValue = Colors.white.value;
      artistColorValue = Colors.white70.value;
    }

    final String? artPath = item!.artUri?.toFilePath();

    await HomeWidget.saveWidgetData<String>(
      'title',
      item?.title ?? 'Kein Titel',
    );
    await HomeWidget.saveWidgetData<String>(
      'artist',
      item?.artist ?? 'Unbekannt',
    );

    if (artPath != null) {
      await HomeWidget.saveWidgetData<String>('cover_path', artPath);
    } else {
      // Wenn kein Cover, leeren Pfad senden, damit Kotlin das Fallback-Icon nimmt
      await HomeWidget.saveWidgetData<String>('cover_path', null);
    }
    await HomeWidget.saveWidgetData<bool>('isPlaying', playing);

    await HomeWidget.saveWidgetData<int>('widgetColor', colorValue);
    await HomeWidget.saveWidgetData<int>('widgetOnColor', onColorValue);
    await HomeWidget.saveWidgetData<int>('widgetArtistColor', artistColorValue);

    await HomeWidget.updateWidget(
      name: 'MusicWidgetProvider',
      androidName: 'MusicWidgetProvider',
    );
  }
}
