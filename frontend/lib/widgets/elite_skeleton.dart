import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sportsverse_app/theme/elite_theme.dart';

class EliteSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const EliteSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 20.0,
    this.borderRadius = 8.0,
  });

  /// Factory constructor for a card-sized skeleton
  factory EliteSkeleton.card({double height = 120.0}) {
    return EliteSkeleton(
      height: height,
      borderRadius: 32.0,
    );
  }

  /// Factory constructor for a text-line skeleton
  factory EliteSkeleton.text({double width = 100.0}) {
    return EliteSkeleton(
      width: width,
      height: 16.0,
      borderRadius: 4.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = EliteTheme.of(context);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.surfaceContainer, // Base color #EDEDF2
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(
          duration: 1500.ms,
          color: theme.surfaceContainerLowest.withOpacity(0.5), // Shimmer pure white
          angle: 1.0, // slight diagonal
        );
  }
}
