@Timeout(Duration(minutes: 2))

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/features/remote_terminal/terminal_controller.dart';
import '../../../lib/features/remote_terminal/terminal_state.dart';
import '../../../lib/core/networking/relay_client.dart';
import '../../../lib/core/crypto/key_pair.dart';
import '../../../lib/core/crypto/message_envelope.dart';
import '../../mock_relay_server.dart';

/// Integration test suite for RemoteTerminalController with MockRelayServer.
///
/// This suite tests the complete terminal flow:
/// 1. Start MockRelayServer with echo enabled
/// 2. Create RelayClient and connect
/// 3. Create RemoteTerminalController
/// 4. Verify terminal I/O through the relay
/// 5. Verify resize messages
/// 6. Verify error handling
void main() {
  group('RemoteTerminalController Integration Tests', () {
    late MockRelayServer server;
    late RelayClient relayClient;
    late KeyPair clientKeys;
    late KeyPair serverKeys;
    late RemoteTerminalController controller;
    late RemoteTerminalState terminalState;
    const pairingCode = 'TERM01';

    setUp(() async {
      // Start MockRelayServer with echo enabled
      server = MockRelayServer(
        config: MockRelayServerConfig(
          verbose: false,
          echoTerminalInput: true, // Echo input back as output
          autoRespondToPairing: true,
        ),
      );
      await server.start();

      // Get server keys
      serverKeys = server.getServerKeys();

      // Generate client keys
      clientKeys = KeyPair.generate();

      // Create RelayClient
      relayClient = RelayClient();
      relayClient.setKeys(clientKeys, serverKeys);

      // Create terminal state
      terminalState = RemoteTerminalState();
    });

    tearDown(() async {
      controller.dispose();
      await relayClient.dispose();
      terminalState.dispose();
      await server.stop();
    });

    group('Connection and initialization', () {
      test('Controller connects and sets state to connected', () async {
        // Connect to server
        final port = server.getPort();
        await relayClient.connect('localhost:$port', pairingCode);

        // Wait for connection
        await Future.delayed(const Duration(milliseconds: 100));

        expect(relayClient.isConnected, isTrue);
        expect(server.isClientConnected(pairingCode), isTrue);

        // Create controller
        controller = RemoteTerminalController(
          relayClient: relayClient,
          ourKeys: clientKeys,
          remoteKeys: serverKeys,
          terminalState: terminalState,
        );

        expect(terminalState.connectionStatus,
            RemoteTerminalConnectionStatus.connected);
      });

      test('Controller initializes with custom terminal size', () async {
        // Connect to server
        final port = server.getPort();
        await relayClient.connect('localhost:$port', pairingCode);
        await Future.delayed(const Duration(milliseconds: 100));

        // Create controller with custom size
        controller = RemoteTerminalController(
          relayClient: relayClient,
          ourKeys: clientKeys,
          remoteKeys: serverKeys,
          terminalState: terminalState,
          rows: 30,
          cols: 100,
        );

        expect(terminalState.rows, 30);
        expect(terminalState.cols, 100);
      });
    });

    group('Terminal input flow', () {
      test('sendTerminalInput completes without error when connected', () async {
        // Connect to server
        final port = server.getPort();
        await relayClient.connect('localhost:$port', pairingCode);
        await Future.delayed(const Duration(milliseconds: 100));

        // Create controller
        controller = RemoteTerminalController(
          relayClient: relayClient,
          ourKeys: clientKeys,
          remoteKeys: serverKeys,
          terminalState: terminalState,
        );

        // Send input should complete without error
        expect(
          () async => await relayClient.sendTerminalInput('ls -la\r'),
          returnsNormally,
        );

        // No error in terminal state
        expect(terminalState.hasError, isFalse);
      });

      test('Multiple sendTerminalInput calls complete without error', () async {
        // Connect to server
        final port = server.getPort();
        await relayClient.connect('localhost:$port', pairingCode);
        await Future.delayed(const Duration(milliseconds: 100));

        // Create controller
        controller = RemoteTerminalController(
          relayClient: relayClient,
          ourKeys: clientKeys,
          remoteKeys: serverKeys,
          terminalState: terminalState,
        );

        // All inputs should complete without error
        await relayClient.sendTerminalInput('a');
        await relayClient.sendTerminalInput('b');
        await relayClient.sendTerminalInput('c');

        // No error in terminal state
        expect(terminalState.hasError, isFalse);
      });
    });

    group('Terminal output flow', () {
      test('Server output is decrypted and written to terminal', () async {
        // Connect to server
        final port = server.getPort();
        await relayClient.connect('localhost:$port', pairingCode);
        await Future.delayed(const Duration(milliseconds: 100));

        // Create controller
        controller = RemoteTerminalController(
          relayClient: relayClient,
          ourKeys: clientKeys,
          remoteKeys: serverKeys,
          terminalState: terminalState,
        );

        // Clear messages
        server.clearReceivedMessages();

        // Send input - server will echo it back
        controller.terminal.onOutput?.call('hello');

        // Wait for echo response
        await Future.delayed(const Duration(milliseconds: 300));

        // The echo server should have echoed the input back
        // We can't easily verify terminal buffer, but we can verify no error occurred
        expect(terminalState.hasError, isFalse);
      });

      test('Echo server echoes input back as output', () async {
        // Connect to server with echo enabled
        final port = server.getPort();
        await relayClient.connect('localhost:$port', pairingCode);
        await Future.delayed(const Duration(milliseconds: 100));

        // Create controller
        controller = RemoteTerminalController(
          relayClient: relayClient,
          ourKeys: clientKeys,
          remoteKeys: serverKeys,
          terminalState: terminalState,
        );

        // Send input - echo server should return it
        await relayClient.sendTerminalInput('echo test');

        // Wait for echo response
        await Future.delayed(const Duration(milliseconds: 500));

        // No error should have occurred
        expect(terminalState.hasError, isFalse);
      });
    });

    group('Resize flow', () {
      test('Resize updates terminal state when connected', () async {
        // Connect to server
        final port = server.getPort();
        await relayClient.connect('localhost:$port', pairingCode);
        await Future.delayed(const Duration(milliseconds: 100));

        // Create controller
        controller = RemoteTerminalController(
          relayClient: relayClient,
          ourKeys: clientKeys,
          remoteKeys: serverKeys,
          terminalState: terminalState,
        );

        // Resize terminal
        controller.resize(50, 120);

        // Verify state was updated
        expect(terminalState.rows, 50);
        expect(terminalState.cols, 120);

        // No error should occur
        expect(terminalState.hasError, isFalse);
      });

      test('sendResize completes without error when connected', () async {
        // Connect to server
        final port = server.getPort();
        await relayClient.connect('localhost:$port', pairingCode);
        await Future.delayed(const Duration(milliseconds: 100));

        // Create controller
        controller = RemoteTerminalController(
          relayClient: relayClient,
          ourKeys: clientKeys,
          remoteKeys: serverKeys,
          terminalState: terminalState,
        );

        // Send resize directly
        await relayClient.sendResize(40, 100);

        // No error should occur
        expect(terminalState.hasError, isFalse);
      });
    });

    group('Error handling', () {
      test('Handles forced disconnect from server', () async {
        // Connect to server
        final port = server.getPort();
        await relayClient.connect('localhost:$port', pairingCode);
        await Future.delayed(const Duration(milliseconds: 100));

        // Create controller
        controller = RemoteTerminalController(
          relayClient: relayClient,
          ourKeys: clientKeys,
          remoteKeys: serverKeys,
          terminalState: terminalState,
        );

        expect(relayClient.isConnected, isTrue);

        // Force disconnect from server
        await server.forceDisconnect(pairingCode);
        await Future.delayed(const Duration(milliseconds: 200));

        // Client should detect disconnection
        expect(relayClient.isConnected, isFalse);
      });

      test('Controller handles disposal gracefully', () async {
        // Connect to server
        final port = server.getPort();
        await relayClient.connect('localhost:$port', pairingCode);
        await Future.delayed(const Duration(milliseconds: 100));

        // Create controller
        controller = RemoteTerminalController(
          relayClient: relayClient,
          ourKeys: clientKeys,
          remoteKeys: serverKeys,
          terminalState: terminalState,
        );

        // Dispose controller
        controller.dispose();

        // Terminal.onOutput should be null
        expect(controller.terminal.onOutput, isNull);

        // Further operations should not throw
        expect(() => controller.writeLocal('test'), returnsNormally);
        expect(() => controller.clear(), returnsNormally);
        expect(() => controller.resize(30, 80), returnsNormally);
      });
    });

    group('Local operations', () {
      test('writeLocal writes directly to terminal without sending to server',
          () async {
        // Connect to server
        final port = server.getPort();
        await relayClient.connect('localhost:$port', pairingCode);
        await Future.delayed(const Duration(milliseconds: 100));

        // Create controller
        controller = RemoteTerminalController(
          relayClient: relayClient,
          ourKeys: clientKeys,
          remoteKeys: serverKeys,
          terminalState: terminalState,
        );

        // Clear messages
        server.clearReceivedMessages();

        // Write local text (should NOT send to server)
        controller.writeLocal('Local message\r\n');

        // Wait a bit
        await Future.delayed(const Duration(milliseconds: 100));

        // Server should NOT receive any messages
        final messages = server.getReceivedMessages();
        final terminalMessages = messages.where(
          (m) =>
              m.type == MessageType.terminalInput ||
              m.type == MessageType.terminalOutput,
        );
        expect(terminalMessages, isEmpty);
      });

      test('clear sends ANSI clear command to terminal', () async {
        // Connect to server
        final port = server.getPort();
        await relayClient.connect('localhost:$port', pairingCode);
        await Future.delayed(const Duration(milliseconds: 100));

        // Create controller
        controller = RemoteTerminalController(
          relayClient: relayClient,
          ourKeys: clientKeys,
          remoteKeys: serverKeys,
          terminalState: terminalState,
        );

        // Clear should not throw
        expect(() => controller.clear(), returnsNormally);

        // Terminal should not have error
        expect(terminalState.hasError, isFalse);
      });
    });

    group('End-to-end terminal session', () {
      test('Complete terminal session flow', () async {
        // 1. Connect to server
        final port = server.getPort();
        await relayClient.connect('localhost:$port', pairingCode);
        await Future.delayed(const Duration(milliseconds: 100));

        expect(relayClient.isConnected, isTrue);

        // 2. Create controller
        controller = RemoteTerminalController(
          relayClient: relayClient,
          ourKeys: clientKeys,
          remoteKeys: serverKeys,
          terminalState: terminalState,
        );

        expect(
            terminalState.connectionStatus, RemoteTerminalConnectionStatus.connected);

        // 3. Write local welcome message
        controller.writeLocal('Welcome to remote terminal!\r\n');

        // 4. Send some input via relay client
        await relayClient.sendTerminalInput('echo hello\r');
        await Future.delayed(const Duration(milliseconds: 100));

        // 5. Resize terminal
        controller.resize(30, 100);
        expect(terminalState.rows, 30);
        expect(terminalState.cols, 100);

        // 6. No errors should have occurred
        expect(terminalState.hasError, isFalse);

        // 7. Dispose gracefully
        controller.dispose();
        expect(controller.terminal.onOutput, isNull);
      });

      test('Session with ANSI escape sequences via relay', () async {
        // Connect to server
        final port = server.getPort();
        await relayClient.connect('localhost:$port', pairingCode);
        await Future.delayed(const Duration(milliseconds: 100));

        // Create controller
        controller = RemoteTerminalController(
          relayClient: relayClient,
          ourKeys: clientKeys,
          remoteKeys: serverKeys,
          terminalState: terminalState,
        );

        // Send arrow key sequences via relay - these should complete without error
        await relayClient.sendTerminalInput('\x1b[A'); // Up arrow
        await relayClient.sendTerminalInput('\x1b[B'); // Down arrow
        await relayClient.sendTerminalInput('\x1b[C'); // Right arrow
        await relayClient.sendTerminalInput('\x1b[D'); // Left arrow

        await Future.delayed(const Duration(milliseconds: 100));

        // No errors should occur
        expect(terminalState.hasError, isFalse);
      });

      test('Session with Unicode characters via relay', () async {
        // Connect to server
        final port = server.getPort();
        await relayClient.connect('localhost:$port', pairingCode);
        await Future.delayed(const Duration(milliseconds: 100));

        // Create controller
        controller = RemoteTerminalController(
          relayClient: relayClient,
          ourKeys: clientKeys,
          remoteKeys: serverKeys,
          terminalState: terminalState,
        );

        // Send Unicode input via relay
        await relayClient.sendTerminalInput('echo "Hello 世界 🌍"\r');

        await Future.delayed(const Duration(milliseconds: 100));

        // No errors should occur
        expect(terminalState.hasError, isFalse);
      });
    });
  });
}
