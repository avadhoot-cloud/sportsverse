// sportsverse/frontend/sportsverse_app/lib/screens/auth/forgot_password_screen_new.dart

import 'package:flutter/material.dart';
import 'package:sportsverse_app/api/auth_api.dart';
import 'package:sportsverse_app/screens/auth/password_reset_confirm_screen.dart';

import 'package:sportsverse_app/api/auth_api.dart';
import 'package:sportsverse_app/screens/auth/password_reset_confirm_screen.dart';
import 'package:sportsverse_app/theme/elite_theme.dart';
import 'package:sportsverse_app/widgets/elite_button.dart';
import 'package:sportsverse_app/widgets/elite_text_input.dart';
import 'package:sportsverse_app/widgets/glass_header.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _requestPasswordReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await authApi.requestPasswordReset(
        _emailController.text.trim(),
      );

      if (response['reset_link'] != null && mounted) {
        String resetLink = response['reset_link'];
        final uri = Uri.parse(resetLink);
        final pathSegments = uri.pathSegments;
        final nonEmptySegments = pathSegments.where((s) => s.isNotEmpty).toList();

        if (nonEmptySegments.length >= 3 &&
            nonEmptySegments[nonEmptySegments.length - 3] == 'reset-password') {
          final uid = nonEmptySegments[nonEmptySegments.length - 2];
          final token = nonEmptySegments[nonEmptySegments.length - 1];

          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: EliteTheme.of(context).surfaceContainerLowest,
              title: Text('Password Reset', style: EliteTheme.of(context).subhead),
              content: Text(
                'Since email is not configured, we can take you directly to reset your password. Would you like to proceed?',
                style: EliteTheme.of(context).body,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: EliteTheme.of(context).caption),
                ),
                EliteButton(
                  text: 'Reset Password',
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PasswordResetConfirmScreen(uid: uid, token: token),
                      ),
                    );
                  },
                  variant: EliteButtonVariant.royal,
                ),
              ],
            ),
          );
        }
      } else {
        _showSnackBar(response['message'] ?? 'Password reset link sent to your email', Colors.green);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(e.toString().replaceAll('Exception: ', ''), Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = EliteTheme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassHeader(title: 'FORGOT PASSWORD'),
      body: SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/login_screen.png',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.primary.withOpacity(0.4),
                      theme.primary.withOpacity(0.95),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: theme.mobileMargin),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 80.0),
                      Text(
                        'RECOVER\nACCESS.',
                        style: theme.display1.copyWith(
                          height: 1.1,
                          color: theme.surfaceContainerLowest,
                        ),
                      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, curve: Curves.easeOutExpo),
                      const SizedBox(height: 16.0),
                      Text(
                        'Enter your email to receive a password reset link.',
                        style: theme.body.copyWith(color: theme.surfaceContainerLowest.withOpacity(0.7)),
                      ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.05, curve: Curves.easeOutExpo),
                      const SizedBox(height: 48.0),
                      
                      EliteTextInput(
                        controller: _emailController,
                        labelText: 'Email Address',
                        keyboardType: TextInputType.emailAddress,
                      ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.05, curve: Curves.easeOutExpo),
                      
                      const SizedBox(height: 32.0),
                      
                      EliteButton(
                        text: 'Send Reset Link',
                        isLoading: _isLoading,
                        onPressed: _requestPasswordReset,
                        variant: EliteButtonVariant.royal,
                      ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 0.05, curve: Curves.easeOutExpo),
                      
                      const SizedBox(height: 32.0),
                      
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'BACK TO LOGIN',
                            style: theme.subhead.copyWith(color: theme.surfaceContainerLowest),
                          ),
                        ),
                      ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
