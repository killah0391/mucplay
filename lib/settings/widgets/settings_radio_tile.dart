import 'package:flutter/material.dart';

class SettingsRadioTile<T> extends StatelessWidget {
  final String title;
  final T value;

  const SettingsRadioTile({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    // Wir übergeben KEIN groupValue und KEIN onChanged mehr.
    // RadioListTile sucht nun automatisch im Widget-Baum nach einer "RadioGroup".
    return RadioListTile<T>(
      title: Text(
        title,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
      value: value,
      activeColor: Theme.of(context).colorScheme.primary,
      // groupValue: ... (Entfernt)
      // onChanged: ... (Entfernt)
    );
  }
}
