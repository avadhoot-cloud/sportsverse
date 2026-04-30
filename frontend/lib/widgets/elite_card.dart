import 'package:flutter/material.dart';
import 'package:sportsverse_app/theme/elite_theme.dart';

class EliteCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const EliteCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = EliteTheme.of(context);
    final cardPadding = padding ?? EdgeInsets.all(theme.cardPadding);

    Widget card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: theme.surfaceContainerLowest, // Pure White
        borderRadius: BorderRadius.circular(theme.cardRadius), // 32px
        // 1px subtle border as allowed by blueprint for definition
        border: Border.all(color: theme.surfaceContainer, width: 1.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(theme.cardRadius),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: theme.primary.withOpacity(0.05),
            highlightColor: theme.primary.withOpacity(0.02),
            child: Padding(
              padding: cardPadding,
              child: child,
            ),
          ),
        ),
      ),
    );

    return card;
  }
}
