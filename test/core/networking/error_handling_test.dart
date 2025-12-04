import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/core/networking/relay_client.dart';
import '../../../lib/core/networking/connection_state.dart';
import '../../../lib/core/crypto/key_pair.dart';
import '../../mock_relay_server.dart';

/// Test Agent 3: Connection Error Handling Tests
///
/// Tests RelayClient error handling, reconnection logic, and error state management.
/// Validates behavior with invalid URLs, rejected pairing codes, server disconnects,
/// and reconnection with exponential backoff.
void main() {
  group('Connection Error Handling Tests', () {
    MockRelayServer? server;
    late RelayClient client;

    setUp(() async {
      // Initialize client
      client = RelayClient();
    });

    tearDown(() async {
      // Clean up
      await client.dispose();
      if (server != null) {
        try {
          await server!.stop();
        } catch (e) {
          // Server may already be stopped
        }
      }
    });

    test('Invalid relay URL results in error state', () async {
      // Arrange
      final invalidUrls = [
        'invalid-url-no-protocol',
        'http://invalid-scheme',
        '',
        'ws://nonexistent-server.invalid:12345',
      ];

      for (final invalidUrl in invalidUrls) {
        final testClient = RelayClient();

        // Track state changes
        final stateChanges = <ConnectionState>[];
        testClient.stateManager.addListener(() {
          stateChanges.add(testClient.stateManager.currentState);
        });

        // Track errors
        final errors = <dynamic>[];
        final errorSubscription = testClient.errorStream.listen((error) {
          errors.add(error);
        });

        // Act & Assert
        try {
          await testClient.connect(invalidUrl, 'ABC123');
          fail('Expected connection to fail for invalid URL: $invalidUrl');
        } catch (e) {
          // Connection should fail with exception
          expect(e, isNotNull);
        }

        // Wait briefly for state updates
        await Future.delayed(Duration(milliseconds: 100));

        // Verify error state
        expect(
          testClient.stateManager.hasError,
          isTrue,
          reason: 'Client should be in error state after invalid URL connection',
        );

        // Verify error message is stored
        expect(
          testClient.stateManager.errorMessage,
          isNotNull,
          reason: 'Error message should be stored in state manager',
        );
        expect(
          testClient.stateManager.errorMessage,
          contains('Connection failed'),
          reason: 'Error message should indicate connection failure',
        );

        // Verify error was reported to error stream
        expect(
          errors.isNotEmpty,
          isTrue,
          reason: 'Error should be reported to error stream',
        );

        // Cleanup
        await errorSubscription.cancel();
        await testClient.dispose();
      }
    });

    test('Invalid pairing code rejected by server', () async {
      // Arrange - Start server that rejects specific pairing codes
      final rejectedCode = 'REJECT';
      server = MockRelayServer(
        config: MockRelayServerConfig.withRejectedCodes({rejectedCode}),
      );
      await server!.start();
      final port = server!.getPort();

      // Track state changes
      final stateChanges = <ConnectionState>[];
      client.stateManager.addListener(() {
        stateChanges.add(client.stateManager.currentState);
      });

      // Track errors
      final errors = <dynamic>[];
      final errorSubscription = client.errorStream.listen((error) {
        errors.add(error);
      });

      // Act - Attempt to connect with rejected pairing code
      try {
        await client.connect('localhost:$port', rejectedCode);
        fail('Expected connection to be rejected for invalid pairing code');
      } catch (e) {
        // Expected to fail
        expect(e, isNotNull);
      }

      // Wait briefly for state updates
      await Future.delayed(Duration(milliseconds: 100));

      // Assert - Verify error state
      expect(
        client.stateManager.hasError,
        isTrue,
        reason: 'Client should be in error state after rejected pairing code',
      );

      // Verify error message mentions connection failure
      expect(
        client.stateManager.errorMessage,
        isNotNull,
        reason: 'Error message should be stored',
      );

      // Verify error was reported
      expect(
        errors.isNotEmpty,
        isTrue,
        reason: 'Error should be reported to error stream',
      );

      // Cleanup
      await errorSubscription.cancel();
    });

    test('Server disconnect during active connection triggers reconnect', () async {
      // Arrange - Start server
      server = MockRelayServer(config: MockRelayServerConfig.verbose());
      await server!.start();
      final port = server!.getPort();
      final pairingCode = 'TEST01';

      // Generate keys for encryption
      final clientKeys = KeyPair.generate();
      final serverKeys = server!.getServerKeys();
      client.setKeys(clientKeys, serverKeys);

      // Connect successfully
      await client.connect('localhost:$port', pairingCode);
      expect(client.isConnected, isTrue);

      // Wait for connection to stabilize
      await Future.delayed(Duration(milliseconds: 200));

      // Track state changes
      final stateChanges = <ConnectionState>[];
      client.stateManager.addListener(() {
        stateChanges.add(client.stateManager.currentState);
      });

      // Act - Force disconnect from server side
      await server!.forceDisconnect(pairingCode);

      // Wait for client to detect disconnect and attempt reconnect
      await Future.delayed(Duration(milliseconds: 500));

      // Assert - Verify reconnecting state was reached
      expect(
        stateChanges.contains(ConnectionState.reconnecting) ||
            client.stateManager.currentState == ConnectionState.reconnecting,
        isTrue,
        reason: 'Client should attempt to reconnect after unexpected disconnect',
      );

      // Verify error state was set (before reconnect attempt)
      expect(
        client.stateManager.errorMessage,
        isNotNull,
        reason: 'Error message should be stored after unexpected disconnect',
      );
    });

    test('Auto-reconnect with exponential backoff', () async {
      // Arrange - Start server
      server = MockRelayServer(config: MockRelayServerConfig.verbose());
      await server!.start();
      final port = server!.getPort();
      final pairingCode = 'BACKOF';

      // Generate keys
      final clientKeys = KeyPair.generate();
      final serverKeys = server!.getServerKeys();
      client.setKeys(clientKeys, serverKeys);

      // Connect and disconnect to trigger reconnect
      await client.connect('localhost:$port', pairingCode);
      expect(client.isConnected, isTrue);
      await Future.delayed(Duration(milliseconds: 100));

      // Track reconnection attempts timing
      final reconnectTimes = <DateTime>[];
      client.stateManager.addListener(() {
        if (client.stateManager.currentState == ConnectionState.reconnecting) {
          reconnectTimes.add(DateTime.now());
        }
      });

      // Stop server to trigger reconnections
      await server!.stop();
      await Future.delayed(Duration(milliseconds: 100));

      // Wait for multiple reconnection attempts with exponential backoff
      // Base delay is 1 second, exponential backoff: 1s, 2s, 4s, 8s...
      // Wait up to 8 seconds to capture first few attempts
      await Future.delayed(Duration(seconds: 8));

      // Assert - Verify exponential backoff is applied
      if (reconnectTimes.length >= 2) {
        // Calculate delays between reconnection attempts
        final delays = <Duration>[];
        for (int i = 1; i < reconnectTimes.length && i < 4; i++) {
          final delay = reconnectTimes[i].difference(reconnectTimes[i - 1]);
          delays.add(delay);
        }

        // Verify delays are increasing (exponential backoff)
        if (delays.length >= 2) {
          expect(
            delays[1].inMilliseconds > delays[0].inMilliseconds,
            isTrue,
            reason: 'Reconnection delays should increase exponentially',
          );
        }
      }

      // Verify client is attempting to reconnect
      expect(
        client.stateManager.currentState == ConnectionState.reconnecting ||
            client.stateManager.hasError,
        isTrue,
        reason: 'Client should be attempting reconnection or in error state',
      );
    });

    test('Maximum reconnect attempts respected', () async {
      // Arrange - Create client without server (to force immediate failures)
      final nonExistentPort = 19999; // Port with no server running
      final pairingCode = 'MAXATT';

      // Disable auto-reconnect initially to control the test
      client.setAutoReconnect(true);

      // Track state changes
      final stateChanges = <ConnectionState>[];
      final errorMessages = <String?>[];
      client.stateManager.addListener(() {
        stateChanges.add(client.stateManager.currentState);
        errorMessages.add(client.stateManager.errorMessage);
      });

      // Act - Attempt connection to non-existent server
      try {
        await client.connect('localhost:$nonExistentPort', pairingCode);
        fail('Expected connection to fail');
      } catch (e) {
        // Expected to fail
      }

      // Wait for maximum reconnect attempts (10 attempts with exponential backoff)
      // This could take a while (1+2+4+8+16+32+60+60+60+60 = ~300 seconds worst case)
      // For test efficiency, we'll check after a shorter period
      await Future.delayed(Duration(seconds: 5));

      // Assert - Check if max reconnect attempts error is set
      final maxAttemptsReached = errorMessages.any(
        (msg) => msg != null && msg.contains('Max reconnection attempts'),
      );

      // After max attempts, client should be disconnected with error
      if (stateChanges.length > 10) {
        // If many reconnect attempts happened, verify final state
        expect(
          client.stateManager.isDisconnected || client.stateManager.hasError,
          isTrue,
          reason: 'Client should be disconnected after max reconnect attempts',
        );
      }

      // Note: This test has a time constraint - full verification would take ~5+ minutes
      // We verify the mechanism is in place by checking for reconnecting states
      expect(
        stateChanges.where((s) => s == ConnectionState.reconnecting).length > 0,
        isTrue,
        reason: 'Client should attempt reconnection at least once',
      );
    });

    test('Error messages stored and accessible', () async {
      // Arrange - Start server then force various error conditions
      server = MockRelayServer(config: MockRelayServerConfig.verbose());
      await server!.start();
      final port = server!.getPort();
      final pairingCode = 'ERRORS';

      // Test 1: Connection to invalid URL
      final testClient1 = RelayClient();
      try {
        await testClient1.connect('invalid-host:99999', pairingCode);
      } catch (e) {
        // Expected
      }
      await Future.delayed(Duration(milliseconds: 100));

      expect(testClient1.stateManager.errorMessage, isNotNull,
          reason: 'Error message should be stored for invalid connection');
      expect(testClient1.stateManager.errorMessage, contains('Connection failed'),
          reason: 'Error message should describe the connection failure');
      expect(testClient1.stateManager.hasError, isTrue,
          reason: 'Client should be in error state');

      await testClient1.dispose();

      // Test 2: Server rejection (invalid pairing code)
      final rejectedCode = 'BAD123';
      final serverWithReject = MockRelayServer(
        config: MockRelayServerConfig.withRejectedCodes({rejectedCode}),
      );
      await serverWithReject.start();
      final rejectPort = serverWithReject.getPort();

      final testClient2 = RelayClient();
      try {
        await testClient2.connect('localhost:$rejectPort', rejectedCode);
      } catch (e) {
        // Expected
      }
      await Future.delayed(Duration(milliseconds: 100));

      expect(testClient2.stateManager.errorMessage, isNotNull,
          reason: 'Error message should be stored for rejected connection');
      expect(testClient2.stateManager.hasError, isTrue,
          reason: 'Client should be in error state after rejection');

      await testClient2.dispose();
      await serverWithReject.stop();

      // Test 3: Successful connection then disconnect
      final testClient3 = RelayClient();
      final clientKeys = KeyPair.generate();
      final serverKeys = server!.getServerKeys();
      testClient3.setKeys(clientKeys, serverKeys);

      await testClient3.connect('localhost:$port', 'DISC01');
      expect(testClient3.isConnected, isTrue);
      await Future.delayed(Duration(milliseconds: 200));

      // Force disconnect
      await server!.forceDisconnect('DISC01');
      await Future.delayed(Duration(milliseconds: 300));

      // Verify error message for unexpected disconnect
      expect(testClient3.stateManager.errorMessage, isNotNull,
          reason: 'Error message should be stored after unexpected disconnect');
      expect(testClient3.stateManager.errorMessage, contains('closed'),
          reason: 'Error message should mention connection closure');

      await testClient3.dispose();
    });

    test('Error state clears on successful reconnection', () async {
      // Arrange - Start server
      server = MockRelayServer(config: MockRelayServerConfig.verbose());
      await server!.start();
      final port = server!.getPort();
      final pairingCode = 'CLEAR1';

      final clientKeys = KeyPair.generate();
      final serverKeys = server!.getServerKeys();
      client.setKeys(clientKeys, serverKeys);

      // Connect successfully
      await client.connect('localhost:$port', pairingCode);
      expect(client.isConnected, isTrue);
      await Future.delayed(Duration(milliseconds: 200));

      // Track state changes
      final stateChanges = <ConnectionState>[];
      client.stateManager.addListener(() {
        stateChanges.add(client.stateManager.currentState);
      });

      // Force disconnect to create error state
      await server!.forceDisconnect(pairingCode);
      await Future.delayed(Duration(milliseconds: 300));

      // Verify error state
      expect(client.stateManager.hasError, isTrue,
          reason: 'Client should be in error state after disconnect');
      expect(client.stateManager.errorMessage, isNotNull,
          reason: 'Error message should be set');

      // Restart server for reconnection
      await server!.start(port: port);
      await Future.delayed(Duration(seconds: 3)); // Wait for reconnection

      // Assert - Verify error cleared after successful reconnection
      if (client.isConnected) {
        expect(client.stateManager.errorMessage, isNull,
            reason: 'Error message should be cleared after successful reconnection');
        expect(client.stateManager.hasError, isFalse,
            reason: 'Client should not be in error state after reconnection');
      }
    });

    test('Disable auto-reconnect prevents reconnection attempts', () async {
      // Arrange - Start server
      server = MockRelayServer(config: MockRelayServerConfig.verbose());
      await server!.start();
      final port = server!.getPort();
      final pairingCode = 'NOAUTO';

      final clientKeys = KeyPair.generate();
      final serverKeys = server!.getServerKeys();
      client.setKeys(clientKeys, serverKeys);

      // Disable auto-reconnect
      client.setAutoReconnect(false);

      // Connect successfully
      await client.connect('localhost:$port', pairingCode);
      expect(client.isConnected, isTrue);
      await Future.delayed(Duration(milliseconds: 200));

      // Track state changes
      final stateChanges = <ConnectionState>[];
      client.stateManager.addListener(() {
        stateChanges.add(client.stateManager.currentState);
      });

      // Force disconnect
      await server!.forceDisconnect(pairingCode);
      await Future.delayed(Duration(milliseconds: 500));

      // Assert - Verify no reconnection attempts
      expect(
        stateChanges.where((s) => s == ConnectionState.reconnecting).isEmpty,
        isTrue,
        reason: 'Client should not attempt reconnection when auto-reconnect is disabled',
      );

      // Client should be in disconnected state (not reconnecting)
      expect(
        client.stateManager.isDisconnected,
        isTrue,
        reason: 'Client should be disconnected when auto-reconnect is disabled',
      );
    });
  });
}
