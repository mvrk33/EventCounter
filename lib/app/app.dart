import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/pin_security_service.dart';
import '../core/sync_service.dart';
import '../features/auth/screens/app_lock_screen.dart';
import '../features/notifications/notification_service.dart';
import '../features/settings/screens/settings_screen.dart';
import '../shared/theme/app_theme.dart';
import 'router.dart';

/// True when the app lock screen should be shown.
final StateProvider<bool> appLockedProvider =
    StateProvider<bool>((Ref ref) => false);

class EventCounterApp extends ConsumerStatefulWidget {
  const EventCounterApp({super.key, this.startupError});

  final String? startupError;

  @override
  ConsumerState<EventCounterApp> createState() => _EventCounterAppState();
}

class _EventCounterAppState extends ConsumerState<EventCounterApp>
    with WidgetsBindingObserver {
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Lock the app when it goes to background if app lock is enabled.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      final PinSecurityService pinSecurity =
          ref.read(pinSecurityServiceProvider);
      if (pinSecurity.isAppLockEnabled) {
        ref.read(appLockedProvider.notifier).state = true;
      }
    }
  }

  Future<void> _initializeApp() async {
    // Lock on first launch if app lock is enabled.
    final PinSecurityService pinSecurity = ref.read(pinSecurityServiceProvider);
    if (pinSecurity.isAppLockEnabled) {
      ref.read(appLockedProvider.notifier).state = true;
    }

    if (mounted) {
      setState(() => _isInitializing = false);
    }
    try {
      final SyncService sync = ref.read(syncServiceProvider);
      await sync.replayPendingSync();
      await ref.read(notificationServiceProvider).requestPermissionsOnFirstLaunch();
    } catch (e) {
      // Silently handle initialization errors
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final bool isLocked = ref.watch(appLockedProvider);

    if (widget.startupError != null) {
      return MaterialApp(
        title: 'Event Counter',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        debugShowCheckedModeBanner: false,
        home: _StartupFailureScreen(errorText: widget.startupError!),
      );
    }

    if (_isInitializing) {
      return MaterialApp(
        title: 'Event Counter',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        debugShowCheckedModeBanner: false,
        home: const _AppLoadingScreen(),
      );
    }

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Event Counter',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (BuildContext context, Widget? child) {
        if (isLocked) {
          return AppLockScreen(
            onUnlocked: () {
              ref.read(appLockedProvider.notifier).state = false;
            },
          );
        }
        return child ?? const SizedBox.shrink();
      },
    );
  }
}

class _AppLoadingScreen extends StatelessWidget {
  const _AppLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _StartupFailureScreen extends StatelessWidget {
  const _StartupFailureScreen({required this.errorText});

  final String errorText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Startup failed',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Daymark could not finish initialization. Please restart the app.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                errorText,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

