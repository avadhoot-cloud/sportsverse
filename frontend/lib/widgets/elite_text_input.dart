import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sportsverse_app/theme/elite_theme.dart';

class EliteTextInput extends StatefulWidget {
  final TextEditingController? controller;
  final String labelText;
  final String? hintText;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  const EliteTextInput({
    super.key,
    this.controller,
    required this.labelText,
    this.hintText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.errorText,
    this.onChanged,
    this.prefixIcon,
    this.suffixIcon,
  });

  @override
  State<EliteTextInput> createState() => _EliteTextInputState();
}

class _EliteTextInputState extends State<EliteTextInput> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = EliteTheme.of(context);
    final hasError = widget.errorText != null;

    // Determine colors based on state machine
    Color backgroundColor = theme.surfaceContainer; // Default #EDEDF2
    Color borderColor = Colors.transparent;

    if (hasError) {
      backgroundColor = theme.errorBackground;
      borderColor = theme.errorBorder;
    } else if (_isFocused) {
      backgroundColor = theme.surfaceContainerLowest; // White
      borderColor = theme.primary; // Navy
    }

    Widget inputContainer = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24.0), // md radius
        border: Border.all(color: borderColor, width: 1.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        onChanged: widget.onChanged,
        style: theme.body,
        cursorColor: theme.primary,
        decoration: InputDecoration(
          labelText: widget.labelText,
          labelStyle: theme.subhead.copyWith(
            color: hasError
                ? Colors.red
                : _isFocused
                    ? theme.primary
                    : theme.disabledText,
          ),
          hintText: widget.hintText,
          hintStyle: theme.body.copyWith(color: theme.disabledText),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          prefixIcon: widget.prefixIcon,
          suffixIcon: widget.suffixIcon,
          // Hide default error text to handle it externally for cleaner layout
          errorStyle: const TextStyle(height: 0),
        ),
      ),
    );

    // Apply error shake animation if needed
    if (hasError) {
      inputContainer = inputContainer.animate(key: ValueKey(widget.errorText)).shakeX(amount: 4, duration: 300.ms);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        inputContainer,
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 20.0, top: 8.0),
            child: Text(
              widget.errorText!,
              style: theme.caption.copyWith(color: Colors.red),
            ).animate().fadeIn(duration: 200.ms),
          ),
      ],
    );
  }
}
