import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/dashboard/presentation/home_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/session/presentation/session_placeholders.dart';
import '../../features/watch/presentation/watch_scan_screen.dart';
import '../../features/session/presentation/watch_session_screen.dart';
import '../../features/session/presentation/video_session_screen.dart';
import '../../features/session/presentation/video_processing_screen.dart';
import '../../features/session/presentation/fusion_session_screen.dart';
import '../../features/session/presentation/session_detail_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Listen to Auth State changes logically
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggingIn = state.uri.toString() == '/login' || state.uri.toString() == '/register';
      final isSplash = state.uri.toString() == '/';
      
      // If unauthenticated and NOT explicitly on a login/register/splash route, force to login
      if (authState.status == AuthStatus.unauthenticated && !isLoggingIn && !isSplash) {
        return '/login';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/session-detail/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return SessionDetailScreen(sessionId: id);
        },
      ),
      GoRoute(
        path: '/session-active/:mode',
        builder: (context, state) {
          final mode = state.pathParameters['mode']!;
          if (mode == 'video_only') return const VideoSessionScreen();
          if (mode == 'fusion') return const FusionSessionScreen();
          return WatchSessionScreen(mode: mode);
        },
      ),
      GoRoute(
        path: '/video-processing/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return VideoProcessingScreen(sessionId: id);
        },
      ),
      GoRoute(
        path: '/watch-scan',
        builder: (context, state) => const WatchScanScreen(),
      ),
    ],
  );
});
