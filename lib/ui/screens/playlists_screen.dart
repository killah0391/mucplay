import 'package:flutter/material.dart';
import 'package:mucplay/ui/tabs/playlists_tab.dart';

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Playlists"),
        automaticallyImplyLeading: false, // Kein Zurück-Pfeil in der MainNav
        // actions: [
        //   IconButton(
        //     onPressed: () {
        //       showCreatePlaylistNameDialog(context, initialSongs: []);
        //     },
        //     icon: Icon(Icons.add),
        //   ),
        // ],
      ),
      body: const PlaylistsTab(),
    );
  }
}
