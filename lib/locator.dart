import 'package:audio_service/audio_service.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mucplay/models/playlist_model.dart';
import 'package:mucplay/services/audio_handler.dart';
import 'package:mucplay/services/library_service.dart';
import 'models/song_model.dart';

final GetIt locator = GetIt.instance;

Future<void> setupLocator() async {
  // 1. Hive initialisieren
  await Hive.initFlutter();

  // Adapter registrieren (nachdem build_runner lief)
  Hive.registerAdapter(SongModelAdapter());
  Hive.registerAdapter(PlaylistModelAdapter());

  // Boxen öffnen (Datenbank-Tabellen)
  final songBox = await Hive.openBox<SongModel>('songs');
  final settingsBox = await Hive.openBox('settings');
  final playlistBox = await Hive.openBox<PlaylistModel>('playlists');

  // 2. Services registrieren
  // Hier registrieren wir später den AudioHandler und SettingsService
  locator.registerSingleton<Box<SongModel>>(songBox);
  locator.registerSingleton<Box>(settingsBox, instanceName: 'settings');
  locator.registerSingleton<LibraryService>(LibraryService());
  locator.registerSingleton<Box<PlaylistModel>>(playlistBox);

  final audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.mucplay.channel.audio',
      androidNotificationChannelName: 'Music Player',
      androidNotificationOngoing: true,
    ),
  );

  locator.registerSingleton<AudioHandler>(audioHandler);
  // locator.registerSingleton<AudioHandler>(await initAudioService());
}
