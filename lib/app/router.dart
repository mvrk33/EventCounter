import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth_service.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/events/screens/home_screen.dart';

final Provider<GoRouter> routerProvider = Provider<GoRouter>((Ref ref) {
  final AuthService auth = ref.read(authServiceProvider);
  final _GoRouterRefreshStream refresh = _GoRouterRefreshStream(auth.authStateChanges);
  ref.onDispose(refresh.dispose);

  final GoRouter router = GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      final bool isSignedIn = ref.read(authServiceProvider).isSignedIn;
      final bool isOnLogin = state.matchedLocation == '/login';
      if (isSignedIn && isOnLogin) {
        return '/home';
      }
      if (!isSignedIn && !isOnLogin) {
        return '/login';
      }
      return null;
    },
    routes: <GoRoute>[
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _GoRouterRefreshStream extends ChangeNotifier {
  _GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((dynamic _) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

