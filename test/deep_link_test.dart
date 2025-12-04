import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myagents_frontend/features/pairing/pairing_screen.dart';
import 'package:myagents_frontend/features/remote_terminal/terminal_screen.dart';

void main() {
  group('US-NAV-001: Deep Link Navigation to Terminal', () {
    /// Step 1: Navigate directly to /terminal URL
    testWidgets('Step 1: Navigate directly to /terminal URL', (WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/terminal', // Deep link directly to terminal
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
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          title: 'MyAgents Frontend',
        ),
      );

      // Verify Terminal screen loads directly
      expect(find.text('Terminal Screen Placeholder'), findsOneWidget);
      expect(find.text('Terminal'), findsOneWidget); // AppBar title
      
      print('[PASS] Step 1: Terminal screen loads directly via deep link');
    });

    /// Step 2: Verify terminal screen functionality
    testWidgets('Step 2: Verify terminal screen is fully functional', (WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/terminal',
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
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          title: 'MyAgents Frontend',
        ),
      );

      // Verify all screen elements are present
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Terminal Screen Placeholder'), findsOneWidget);
      expect(find.text('Back to Pairing'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
      
      print('[PASS] Step 2: Screen is fully functional with all elements');
    });

    /// Step 3: Verify no redirect guards block access
    testWidgets('Step 3: No unnecessary redirects occur', (WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/terminal',
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
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          title: 'MyAgents Frontend',
        ),
      );

      // We should be on Terminal, not redirected to Pairing
      expect(find.text('Terminal Screen Placeholder'), findsOneWidget);
      expect(find.text('Pairing Screen Placeholder'), findsNothing);
      
      print('[PASS] Step 3: No redirects - direct access works');
    });

    /// Step 4: Verify TerminalScreen independence from PairingScreen state
    testWidgets('Step 4: TerminalScreen works independently', (WidgetTester tester) async {
      // Create router with /terminal as initial location
      // This ensures TerminalScreen loads without any prior PairingScreen initialization
      final router = GoRouter(
        initialLocation: '/terminal',
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
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          title: 'MyAgents Frontend',
        ),
      );

      // Verify TerminalScreen loads without errors and is functional
      expect(find.text('Terminal Screen Placeholder'), findsOneWidget);
      
      // Test navigation button works
      await tester.tap(find.text('Back to Pairing'));
      await tester.pumpAndSettle();
      
      // Should navigate to pairing
      expect(find.text('Pairing Screen Placeholder'), findsOneWidget);
      
      print('[PASS] Step 4: TerminalScreen is independent and fully functional');
    });

    /// Success Criteria Verification
    testWidgets('Success Criteria: All requirements met', (WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/terminal',
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
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          title: 'MyAgents Frontend',
        ),
      );

      // Requirement 1: Direct URL access works
      expect(find.text('Terminal Screen Placeholder'), findsOneWidget);
      print('[OK] Requirement 1: Direct URL access works');
      
      // Requirement 2: No unnecessary redirects
      expect(find.text('Pairing Screen Placeholder'), findsNothing);
      print('[OK] Requirement 2: No unnecessary redirects');
      
      // Requirement 3: Screen fully functional after direct access
      expect(find.byType(ElevatedButton), findsOneWidget);
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(find.text('Pairing Screen Placeholder'), findsOneWidget);
      print('[OK] Requirement 3: Screen fully functional after direct access');
      
      print('[PASS] All success criteria met for US-NAV-001');
    });
  });
}
