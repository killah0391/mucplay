import 'package:hive_flutter/hive_flutter.dart';

class StorageService {
  static const String boxName = 'mucplay_box';
  static const String keyScanPaths = 'scan_paths';

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(boxName);
  }

  Box get _box => Hive.box(boxName);

  // --- SCAN PFADE SPEICHERN & LADEN ---

  List<String> getScanPaths() {
    final dynamic data = _box.get(
      keyScanPaths,
      defaultValue: ['/storage/emulated/0/Music'],
    );
    return List<String>.from(data);
  }

  Future<void> saveScanPaths(List<String> paths) async {
    await _box.put(keyScanPaths, paths);
  }

  Future<void> resetScanPaths(String path) async {
    await _box.put(keyScanPaths, '/storage/emulated/0/Music');
  }
}
