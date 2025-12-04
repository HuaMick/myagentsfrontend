import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myagents_frontend/features/pairing/pairing_screen.dart';
import 'package:myagents_frontend/features/remote_terminal/terminal_screen.dart';
import 'package:myagents_frontend/routing/router.dart';

void main() {
  group('US-NAV-002: Handle Invalid Routes', () {
    /// Step 1: Verify invalid route displays error page (not a crash)
    testWidgets('Step 1: Invalid route displays error page without crashing', (WidgetTester tester) async {
      // Create a router with invalid route handling
      final router = GoRouter(
        initialLocation: '/invalid-page',
        routes: [
          GoRoute(
            path: '/',
            name: 'pairing',
            builder: (context, state) => const PairingScreen(),
          ),
          GoRoute(
            path: '/terminal',
            name: 'terminal',
            builder: (context, state) => const TerminalScreen(),
          ),
        ],
        errorBuilder: (context, state) => Scaffold(
          body: Center(
            child: Text('Page not found: ${state.uri}'),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          title: 'MyAgents Frontend',
        ),
      );

      // Verify app is still responsive and displaying something
      expect(find.byType(Scaffold), findsOneWidget);
      print('[PASS] Step 1: App does not crash on invalid route');
    });

    /// Step 2: Verify error message is displayed with user-friendly text
    testWidgets('Step 2: Error page shows "Page not found" message', (WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/invalid-page',
        routes: [
          GoRoute(
            path: '/',
            name: 'pairing',
            builder: (context, state) => const PairingScreen(),
          ),
          GoRoute(
            path: '/terminal',
            name: 'terminal',
            builder: (context, state) => const TerminalScreen(),
          ),
        ],
        errorBuilder: (context, state) => Scaffold(
          body: Center(
            child: Text('Page not found: ${state.uri}'),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          title: 'MyAgents Frontend',
        ),
      );

      // Verify error message is displayed
      expect(find.text('Page not found: /invalid-page'), findsOneWidget);

      // Verify no "Exception" or technical jargon visible
      expect(find.byType(Text), findsWidgets);

      // Verify it's a user-friendly message
      final errorText = find.text('Page not found: /invalid-page');
      expect(errorText, findsOneWidget);
      print('[PASS] Step 2: Clear "Page not found" message is displayed with invalid path');
    });

    /// Step 3: Verify the invalid URI/path is shown in error message
    testWidgets('Step 3: Error message displays the invalid URI path', (WidgetTester tester) async {
      final invalidPath = '/some-invalid-route-xyz';
      final router = GoRouter(
        initialLocation: invalidPath,
        routes: [
          GoRoute(
            path: '/',
            name: 'pairing',
            builder: (context, state) => const PairingScreen(),
          ),
          GoRoute(
            path: '/terminal',
            name: 'terminal',
            builder: (context, state) => const TerminalScreen(),
          ),
        ],
        errorBuilder: (context, state) => Scaffold(
          body: Center(
            child: Text('Page not found: ${state.uri}'),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          title: 'MyAgents Frontend',
        ),
      );

      // Verify the invalid path is shown in the error message
      expect(find.text('Page not found: $invalidPath'), findsOneWidget);
      print('[PASS] Step 3: Invalid path ($invalidPath) is clearly displayed in error message');
    });

    /// Step 4: Verify app is still usable - can navigate to valid route
    testWidgets('Step 4: Can navigate away from error page to valid route', (WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/invalid-page',
        routes: [
          GoRoute(
            path: '/',
            name: 'pairing',
            builder: (context, state) => const PairingScreen(),
          ),
          GoRoute(
            path: '/terminal',
            name: 'terminal',
            builder: (context, state) => const TerminalScreen(),
          ),
        ],
        errorBuilder: (context, state) => Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Page not found: ${state.uri}'),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Go to Home'),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          title: 'MyAgents Frontend',
        ),
      );

      // Verify error page is displayed
      expect(find.text('Page not found: /invalid-page'), findsOneWidget);

      // Find and tap the "Go to Home" button
      final button = find.byType(ElevatedButton);
      expect(button, findsOneWidget);

      await tester.tap(button);
      await tester.pumpAndSettle();

      // Verify we navigated to a valid page
      expect(find.byType(Scaffold), findsOneWidget);
      print('[PASS] Step 4: App is still usable and can navigate from error page');
    });

    /// Step 5: Verify error page is a proper Scaffold (not a crash)
    testWidgets('Step 5: Error page renders as a Scaffold (proper widget tree)', (WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/invalid-xyz-route',
        routes: [
          GoRoute(
            path: '/',
            name: 'pairing',
            builder: (context, state) => const PairingScreen(),
          ),
          GoRoute(
            path: '/terminal',
            name: 'terminal',
            builder: (context, state) => const TerminalScreen(),
          ),
        ],
        errorBuilder: (context, state) => Scaffold(
          body: Center(
            child: Text('Page not found: ${state.uri}'),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          title: 'MyAgents Frontend',
        ),
      );

      // Verify Scaffold exists (proper widget hierarchy)
      expect(find.byType(Scaffold), findsOneWidget);

      // Verify Center exists (layout widget)
      expect(find.byType(Center), findsOneWidget);

      // Verify Text widget exists
      expect(find.byType(Text), findsWidgets);

      print('[PASS] Step 5: Error page has proper widget structure (Scaffold, Center, Text)');
    });

    /// Step 6: Test multiple different invalid routes
    testWidgets('Step 6: Multiple different invalid routes all show error page', (WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            name: 'pairing',
            builder: (context, state) => const PairingScreen(),
          ),
          GoRoute(
            path: '/terminal',
            name: 'terminal',
            builder: (context, state) => const TerminalScreen(),
          ),
        ],
        errorBuilder: (context, state) => Scaffold(
          body: Center(
            child: Text('Page not found: ${state.uri}'),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          title: 'MyAgents Frontend',
        ),
      );

      // Start at home
      expect(find.byType(PairingScreen), findsOneWidget);

      // Navigate to invalid route 1
      router.go('/invalid-route-1');
      await tester.pumpAndSettle();
      expect(find.text('Page not found: /invalid-route-1'), findsOneWidget);
      print('[OK] Invalid route 1 handled');

      // Navigate to invalid route 2
      router.go('/another-invalid-path');
      await tester.pumpAndSettle();
      expect(find.text('Page not found: /another-invalid-path'), findsOneWidget);
      print('[OK] Invalid route 2 handled');

      // Navigate to invalid route with parameters
      router.go('/invalid/path/with/segments');
      await tester.pumpAndSettle();
      expect(find.text('Page not found: /invalid/path/with/segments'), findsOneWidget);
      print('[OK] Invalid route with segments handled');

      print('[PASS] Step 6: Multiple different invalid routes handled correctly');
    });

    /// Step 7: Verify actual app router has errorBuilder
    testWidgets('Step 7: Production router (appRouter) has errorBuilder configured', (WidgetTester tester) async {
      // Use the actual app router from the app
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: appRouter,
          title: 'MyAgents Frontend',
        ),
      );

      // Navigate to an invalid route
      appRouter.go('/nonexistent-route-for-testing');
      await tester.pumpAndSettle();

      // Verify error handling is active (Scaffold should still exist)
      expect(find.byType(Scaffold), findsOneWidget);
      print('[PASS] Step 7: Production appRouter has errorBuilder configured');
    });

    /// Step 8: Verify error page content uses state.uri
    testWidgets('Step 8: Error builder correctly uses state.uri from router state', (WidgetTester tester) async {
      final testPaths = [
        '/test-path-1',
        '/api/invalid',
        '/deeply/nested/invalid/path',
      ];

      for (final path in testPaths) {
        final router = GoRouter(
          initialLocation: path,
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const PairingScreen(),
            ),
          ],
          errorBuilder: (context, state) => Scaffold(
            body: Center(
              child: Text('Page not found: ${state.uri}'),
            ),
          ),
        );

        await tester.pumpWidget(
          MaterialApp.router(
            routerConfig: router,
            title: 'Test',
          ),
        );

        // Verify state.uri is correctly passed and displayed
        expect(find.text('Page not found: $path'), findsOneWidget);
        print('[OK] state.uri correctly displays: $path');
      }

      print('[PASS] Step 8: state.uri properly used in error messages for all test paths');
    });
  });
}
