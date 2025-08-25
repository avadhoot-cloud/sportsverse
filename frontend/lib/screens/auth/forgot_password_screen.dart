// sportsverse/frontend/sportsverse_app/lib/screens/auth/forgot_password_screen_new.dart

import 'package:flutter/material.dart';
import 'package:sportsverse_app/api/auth_api.dart';
import 'package:sportsverse_app/screens/auth/password_reset_confirm_screen.dart';

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

      print('DEBUG: Got response: $response'); // Debug log

      // Check if we got a reset link (development mode)
      if (response['reset_link'] != null && mounted) {
        String resetLink = response['reset_link'];
        print('DEBUG: Got reset link: $resetLink'); // Debug log

        // Extract UID and token from URL
        final uri = Uri.parse(resetLink);
        final pathSegments = uri.pathSegments;

        print('DEBUG: Path segments: $pathSegments'); // Debug log

        // Filter out empty segments and find reset-password
        final nonEmptySegments = pathSegments
            .where((s) => s.isNotEmpty)
            .toList();

        if (nonEmptySegments.length >= 3 &&
            nonEmptySegments[nonEmptySegments.length - 3] == 'reset-password') {
          final uid = nonEmptySegments[nonEmptySegments.length - 2];
          final token = nonEmptySegments[nonEmptySegments.length - 1];

          print('DEBUG: Extracted UID: $uid, Token: $token'); // Debug log

          // Show dialog and navigate to password reset screen
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Password Reset'),
              content: const Text(
                'Since email is not configured, we can take you directly to reset your password. '
                'Would you like to proceed?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            PasswordResetConfirmScreen(uid: uid, token: token),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Reset Password'),
                ),
              ],
            ),
          );
        } else {
          print('DEBUG: Failed to parse reset link path segments');
        }
      } else {
        print('DEBUG: No reset_link in response or not mounted');
        // Show success message if email was sent
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message'] ?? 'Password reset link sent to your email',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot Password'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                const Icon(Icons.lock_reset, size: 80, color: Colors.blue),
                const SizedBox(height: 24),
                const Text(
                  'Reset Your Password',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Enter your email address and we\'ll help you reset your password.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'Enter your registered email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!RegExp(
                      r'^[^@]+@[^@]+\.[^@]+',
                    ).hasMatch(value.trim())) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _requestPasswordReset(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _requestPasswordReset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('Sending...'),
                          ],
                        )
                      : const Text(
                          'Send Reset Link',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
                const SizedBox(height: 32),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Back to Login',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
