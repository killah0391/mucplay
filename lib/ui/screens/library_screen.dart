import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:mucplay/locator.dart';
import 'package:mucplay/providers/playlist_provider.dart';
import 'package:mucplay/providers/theme_provider.dart';
import 'package:mucplay/ui/tabs/albums_tab.dart';
import 'package:mucplay/ui/tabs/playlists_tab.dart';
import 'package:mucplay/ui/tabs/years_tab.dart';
import 'package:provider/provider.dart';
import '../../providers/library_provider.dart';
import '../widgets/song_tile.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Provider abrufen
    // final provider = context.watch<LibraryProvider>();
    // final showPlaylistsTab = provider.playlistNavigationMode == 'tab';

    // // 2. Tabs dynamisch aufbauen
    // final tabs = [
    //   const Tab(text: "Titel"),
    //   if (showPlaylistsTab) const Tab(text: "Playlists"), // Bedingt
    //   const Tab(text: "Album"),
    //   const Tab(text: "Interpret"),
    //   const Tab(text: "Genre"),
    //   const Tab(text: "Jahr"),
    // ];

    // final tabViews = [
    //   _buildSongList(provider),
    //   if (showPlaylistsTab) const PlaylistsTab(), // Bedingt
    //   const AlbumsTab(),
    //   const Center(child: Text("Interpreten Ansicht kommt bald")),
    //   const Center(child: Text("Genre Ansicht kommt bald")),
    //   const YearsTab(),
    // ];

    // WICHTIG: DefaultTabController Länge muss dynamisch sein!
    // Wir nutzen 'key', damit Flutter den Controller neu baut, wenn sich die Länge ändert.
    return Consumer<LibraryProvider>(
      builder: (context, provider, child) {
        // 1. Reihenfolge holen
        final order = provider.tabOrder;

        // 2. Definitionen aller möglichen Tabs
        // Hier mappen wir den Key auf das Widget und den Titel
        final Map<String, Widget> tabContents = {
          'songs': _buildSongList(provider),
          'playlists': const PlaylistsTab(),
          'albums': const AlbumsTab(),
          'artists': const Center(
            child: Text("Interpreten Ansicht kommt bald"),
          ),
          'genres': const Center(child: Text("Genre Ansicht kommt bald")),
          'years': const YearsTab(),
        };

        final Map<String, String> tabTitles = {
          'songs': 'Titel',
          'playlists': 'Playlists',
          'albums': 'Album',
          'artists': 'Interpret',
          'genres': 'Genre',
          'years': 'Jahr',
        };

        // 3. Listen für TabBar und TabView aufbauen
        final List<Widget> myTabs = [];
        final List<Widget> myViews = [];

        for (String key in order) {
          // Spezialfall: Playlists überspringen, wenn Modus == 'nav'
          if (key == 'playlists' && provider.playlistNavigationMode == 'nav') {
            continue;
          }

          // Sicherheitscheck, falls ein unbekannter Key in Hive ist
          if (tabContents.containsKey(key)) {
            myTabs.add(Tab(text: tabTitles[key]));
            myViews.add(tabContents[key]!);
          }
        }

        final themeProvider = Provider.of<ThemeProvider>(context);

        // 4. DefaultTabController mit dynamischer Länge
        return DefaultTabController(
          key: ValueKey(myTabs.length), // Rebuild bei Änderung
          length: myTabs.length,
          child: Scaffold(
            backgroundColor: themeProvider.currentThemeMode == "amoled"
                ? Theme.of(context).scaffoldBackgroundColor
                : Theme.of(context).colorScheme.surface,
            appBar: AppBar(
              title: const Text('Bibliothek'),
              backgroundColor: themeProvider.currentThemeMode == "amoled"
                  ? Theme.of(context).scaffoldBackgroundColor
                  : Theme.of(context).colorScheme.surface,
              bottom: TabBar(
                physics: ScrollPhysics(),
                tabAlignment: TabAlignment.center,
                labelPadding: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(vertical: 12),
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  color: Theme.of(context).colorScheme.primary,
                ),
                labelColor: Theme.of(context).colorScheme.onPrimary,
                splashBorderRadius: BorderRadius.circular(50),
                isScrollable: true,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: myTabs, // Dynamische Liste nutzen
              ),
            ),
            body: TabBarView(
              physics: provider.libraryTabMode
                  ? ScrollPhysics()
                  : NeverScrollableScrollPhysics(),
              children: myViews, // Dynamische Views
            ),
          ),
        );
      },
    );
  }

  Widget _buildSongList(LibraryProvider provider) {
    return ListView.builder(
      itemCount: provider.songs.length,
      padding: EdgeInsets.only(
        bottom: provider.currentSongId != null ? 100 : 0,
      ),
      itemBuilder: (context, index) {
        final song = provider.songs[index];

        // 1. Prüfen: Ist das der aktuell geladene Song? (Egal ob Pause oder Play)
        final bool isCurrent = provider.currentSongId == song.path;

        return SongTile(
          song: song,
          isCurrent: isCurrent, // Neue Property nutzen
          onTap: () {
            // Logik für Tap
            if (isCurrent) {
              // Wenn es schon der aktuelle Song ist: Play/Pause toggeln
              if (provider.isPlaying) {
                locator<AudioHandler>().pause();
              } else {
                locator<AudioHandler>().play();
              }
            } else {
              // Wenn es ein neuer Song ist: Abspielen
              context.read<PlaylistProvider>().setActivePlaylist(null);
              provider.playSong(provider.songs, index);
            }
          },
        );
      },
    );
  }
}
