import 'package:flutter/material.dart';
import 'package:text_scroll/text_scroll.dart';

class SmartText extends StatelessWidget {
  final String title;
  final Color? textColor;

  const SmartText(this.title, this.textColor, {super.key});

  @override
  Widget build(BuildContext context) {
    // Implement scroll setting from application settings
    return TextScroll(
      title,
      mode: TextScrollMode.bouncing,
      velocity: const Velocity(pixelsPerSecond: Offset(30, 0)),
      delayBefore: const Duration(seconds: 2),
      pauseBetween: const Duration(seconds: 5),
      fadedBorder: false,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: textColor,
        // fontSize: 14,
      ),
    );
  }
}
