import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:daymark/app/app.dart';
import 'package:daymark/app/router.dart';
import 'package:daymark/core/sync_service.dart';

void main() {
  GoRouter buildTestRouter() {
    return GoRouter(
      initialLocation: '/home',
      routes: <GoRoute>[
        GoRoute(
          path: '/home',
          builder: (_, __) => const _TestHomeScreen(),
        ),
      ],
    );
  }

  testWidgets('app starts with loading and then shows routed screen',
      (WidgetTester tester) async {
    final GoRouter router = buildTestRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          routerProvider.overrideWithValue(router),
          // Force init path to throw early so this test stays fully deterministic.
          syncServiceProvider.overrideWith((Ref ref) => throw StateError('test init error')),
        ],
        child: const EventCounterApp(),
      ),
    );

    // First frame should show startup loading UI.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Test Home Ready'), findsNothing);

    // Next frame processes post-frame init and should leave loading state.
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Test Home Ready'), findsOneWidget);
  });

  testWidgets('startup health: app does not get stuck on loading screen',
      (WidgetTester tester) async {
    final GoRouter router = buildTestRouter();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          routerProvider.overrideWithValue(router),
          syncServiceProvider.overrideWith((Ref ref) => throw StateError('test init error')),
        ],
        child: const EventCounterApp(),
      ),
    );

    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Test Home Ready'), findsOneWidget);
  });
}

class _TestHomeScreen extends StatelessWidget {
  const _TestHomeScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Test Home Ready'),
      ),
    );
  }
}
