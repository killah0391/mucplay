import 'package:flutter/material.dart';

class SmartTile extends StatelessWidget {
  final RoundedRectangleBorder? shape;
  final BorderRadius? borderRadius;
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final Color? tileColor;
  final Color? textColor;
  final TextStyle style = const TextStyle();
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  const SmartTile({
    super.key,
    this.shape,
    this.borderRadius,
    required this.title,
    this.tileColor,
    this.onTap,
    this.textColor,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        shape:
            shape ??
            RoundedRectangleBorder(
              borderRadius: borderRadius ?? BorderRadius.circular(8),
            ),
        tileColor: tileColor ?? Colors.transparent,
        title: Text(
          title is Text ? (title as Text).data ?? "" : "",
          style: TextStyle(color: textColor ?? Colors.white),
        ),
        // style: textColor,
        onTap: onTap,
        leading: leading,
        subtitle: subtitle,
        trailing: trailing,
        onLongPress: onLongPress,
      ),
    );
  }
}
