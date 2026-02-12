// import 'package:audio_service/audio_service.dart';
import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:mucplay/providers/library_provider.dart';
import 'package:mucplay/providers/playlist_provider.dart';
import 'package:mucplay/providers/selection_provider.dart';
import 'package:mucplay/providers/theme_provider.dart';

import 'package:provider/provider.dart';
import 'locator.dart';
import 'ui/screens/main_screen.dart';

@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  print("🎵 HomeWidget Callback: $uri");

  try {
    if (uri == null) return;

    print("DEBUG: Processing widget intent - host: ${uri.host}");

    // setupLocator mit globalem Flag verhindert mehrfache AudioService.init() Aufrufe
    await setupLocator();
    final handler = locator<AudioHandler>();

    // Kleine Verzögerung um sicherzustellen dass Handler ein Running ist
    await Future.delayed(const Duration(milliseconds: 200));

    if (uri.host == 'shuffle') {
      print("DEBUG: Handling SHUFFLE");
      final current = handler.playbackState.value.shuffleMode;
      print("DEBUG: Current shuffle: $current");

      final next = current == AudioServiceShuffleMode.all
          ? AudioServiceShuffleMode.none
          : AudioServiceShuffleMode.all;

      print("DEBUG: Setting shuffle to: $next");
      await handler.setShuffleMode(next);
      print("✓ Shuffle updated");
    } else if (uri.host == 'repeat') {
      print("DEBUG: Handling REPEAT");
      final current = handler.playbackState.value.repeatMode;
      print("DEBUG: Current repeat: $current");

      final next = current == AudioServiceRepeatMode.none
          ? AudioServiceRepeatMode.all
          : (current == AudioServiceRepeatMode.all
                ? AudioServiceRepeatMode.one
                : AudioServiceRepeatMode.none);

      print("DEBUG: Setting repeat to: $next");
      await handler.setRepeatMode(next);
      print("✓ Repeat updated");
    }
  } catch (e, stack) {
    print("❌ Error in widget callback: $e");
    print("Stack: $stack");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Setup Dependency Injection & DB
  await setupLocator();

  // Widget-Status Listener starten
  _startWidgetStatusListener();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
        ChangeNotifierProvider(create: (_) => SelectionProvider()),
        ChangeNotifierProvider(create: (_) => PlaylistProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

void _startWidgetStatusListener() {
  // Prüft alle 500ms, ob Widget Play/Pause gedrückt hat und synchronisiert den Player
  Timer.periodic(const Duration(milliseconds: 500), (timer) async {
    // Hole den aktuellen Status aus HomeWidget
    final isPlaying = await HomeWidget.getWidgetData<bool>('isPlaying');
    final title = await HomeWidget.getWidgetData<String>('title');
    final artist = await HomeWidget.getWidgetData<String>('artist');

    final handler = locator<AudioHandler>();
    final appPlaying = handler.playbackState.value.playing;
    final appTitle = handler.mediaItem.value?.title;
    final appArtist = handler.mediaItem.value?.artist;

    // Wenn Widget Play/Pause gedrückt hat und Status abweicht, synchronisieren
    if (isPlaying != null && isPlaying != appPlaying) {
      if (isPlaying) {
        await handler.play();
      } else {
        await handler.pause();
      }
    }

    // Wenn Widget einen anderen Song anzeigt, synchronisieren
    if (title != null &&
        artist != null &&
        (title != appTitle || artist != appArtist)) {
      // Hier könntest du den Song anhand Titel/Artist suchen und abspielen
      // Beispiel: handler.playSongByTitleAndArtist(title, artist);
      // (Implementierung in AudioHandler nötig)
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          title: 'Ultimate Music Player',
          debugShowCheckedModeBanner: false,

          // Wir übergeben das System-Schema an unsere neue getTheme Methode
          theme: themeProvider.getTheme(lightDynamic, false),
          darkTheme: themeProvider.getTheme(darkDynamic, true),

          themeMode: themeProvider.flutterThemeMode,

          home: const MainScreen(),
        );
      },
    );
  }
}
