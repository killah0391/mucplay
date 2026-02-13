import 'dart:async';
import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:mucplay/providers/library_provider.dart';
import 'package:mucplay/providers/selection_provider.dart';
import 'package:mucplay/providers/theme_provider.dart';
import 'package:mucplay/settings/screens/home_widget_settings_screen.dart';
import 'package:mucplay/settings/screens/player_theme_settings_screen.dart';
import 'package:mucplay/settings/screens/settings_screen.dart';
import 'package:mucplay/ui/screens/playlists_screen.dart';
import 'package:mucplay/ui/screens/statistics_screen.dart';
import 'package:mucplay/ui/utils/selection_bar.dart';
import 'package:provider/provider.dart';
// Importiere den SettingsScreen
import '../../locator.dart';
import 'library_screen.dart';
import 'full_player_screen.dart';
import '../widgets/mini_player.dart';
import '../../main.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _playerController;
  late Animation<double> _navbarAnimation;
  final AudioHandler _audioHandler = locator<AudioHandler>();
  final double _miniPlayerHeight = 80.0;
  DateTime? _lastBackPressTime;

  final GlobalKey<NavigatorState> _libraryNavKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _playlistsNavKey =
      GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> _statisticsNavKey =
      GlobalKey<NavigatorState>();

  static const platform = MethodChannel('com.example.mucplay/widget');

  // NEU: Navigation State
  int _currentIndex = 0;

  StreamSubscription? _mediaItemSub;

  // NEU: Die Screens, zwischen denen gewechselt wird
  // final List<Widget> _screens = [const LibraryScreen(), const SettingsScreen()];

  void _navigateToSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const HomeWidgetSettingsScreen(), // Dein Screen
      ),
    );
  }

  // Deine existierende _handleLoadFromWidget Funktion anpassen
  void _handleLoadFromWidget(Uri? uri) {
    if (uri != null && uri.toString().contains("settings")) {
      _navigateToSettings();
    }
  }

  @override
  void initState() {
    super.initState();
    _playerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _navbarAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(_playerController);

    _mediaItemSub = _audioHandler.mediaItem.listen((item) {
      // Wenn das Item null wird (Stop/Löschen) UND der Player offen war
      if (item == null && _playerController.value > 0.0) {
        // Fahre die Animation zurück -> Navbar erscheint wieder
        _playerController.reverse();
      }
    });
    // HomeWidget.registerInteractivityCallback(backgroundCallback);
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleLoadFromWidget);
    HomeWidget.widgetClicked.listen(_handleLoadFromWidget);

    platform.setMethodCallHandler((call) async {
      if (call.method == 'openSettings') {
        // Hier direkt zu den Settings navigieren
        _navigateToSettings();
      }
    });

    _checkConfigurationLaunch();
  }

  Future<void> _checkConfigurationLaunch() async {
    // Da home_widget das Configure-Event nicht direkt als URI liefert,
    // nutzen wir einen kleinen Trick: Wir prüfen einfach, ob wir die App
    // "frisch" öffnen. Wenn wir wollen, können wir auch MethodChannel nutzen,
    // aber oft reicht es, die Logik in Step 3 zu haben und hier einfach zu prüfen:

    // Einfacherer Weg mit home_widget (leider eingeschränkt):
    // Wir bauen eine Logik: Wenn die App startet, und wir wollen
    // direkt zu Settings, machen wir das.

    // Für eine echte Unterscheidung bräuchten wir Platform Channels.
    // Aber da du im Schritt 2 in MainActivity "setResult OK" sendest,
    // öffnet sich die App ganz normal.

    // Um direkt zu den Settings zu springen, können wir in MainActivity.kt
    // dem Intent noch Daten mitgeben, aber das ist komplex.

    // ALTERNATIVE: Wir lassen es so. Wenn du auf "Bearbeiten" klickst,
    // öffnet sich die App. Da du ja willst, dass man direkt einstellen kann,
    // bauen wir uns eine Vorschau in den Settings Screen!
  }

  @override
  void dispose() {
    _playerController.dispose();
    _mediaItemSub?.cancel();
    super.dispose();
  }

  // --- GESTEN LOGIK ---
  void _onVerticalDragUpdate(DragUpdateDetails details, double screenHeight) {
    if (_audioHandler.mediaItem.value == null) return;
    double delta = details.primaryDelta! / (screenHeight - _miniPlayerHeight);
    _playerController.value -= delta;
    if (_playerController.value <= 0.01 && details.primaryDelta! > 5) {
      _audioHandler.stop();
      _playerController.reset();
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_playerController.isDismissed) return;
    double velocity = details.primaryVelocity ?? 0;
    if (velocity < -500) {
      _playerController.forward();
    } else if (velocity > 500) {
      _playerController.reverse();
    } else {
      if (_playerController.value > 0.5) {
        _playerController.forward();
      } else {
        _playerController.reverse();
      }
    }
  }

  void _closePlayer() {
    _playerController.reverse();
  }

  // NEU: Tab Wechsel Funktion
  void _onTabTapped(int index) {
    // Einstellungen hinzufügen um das dem Nutzer zu überlassen, ob zum Anfang der Liste gesprungen werden soll, wenn bereits in der Bibliothek und erneut auf Bibliothek getippt wird
    final libraryProvider = Provider.of<LibraryProvider>(
      context,
      listen: false,
    );
    final bool showPlaylistsInNav =
        libraryProvider.playlistNavigationMode == 'nav';

    // Logik für Bibliothek (Tab 0)
    if (index == 0 && _currentIndex == 0) {
      _libraryNavKey.currentState?.popUntil((route) => route.isFirst);
    }

    // NEU: Logik für Playlists (Tab 1, falls aktiv)
    if (showPlaylistsInNav && index == 1 && _currentIndex == 1) {
      _playlistsNavKey.currentState?.popUntil((route) => route.isFirst);
    }

    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Provider abhören
    final selectionProvider = Provider.of<SelectionProvider>(context);
    final libraryProvider = Provider.of<LibraryProvider>(context);

    // Checken, welcher Modus aktiv ist
    final bool showPlaylistsInNav =
        libraryProvider.playlistNavigationMode == 'nav';
    final statisticsEnabled = libraryProvider.statisticsMode;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final surfaceColor = themeProvider.currentThemeMode == "amoled"
        ? Theme.of(context).scaffoldBackgroundColor
        : Theme.of(context).colorScheme.surface;

    // Screens definieren
    final List<Widget> screens = [
      // Navigator(
      //   key: _homeNavKey,
      //   onGenerateRoute: (settings) =>
      //       MaterialPageRoute(builder: (_) => const HomeTab()),
      // ),
      // Index 0: Bibliothek
      Navigator(
        key: _libraryNavKey,
        onGenerateRoute: (settings) =>
            MaterialPageRoute(builder: (_) => const LibraryScreen()),
      ),

      // Index 1 (nur wenn aktiv): Playlists
      if (showPlaylistsInNav)
        Navigator(
          key: _playlistsNavKey,
          onGenerateRoute: (settings) =>
              MaterialPageRoute(builder: (_) => const PlaylistsScreen()),
        ),

      if (statisticsEnabled)
        Navigator(
          key: _statisticsNavKey,
          onGenerateRoute: (settings) =>
              MaterialPageRoute(builder: (_) => const StatisticsScreen()),
        ),

      // Index 1 oder 2: Einstellungen
      const SettingsScreen(),
    ];

    // Nav Items definieren
    final List<BottomNavigationBarItem> navItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.music_note),
        label: "Bibliothek",
      ),

      if (showPlaylistsInNav)
        const BottomNavigationBarItem(
          icon: Icon(Icons.queue_music),
          label: "Playlists",
        ),

      if (statisticsEnabled)
        const BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart),
          label: "Statistiken",
        ),

      BottomNavigationBarItem(
        icon: Icon(Icons.settings),
        label: "Einstellungen",
      ),
    ];

    // Sicherstellen, dass _currentIndex gültig bleibt (falls man von 3 Tabs auf 2 wechselt)
    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;

        // 1. Wenn FullPlayer offen ist -> schließen
        if (_playerController.value > 0.1) {
          _closePlayer();
          return;
        }

        // 2. Wenn wir im Library Tab sind und dort tiefer navigiert haben -> zurück
        // (z.B. von Album-Detail zurück zur Liste)
        if (_currentIndex == 0) {
          // Bibliothek Zurück
          final navigator = _libraryNavKey.currentState;
          if (navigator != null && navigator.canPop()) {
            navigator.pop();
            return;
          }
        } else if (showPlaylistsInNav && _currentIndex == 1) {
          // NEU: Playlist Zurück
          final navigator = _playlistsNavKey.currentState;
          if (navigator != null && navigator.canPop()) {
            navigator.pop();
            return;
          }
        }

        // 3. NEU: Double-Back-To-Exit Logik
        final now = DateTime.now();
        final difference = now.difference(
          _lastBackPressTime ?? DateTime(0),
        ); // Zeitunterschied berechnen
        const exitWarningDuration = Duration(
          seconds: 2,
        ); // Zeitfenster: 2 Sekunden

        // Wenn der letzte Klick länger als 2 Sek her ist ODER es noch gar keinen gab
        if (difference > exitWarningDuration) {
          _lastBackPressTime = now; // Zeit merken

          // Hinweis anzeigen
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                "Zum Beenden nochmal drücken",
                style: TextStyle(color: Colors.white),
              ),
              duration: exitWarningDuration,
              behavior: SnackBarBehavior.floating, // Schwebt über der Leiste
              margin: EdgeInsets.all(20), // Etwas Abstand vom Rand
              backgroundColor: Colors.grey[900],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          return; // Wir beenden hier, damit die App NICHT schließt
        }

        // 4. Wenn wir hier ankommen, wurde innerhalb von 2 Sek. zweimal gedrückt
        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: surfaceColor,
        bottomNavigationBar: selectionProvider.isSelectionMode
            ? buildSelectionBar(context, selectionProvider)
            : SizeTransition(
                sizeFactor: _navbarAnimation,
                axisAlignment: -1.0,

                child: BottomNavigationBar(
                  selectedItemColor: Theme.of(context).colorScheme.onPrimary,
                  unselectedItemColor: Theme.of(
                    context,
                  ).colorScheme.onPrimary.withAlpha(128),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  currentIndex: _currentIndex,
                  onTap:
                      _onTabTapped, // Die Funktion muss Index-unabhängig funktionieren, das tut sie meistens
                  items: navItems, // Dynamische Liste
                ),
              ),

        body: StreamBuilder<MediaItem?>(
          stream: _audioHandler.mediaItem,
          builder: (context, snapshot) {
            final bool hasSong = snapshot.data != null;

            return Stack(
              children: [
                Positioned.fill(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: screens, // Dynamische Screens
                  ),
                ),

                // 2. DER PLAYER (bleibt wie er ist)
                if (hasSong && !selectionProvider.isSelectionMode)
                  AnimatedBuilder(
                    animation: _playerController,
                    builder: (context, child) {
                      final height = lerpDouble(
                        _miniPlayerHeight + bottomPadding,
                        screenHeight,
                        _playerController.value,
                      )!;

                      final fullPlayerOpacity =
                          (_playerController.value - 0.2) / 0.8;
                      final miniPlayerOpacity =
                          1.0 - (_playerController.value / 0.2);

                      return Positioned(
                        height: height,
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onVerticalDragUpdate: (d) =>
                              _onVerticalDragUpdate(d, screenHeight),
                          onVerticalDragEnd: _onVerticalDragEnd,
                          onTap: () {
                            if (_playerController.value < 0.1) {
                              _playerController.forward();
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(
                                  lerpDouble(
                                    0,
                                    30,
                                    1 - _playerController.value,
                                  )!,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context).colorScheme.primary,
                                  blurRadius: 10,
                                  offset: const Offset(0, -2),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // Full Player UI
                                if (_playerController.value > 0.01)
                                  Opacity(
                                    opacity: fullPlayerOpacity.clamp(0.0, 1.0),
                                    child: IgnorePointer(
                                      ignoring: _playerController.value < 0.5,
                                      child: OverflowBox(
                                        minHeight: screenHeight,
                                        maxHeight: screenHeight,
                                        alignment: Alignment.topCenter,
                                        child: FullPlayerScreen(
                                          onClose: _closePlayer,
                                        ),
                                      ),
                                    ),
                                  ),

                                // Mini Player UI
                                // FIX: 'if' entfernt, damit der Player im Speicher bleibt und den
                                // Fortschritt auch im pausierten Zustand behält.
                                Opacity(
                                  opacity: miniPlayerOpacity.clamp(0.0, 1.0),
                                  child: IgnorePointer(
                                    ignoring: _playerController.value > 0.2,
                                    child: const SizedBox(
                                      height: 80,
                                      child: MiniPlayer(isInteractive: true),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
