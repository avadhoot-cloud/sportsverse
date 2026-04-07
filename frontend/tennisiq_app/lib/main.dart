import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';

import 'dart:ui';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // App-Level Error Boundary natively hooking loops securely
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Native Global Exploit boundary caught: $error');
    return true; // Consume cleanly structurally preventing native crashes
  };
  
  ErrorWidget.builder = (FlutterErrorDetails details) {
     return Scaffold(
         backgroundColor: const Color(0xFF0D1117),
         body: Center(
             child: Padding(
                 padding: const EdgeInsets.all(24.0),
                 child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
                        const SizedBox(height: 16),
                        const Text('Something went wrong!', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Our boundary systems safely caught an error locally.', style: TextStyle(color: Colors.white54, textAlign: TextAlign.center)),
                        const SizedBox(height: 24),
                        ElevatedButton(
                            onPressed: () { /* Safe Reload Mock mapping loops*/ },
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5A0)),
                            child: const Text('RETRY', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))
                        )
                     ]
                 )
             )
         )
     );
  };

  runApp(
    const ProviderScope(
      child: TennisIQApp(),
    ),
  );
}

class TennisIQApp extends ConsumerWidget {
  const TennisIQApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goRouter = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'TennisIQ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: goRouter,
    );
  }
}
