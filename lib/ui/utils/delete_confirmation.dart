import 'package:flutter/material.dart';
import 'package:mucplay/models/song_model.dart';
import 'package:mucplay/providers/library_provider.dart';
import 'package:mucplay/providers/selection_provider.dart';
import 'package:provider/provider.dart';

void deleteConfirmation(BuildContext context, List<SongModel> songs) {
  final libraryProvider = Provider.of<LibraryProvider>(context, listen: false);
  final selectionProvider = Provider.of<SelectionProvider>(
    context,
    listen: false,
  );
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: songs.length < 2
            ? Row(
                children: [
                  Icon(Icons.warning),
                  SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      "Möchtest du diesen Titel wirklich unwiederuflich vom Speicher löschen?",
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Icon(Icons.warning),
                  SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      "Möchtest du die ${songs.length} Titel wirklich unwiederuflich vom Speicher löschen?",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ],
              ),
        content: songs.length < 2
            ? Text("${songs.first.title}")
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Padding(
                    //   padding: const EdgeInsets.only(bottom: 8.0),
                    //   child: Text(
                    //     "Möchtest du die ${songs.length} Titel wirklich unwiederuflich vom Speicher löschen?",
                    //     style: TextStyle(
                    //       fontWeight: FontWeight.bold,
                    //       fontSize: 20,
                    //     ),
                    //   ),
                    // ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: songs.map((song) {
                        return Text(song.title);
                      }).toList(),
                    ),
                  ],
                ),
              ),
        actions: [
          // Abbrechen
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Abbrechen",
              style: TextStyle(color: Colors.white),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              libraryProvider.deleteSongs(songs);
              if (selectionProvider.isSelectionMode) {
                selectionProvider.clearSelection();
              }
            },
            child: const Text("Löschen", style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    },
  );
}
