import 'package:audio_service/audio_service.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mucplay/models/playlist_model.dart';
import 'package:mucplay/services/audio_handler.dart';
import 'package:mucplay/services/library_service.dart';
import 'models/song_model.dart';

final GetIt locator = GetIt.instance;

// Flag um zu prüfen ob Hive bereits initialisiert wurde
bool _hiveInitialized = false;

Future<void> setupLocator() async {
  // WICHTIG: Überprüfe zuerst, ob die Box bereits initialisiert ist
  // Das ist zuverlässiger als ein globales Flag, das nicht zwischen Isolates geteilt wird
  if (locator.isRegistered<Box<SongModel>>()) {
    print("DEBUG: Locator already initialized, skipping setup");
    return;
  }

  print("DEBUG: Initializing Locator...");

  // 1. Hive initialisieren (nur wenn noch nicht geschehen)
  try {
    if (!_hiveInitialized) {
      await Hive.initFlutter();
      _hiveInitialized = true;
      print("DEBUG: Hive initialized");
    }
  } catch (e) {
    print("DEBUG: Hive already initialized or error: $e");
    _hiveInitialized = true;
  }

  // Adapter registrieren (nachdem build_runner lief)
  Hive.registerAdapter(SongModelAdapter());
  Hive.registerAdapter(PlaylistModelAdapter());

  // Boxen öffnen (Datenbank-Tabellen)
  final songBox = await Hive.openBox<SongModel>('songs');
  final settingsBox = await Hive.openBox('settings');
  final playlistBox = await Hive.openBox<PlaylistModel>('playlists');

  // 2. Services registrieren
  locator.registerSingleton<Box<SongModel>>(songBox);
  locator.registerSingleton<Box>(settingsBox, instanceName: 'settings');
  locator.registerSingleton<LibraryService>(LibraryService());
  locator.registerSingleton<Box<PlaylistModel>>(playlistBox);

  // 3. AudioHandler initialisieren
  // WICHTIG: AudioService.init() wird nur aufgerufen wenn AudioHandler noch nicht registriert ist
  // Das verhindert mehrfache Instanzen, da GetIt.isRegistered() zuverlässiger ist als globale Flags
  if (!locator.isRegistered<AudioHandler>()) {
    print("DEBUG: Initializing AudioService...");
    final audioHandler = await AudioService.init(
      builder: () => AudioPlayerHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.example.mucplay.channel.audio',
        androidNotificationChannelName: 'Music Player',
        androidNotificationOngoing: true,
      ),
    );
    locator.registerSingleton<AudioHandler>(audioHandler);
    print("DEBUG: AudioService initialized");
  } else {
    print("DEBUG: AudioService already initialized, using existing handler");
  }

  print("DEBUG: Locator initialization complete");
}
