import 'package:flutter/material.dart';
import 'package:mucplay/providers/library_provider.dart';
import 'package:mucplay/settings/widgets/settings_card.dart';
import 'package:mucplay/settings/widgets/settings_section_header.dart';
import 'package:provider/provider.dart';

class StatisticsScreen extends StatelessWidget {
  final String? status;
  const StatisticsScreen({super.key, this.status});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistiken')),
      body: Consumer<LibraryProvider>(
        builder: (context, provider, child) {
          // final status = '';
          // final String? status;
          final status = provider.statisticsMode
              ? 'deaktivieren'
              : 'aktivieren';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SettingsSectionHeader(
                  title: "Statistiken anzeigen",
                  subtitle: '',
                ),
                SettingsCard(
                  child: SwitchListTile(
                    title: Text(
                      "Statistiken $status",
                      style: TextStyle(fontSize: 18),
                    ),
                    subtitle: Text(
                      "Fügt eine neue Ansicht zuletzt gespielter Titel hinzu",
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha(128),
                      ),
                    ),
                    value: provider.statisticsMode,
                    onChanged: (val) {
                      provider.setStatisticsMode(val);
                    },
                  ),
                ),
                provider.statisticsMode
                    ? Column(
                        children: [
                          SettingsSectionHeader(
                            title: "Zeiträume",
                            subtitle: '',
                          ),
                          SettingsCard(child: Text('data')),
                        ],
                      )
                    : SizedBox.shrink(),
              ],
            ),
          );
        },
      ),
    );
  }
}
