// import 'package:audio_service/audio_service.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:mucplay/providers/library_provider.dart';
import 'package:mucplay/providers/playlist_provider.dart';
import 'package:mucplay/providers/selection_provider.dart';
import 'package:mucplay/providers/theme_provider.dart';

import 'package:provider/provider.dart';
import 'locator.dart';
import 'ui/screens/main_screen.dart';

// @pragma('vm:entry-point')
// Future<void> backgroundCallback(Uri? uri) async {
//   try {
//     // Wir versuchen auf den AudioHandler zuzugreifen
//     await setupLocator();
//     final handler = locator<AudioHandler>();

//     if (uri?.host == 'play') {
//       final playing = handler.playbackState.value.playing;
//       playing ? await handler.pause() : await handler.play();
//     } else if (uri?.host == 'next') {
//       await handler.skipToNext();
//     } else if (uri?.host == 'prev') {
//       await handler.skipToPrevious();
//     }
//   } catch (e) {
//     print("Widget Error: $e");
//   }
// }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Setup Dependency Injection & DB
  await setupLocator();

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
