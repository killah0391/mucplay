import 'package:audio_service/audio_service.dart';
import 'package:audiotags/audiotags.dart'; // Wichtig für das Auslesen des Jahres
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mucplay/locator.dart';
import 'package:mucplay/models/song_model.dart';
import 'package:mucplay/providers/library_provider.dart';
import 'package:mucplay/services/tag_editor_service.dart';
import 'package:provider/provider.dart';

class TagEditorDialog extends StatefulWidget {
  final SongModel song;

  const TagEditorDialog({super.key, required this.song});

  @override
  State<TagEditorDialog> createState() => _TagEditorDialogState();
}

class _TagEditorDialogState extends State<TagEditorDialog> {
  late TextEditingController _titleController;
  late TextEditingController _artistController;
  late TextEditingController _albumController;
  late TextEditingController _yearController; // NEU
  late TextEditingController _genreController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.song.title);
    _artistController = TextEditingController(text: widget.song.artist);
    _albumController = TextEditingController(text: widget.song.album);
    _yearController = TextEditingController(
      text: widget.song.year?.toString() ?? "",
    );
    _genreController = TextEditingController(text: widget.song.genre);

    _loadYear();
  }

  // Jahr asynchron aus der Datei lesen (da nicht im SongModel)
  Future<void> _loadYear() async {
    try {
      final tag = await AudioTags.read(widget.song.path);
      if (tag?.year != null && mounted) {
        setState(() {
          _yearController.text = tag!.year.toString();
        });
      }
    } catch (e) {
      print("Konnte Jahr nicht lesen: $e");
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _albumController.dispose();
    _yearController.dispose();
    _genreController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);

    // Player Logik (Stop wenn läuft) ...
    final audioHandler = locator<AudioHandler>();
    final currentItem = audioHandler.mediaItem.value;
    if (currentItem?.id == widget.song.path) {
      await audioHandler.stop();
    }

    // 1. Tags physisch schreiben
    final success = await TagEditorService.saveTags(
      song: widget.song,
      newTitle: _titleController.text,
      newArtist: _artistController.text,
      newAlbum: _albumController.text,
      newYear: _yearController.text,
      newGenre: _genreController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      // 2. Datenbank (Hive) direkt aktualisieren -> KEIN RESCAN NÖTIG
      final box = locator<Box<SongModel>>();

      // Neues Model erstellen (da Felder final sind)
      final updatedSong = SongModel(
        path: widget.song.path,
        title: _titleController.text,
        artist: _artistController.text,
        album: _albumController.text,
        year: int.tryParse(_yearController.text),
        genre: _genreController.text,
        durationMs: widget.song.durationMs,
        format: widget.song.format,
        artUri: widget.song.artUri,
        isFavorite: widget.song.isFavorite,
      );

      // In Hive speichern (nutzt den gleichen Key/Pfad)
      await box.put(widget.song.path, updatedSong);

      // 3. UI aktualisieren (nur RAM neu laden)
      context.read<LibraryProvider>().reloadSongs();

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tags erfolgreich gespeichert")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Fehler beim Speichern (siehe Logs)"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text(
        "Tags bearbeiten",
        style: TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              )
            else ...[
              _buildTextField("Titel", _titleController),
              const SizedBox(height: 10),
              _buildTextField("Künstler", _artistController),
              const SizedBox(height: 10),
              _buildTextField("Album", _albumController),
              const SizedBox(height: 10),
              // NEU: Jahr Feld
              _buildTextField("Jahr", _yearController, isNumber: true),
              const SizedBox(height: 10),
              _buildTextField("Genre", _genreController),
              const SizedBox(height: 10),

              Text(
                "Pfad: ${widget.song.path.split('/').last}",
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!_isLoading) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              "Abbrechen",
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            child: const Text(
              "Speichern",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.blueAccent),
        ),
      ),
    );
  }
}
