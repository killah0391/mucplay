import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mucplay/providers/library_provider.dart';
import 'package:mucplay/settings/widgets/settings_card.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class FolderManagementScreen extends StatelessWidget {
  const FolderManagementScreen({super.key});

  // Future<void> _pickFolder(BuildContext context) async {
  //   // 1. Berechtigung sicherstellen
  //   var status = await Permission.storage.status;
  //   if (!status.isGranted) {
  //     await Permission.storage.request();
  //   }
  //   // Android 11+ Check
  //   if (await Permission.manageExternalStorage.status.isDenied) {
  //     // Optional: User fragen
  //     // await Permission.manageExternalStorage.request();
  //   }

  //   // 2. Picker öffnen
  //   String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

  //   if (selectedDirectory != null && context.mounted) {
  //     // 3. Dem Provider hinzufügen
  //     Provider.of<LibraryProvider>(
  //       context,
  //       listen: false,
  //     ).addScanPath(selectedDirectory);
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LibraryProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bibliothek'),
        // actions: [
        //   IconButton(
        //     icon: Icon(Icons.restore),
        //     onPressed: () {},
        //     tooltip: 'Zurücksetzen',
        //   ),
        // ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Slider für Mindestdauer
          SettingsCard(
            // color: Colors.grey[900],
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Mindestdauer für Songs",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "Aktuell: ${provider.minDuration} Sekunden",
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(128),
                    ),
                  ),
                  Slider(
                    value: provider.minDuration.toDouble(),
                    min: 0,
                    max: 300, // Bis zu 5 Minuten
                    divisions: 60, // 5-Sekunden Schritte
                    label: "${provider.minDuration}s",
                    activeColor: Theme.of(context).colorScheme.primary,
                    onChanged: (val) {
                      provider.setMinDuration(val.toInt());
                    },
                  ),
                  Text(
                    "Songs kürzer als dieser Wert werden ignoriert (z.B. WhatsApp Audios).",
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(96),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Liste der überwachten Ordner
          Card(
            color: Colors.grey[900],
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.folder),
                  title: Text(
                    "Überwachte Ordner",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Zu scannende Ordner',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(128),
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.add, color: Colors.white),
                    onPressed: () => provider.pickAndScanFolder(),
                  ),
                ),
                // Liste der Pfade anzeigen
                if (provider.scanPaths.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      "Keine Ordner ausgewählt",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),

                ...provider.scanPaths.map(
                  (path) => ListTile(
                    title: Text(
                      path,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      onPressed: () => provider.removeFolder(path),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text("Bibliothek komplett neu scannen"),
            onPressed: provider.isScanning
                ? null
                : () => provider.rescanLibrary(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
