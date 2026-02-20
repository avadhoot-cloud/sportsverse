// sportsverse/frontend/sportsverse_app/lib/screens/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sportsverse_app/providers/auth_provider.dart';

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

    print('🔐 Starting login process...');
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      // 2. Perform the login request
      await authProvider.login(
        _usernameController.text,
        _passwordController.text,
      );

      // 3. CRITICAL: Check if the widget is still in the tree before proceeding
      if (!mounted) return;

      print('🔐 Login request finished. Current user: ${authProvider.currentUser?.username}');

      if (authProvider.currentUser != null) {
        _showSnackBar('Login successful!', Colors.green);
        print('🔐 Navigating based on user role: ${authProvider.currentUser?.userType}');

        // 4. Role-based Navigation
        String userRole = authProvider.currentUser?.userType ?? 'STUDENT';

        if (userRole == 'STUDENT') {
          Navigator.of(context).pushNamedAndRemoveUntil('/student-home', (route) => false);
        } else if (userRole == 'ACADEMY_ADMIN') {
          Navigator.of(context).pushNamedAndRemoveUntil('/admin-home', (route) => false);
        } else if (userRole == 'COACH') {
          Navigator.of(context).pushNamedAndRemoveUntil('/coach-home', (route) => false);
        } else {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
        
      } else {
        // Handle failed login (wrong credentials)
        print('🔐 Login failed: ${authProvider.errorMessage}');
        _showSnackBar(authProvider.errorMessage ?? 'Login failed. Please check your credentials.', Colors.red);
      }
    } catch (e) {
      // Handle unexpected exceptions
      if (!mounted) return;
      print('🔐 Login error: $e');
      _showSnackBar('Login error: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    // Check mounted because SnackBars depend on Scaffold context
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Clear existing ones
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Login to SportsVerse',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Logo section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(
                  Icons.sports_soccer, 
                  size: 80,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(height: 32.0),
              
              // Username/Email Field
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username or Email',
                  prefixIcon: Icon(Icons.person),
                  hintText: 'Enter your username or email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16.0),
              
              // Password Field
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
              ),
              const SizedBox(height: 24.0),
              
              // Login Button with Loading State
              Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  return authProvider.isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                          onPressed: _login,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            elevation: 5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Log In',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        );
                },
              ),
              const SizedBox(height: 20.0),
              
              // Navigation Buttons
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/register-academy');
                },
                child: Text(
                  "Don't have an academy? Register Here",
                  style: TextStyle(color: Colors.blue.shade600),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/forgot-password');
                },
                child: Text(
                  "Forgot Password?",
                  style: TextStyle(color: Colors.blue.shade400),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}