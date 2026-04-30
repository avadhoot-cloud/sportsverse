import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sportsverse_app/theme/elite_theme.dart';

class GlassHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool useNavyStyle;

  const GlassHeader({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.useNavyStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = EliteTheme.of(context);
    
    final backgroundColor = useNavyStyle
        ? theme.primary.withOpacity(0.8)
        : theme.surface.withOpacity(0.85);
        
    final textColor = useNavyStyle ? theme.surfaceContainerLowest : theme.primary;

    return RepaintBoundary(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
          child: Container(
            color: backgroundColor,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: preferredSize.height,
                child: Row(
                  children: [
                    if (leading != null) ...[
                      const SizedBox(width: 8.0),
                      leading!,
                    ] else if (Navigator.canPop(context)) ...[
                      const SizedBox(width: 8.0),
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ] else ...[
                      const SizedBox(width: 24.0), // Mobile margin alignment
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: theme.display2.copyWith(color: textColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (actions != null) ...actions!,
                    const SizedBox(width: 16.0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(64.0);
}
