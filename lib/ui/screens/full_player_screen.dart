import 'dart:io';
import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:mucplay/models/song_model.dart';
import 'package:mucplay/providers/theme_provider.dart';
import 'package:mucplay/ui/utils/queue_popup.dart';
import 'package:mucplay/ui/utils/song_options.dart';
import 'package:mucplay/ui/widgets/album_art_widget.dart';
import 'package:provider/provider.dart';
import 'package:text_scroll/text_scroll.dart';
import '../../locator.dart';

class FullPlayerScreen extends StatelessWidget {
  final VoidCallback? onClose;

  const FullPlayerScreen({super.key, this.onClose});

  @override
  Widget build(BuildContext context) {
    final audioHandler = locator<AudioHandler>();
    final size = MediaQuery.of(context).size;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // Farben definieren
    final primaryColor = Theme.of(context).colorScheme.primary;
    final onPrimaryColor = Theme.of(context).colorScheme.onPrimary;
    Color surfaceColor = themeProvider.currentThemeMode == "amoled"
        ? Theme.of(context).scaffoldBackgroundColor
        : Theme.of(context).colorScheme.surface;

    // Logik: Bunter Hintergrund nur wenn Einstellung an UND kein Monochrom
    final bool useColoredBackground =
        themeProvider.useAccentColorPlayer && !themeProvider.isMonochrome;

    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;

        if (mediaItem == null) return const SizedBox.shrink();

        final currentSong = SongModel(
          path: mediaItem.extras?['path'] ?? '',
          title: mediaItem.title,
          artist: mediaItem.artist ?? 'Unbekannt',
          album: mediaItem.album ?? 'Unbekannt',
          durationMs: mediaItem.duration?.inMilliseconds ?? 0,
          format: mediaItem.extras?['format'] ?? '',
          artUri: mediaItem.artUri?.toFilePath(),
          year: mediaItem.extras?['year'] ?? 0,
          genre: mediaItem.genre ?? 'Unbekannt',
        );

        final bool hasCover =
            currentSong.artUri != null &&
            File(currentSong.artUri!).existsSync();

        return Stack(
          children: [
            // --- EBENE 1: HINTERGRUND (BILD ODER FARBE) ---
            Positioned.fill(
              child: hasCover
                  ? Image.file(
                      File(currentSong.artUri!),
                      fit: BoxFit.cover,
                      height: size.height,
                      width: size.width,
                      gaplessPlayback: true,
                    )
                  // WICHTIG: Die Farbe liegt jetzt hier unten!
                  // Dadurch liegt der Gradient (Ebene 2) DARÜBER.
                  : Container(
                      color: useColoredBackground ? primaryColor : surfaceColor,
                    ),
            ),

            // --- EBENE 2: DER GLAS-EFFEKT (BLUR & TÖNUNG & GRADIENT) ---
            Positioned.fill(
              child: BackdropFilter(
                blendMode: BlendMode.src,
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: hasCover
                          ? [
                              const Color.fromARGB(50, 174, 174, 174),
                              const Color.fromARGB(75, 255, 255, 255),
                              const Color.fromARGB(100, 174, 174, 174),
                            ]
                          : [
                              const Color.fromARGB(0, 174, 174, 174),
                              const Color.fromARGB(50, 255, 255, 255),
                              const Color.fromARGB(100, 255, 255, 255),
                            ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                    // Tönung nur bei Cover nötig, um es abzudunkeln/einzufärben.
                    // Ohne Cover haben wir ja schon die Farbe in Ebene 1.
                    color: hasCover
                        ? (useColoredBackground
                              ? primaryColor.withOpacity(0.5)
                              : Colors.black.withOpacity(0.3))
                        : primaryColor,
                  ),
                ),
              ),
            ),

            // --- EBENE 3: INHALT (Scaffold) ---
            Scaffold(
              // WICHTIG: Immer transparent, damit man Ebene 1 & 2 sieht!
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    size: 30,
                    color: useColoredBackground ? onPrimaryColor : primaryColor,
                  ),
                  onPressed: onClose,
                ),
                actions: [
                  IconButton(
                    icon: Icon(
                      Icons.more_vert,
                      size: 30,
                      color: useColoredBackground
                          ? onPrimaryColor
                          : primaryColor,
                    ),
                    onPressed: () {
                      songOptions(context, currentSong, playSong: false);
                    },
                  ),
                ],
              ),
              // ... Body bleibt unverändert ...
              body: SafeArea(
                // HIER IST DIE LOGIK FÜR DAS LAYOUT
                child: isLandscape
                    ? _buildLandscapeLayout(
                        context,
                        currentSong,
                        audioHandler,
                        mediaItem,
                        useColoredBackground,
                        primaryColor,
                        onPrimaryColor,
                      )
                    : _buildPortraitLayout(
                        context,
                        currentSong,
                        size,
                        audioHandler,
                        mediaItem,
                        useColoredBackground,
                        primaryColor,
                        onPrimaryColor,
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPortraitLayout(
    BuildContext context,
    SongModel currentSong,
    Size size,
    AudioHandler audioHandler,
    MediaItem mediaItem,
    bool useColoredBackground,
    Color primaryColor,
    Color onPrimaryColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          const Spacer(flex: 1),
          // Cover
          _buildCover(
            context,
            currentSong,
            size.width * 0.85,
            useColoredBackground,
            primaryColor,
          ),
          const SizedBox(height: 50),
          // Infos
          _buildSongInfo(
            currentSong,
            useColoredBackground,
            primaryColor,
            onPrimaryColor,
          ),
          const Spacer(flex: 2),
          // Slider
          _buildSlider(
            context,
            audioHandler,
            mediaItem,
            useColoredBackground,
            primaryColor,
            onPrimaryColor,
          ),
          const SizedBox(height: 20),
          // Controls
          _buildControls(
            context,
            audioHandler,
            currentSong,
            useColoredBackground,
            primaryColor,
            onPrimaryColor,
          ),
          const SizedBox(height: 40),
          // Bottom Actions
          _buildBottomActions(
            context,
            audioHandler,
            useColoredBackground,
            primaryColor,
            onPrimaryColor,
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // Das NEUE Querformat-Layout
  Widget _buildLandscapeLayout(
    BuildContext context,
    SongModel currentSong,
    AudioHandler audioHandler,
    MediaItem mediaItem,
    bool useColoredBackground,
    Color primaryColor,
    Color onPrimaryColor,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 8, 32, 24),
      child: Row(
        children: [
          // LINKS: Cover
          Expanded(
            flex: 5,
            child: Center(
              child: _buildCover(
                context,
                currentSong,
                300, // Maximale Größe im Landscape
                useColoredBackground,
                primaryColor,
              ),
            ),
          ),
          const SizedBox(width: 32),
          // RECHTS: Infos & Controls
          Expanded(
            flex: 6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                _buildSongInfo(
                  currentSong,
                  useColoredBackground,
                  primaryColor,
                  onPrimaryColor,
                ),
                const SizedBox(height: 20),
                _buildSlider(
                  context,
                  audioHandler,
                  mediaItem,
                  useColoredBackground,
                  primaryColor,
                  onPrimaryColor,
                ),
                const SizedBox(height: 10),
                _buildControls(
                  context,
                  audioHandler,
                  currentSong,
                  useColoredBackground,
                  primaryColor,
                  onPrimaryColor,
                ),
                const SizedBox(height: 20),
                _buildBottomActions(
                  context,
                  audioHandler,
                  useColoredBackground,
                  primaryColor,
                  onPrimaryColor,
                ),
                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- KOMPONENTEN WIDGETS ---

  Widget _buildCover(
    BuildContext context,
    SongModel currentSong,
    double size,
    bool useColoredBackground,
    Color primaryColor,
  ) {
    return Hero(
      tag: 'currentArtwork',
      child: GlassmorphicContainer(
        width: size,
        height: size,
        borderRadius: 20,
        blur: 20,
        alignment: Alignment.center,
        border: 2,
        linearGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: useColoredBackground
              ? [
                  Theme.of(context).colorScheme.surface.withAlpha(64),
                  Theme.of(context).colorScheme.surface.withAlpha(128),
                ]
              : [primaryColor.withAlpha(64), primaryColor.withAlpha(128)],
          stops: const [0.1, 1],
        ),
        borderGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: useColoredBackground
              ? [
                  Theme.of(context).colorScheme.surface.withAlpha(64),
                  Theme.of(context).colorScheme.surface.withAlpha(128),
                ]
              : [primaryColor.withAlpha(64), primaryColor.withAlpha(128)],
        ),
        child: AlbumArtWidget(
          song: currentSong,
          size: size,
          borderRadius: 20,
          allowOverlay: false,
          transparentBackground: true,
        ),
      ),
    );
  }

  Widget _buildSongInfo(
    SongModel currentSong,
    bool useColoredBackground,
    Color primaryColor,
    Color onPrimaryColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          TextScroll(
            currentSong.title,
            mode: TextScrollMode.endless,
            velocity: const Velocity(pixelsPerSecond: Offset(30, 0)),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: useColoredBackground ? onPrimaryColor : primaryColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currentSong.artist,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: useColoredBackground
                  ? onPrimaryColor.withAlpha(160)
                  : primaryColor.withAlpha(160),
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(
    BuildContext context,
    AudioHandler audioHandler,
    MediaItem mediaItem,
    bool useColoredBackground,
    Color primaryColor,
    Color onPrimaryColor,
  ) {
    return StreamBuilder<Duration>(
      stream: AudioService.position,
      initialData: audioHandler.playbackState.value.position,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = mediaItem.duration ?? Duration.zero;
        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                trackHeight: 4,
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: useColoredBackground
                    ? onPrimaryColor
                    : primaryColor,
                inactiveTrackColor: useColoredBackground
                    ? onPrimaryColor.withAlpha(64)
                    : primaryColor.withAlpha(64),
                thumbColor: useColoredBackground
                    ? onPrimaryColor
                    : primaryColor,
              ),
              child: Slider(
                value: position.inMilliseconds.toDouble().clamp(
                  0.0,
                  duration.inMilliseconds.toDouble(),
                ),
                min: 0.0,
                max: duration.inMilliseconds.toDouble(),
                onChanged: (value) {
                  audioHandler.seek(Duration(milliseconds: value.toInt()));
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(position),
                    style: TextStyle(
                      color: useColoredBackground
                          ? onPrimaryColor.withAlpha(128)
                          : primaryColor.withAlpha(128),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _formatDuration(duration),
                    style: TextStyle(
                      color: useColoredBackground
                          ? onPrimaryColor.withAlpha(128)
                          : primaryColor.withAlpha(128),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControls(
    BuildContext context,
    AudioHandler audioHandler,
    SongModel currentSong,
    bool useColoredBackground,
    Color primaryColor,
    Color onPrimaryColor,
  ) {
    final bool hasCover =
        currentSong.artUri != null && File(currentSong.artUri!).existsSync();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildShuffleButton(
          audioHandler,
          context,
          useColoredBackground ? onPrimaryColor : primaryColor,
        ),
        IconButton(
          icon: Icon(
            Icons.skip_previous_rounded,
            color: useColoredBackground ? onPrimaryColor : primaryColor,
            size: 45,
          ),
          onPressed: audioHandler.skipToPrevious,
        ),
        _buildPlayPauseButton(audioHandler, context, hasCover),
        IconButton(
          icon: Icon(
            Icons.skip_next_rounded,
            color: useColoredBackground ? onPrimaryColor : primaryColor,
            size: 45,
          ),
          onPressed: audioHandler.skipToNext,
        ),
        _buildRepeatButton(
          audioHandler,
          context,
          useColoredBackground ? onPrimaryColor : primaryColor,
        ),
      ],
    );
  }

  Widget _buildBottomActions(
    BuildContext context,
    AudioHandler audioHandler,
    bool useColoredBackground,
    Color primaryColor,
    Color onPrimaryColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        IconButton(
          icon: Icon(
            Icons.queue_music,
            color: useColoredBackground ? onPrimaryColor : primaryColor,
          ),
          onPressed: () => queuePopup(context, audioHandler),
        ),
        IconButton(
          icon: Icon(
            Icons.equalizer,
            color: useColoredBackground ? onPrimaryColor : primaryColor,
          ),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Equalizer kommt bald!")),
            );
          },
        ),
      ],
    );
  }

  // --- HELPER METHODEN (Bleiben unverändert) ---
  Widget _buildPlayPauseButton(
    AudioHandler handler,
    BuildContext context,
    bool hasCover,
  ) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final onPrimaryColor = Theme.of(context).colorScheme.onPrimary;

    return StreamBuilder<PlaybackState>(
      stream: handler.playbackState,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing ?? false;
        return Container(
          width: 75,
          height: 75,
          decoration: BoxDecoration(
            color: playing ? primaryColor : onPrimaryColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20),
            ],
          ),
          child: IconButton(
            icon: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: playing ? onPrimaryColor : primaryColor,
              size: 45,
            ),
            onPressed: playing ? handler.pause : handler.play,
          ),
        );
      },
    );
  }

  Widget _buildShuffleButton(
    AudioHandler handler,
    BuildContext context,
    Color activeColor,
  ) {
    return StreamBuilder<PlaybackState>(
      stream: handler.playbackState,
      builder: (context, snapshot) {
        final mode = snapshot.data?.shuffleMode ?? AudioServiceShuffleMode.none;
        final isActive = mode == AudioServiceShuffleMode.all;
        Color primary = Theme.of(context).colorScheme.primary;
        final themeProvider = Provider.of<ThemeProvider>(context);

        final bool useColoredBackground =
            themeProvider.useAccentColorPlayer && !themeProvider.isMonochrome;

        if (useColoredBackground) {
          primary = Theme.of(context).colorScheme.onPrimary;
        } else {
          primary = Theme.of(context).colorScheme.onSurface;
        }

        final color = isActive ? activeColor : primary.withAlpha(64);

        return IconButton(
          icon: Icon(Icons.shuffle, color: color),
          onPressed: () {
            handler.setShuffleMode(
              isActive
                  ? AudioServiceShuffleMode.none
                  : AudioServiceShuffleMode.all,
            );
          },
        );
      },
    );
  }

  Widget _buildRepeatButton(
    AudioHandler handler,
    BuildContext context,
    Color activeColor,
  ) {
    return StreamBuilder<PlaybackState>(
      stream: handler.playbackState,
      builder: (context, snapshot) {
        final mode = snapshot.data?.repeatMode ?? AudioServiceRepeatMode.none;
        Color primary = Theme.of(context).colorScheme.primary;
        final themeProvider = Provider.of<ThemeProvider>(context);

        final bool useColoredBackground =
            themeProvider.useAccentColorPlayer && !themeProvider.isMonochrome;

        if (useColoredBackground) {
          primary = Theme.of(context).colorScheme.onPrimary;
        } else {
          primary = Theme.of(context).colorScheme.onSurface;
        }

        IconData icon = Icons.repeat;
        bool isActive = mode != AudioServiceRepeatMode.none;

        if (mode == AudioServiceRepeatMode.one) {
          icon = Icons.repeat_one;
        }

        final color = isActive ? activeColor : primary.withAlpha(64);

        return IconButton(
          icon: Icon(icon, color: color),
          onPressed: () {
            final next = mode == AudioServiceRepeatMode.none
                ? AudioServiceRepeatMode.all
                : (mode == AudioServiceRepeatMode.all
                      ? AudioServiceRepeatMode.one
                      : AudioServiceRepeatMode.none);
            handler.setRepeatMode(next);
          },
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    if (d.inMilliseconds == 0) return "0:00";
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }
}
