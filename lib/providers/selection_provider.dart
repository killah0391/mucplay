import 'package:flutter/material.dart';
import '../../../models/song_model.dart';

class SelectionProvider extends ChangeNotifier {
  // Ist der Auswahlmodus aktiv?
  bool _isSelectionMode = false;

  // Welche Songs sind ausgewählt? (Wir speichern IDs oder Song-Objekte)
  final Set<SongModel> _selectedSongs = {};

  bool get isSelectionMode => _isSelectionMode;
  int get selectedCount => _selectedSongs.length;
  List<SongModel> get selectedSongs => _selectedSongs.toList();

  // Prüfen, ob ein Song gewählt ist
  bool isSelected(SongModel song) => _selectedSongs.contains(song);

  // Modus starten (z.B. mit dem ersten Song)
  void startSelection(SongModel initialSong) {
    _isSelectionMode = true;
    _selectedSongs.clear();
    _selectedSongs.add(initialSong);
    notifyListeners();
  }

  // Song umschalten (An/Aus)
  void toggleSong(SongModel song) {
    if (_selectedSongs.contains(song)) {
      _selectedSongs.remove(song);
      // Wenn keine Songs mehr gewählt sind, Modus beenden?
      if (_selectedSongs.isEmpty) {
        _isSelectionMode = false;
      }
    } else {
      _selectedSongs.add(song);
    }
    notifyListeners();
  }

  // Alles abwählen / Modus beenden
  void clearSelection() {
    _isSelectionMode = false;
    _selectedSongs.clear();
    notifyListeners();
  }

  // Alles auswählen (optional)
  void selectAll(List<SongModel> allSongs) {
    _selectedSongs.addAll(allSongs);
    notifyListeners();
  }
}
