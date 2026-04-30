import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sportsverse_app/theme/elite_theme.dart';

enum EliteButtonVariant { primary, secondary, accent, royal }

class EliteButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final EliteButtonVariant variant;
  final IconData? icon;

  const EliteButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.variant = EliteButtonVariant.primary,
    this.icon,
  });

  @override
  State<EliteButton> createState() => _EliteButtonState();
}

class _EliteButtonState extends State<EliteButton> {
  bool _isPressed = false;

  bool get _isDisabled => widget.onPressed == null || widget.isLoading;

  Color _getBackgroundColor(EliteTheme theme) {
    if (_isDisabled) return theme.disabledBackground;
    switch (widget.variant) {
      case EliteButtonVariant.primary:
        return theme.primary;
      case EliteButtonVariant.secondary:
        return theme.surfaceContainerLowest; // White
      case EliteButtonVariant.accent:
        return theme.accent;
      case EliteButtonVariant.royal:
        return theme.royalAccent;
    }
  }

  Color _getTextColor(EliteTheme theme) {
    if (_isDisabled) return theme.disabledText;
    switch (widget.variant) {
      case EliteButtonVariant.primary:
        return theme.surfaceContainerLowest; // White
      case EliteButtonVariant.secondary:
        return theme.primary; // Navy
      case EliteButtonVariant.accent:
        return theme.primary; // Navy
      case EliteButtonVariant.royal:
        return theme.surfaceContainerLowest; // White
    }
  }

  BorderSide _getBorder(EliteTheme theme) {
    if (widget.variant == EliteButtonVariant.secondary && !_isDisabled) {
      return BorderSide(color: theme.primary, width: 1.0);
    }
    return BorderSide.none;
  }

  @override
  Widget build(BuildContext context) {
    final theme = EliteTheme.of(context);

    return GestureDetector(
      onTapDown: _isDisabled ? null : (_) => setState(() => _isPressed = true),
      onTapUp: _isDisabled ? null : (_) => setState(() => _isPressed = false),
      onTapCancel: _isDisabled ? null : () => setState(() => _isPressed = false),
      onTap: _isDisabled ? null : widget.onPressed,
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutQuad,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
          decoration: BoxDecoration(
            color: _getBackgroundColor(theme),
            borderRadius: BorderRadius.circular(100.0), // Fully rounded
            border: Border.fromBorderSide(_getBorder(theme)),
          ),
          child: Center(
            child: widget.isLoading
                ? _buildLoadingDots(theme)
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: _getTextColor(theme), size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        widget.text.toUpperCase(),
                        style: theme.subhead.copyWith(
                          color: _getTextColor(theme),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 200.ms),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingDots(EliteTheme theme) {
    final color = _getTextColor(theme);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color.withOpacity(0.8),
            shape: BoxShape.circle,
          ),
        )
            .animate(onPlay: (controller) => controller.repeat())
            .fadeIn(duration: 400.ms, delay: (index * 200).ms)
            .then(delay: 400.ms)
            .fadeOut(duration: 400.ms);
      }),
    );
  }
}
