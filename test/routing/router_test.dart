import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myagents_frontend/routing/router.dart';
import 'package:myagents_frontend/features/pairing/pairing_screen.dart';
import 'package:myagents_frontend/features/remote_terminal/terminal_screen.dart';
import 'package:myagents_frontend/core/networking/relay_client.dart';
import 'package:myagents_frontend/core/crypto/key_pair.dart';

void main() {
  // Create mock dependencies that can be reused across tests
  late RelayClient mockRelayClient;
  late KeyPair mockOurKeys;
  late KeyPair mockRemoteKeys;

  setUp(() {
    mockRelayClient = RelayClient();
    mockOurKeys = KeyPair.generate();
    mockRemoteKeys = KeyPair.generate();
  });

  tearDown(() {
    mockRelayClient.disconnect();
  });

  // Helper to create routers with TerminalScreen that has injected dependencies
  GoRouter createRouterWithMockTerminal(String initialLocation) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/',
          name: 'pairing',
          builder: (context, state) => const PairingScreen(),
        ),
        GoRoute(
          path: '/terminal',
          name: 'terminal',
          builder: (context, state) => TerminalScreen(
            relayClient: mockRelayClient,
            ourKeys: mockOurKeys,
            remoteKeys: mockRemoteKeys,
          ),
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Text('Page not found: ${state.uri}'),
        ),
      ),
    );
  }
  group('Router Configuration', () {
    test('appRouter is properly configured', () {
      expect(appRouter, isNotNull);
      expect(appRouter, isA<GoRouter>());
    });

    testWidgets('initial route is / (pairing screen)', (tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: appRouter,
        ),
      );
      await tester.pumpAndSettle();

      // Verify PairingScreen is displayed
      expect(find.byType(PairingScreen), findsOneWidget);
      expect(find.text('Claude Remote Terminal'), findsOneWidget);
    });
  });

  group('Route Registration', () {
    testWidgets('/ route is registered and resolves to PairingScreen',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: appRouter,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PairingScreen), findsOneWidget);
      expect(find.byType(TerminalScreen), findsNothing);
    });

    testWidgets('/terminal route is registered and resolves to TerminalScreen',
        (tester) async {
      final testRouter = createRouterWithMockTerminal('/terminal');

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: testRouter),
      );
      await tester.pump();

      expect(find.byType(TerminalScreen), findsOneWidget);
      expect(find.byType(PairingScreen), findsNothing);
    });

    test('/ route has correct name (pairing)', () {
      // Create a test context to verify route names
      final routes = [
        GoRoute(
          path: '/',
          name: 'pairing',
          builder: (context, state) => const PairingScreen(),
        ),
      ];

      expect(routes[0].name, equals('pairing'));
    });

    test('/terminal route has correct name (terminal)', () {
      final routes = [
        GoRoute(
          path: '/terminal',
          name: 'terminal',
          builder: (context, state) => const TerminalScreen(),
        ),
      ];

      expect(routes[0].name, equals('terminal'));
    });
  });

  group('Navigation Flow', () {
    testWidgets('navigation from pairing to terminal works', (tester) async {
      final testRouter = createRouterWithMockTerminal('/');

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: testRouter),
      );
      await tester.pump();

      // Verify we start at PairingScreen
      expect(find.byType(PairingScreen), findsOneWidget);

      // Navigate to terminal
      testRouter.go('/terminal');
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      // Verify TerminalScreen is now present
      expect(find.byType(TerminalScreen), findsOneWidget);
    });

    testWidgets('navigation from terminal to pairing works', (tester) async {
      final testRouter = createRouterWithMockTerminal('/terminal');

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: testRouter),
      );
      await tester.pump();

      // Verify we start at TerminalScreen
      expect(find.byType(TerminalScreen), findsOneWidget);

      // Navigate to pairing
      testRouter.go('/');
      await tester.pumpAndSettle();

      // Verify we're now at PairingScreen
      expect(find.byType(PairingScreen), findsOneWidget);
      expect(find.byType(TerminalScreen), findsNothing);
    });

    testWidgets('navigation using route names works', (tester) async {
      final testRouter = createRouterWithMockTerminal('/');

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: testRouter),
      );
      await tester.pump();

      // Navigate to terminal using route name
      testRouter.goNamed('terminal');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      expect(find.byType(TerminalScreen), findsOneWidget);

      // Navigate to pairing using route name
      testRouter.goNamed('pairing');
      await tester.pumpAndSettle();

      expect(find.byType(PairingScreen), findsOneWidget);
    });
  });

  group('Deep Link Tests', () {
    testWidgets('deep link to /terminal works', (tester) async {
      final testRouter = createRouterWithMockTerminal('/terminal');

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: testRouter),
      );
      await tester.pump();

      expect(find.byType(TerminalScreen), findsOneWidget);
      expect(find.byType(PairingScreen), findsNothing);
    });

    testWidgets('deep link to / works', (tester) async {
      final testRouter = createRouterWithMockTerminal('/');

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: testRouter),
      );
      await tester.pump();

      expect(find.byType(PairingScreen), findsOneWidget);
      expect(find.byType(TerminalScreen), findsNothing);
    });
  });

  group('Invalid Route Handling', () {
    testWidgets('invalid route shows error page', (tester) async {
      final testRouter = GoRouter(
        initialLocation: '/invalid-route',
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
          routerConfig: testRouter,
        ),
      );
      await tester.pumpAndSettle();

      // Should not find either screen
      expect(find.byType(PairingScreen), findsNothing);
      expect(find.byType(TerminalScreen), findsNothing);

      // Should find error message
      expect(find.text('Page not found: /invalid-route'), findsOneWidget);
    });

    testWidgets('error page displays correct URI', (tester) async {
      final testRouter = GoRouter(
        initialLocation: '/some/random/path',
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
          routerConfig: testRouter,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Page not found: /some/random/path'), findsOneWidget);
    });

    testWidgets('random path like /nonexistent shows error', (tester) async {
      final testRouter = GoRouter(
        initialLocation: '/nonexistent',
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
          routerConfig: testRouter,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Page not found: /nonexistent'), findsOneWidget);
    });

    testWidgets('navigating to invalid route shows error page',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: appRouter,
        ),
      );
      await tester.pumpAndSettle();

      // Start at valid route
      expect(find.byType(PairingScreen), findsOneWidget);

      // Navigate to invalid route
      appRouter.go('/does-not-exist');
      await tester.pumpAndSettle();

      // Should show error page
      expect(find.text('Page not found: /does-not-exist'), findsOneWidget);
      expect(find.byType(PairingScreen), findsNothing);
      expect(find.byType(TerminalScreen), findsNothing);
    });
  });

  group('Error Builder Tests', () {
    testWidgets('errorBuilder returns Scaffold', (tester) async {
      final testRouter = GoRouter(
        initialLocation: '/bad-route',
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
          routerConfig: testRouter,
        ),
      );
      await tester.pumpAndSettle();

      // Error page should be wrapped in Scaffold
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('error displays unmatched URI', (tester) async {
      final testRouter = GoRouter(
        initialLocation: '/unmatched',
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
          routerConfig: testRouter,
        ),
      );
      await tester.pumpAndSettle();

      // Should display the full URI
      expect(find.textContaining('Page not found:'), findsOneWidget);
      expect(find.textContaining('/unmatched'), findsOneWidget);
    });

    testWidgets('error page has centered text', (tester) async {
      final testRouter = GoRouter(
        initialLocation: '/error-test',
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
          routerConfig: testRouter,
        ),
      );
      await tester.pumpAndSettle();

      // Find the Center widget containing the error text
      final centerFinder = find.ancestor(
        of: find.textContaining('Page not found:'),
        matching: find.byType(Center),
      );

      expect(centerFinder, findsOneWidget);
    });
  });

  group('Route State Tests', () {
    testWidgets('router maintains correct location after navigation',
        (tester) async {
      final testRouter = createRouterWithMockTerminal('/');

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: testRouter),
      );
      await tester.pump();

      // Verify initial state - PairingScreen is shown
      expect(find.byType(PairingScreen), findsOneWidget);

      // Navigate to terminal
      testRouter.go('/terminal');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();

      // Verify TerminalScreen is shown
      expect(find.byType(TerminalScreen), findsOneWidget);

      // Navigate back to pairing
      testRouter.go('/');
      await tester.pumpAndSettle();

      // Verify PairingScreen is shown again
      expect(find.byType(PairingScreen), findsOneWidget);
    });

    testWidgets('router can navigate back and forth multiple times',
        (tester) async {
      final testRouter = createRouterWithMockTerminal('/');

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: testRouter),
      );
      await tester.pump();

      // First navigation cycle
      expect(find.byType(PairingScreen), findsOneWidget);
      testRouter.go('/terminal');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.byType(TerminalScreen), findsOneWidget);

      // Second navigation cycle
      testRouter.go('/');
      await tester.pumpAndSettle();
      expect(find.byType(PairingScreen), findsOneWidget);
      testRouter.go('/terminal');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.byType(TerminalScreen), findsOneWidget);

      // Third navigation cycle
      testRouter.go('/');
      await tester.pumpAndSettle();
      expect(find.byType(PairingScreen), findsOneWidget);
    });
  });
}
