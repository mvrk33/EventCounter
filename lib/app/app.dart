import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth_service.dart';
import '../core/sync_service.dart';
import '../features/settings/screens/settings_screen.dart';
import '../shared/theme/app_theme.dart';
import 'router.dart';

class DayMarkApp extends ConsumerStatefulWidget {
  const DayMarkApp({super.key});

  @override
  ConsumerState<DayMarkApp> createState() => _DayMarkAppState();
}

class _DayMarkAppState extends ConsumerState<DayMarkApp> {
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
    } catch (e) {
      // Silently handle initialization errors
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'DayMark',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
