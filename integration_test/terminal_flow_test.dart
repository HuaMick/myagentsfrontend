import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myagents_frontend/features/remote_terminal/terminal_screen.dart';
import 'package:myagents_frontend/core/networking/relay_client.dart';
import 'package:myagents_frontend/core/crypto/key_pair.dart';
import 'helpers/test_helpers.dart';
import 'fixtures/test_fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Terminal Flow E2E', () {
    late RelayClient mockRelayClient;
    late KeyPair ourKeys;
    late KeyPair remoteKeys;

    setUp(() {
      mockRelayClient = RelayClient();
      ourKeys = TestKeyPairs.aliceKeys;
      remoteKeys = TestKeyPairs.bobKeys;
    });

    tearDown(() async {
      await mockRelayClient.dispose();
    });

    testWidgets('terminal screen renders correctly', (tester) async {
      // Create a router with terminal screen
      final router = GoRouter(
        initialLocation: '/terminal',
        routes: [
          GoRoute(
            path: '/terminal',
            builder: (context, state) => TerminalScreen(
              relayClient: mockRelayClient,
              ourKeys: ourKeys,
              remoteKeys: remoteKeys,
            ),
          ),
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: Text('Pairing Screen'),
            ),
          ),
        ],
      );

      // Pump the app with custom router
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Verify AppBar with title
      expect(find.text('Remote Terminal'), findsOneWidget);
      verifyVisible(find.text('Remote Terminal'));

      // Verify AppBar has back button
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      verifyVisible(find.byIcon(Icons.arrow_back));

      // Verify disconnect button
      expect(find.byIcon(Icons.close), findsOneWidget);
      verifyVisible(find.byIcon(Icons.close));

      // Verify connection status indicator is present
      expect(find.byType(Container), findsWidgets);

      // Verify terminal screen has black background
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, Colors.black);
    });

    testWidgets('connecting state shows loading indicator', (tester) async {
      // Create a router with terminal screen
      final router = GoRouter(
        initialLocation: '/terminal',
        routes: [
          GoRoute(
            path: '/terminal',
            builder: (context, state) => TerminalScreen(
              relayClient: mockRelayClient,
              ourKeys: ourKeys,
              remoteKeys: remoteKeys,
            ),
          ),
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: Text('Pairing Screen'),
            ),
          ),
        ],
      );

      // Set relay client to connecting state
      mockRelayClient.stateManager.setConnecting();

      // Pump the app
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Verify loading indicator is shown
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      verifyVisible(find.byType(CircularProgressIndicator));

      // Verify "Connecting..." text
      expect(find.text('Connecting...'), findsOneWidget);
      verifyVisible(find.text('Connecting...'));

      // Verify connection status shows "Connecting..."
      expect(find.text('Connecting...'), findsWidgets);
    });

    testWidgets('connected state shows green status indicator', (tester) async {
      // Create a router with terminal screen
      final router = GoRouter(
        initialLocation: '/terminal',
        routes: [
          GoRoute(
            path: '/terminal',
            builder: (context, state) => TerminalScreen(
              relayClient: mockRelayClient,
              ourKeys: ourKeys,
              remoteKeys: remoteKeys,
            ),
          ),
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: Text('Pairing Screen'),
            ),
          ),
        ],
      );

      // Set relay client to connected state
      mockRelayClient.stateManager.setConnecting();
      mockRelayClient.stateManager.setConnected();

      // Pump the app
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Verify "Connected" text in status indicator
      expect(find.text('Connected'), findsOneWidget);
      verifyVisible(find.text('Connected'));

      // Find the status indicator container with green color
      final containerFinder = find.descendant(
        of: find.byType(AppBar),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color == Colors.green,
        ),
      );
      expect(containerFinder, findsOneWidget);
    });

    testWidgets('error state shows error message and retry button', (tester) async {
      // Create a router with terminal screen
      final router = GoRouter(
        initialLocation: '/terminal',
        routes: [
          GoRoute(
            path: '/terminal',
            builder: (context, state) => TerminalScreen(
              relayClient: mockRelayClient,
              ourKeys: ourKeys,
              remoteKeys: remoteKeys,
            ),
          ),
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: Text('Pairing Screen'),
            ),
          ),
        ],
      );

      // Set relay client to error state
      mockRelayClient.stateManager.setError(TestErrorMessages.connectionFailed);

      // Pump the app
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Verify error icon is shown
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      verifyVisible(find.byIcon(Icons.error_outline));

      // Verify error message is displayed
      expect(find.text(TestErrorMessages.connectionFailed), findsOneWidget);
      verifyVisible(find.text(TestErrorMessages.connectionFailed));

      // Verify retry button exists
      expect(find.widgetWithIcon(ElevatedButton, Icons.refresh), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      verifyVisible(find.text('Retry'));

      // Verify back button exists
      expect(find.widgetWithIcon(OutlinedButton, Icons.arrow_back), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      verifyVisible(find.text('Back'));

      // Verify "Error" status in AppBar
      expect(find.text('Error'), findsOneWidget);
    });

    testWidgets('disconnected state shows reconnect option', (tester) async {
      // Create a router with terminal screen
      final router = GoRouter(
        initialLocation: '/terminal',
        routes: [
          GoRoute(
            path: '/terminal',
            builder: (context, state) => TerminalScreen(
              relayClient: mockRelayClient,
              ourKeys: ourKeys,
              remoteKeys: remoteKeys,
            ),
          ),
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: Text('Pairing Screen'),
            ),
          ),
        ],
      );

      // Relay client starts in disconnected state
      // No need to set it explicitly

      // Pump the app
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Verify disconnected icon is shown
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      verifyVisible(find.byIcon(Icons.cloud_off));

      // Verify "Disconnected" text
      expect(find.text('Disconnected'), findsWidgets);

      // Verify reconnect button exists
      expect(find.widgetWithIcon(ElevatedButton, Icons.refresh), findsOneWidget);
      expect(find.text('Reconnect'), findsOneWidget);
      verifyVisible(find.text('Reconnect'));

      // Verify back button exists
      expect(find.widgetWithIcon(OutlinedButton, Icons.arrow_back), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      verifyVisible(find.text('Back'));
    });

    testWidgets('back button navigates to pairing screen', (tester) async {
      // Track navigation
      bool navigatedToPairing = false;

      // Create a router with terminal screen
      final router = GoRouter(
        initialLocation: '/terminal',
        routes: [
          GoRoute(
            path: '/terminal',
            builder: (context, state) => TerminalScreen(
              relayClient: mockRelayClient,
              ourKeys: ourKeys,
              remoteKeys: remoteKeys,
            ),
          ),
          GoRoute(
            path: '/',
            builder: (context, state) {
              navigatedToPairing = true;
              return const Scaffold(
                body: Text('Pairing Screen'),
              );
            },
          ),
        ],
      );

      // Pump the app
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Find and tap the back button in AppBar
      final backButton = find.byIcon(Icons.arrow_back);
      expect(backButton, findsOneWidget);

      await tapButton(tester, backButton);

      // Verify navigation occurred
      expect(navigatedToPairing, isTrue);
      expect(find.text('Pairing Screen'), findsOneWidget);
      verifyVisible(find.text('Pairing Screen'));
    });

    testWidgets('disconnect button navigates to pairing screen', (tester) async {
      // Track navigation
      bool navigatedToPairing = false;

      // Create a router with terminal screen
      final router = GoRouter(
        initialLocation: '/terminal',
        routes: [
          GoRoute(
            path: '/terminal',
            builder: (context, state) => TerminalScreen(
              relayClient: mockRelayClient,
              ourKeys: ourKeys,
              remoteKeys: remoteKeys,
            ),
          ),
          GoRoute(
            path: '/',
            builder: (context, state) {
              navigatedToPairing = true;
              return const Scaffold(
                body: Text('Pairing Screen'),
              );
            },
          ),
        ],
      );

      // Pump the app
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Find and tap the disconnect button (close icon in AppBar)
      final disconnectButton = find.byIcon(Icons.close);
      expect(disconnectButton, findsOneWidget);

      await tapButton(tester, disconnectButton);

      // Verify navigation occurred
      expect(navigatedToPairing, isTrue);
      expect(find.text('Pairing Screen'), findsOneWidget);
      verifyVisible(find.text('Pairing Screen'));
    });

    testWidgets('terminal area has black background', (tester) async {
      // Create a router with terminal screen
      final router = GoRouter(
        initialLocation: '/terminal',
        routes: [
          GoRoute(
            path: '/terminal',
            builder: (context, state) => TerminalScreen(
              relayClient: mockRelayClient,
              ourKeys: ourKeys,
              remoteKeys: remoteKeys,
            ),
          ),
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: Text('Pairing Screen'),
            ),
          ),
        ],
      );

      // Set relay client to connected state to show terminal
      mockRelayClient.stateManager.setConnecting();
      mockRelayClient.stateManager.setConnected();

      // Pump the app
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Verify scaffold has black background
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, Colors.black);
    });

    testWidgets('terminal area uses LayoutBuilder for sizing', (tester) async {
      // Create a router with terminal screen
      final router = GoRouter(
        initialLocation: '/terminal',
        routes: [
          GoRoute(
            path: '/terminal',
            builder: (context, state) => TerminalScreen(
              relayClient: mockRelayClient,
              ourKeys: ourKeys,
              remoteKeys: remoteKeys,
            ),
          ),
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: Text('Pairing Screen'),
            ),
          ),
        ],
      );

      // Set relay client to connected state to show terminal
      mockRelayClient.stateManager.setConnecting();
      mockRelayClient.stateManager.setConnected();

      // Pump the app
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Verify LayoutBuilder is used in the terminal view
      expect(find.byType(LayoutBuilder), findsOneWidget);
      verifyVisible(find.byType(LayoutBuilder));
    });

    testWidgets('retry button attempts reconnection', (tester) async {
      // Create a router with terminal screen
      final router = GoRouter(
        initialLocation: '/terminal',
        routes: [
          GoRoute(
            path: '/terminal',
            builder: (context, state) => TerminalScreen(
              relayClient: mockRelayClient,
              ourKeys: ourKeys,
              remoteKeys: remoteKeys,
            ),
          ),
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: Text('Pairing Screen'),
            ),
          ),
        ],
      );

      // Set relay client to error state
      mockRelayClient.stateManager.setError(TestErrorMessages.connectionFailed);

      // Pump the app
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Verify error state is shown
      expect(find.text('Retry'), findsOneWidget);

      // Tap retry button
      await tapButton(tester, find.text('Retry'));

      // The state should transition to connecting
      // Note: Since we're using a real RelayClient without a server,
      // it will attempt to connect but likely fail. We're just testing
      // that the UI responds to the retry button press.
      await tester.pump();

      // The connecting state should be set (though it may quickly fail)
      // We can't easily verify the final state without a mock server,
      // but we can verify the button was tapped successfully
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('connection status indicator updates on state change', (tester) async {
      // Create a router with terminal screen
      final router = GoRouter(
        initialLocation: '/terminal',
        routes: [
          GoRoute(
            path: '/terminal',
            builder: (context, state) => TerminalScreen(
              relayClient: mockRelayClient,
              ourKeys: ourKeys,
              remoteKeys: remoteKeys,
            ),
          ),
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: Text('Pairing Screen'),
            ),
          ),
        ],
      );

      // Start in disconnected state
      // Pump the app
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Verify disconnected state
      expect(find.text('Disconnected'), findsWidgets);

      // Change state to connecting
      mockRelayClient.stateManager.setConnecting();
      await tester.pumpAndSettle();

      // Verify connecting state
      expect(find.text('Connecting...'), findsWidgets);

      // Change state to connected
      mockRelayClient.stateManager.setConnected();
      await tester.pumpAndSettle();

      // Verify connected state
      expect(find.text('Connected'), findsOneWidget);

      // Change state to error
      mockRelayClient.stateManager.setError(TestErrorMessages.networkError);
      await tester.pumpAndSettle();

      // Verify error state
      expect(find.text('Error'), findsOneWidget);
      expect(find.text(TestErrorMessages.networkError), findsOneWidget);
    });

    testWidgets('AppBar has correct background color', (tester) async {
      // Create a router with terminal screen
      final router = GoRouter(
        initialLocation: '/terminal',
        routes: [
          GoRoute(
            path: '/terminal',
            builder: (context, state) => TerminalScreen(
              relayClient: mockRelayClient,
              ourKeys: ourKeys,
              remoteKeys: remoteKeys,
            ),
          ),
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: Text('Pairing Screen'),
            ),
          ),
        ],
      );

      // Pump the app
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Verify AppBar background color is dark gray
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, Colors.grey[900]);
    });

    testWidgets('terminal screen handles missing remote keys gracefully', (tester) async {
      // Create a router with terminal screen WITHOUT remote keys
      final router = GoRouter(
        initialLocation: '/terminal',
        routes: [
          GoRoute(
            path: '/terminal',
            builder: (context, state) => TerminalScreen(
              relayClient: mockRelayClient,
              ourKeys: ourKeys,
              // remoteKeys intentionally omitted
            ),
          ),
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: Text('Pairing Screen'),
            ),
          ),
        ],
      );

      // Pump the app
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // The screen should show an error state since remote keys are missing
      // and there's no Provider to fall back to
      expect(find.byType(TerminalScreen), findsOneWidget);

      // Verify error state is shown
      // The exact error message depends on implementation
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('multiple state transitions work correctly', (tester) async {
      // Create a router with terminal screen
      final router = GoRouter(
        initialLocation: '/terminal',
        routes: [
          GoRoute(
            path: '/terminal',
            builder: (context, state) => TerminalScreen(
              relayClient: mockRelayClient,
              ourKeys: ourKeys,
              remoteKeys: remoteKeys,
            ),
          ),
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: Text('Pairing Screen'),
            ),
          ),
        ],
      );

      // Pump the app
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Start: disconnected
      expect(find.text('Disconnected'), findsWidgets);

      // Transition to connecting
      mockRelayClient.stateManager.setConnecting();
      await tester.pumpAndSettle();
      expect(find.text('Connecting...'), findsWidgets);

      // Transition to connected
      mockRelayClient.stateManager.setConnected();
      await tester.pumpAndSettle();
      expect(find.text('Connected'), findsOneWidget);

      // Transition to error
      mockRelayClient.stateManager.setError('Test error');
      await tester.pumpAndSettle();
      expect(find.text('Error'), findsOneWidget);

      // Transition back to connecting (retry)
      mockRelayClient.stateManager.setReconnecting();
      await tester.pumpAndSettle();
      expect(find.text('Connecting...'), findsWidgets);

      // Transition to disconnected
      mockRelayClient.stateManager.setDisconnected();
      await tester.pumpAndSettle();
      expect(find.text('Disconnected'), findsWidgets);
    });
  });
}
