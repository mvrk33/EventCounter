import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth_service.dart';
import '../core/constants.dart';
import '../core/sync_service.dart';
import '../features/notifications/notification_service.dart';
import '../features/settings/screens/settings_screen.dart';
import '../shared/theme/app_theme.dart';
import 'router.dart';

class EventCounterApp extends ConsumerStatefulWidget {
  const EventCounterApp({super.key});

  @override
  ConsumerState<EventCounterApp> createState() => _EventCounterAppState();
}

class _EventCounterAppState extends ConsumerState<EventCounterApp> {
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final SyncService sync = ref.read(syncServiceProvider);
      await sync.replayPendingSync();
      final auth = ref.read(authServiceProvider);
      if (auth.isSignedIn && await sync.shouldAutoRestoreOnLaunch()) {
        await sync.restoreAll();
      }
      await ref.read(notificationServiceProvider).requestPermissionsOnFirstLaunch();
    } catch (e) {
      // Silently handle initialization errors
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    if (_isInitializing) {
      return MaterialApp(
        title: AppConstants.appName,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        debugShowCheckedModeBanner: false,
        home: const _AppLoadingScreen(),
      );
    }

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class _AppLoadingScreen extends StatelessWidget {
  const _AppLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Image.asset(
                  AppConstants.logoAssetPath,
                  width: 84,
                  height: 84,
                ),
                const SizedBox(height: 14),
                Text(
                  AppConstants.appName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  AppConstants.loadingCaption,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface.withValues(alpha: 0.7),
                      ),
                ),
                const SizedBox(height: 20),
                const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

