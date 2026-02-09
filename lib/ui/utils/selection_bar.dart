import 'package:flutter/material.dart';

import 'package:mucplay/ui/utils/song_options.dart';

import 'package:mucplay/providers/selection_provider.dart';

Widget buildSelectionBar(BuildContext context, SelectionProvider provider) {
  return Container(
    height: 70, // Etwas höher für bessere Bedienung
    decoration: BoxDecoration(
      color: Theme.of(
        context,
      ).colorScheme.primary, // Oder AppColors.cardBackground
      boxShadow: [
        BoxShadow(
          color: Theme.of(context).colorScheme.primary.withAlpha(128),
          blurRadius: 10,
          offset: const Offset(0, -2),
        ),
      ],
    ),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 1. ABBRECHEN BUTTON
            TextButton.icon(
              onPressed: () => provider.clearSelection(),
              icon: Icon(
                Icons.close,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
              label: Text(
                "Abbrechen",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),

            // 2. ZÄHLER (Wie viele gewählt?)
            Text(
              "${provider.selectedCount} gewählt",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
            IconButton(
              onPressed: () {
                songOptions(context, provider.selectedSongs.first);
              },
              icon: Icon(
                Icons.more_vert,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
