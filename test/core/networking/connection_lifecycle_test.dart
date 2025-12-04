import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/core/networking/relay_client.dart';
import '../../../lib/core/networking/connection_state.dart';
import '../../../lib/core/crypto/key_pair.dart';
import '../../mock_relay_server.dart';

/// Test suite for RelayClient connection lifecycle management.
///
/// This suite covers:
/// 1. MockRelayServer startup and cleanup
/// 2. Client connection to mock server
/// 3. State transitions: disconnected -> connecting -> connected
/// 4. Disconnect and state verification: connected -> disconnected
/// 5. Reconnect after disconnect
/// 6. MockRelayServer shutdown and cleanup
void main() {
  group('RelayClient Connection Lifecycle', () {
    late MockRelayServer server;
    late RelayClient client;
    late KeyPair clientKeys;
    late KeyPair serverKeys;
    const pairingCode = 'ABC123';

    setUp(() async {
      // Start MockRelayServer on random port
      server = MockRelayServer(
        config: MockRelayServerConfig(
          verbose: false,
          echoTerminalInput: false,
          autoRespondToPairing: false,
        ),
      );
      await server!.start();

      // Get server keys for encryption
      serverKeys = server!.getServerKeys();

      // Generate client keys for encryption
      clientKeys = KeyPair.generate();

      // Create RelayClient instance
      client = RelayClient();
      client.setKeys(clientKeys, serverKeys);
    });

    tearDown(() async {
      // Clean up client
      await client.dispose();

      // Stop server
      await server!.stop();
    });

    test('MockRelayServer starts successfully and accepts connections', () async {
      // Verify server is running
      expect(server!.getPort(), greaterThan(0));
      expect(server!.isClientConnected(pairingCode), isFalse);
    });

    test('RelayClient initial state is disconnected', () {
      expect(client.stateManager.currentState, equals(ConnectionState.disconnected));
      expect(client.isConnected, isFalse);
      expect(client.stateManager.isDisconnected, isTrue);
      expect(client.stateManager.isConnecting, isFalse);
    });

    test('RelayClient connects successfully and transitions through states', () async {
      // Track state transitions
      final stateTransitions = <ConnectionState>[];
      client.stateManager.addListener(() {
        stateTransitions.add(client.stateManager.currentState);
      });

      // Initial state should be disconnected
      expect(client.stateManager.currentState, equals(ConnectionState.disconnected));

      // Connect to server
      final port = server!.getPort();
      final connectFuture = client.connect('localhost:$port', pairingCode);

      // Wait briefly for connection to establish
      await Future.delayed(const Duration(milliseconds: 100));

      // Wait for connection to complete
      await connectFuture;

      // Verify final state is connected
      expect(client.stateManager.currentState, equals(ConnectionState.connected));
      expect(client.isConnected, isTrue);

      // Verify state transitions occurred
      expect(stateTransitions, contains(ConnectionState.connecting));
      expect(stateTransitions, contains(ConnectionState.connected));

      // Verify state transitions are in correct order
      final connectingIndex = stateTransitions.indexOf(ConnectionState.connecting);
      final connectedIndex = stateTransitions.indexOf(ConnectionState.connected);
      expect(connectingIndex, lessThan(connectedIndex),
          reason: 'connecting state should occur before connected state');

      // Verify client is connected on server side
      await server!.waitForClient(pairingCode, timeout: const Duration(seconds: 2));
      expect(server!.isClientConnected(pairingCode), isTrue);
    });

    test('RelayClient disconnects cleanly and transitions to disconnected state', () async {
      // Connect first
      final port = server!.getPort();
      await client.connect('localhost:$port', pairingCode);

      // Wait for connection to establish
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify connected
      expect(client.isConnected, isTrue);
      expect(server!.isClientConnected(pairingCode), isTrue);

      // Track state during disconnect
      ConnectionState? stateAfterDisconnect;
      client.stateManager.addListener(() {
        stateAfterDisconnect = client.stateManager.currentState;
      });

      // Disconnect
      await client.disconnect();

      // Verify state is disconnected
      expect(client.stateManager.currentState, equals(ConnectionState.disconnected));
      expect(client.isConnected, isFalse);
      expect(stateAfterDisconnect, equals(ConnectionState.disconnected));

      // Wait for server to detect disconnect
      await Future.delayed(const Duration(milliseconds: 200));

      // Verify client is disconnected on server side
      expect(server!.isClientConnected(pairingCode), isFalse);
    });

    test('RelayClient reconnects successfully after disconnect', () async {
      // First connection
      final port = server!.getPort();
      await client.connect('localhost:$port', pairingCode);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(client.isConnected, isTrue);

      // Disconnect
      await client.disconnect();
      expect(client.isConnected, isFalse);

      // Wait for disconnect to complete
      await Future.delayed(const Duration(milliseconds: 100));

      // Reconnect
      await client.reconnect();

      // Wait for reconnection to establish
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify reconnected
      expect(client.stateManager.currentState, equals(ConnectionState.connected));
      expect(client.isConnected, isTrue);
      expect(server!.isClientConnected(pairingCode), isTrue);
    });

    test('RelayClient handles multiple connect/disconnect cycles', () async {
      final port = server!.getPort();

      for (int i = 0; i < 3; i++) {
        // Connect
        await client.connect('localhost:$port', pairingCode);
        await Future.delayed(const Duration(milliseconds: 100));
        expect(client.isConnected, isTrue,
            reason: 'Should be connected on cycle $i');

        // Disconnect
        await client.disconnect();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(client.isConnected, isFalse,
            reason: 'Should be disconnected on cycle $i');
      }
    });

    test('RelayClient state manager tracks lastStateChange timestamp', () async {
      // Record initial state
      final initialTimestamp = client.stateManager.lastStateChange;

      // Connect
      final port = server!.getPort();
      await client.connect('localhost:$port', pairingCode);
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify timestamp changed
      expect(client.stateManager.lastStateChange, isNotNull);
      if (initialTimestamp != null) {
        expect(client.stateManager.lastStateChange!.isAfter(initialTimestamp), isTrue);
      }

      // Store connected timestamp
      final connectedTimestamp = client.stateManager.lastStateChange;

      // Wait briefly
      await Future.delayed(const Duration(milliseconds: 50));

      // Disconnect
      await client.disconnect();

      // Verify timestamp changed again
      expect(client.stateManager.lastStateChange, isNotNull);
      expect(client.stateManager.lastStateChange!.isAfter(connectedTimestamp!), isTrue);
    });

    test('RelayClient throws StateError when connecting while already connected', () async {
      // Connect first
      final port = server!.getPort();
      await client.connect('localhost:$port', pairingCode);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(client.isConnected, isTrue);

      // Try to connect again
      expect(
        () => client.connect('localhost:$port', pairingCode),
        throwsStateError,
      );
    });

    test('RelayClient handles server-initiated disconnect (connection closed unexpectedly)', () async {
      // Disable auto-reconnect for this test
      client.setAutoReconnect(false);

      // Connect
      final port = server!.getPort();
      await client.connect('localhost:$port', pairingCode);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(client.isConnected, isTrue);

      // Force disconnect from server side
      await server!.forceDisconnect(pairingCode);

      // Wait for client to detect disconnect
      await Future.delayed(const Duration(milliseconds: 300));

      // Verify client detected the disconnect
      expect(client.isConnected, isFalse);
      expect(client.stateManager.currentState, equals(ConnectionState.disconnected));
    });

    test('MockRelayServer stops cleanly and closes all connections', () async {
      // Connect client
      final port = server!.getPort();
      await client.connect('localhost:$port', pairingCode);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(server!.isClientConnected(pairingCode), isTrue);

      // Stop server
      await server!.stop();

      // Verify server is stopped (getPort should throw)
      expect(() => server!.getPort(), throwsStateError);

      // Wait for client to detect server shutdown
      await Future.delayed(const Duration(milliseconds: 300));

      // Verify client detected the disconnect
      expect(client.isConnected, isFalse);
    });

    test('RelayClient dispose cleans up resources properly', () async {
      // Connect
      final port = server!.getPort();
      await client.connect('localhost:$port', pairingCode);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(client.isConnected, isTrue);

      // Dispose
      await client.dispose();

      // Verify disconnected
      expect(client.isConnected, isFalse);

      // Wait for server to detect disconnect
      await Future.delayed(const Duration(milliseconds: 200));
      expect(server!.isClientConnected(pairingCode), isFalse);
    });

    test('RelayClient connection state manager isConnecting returns true during connection', () async {
      // Track connecting state
      bool wasConnecting = false;
      client.stateManager.addListener(() {
        if (client.stateManager.isConnecting) {
          wasConnecting = true;
        }
      });

      // Connect
      final port = server!.getPort();
      final connectFuture = client.connect('localhost:$port', pairingCode);

      // Briefly check if connecting state is active
      await Future.delayed(const Duration(milliseconds: 10));

      // Wait for connection to complete
      await connectFuture;
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify we passed through connecting state
      expect(wasConnecting, isTrue, reason: 'Should have been in connecting state');
      expect(client.stateManager.isConnecting, isFalse, reason: 'Should no longer be connecting');
      expect(client.isConnected, isTrue);
    });

    test('Multiple RelayClients can connect to same MockRelayServer', () async {
      // Create second client
      final client2 = RelayClient();
      final clientKeys2 = KeyPair.generate();
      client2.setKeys(clientKeys2, serverKeys);
      const pairingCode2 = 'XYZ789';

      try {
        // Connect both clients
        final port = server!.getPort();
        await client.connect('localhost:$port', pairingCode);
        await client2.connect('localhost:$port', pairingCode2);

        // Wait for connections to establish
        await Future.delayed(const Duration(milliseconds: 100));

        // Verify both connected
        expect(client.isConnected, isTrue);
        expect(client2.isConnected, isTrue);
        expect(server!.isClientConnected(pairingCode), isTrue);
        expect(server!.isClientConnected(pairingCode2), isTrue);
      } finally {
        // Clean up second client
        await client2.dispose();
      }
    });

    test('RelayClient connection survives with proper state transitions', () async {
      // This test verifies the complete lifecycle end-to-end
      final port = server!.getPort();
      final stateLog = <String>[];

      // Listen to all state changes
      client.stateManager.addListener(() {
        stateLog.add('State: ${client.stateManager.currentState}');
      });

      // 1. Initial state
      expect(client.stateManager.currentState, equals(ConnectionState.disconnected));
      stateLog.add('Initial: ${client.stateManager.currentState}');

      // 2. Connect
      await client.connect('localhost:$port', pairingCode);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(client.isConnected, isTrue);

      // 3. Verify server sees connection
      expect(server!.isClientConnected(pairingCode), isTrue);

      // 4. Disconnect
      await client.disconnect();
      expect(client.isConnected, isFalse);

      // 5. Reconnect
      await client.reconnect();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(client.isConnected, isTrue);

      // 6. Final disconnect
      await client.disconnect();
      expect(client.isConnected, isFalse);

      // Print state log for debugging
      // ignore: avoid_print
      print('State transitions: $stateLog');

      // Verify we went through expected states
      expect(stateLog.any((s) => s.contains('connecting')), isTrue);
      expect(stateLog.any((s) => s.contains('connected')), isTrue);
      expect(stateLog.any((s) => s.contains('disconnected')), isTrue);
    });
  });
}
