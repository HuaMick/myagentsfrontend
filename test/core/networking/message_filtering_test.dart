import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import '../../../lib/core/crypto/key_pair.dart';
import '../../../lib/core/crypto/message_envelope.dart';
import '../../../lib/core/networking/relay_client.dart';
import '../../mock_relay_server.dart';

/// Test suite for RelayClient message filtering and streaming functionality.
///
/// This test suite validates:
/// - getMessagesByType() filters messages correctly
/// - terminalOutputStream convenience method works
/// - Streams don't block when empty
/// - Stream cancellation cleans up properly
/// - Multiple message types can be sent and filtered
void main() {
  group('RelayClient Message Filtering and Streaming', () {
    late MockRelayServer server;
    late RelayClient client;
    late KeyPair clientKeys;
    late KeyPair serverKeys;
    late String pairingCode;

    setUp(() async {
      // Generate key pairs
      clientKeys = KeyPair.generate();

      // Start mock server
      server = MockRelayServer(
        config: const MockRelayServerConfig(
          verbose: false,
          echoTerminalInput: false, // Disable echo so we control messages
          autoRespondToPairing: false,
        ),
      );
      await server!.start();
      serverKeys = server!.getServerKeys();

      // Create client
      client = RelayClient();
      pairingCode = 'TEST01';
    });

    tearDown(() async {
      await client.dispose();
      await server!.stop();
    });

    test('getMessagesByType filters terminal_output messages correctly', () async {
      // Connect and set keys
      await client.connect('localhost:${server!.getPort()}', pairingCode);
      client.setKeys(clientKeys, serverKeys);

      // Set up filtered stream for terminal_output only
      final outputMessages = <MessageEnvelope>[];
      final subscription = client.getMessagesByType(MessageType.terminalOutput)
          .listen(outputMessages.add);

      // Wait for connection
      await Future.delayed(const Duration(milliseconds: 100));

      // Send multiple message types from server
      await server!.sendToClient(
        pairingCode,
        MessageType.terminalOutput,
        {'data': 'Output 1'},
      );
      await server!.sendToClient(
        pairingCode,
        MessageType.terminalOutput,
        {'data': 'Output 2'},
      );
      await server!.sendToClient(
        pairingCode,
        MessageType.resize,
        {'rows': 24, 'cols': 80},
      );
      await server!.sendToClient(
        pairingCode,
        MessageType.terminalOutput,
        {'data': 'Output 3'},
      );

      // Wait for messages to be processed
      await Future.delayed(const Duration(milliseconds: 200));

      // Verify only terminal_output messages were received
      expect(outputMessages.length, equals(3));
      expect(outputMessages[0].type, equals(MessageType.terminalOutput));
      expect(outputMessages[1].type, equals(MessageType.terminalOutput));
      expect(outputMessages[2].type, equals(MessageType.terminalOutput));

      // Verify we can decrypt the messages
      final data1 = outputMessages[0].open(clientKeys, serverKeys);
      final data2 = outputMessages[1].open(clientKeys, serverKeys);
      final data3 = outputMessages[2].open(clientKeys, serverKeys);

      expect(data1['data'], equals('Output 1'));
      expect(data2['data'], equals('Output 2'));
      expect(data3['data'], equals('Output 3'));

      await subscription.cancel();
    });

    test('terminalOutputStream convenience method filters correctly', () async {
      // Connect and set keys
      await client.connect('localhost:${server!.getPort()}', pairingCode);
      client.setKeys(clientKeys, serverKeys);

      // Set up convenience stream
      final outputMessages = <MessageEnvelope>[];
      final subscription = client.terminalOutputStream.listen(outputMessages.add);

      // Wait for connection
      await Future.delayed(const Duration(milliseconds: 100));

      // Send mixed message types
      await server!.sendToClient(
        pairingCode,
        MessageType.terminalOutput,
        {'data': 'Terminal output 1'},
      );
      await server!.sendToClient(
        pairingCode,
        MessageType.pairingRequest,
        {'request': 'pair'},
      );
      await server!.sendToClient(
        pairingCode,
        MessageType.terminalOutput,
        {'data': 'Terminal output 2'},
      );

      // Wait for messages
      await Future.delayed(const Duration(milliseconds: 200));

      // Verify only terminal_output messages
      expect(outputMessages.length, equals(2));

      final data1 = outputMessages[0].open(clientKeys, serverKeys);
      final data2 = outputMessages[1].open(clientKeys, serverKeys);

      expect(data1['data'], equals('Terminal output 1'));
      expect(data2['data'], equals('Terminal output 2'));

      await subscription.cancel();
    });

    test('multiple message types can be filtered independently', () async {
      // Connect and set keys
      await client.connect('localhost:${server!.getPort()}', pairingCode);
      client.setKeys(clientKeys, serverKeys);

      // Set up multiple filtered streams
      final outputMessages = <MessageEnvelope>[];
      final resizeMessages = <MessageEnvelope>[];
      final pairingMessages = <MessageEnvelope>[];

      final outputSub = client.getMessagesByType(MessageType.terminalOutput)
          .listen(outputMessages.add);
      final resizeSub = client.getMessagesByType(MessageType.resize)
          .listen(resizeMessages.add);
      final pairingSub = client.getMessagesByType(MessageType.pairingRequest)
          .listen(pairingMessages.add);

      // Wait for connection
      await Future.delayed(const Duration(milliseconds: 100));

      // Send various message types
      await server!.sendToClient(
        pairingCode,
        MessageType.terminalOutput,
        {'data': 'Output'},
      );
      await server!.sendToClient(
        pairingCode,
        MessageType.resize,
        {'rows': 30, 'cols': 100},
      );
      await server!.sendToClient(
        pairingCode,
        MessageType.pairingRequest,
        {'key': 'value'},
      );
      await server!.sendToClient(
        pairingCode,
        MessageType.terminalOutput,
        {'data': 'More output'},
      );

      // Wait for messages
      await Future.delayed(const Duration(milliseconds: 200));

      // Verify each stream received only its type
      expect(outputMessages.length, equals(2));
      expect(resizeMessages.length, equals(1));
      expect(pairingMessages.length, equals(1));

      // Verify content
      final output1 = outputMessages[0].open(clientKeys, serverKeys);
      expect(output1['data'], equals('Output'));

      final resize = resizeMessages[0].open(clientKeys, serverKeys);
      expect(resize['rows'], equals(30));
      expect(resize['cols'], equals(100));

      final pairing = pairingMessages[0].open(clientKeys, serverKeys);
      expect(pairing['key'], equals('value'));

      await outputSub.cancel();
      await resizeSub.cancel();
      await pairingSub.cancel();
    });

    test('filtered stream does not block when no messages match', () async {
      // Connect and set keys
      await client.connect('localhost:${server!.getPort()}', pairingCode);
      client.setKeys(clientKeys, serverKeys);

      // Set up stream for terminal_output
      final outputMessages = <MessageEnvelope>[];
      final subscription = client.terminalOutputStream.listen(outputMessages.add);

      // Wait for connection
      await Future.delayed(const Duration(milliseconds: 100));

      // Send only resize messages (not terminal_output)
      await server!.sendToClient(
        pairingCode,
        MessageType.resize,
        {'rows': 24, 'cols': 80},
      );
      await server!.sendToClient(
        pairingCode,
        MessageType.resize,
        {'rows': 30, 'cols': 100},
      );

      // Wait a bit
      await Future.delayed(const Duration(milliseconds: 200));

      // Stream should not block and should have no messages
      expect(outputMessages.length, equals(0));

      // Now send a terminal_output message
      await server!.sendToClient(
        pairingCode,
        MessageType.terminalOutput,
        {'data': 'Finally some output'},
      );

      // Wait for message
      await Future.delayed(const Duration(milliseconds: 200));

      // Should now have one message
      expect(outputMessages.length, equals(1));

      final data = outputMessages[0].open(clientKeys, serverKeys);
      expect(data['data'], equals('Finally some output'));

      await subscription.cancel();
    });

    test('stream cancellation cleans up properly', () async {
      // Connect and set keys
      await client.connect('localhost:${server!.getPort()}', pairingCode);
      client.setKeys(clientKeys, serverKeys);

      // Set up stream and cancel it
      final outputMessages = <MessageEnvelope>[];
      final subscription = client.terminalOutputStream.listen(outputMessages.add);

      // Wait for connection
      await Future.delayed(const Duration(milliseconds: 100));

      // Send a message before cancellation
      await server!.sendToClient(
        pairingCode,
        MessageType.terminalOutput,
        {'data': 'Before cancel'},
      );

      await Future.delayed(const Duration(milliseconds: 100));
      expect(outputMessages.length, equals(1));

      // Cancel subscription
      await subscription.cancel();

      // Send messages after cancellation
      await server!.sendToClient(
        pairingCode,
        MessageType.terminalOutput,
        {'data': 'After cancel 1'},
      );
      await server!.sendToClient(
        pairingCode,
        MessageType.terminalOutput,
        {'data': 'After cancel 2'},
      );

      // Wait to ensure messages aren't delivered
      await Future.delayed(const Duration(milliseconds: 200));

      // Should still have only the first message
      expect(outputMessages.length, equals(1));
    });

    test('multiple subscribers to same filtered stream receive all messages', () async {
      // Connect and set keys
      await client.connect('localhost:${server!.getPort()}', pairingCode);
      client.setKeys(clientKeys, serverKeys);

      // Set up multiple subscribers to same stream type
      final subscriber1Messages = <MessageEnvelope>[];
      final subscriber2Messages = <MessageEnvelope>[];
      final subscriber3Messages = <MessageEnvelope>[];

      final sub1 = client.terminalOutputStream.listen(subscriber1Messages.add);
      final sub2 = client.terminalOutputStream.listen(subscriber2Messages.add);
      final sub3 = client.terminalOutputStream.listen(subscriber3Messages.add);

      // Wait for connection
      await Future.delayed(const Duration(milliseconds: 100));

      // Send messages
      await server!.sendToClient(
        pairingCode,
        MessageType.terminalOutput,
        {'data': 'Message 1'},
      );
      await server!.sendToClient(
        pairingCode,
        MessageType.terminalOutput,
        {'data': 'Message 2'},
      );

      // Wait for messages
      await Future.delayed(const Duration(milliseconds: 200));

      // All subscribers should receive all messages (broadcast stream)
      expect(subscriber1Messages.length, equals(2));
      expect(subscriber2Messages.length, equals(2));
      expect(subscriber3Messages.length, equals(2));

      await sub1.cancel();
      await sub2.cancel();
      await sub3.cancel();
    });

    test('stream continues working after reconnection', () async {
      // Connect and set keys
      await client.connect('localhost:${server!.getPort()}', pairingCode);
      client.setKeys(clientKeys, serverKeys);

      // Set up stream before reconnection
      final outputMessages = <MessageEnvelope>[];
      final subscription = client.terminalOutputStream.listen(outputMessages.add);

      // Wait for connection
      await Future.delayed(const Duration(milliseconds: 100));

      // Send a message before disconnect
      await server!.sendToClient(
        pairingCode,
        MessageType.terminalOutput,
        {'data': 'Before disconnect'},
      );

      await Future.delayed(const Duration(milliseconds: 100));
      expect(outputMessages.length, equals(1));

      // Force disconnect and reconnect
      await server!.forceDisconnect(pairingCode);
      await Future.delayed(const Duration(milliseconds: 100));

      // Reconnect
      await client.reconnect();
      await Future.delayed(const Duration(milliseconds: 200));

      // Send message after reconnection
      await server!.sendToClient(
        pairingCode,
        MessageType.terminalOutput,
        {'data': 'After reconnect'},
      );

      await Future.delayed(const Duration(milliseconds: 200));

      // Stream should continue working
      expect(outputMessages.length, equals(2));

      final data1 = outputMessages[0].open(clientKeys, serverKeys);
      final data2 = outputMessages[1].open(clientKeys, serverKeys);

      expect(data1['data'], equals('Before disconnect'));
      expect(data2['data'], equals('After reconnect'));

      await subscription.cancel();
    });

    test('sending multiple message types and filtering them', () async {
      // Connect and set keys
      await client.connect('localhost:${server!.getPort()}', pairingCode);
      client.setKeys(clientKeys, serverKeys);

      // Set up stream to collect terminal_output messages
      final outputMessages = <MessageEnvelope>[];
      final subscription = client.terminalOutputStream.listen(outputMessages.add);

      // Wait for connection
      await Future.delayed(const Duration(milliseconds: 100));

      // Client sends various message types
      await client.send(MessageType.terminalInput, {'input': 'ls -la'});
      await client.send(MessageType.resize, {'rows': 24, 'cols': 80});
      await client.send(MessageType.terminalInput, {'input': 'pwd'});

      // Wait for messages to be sent
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify server received them
      final receivedMessages = server.getReceivedMessages();
      expect(receivedMessages.length, equals(3));
      expect(receivedMessages[0].type, equals(MessageType.terminalInput));
      expect(receivedMessages[1].type, equals(MessageType.resize));
      expect(receivedMessages[2].type, equals(MessageType.terminalInput));

      // Server sends back terminal_output messages
      await server!.sendToClient(
        pairingCode,
        MessageType.terminalOutput,
        {'data': 'file1.txt\nfile2.txt'},
      );
      await server!.sendToClient(
        pairingCode,
        MessageType.terminalOutput,
        {'data': '/home/user'},
      );

      // Wait for messages
      await Future.delayed(const Duration(milliseconds: 200));

      // Client should have filtered and received only terminal_output
      expect(outputMessages.length, equals(2));

      final data1 = outputMessages[0].open(clientKeys, serverKeys);
      final data2 = outputMessages[1].open(clientKeys, serverKeys);

      expect(data1['data'], equals('file1.txt\nfile2.txt'));
      expect(data2['data'], equals('/home/user'));

      await subscription.cancel();
    });

    test('pairingRequestStream convenience method filters correctly', () async {
      // Connect and set keys
      await client.connect('localhost:${server!.getPort()}', pairingCode);
      client.setKeys(clientKeys, serverKeys);

      // Set up pairing request stream
      final pairingMessages = <MessageEnvelope>[];
      final subscription = client.pairingRequestStream.listen(pairingMessages.add);

      // Wait for connection
      await Future.delayed(const Duration(milliseconds: 100));

      // Send mixed message types
      await server!.sendToClient(
        pairingCode,
        MessageType.pairingRequest,
        {'publicKey': 'key1'},
      );
      await server!.sendToClient(
        pairingCode,
        MessageType.terminalOutput,
        {'data': 'output'},
      );
      await server!.sendToClient(
        pairingCode,
        MessageType.pairingRequest,
        {'publicKey': 'key2'},
      );

      // Wait for messages
      await Future.delayed(const Duration(milliseconds: 200));

      // Verify only pairing_request messages
      expect(pairingMessages.length, equals(2));

      final data1 = pairingMessages[0].open(clientKeys, serverKeys);
      final data2 = pairingMessages[1].open(clientKeys, serverKeys);

      expect(data1['publicKey'], equals('key1'));
      expect(data2['publicKey'], equals('key2'));

      await subscription.cancel();
    });
  });
}
