import 'package:flutter/material.dart';
import 'package:sportsverse_app/theme/elite_theme.dart';

enum BadgeStatus { live, neutral, inactive, success, error }

class PerformanceBadge extends StatelessWidget {
  final String label;
  final BadgeStatus status;
  final IconData? icon;

  const PerformanceBadge({
    super.key,
    required this.label,
    this.status = BadgeStatus.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = EliteTheme.of(context);

    Color backgroundColor;
    Color textColor;

    switch (status) {
      case BadgeStatus.live:
        backgroundColor = theme.accent; // Lime
        textColor = theme.primary; // Navy
        break;
      case BadgeStatus.neutral:
        backgroundColor = theme.primary; // Navy
        textColor = theme.surfaceContainerLowest; // White
        break;
      case BadgeStatus.inactive:
        backgroundColor = theme.disabledBackground;
        textColor = theme.disabledText;
        break;
      case BadgeStatus.success:
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade900;
        break;
      case BadgeStatus.error:
        backgroundColor = theme.errorBackground;
        textColor = Colors.red.shade900;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(100.0), // Pill shape
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4.0),
          ],
          Text(
            label.toUpperCase(),
            style: theme.caption.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}
