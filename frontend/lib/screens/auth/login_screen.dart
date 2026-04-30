// sportsverse/frontend/sportsverse_app/lib/screens/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sportsverse_app/providers/auth_provider.dart';

import 'package:sportsverse_app/theme/elite_theme.dart';
import 'package:sportsverse_app/widgets/elite_button.dart';
import 'package:sportsverse_app/widgets/elite_text_input.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  void _login() async {
    // 1. Basic validation
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar('Please enter username/email and password.', Colors.red);
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      // 2. Perform the login request
      await authProvider.login(
        _usernameController.text,
        _passwordController.text,
      );

      // 3. CRITICAL: Check if the widget is still in the tree before proceeding
      if (!mounted) return;

      if (authProvider.currentUser != null) {
        _showSnackBar('Login successful!', Colors.green);

        // 4. Navigate to '/' — the root route's Consumer<AuthProvider> already
        //    switches to the correct dashboard based on user type.
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        
      } else {
        // Handle failed login (wrong credentials)
        _showSnackBar(authProvider.errorMessage ?? 'Login failed. Please check your credentials.', Colors.red);
      }
    } catch (e) {
      // Handle unexpected exceptions
      if (!mounted) return;
      _showSnackBar('Login error: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = EliteTheme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: SizedBox.expand(
        child: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: Image.asset(
                'assets/images/login_screen.png',
                fit: BoxFit.cover,
              ),
            ),
            
            // Dark Gradient Overlay for readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.primary.withOpacity(0.5), // Lighter at top
                      theme.primary.withOpacity(0.95), // Dark Navy at bottom
                    ],
                  ),
                ),
              ),
            ),
            
            // Content
            SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: theme.mobileMargin),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 80.0),
                      
                      // Editorial Header
                      Text(
                        'WELCOME\nTO THE CLUB.',
                        style: theme.display1.copyWith(
                          height: 1.1,
                          color: theme.surfaceContainerLowest, // White text
                        ),
                      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, curve: Curves.easeOutExpo),
                      
                      const SizedBox(height: 16.0),
                      Text(
                        'Sign in to access your dashboard.',
                        style: theme.body.copyWith(color: theme.surfaceContainerLowest.withOpacity(0.7)),
                      ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.05, curve: Curves.easeOutExpo),
                      
                      const SizedBox(height: 48.0),
                      
                      // Form Fields
                      Column(
                        children: [
                          EliteTextInput(
                            controller: _usernameController,
                            labelText: 'Username or Email',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16.0),
                          EliteTextInput(
                            controller: _passwordController,
                            labelText: 'Password',
                            obscureText: !_isPasswordVisible,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                color: theme.primary,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                          ),
                        ],
                      ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.05, curve: Curves.easeOutExpo),
                      
                      const SizedBox(height: 32.0),
                      
                      // Login Button
                      Consumer<AuthProvider>(
                        builder: (context, authProvider, child) {
                          return EliteButton(
                            text: 'Log In',
                            isLoading: authProvider.isLoading,
                            onPressed: _login,
                            variant: EliteButtonVariant.royal,
                          );
                        },
                      ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideY(begin: 0.05, curve: Curves.easeOutExpo),
                      
                      const SizedBox(height: 32.0),
                      
                      // Footer Links
                      Center(
                        child: Column(
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pushNamed(context, '/register-academy'),
                              child: Text(
                                "REGISTER ACADEMY",
                                style: theme.subhead.copyWith(color: theme.surfaceContainerLowest),
                              ),
                            ),
                            const SizedBox(height: 8.0),
                            TextButton(
                              onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                              child: Text(
                                "FORGOT PASSWORD?",
                                style: theme.caption.copyWith(color: theme.surfaceContainerLowest.withOpacity(0.6)),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
                      
                      const SizedBox(height: 40.0), // Extra padding at bottom
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