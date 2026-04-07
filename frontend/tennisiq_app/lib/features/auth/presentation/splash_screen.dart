import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  
  @override
  void initState() {
    super.initState();
    _checkRouting();
  }

  void _checkRouting() async {
    // Adding slight delay to let UI render the beautiful green brand
    await Future.delayed(const Duration(seconds: 2));
    final status = ref.read(authProvider).status;
    if (mounted) {
      if (status == AuthStatus.authenticated) {
        context.go('/dashboard');
      } else {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D1117),
      body: Center(
        child: Text(
          'TennisIQ',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00E5A0),
            letterSpacing: 2.0,
          ),
        ),
      ),
    );
  }
}
