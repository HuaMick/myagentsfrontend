import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myagents_frontend/features/pairing/pairing_screen.dart';
import 'package:myagents_frontend/features/remote_terminal/terminal_screen.dart';

void main() {
  group('US-TERM-002: Navigate from Terminal to Pairing', () {
    /// Step 1: Verify "Back to Pairing" button is visible on Terminal screen
    testWidgets('Step 1: Locate the "Back to Pairing" button', (WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const PairingScreen(),
          ),
          GoRoute(
            path: '/terminal',
            builder: (context, state) => const TerminalScreen(),
          ),
        ],
      );

      // Navigate to terminal screen
      router.go('/terminal');

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          title: 'MyAgents Frontend',
        ),
      );

      // Verify Terminal screen is displayed
      expect(find.text('Terminal Screen Placeholder'), findsOneWidget);
      
      // Verify "Back to Pairing" button is visible
      expect(find.text('Back to Pairing'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
      
      print('[PASS] Step 1: "Back to Pairing" button is clearly visible');
    });

    /// Step 2: Click the "Back to Pairing" button
    testWidgets('Step 2: Click/tap the "Back to Pairing" button', (WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const PairingScreen(),
          ),
          GoRoute(
            path: '/terminal',
            builder: (context, state) => const TerminalScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          title: 'MyAgents Frontend',
        ),
      );

      // Navigate to terminal
      router.go('/terminal');
      await tester.pumpAndSettle();

      // Verify we're on terminal screen
      expect(find.text('Terminal Screen Placeholder'), findsOneWidget);

      // Find and tap the "Back to Pairing" button
      final buttonFinder = find.byType(ElevatedButton);
      expect(buttonFinder, findsOneWidget);
      
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();
      
      print('[PASS] Step 2: Button click executed without errors');
    });

    /// Step 3: Verify pairing screen is loaded
    testWidgets('Step 3: Verify pairing screen loaded', (WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const PairingScreen(),
          ),
          GoRoute(
            path: '/terminal',
            builder: (context, state) => const TerminalScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          title: 'MyAgents Frontend',
        ),
      );

      // Start on pairing screen (root route)
      expect(find.text('Pairing Screen Placeholder'), findsOneWidget);

      // Navigate to terminal
      router.go('/terminal');
      await tester.pumpAndSettle();
      expect(find.text('Terminal Screen Placeholder'), findsOneWidget);

      // Navigate back to pairing
      router.go('/');
      await tester.pumpAndSettle();

      // Verify we're on pairing screen
      expect(find.text('Pairing Screen Placeholder'), findsOneWidget);
      expect(find.text('Go to Terminal'), findsOneWidget);
      
      print('[PASS] Step 3: Pairing screen successfully loaded after navigation');
    });

    /// Bidirectional navigation test
    testWidgets('Bidirectional navigation: pairing->terminal->pairing', (WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const PairingScreen(),
          ),
          GoRoute(
            path: '/terminal',
            builder: (context, state) => const TerminalScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          title: 'MyAgents Frontend',
        ),
      );

      // Start at pairing
      expect(find.text('Pairing Screen Placeholder'), findsOneWidget);
      print('[OK] Starting at Pairing screen');

      // Navigate to terminal using button
      await tester.tap(find.text('Go to Terminal'));
      await tester.pumpAndSettle();
      expect(find.text('Terminal Screen Placeholder'), findsOneWidget);
      print('[OK] Navigation to Terminal screen successful');

      // Navigate back to pairing using button
      await tester.tap(find.text('Back to Pairing'));
      await tester.pumpAndSettle();
      expect(find.text('Pairing Screen Placeholder'), findsOneWidget);
      print('[OK] Navigation back to Pairing screen successful');

      // Verify we can go to terminal again
      await tester.tap(find.text('Go to Terminal'));
      await tester.pumpAndSettle();
      expect(find.text('Terminal Screen Placeholder'), findsOneWidget);
      print('[OK] Second navigation to Terminal successful');

      // Navigate back to pairing again
      await tester.tap(find.text('Back to Pairing'));
      await tester.pumpAndSettle();
      expect(find.text('Pairing Screen Placeholder'), findsOneWidget);
      print('[PASS] Bidirectional navigation works correctly');
    });

    /// Verify AppBar and UI consistency
    testWidgets('Navigation maintains UI consistency', (WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const PairingScreen(),
          ),
          GoRoute(
            path: '/terminal',
            builder: (context, state) => const TerminalScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          title: 'MyAgents Frontend',
        ),
      );

      // Check pairing screen UI
      expect(find.text('Pairing'), findsOneWidget); // AppBar title
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      // Navigate to terminal
      router.go('/terminal');
      await tester.pumpAndSettle();

      // Check terminal screen UI
      expect(find.text('Terminal'), findsOneWidget); // AppBar title
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);

      print('[PASS] UI consistency maintained across navigation');
    });
  });
}
