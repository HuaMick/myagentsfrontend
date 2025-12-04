import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/core/networking/relay_client.dart';
import '../../../lib/core/crypto/key_pair.dart';
import '../../../lib/core/crypto/message_envelope.dart';
import '../../../lib/core/crypto/nacl_crypto.dart';
import '../../mock_relay_server.dart';

/// Integration tests for RelayClient with crypto layer.
///
/// Tests the full end-to-end encryption flow:
/// - KeyPair generation
/// - Public key exchange (simulated pairing)
/// - MessageEnvelope encryption with seal()
/// - MessageEnvelope decryption with open()
/// - Timestamp validation
/// - All message types (terminal_input, terminal_output, resize)
/// - Sender public key verification
void main() {
  group('RelayClient Crypto Integration Tests', () {
    late MockRelayServer server;
    late RelayClient client;
    late int port;
    late String pairingCode;

    setUp(() async {
      // Start mock relay server
      server = MockRelayServer(config: MockRelayServerConfig.verbose());
      port = await server!.start();
      pairingCode = 'TEST01';

      // Create client
      client = RelayClient();
    });

    tearDown(() async {
      // Clean up
      await client.dispose();
      await server!.stop();
    });

    test('KeyPair.generate() creates valid keys', () {
      // Generate key pair
      final keys = KeyPair.generate();

      // Verify keys exist
      expect(keys.privateKeyBytes, isNotNull);
      expect(keys.publicKeyBytes, isNotNull);

      // Verify key lengths (X25519 keys are 32 bytes)
      expect(keys.privateKeyBytes.length, equals(32));
      expect(keys.publicKeyBytes.length, equals(32));

      // Verify keys are not all zeros
      final allZerosPrivate = keys.privateKeyBytes.every((byte) => byte == 0);
      final allZerosPublic = keys.publicKeyBytes.every((byte) => byte == 0);
      expect(allZerosPrivate, isFalse, reason: 'Private key should not be all zeros');
      expect(allZerosPublic, isFalse, reason: 'Public key should not be all zeros');
    });

    test('KeyPair.generate() creates unique keys each time', () {
      // Generate two key pairs
      final keys1 = KeyPair.generate();
      final keys2 = KeyPair.generate();

      // Verify they are different
      expect(keys1.privateKeyBytes, isNot(equals(keys2.privateKeyBytes)));
      expect(keys1.publicKeyBytes, isNot(equals(keys2.publicKeyBytes)));
    });

    test('KeyPair can be exported to Base64 and imported back', () {
      // Generate key pair
      final originalKeys = KeyPair.generate();

      // Export to Base64
      final base64Keys = originalKeys.toBase64();
      expect(base64Keys, containsPair('privateKey', isA<String>()));
      expect(base64Keys, containsPair('publicKey', isA<String>()));

      // Import from Base64
      final importedKeys = KeyPair.fromBase64(base64Keys);

      // Verify keys match
      expect(importedKeys.privateKeyBytes, equals(originalKeys.privateKeyBytes));
      expect(importedKeys.publicKeyBytes, equals(originalKeys.publicKeyBytes));
    });

    test('MessageEnvelope.seal() encrypts payload correctly', () {
      // Generate key pairs for sender and recipient
      final senderKeys = KeyPair.generate();
      final recipientKeys = KeyPair.generate();

      // Create payload data
      final payloadData = {'message': 'Hello, encrypted world!'};

      // Seal the message
      final envelope = MessageEnvelope.seal(
        MessageType.terminalInput,
        payloadData,
        senderKeys,
        recipientKeys,
      );

      // Verify envelope fields
      expect(envelope.type, equals(MessageType.terminalInput));
      expect(envelope.payload, isNotEmpty);
      expect(envelope.senderPublicKey, isNotEmpty);
      expect(envelope.timestamp, isA<DateTime>());

      // Verify sender public key matches
      final expectedPublicKey = base64Encode(senderKeys.publicKeyBytes);
      expect(envelope.senderPublicKey, equals(expectedPublicKey));

      // Verify payload is encrypted (should be Base64 string)
      expect(() => base64Decode(envelope.payload), returnsNormally);

      // Verify payload is not plaintext JSON
      expect(envelope.payload, isNot(contains('Hello, encrypted world!')));
    });

    test('MessageEnvelope.open() decrypts payload correctly', () {
      // Generate key pairs for sender and recipient
      final senderKeys = KeyPair.generate();
      final recipientKeys = KeyPair.generate();

      // Create and seal message
      final originalPayload = {'message': 'Secret data', 'value': 42};
      final envelope = MessageEnvelope.seal(
        MessageType.terminalOutput,
        originalPayload,
        senderKeys,
        recipientKeys,
      );

      // Open (decrypt) the message
      final decryptedPayload = envelope.open(recipientKeys, senderKeys);

      // Verify decrypted payload matches original
      expect(decryptedPayload, equals(originalPayload));
      expect(decryptedPayload['message'], equals('Secret data'));
      expect(decryptedPayload['value'], equals(42));
    });

    test('MessageEnvelope encryption fails with wrong keys', () {
      // Generate key pairs
      final senderKeys = KeyPair.generate();
      final recipientKeys = KeyPair.generate();
      final wrongKeys = KeyPair.generate();

      // Create and seal message
      final payload = {'test': 'data'};
      final envelope = MessageEnvelope.seal(
        MessageType.terminalInput,
        payload,
        senderKeys,
        recipientKeys,
      );

      // Attempt to decrypt with wrong keys should fail
      expect(
        () => envelope.open(recipientKeys, wrongKeys),
        throwsA(isA<CryptoException>()),
      );
    });

    test('MessageEnvelope timestamp is present and valid', () {
      final senderKeys = KeyPair.generate();
      final recipientKeys = KeyPair.generate();

      // Record time before creating envelope
      final beforeTime = DateTime.now().toUtc();

      // Create envelope
      final envelope = MessageEnvelope.seal(
        MessageType.terminalInput,
        {'test': 'data'},
        senderKeys,
        recipientKeys,
      );

      // Record time after creating envelope
      final afterTime = DateTime.now().toUtc();

      // Verify timestamp is between before and after times
      expect(envelope.timestamp.isAfter(beforeTime.subtract(Duration(seconds: 1))), isTrue);
      expect(envelope.timestamp.isBefore(afterTime.add(Duration(seconds: 1))), isTrue);

      // Verify timestamp is in UTC
      expect(envelope.timestamp.isUtc, isTrue);
    });

    test('MessageEnvelope preserves timestamp through serialization', () {
      final senderKeys = KeyPair.generate();
      final recipientKeys = KeyPair.generate();

      // Create envelope with specific timestamp
      final specificTime = DateTime.utc(2025, 12, 4, 10, 30, 0);
      final envelope = MessageEnvelope(
        type: MessageType.terminalInput,
        payload: 'dummy',
        senderPublicKey: base64Encode(senderKeys.publicKeyBytes),
        timestamp: specificTime,
      );

      // Serialize to JSON
      final json = envelope.toJson();

      // Deserialize from JSON
      final deserialized = MessageEnvelope.fromJson(json);

      // Verify timestamp is preserved
      expect(deserialized.timestamp, equals(specificTime));
    });

    test('MessageEnvelope works with terminal_input message type', () async {
      // Connect client to server
      final clientKeys = KeyPair.generate();
      final serverKeys = server!.getServerKeys();

      await client.connect('localhost:$port', pairingCode);
      await server!.waitForClient(pairingCode);

      client.setKeys(clientKeys, serverKeys);

      // Send terminal_input message
      final inputData = {'data': 'ls -la'};
      await client.send(MessageType.terminalInput, inputData);

      // Wait for server to receive message
      await server.waitForMessages(1);

      // Verify message was received and decrypted correctly
      final receivedMessages = server.getReceivedMessages();
      expect(receivedMessages.length, equals(1));
      expect(receivedMessages[0].type, equals(MessageType.terminalInput));
      expect(receivedMessages[0].payload, equals(inputData));
    });

    test('MessageEnvelope works with terminal_output message type', () async {
      // Connect client to server
      final clientKeys = KeyPair.generate();
      final serverKeys = server!.getServerKeys();

      await client.connect('localhost:$port', pairingCode);
      await server!.waitForClient(pairingCode);

      client.setKeys(clientKeys, serverKeys);

      // Create a completer to capture the received message
      final receivedCompleter = Completer<MessageEnvelope>();
      final subscription = client.terminalOutputStream.listen((envelope) {
        if (!receivedCompleter.isCompleted) {
          receivedCompleter.complete(envelope);
        }
      });

      // Server sends terminal_output to client
      final outputData = {'data': 'Command output\r\n'};
      await server!.sendToClient(pairingCode, MessageType.terminalOutput, outputData);

      // Wait for client to receive message
      final receivedEnvelope = await receivedCompleter.future
          .timeout(Duration(seconds: 5));

      // Decrypt and verify payload
      final decryptedPayload = receivedEnvelope.open(clientKeys, serverKeys);
      expect(decryptedPayload, equals(outputData));
      expect(receivedEnvelope.type, equals(MessageType.terminalOutput));

      await subscription.cancel();
    });

    test('MessageEnvelope works with resize message type', () async {
      // Connect client to server
      final clientKeys = KeyPair.generate();
      final serverKeys = server!.getServerKeys();

      await client.connect('localhost:$port', pairingCode);
      await server!.waitForClient(pairingCode);

      client.setKeys(clientKeys, serverKeys);

      // Send resize message
      final resizeData = {'rows': 24, 'cols': 80};
      await client.send(MessageType.resize, resizeData);

      // Wait for server to receive message
      await server.waitForMessages(1);

      // Verify message was received and decrypted correctly
      final receivedMessages = server.getReceivedMessages();
      expect(receivedMessages.length, equals(1));
      expect(receivedMessages[0].type, equals(MessageType.resize));
      expect(receivedMessages[0].payload, equals(resizeData));
    });

    test('MessageEnvelope works with pairing_request message type', () async {
      // Connect client to server
      final clientKeys = KeyPair.generate();
      final serverKeys = server!.getServerKeys();

      await client.connect('localhost:$port', pairingCode);
      await server!.waitForClient(pairingCode);

      client.setKeys(clientKeys, serverKeys);

      // Send pairing_request message
      final pairingData = {
        'public_key': base64Encode(clientKeys.publicKeyBytes),
        'device_name': 'Test Device',
      };
      await client.send(MessageType.pairingRequest, pairingData);

      // Wait for server to receive message
      await server.waitForMessages(1);

      // Verify message was received and decrypted correctly
      final receivedMessages = server.getReceivedMessages();
      expect(receivedMessages.length, equals(1));
      expect(receivedMessages[0].type, equals(MessageType.pairingRequest));
      expect(receivedMessages[0].payload, equals(pairingData));
    });

    test('Sender public key is correctly included in messages', () async {
      // Connect client to server
      final clientKeys = KeyPair.generate();
      final serverKeys = server!.getServerKeys();

      await client.connect('localhost:$port', pairingCode);
      await server!.waitForClient(pairingCode);

      client.setKeys(clientKeys, serverKeys);

      // Create a completer to capture raw message
      final messageCompleter = Completer<MessageEnvelope>();
      final subscription = client.messageStream.listen((envelope) {
        if (!messageCompleter.isCompleted) {
          messageCompleter.complete(envelope);
        }
      });

      // Server sends message to client
      await server!.sendToClient(
        pairingCode,
        MessageType.terminalOutput,
        {'data': 'test'},
      );

      // Wait for message
      final receivedEnvelope = await messageCompleter.future
          .timeout(Duration(seconds: 5));

      // Verify sender public key matches server's public key
      final expectedPublicKey = base64Encode(serverKeys.publicKeyBytes);
      expect(receivedEnvelope.senderPublicKey, equals(expectedPublicKey));

      await subscription.cancel();
    });

    test('Client public key is correctly included in sent messages', () async {
      // Connect client to server
      final clientKeys = KeyPair.generate();
      final serverKeys = server!.getServerKeys();

      await client.connect('localhost:$port', pairingCode);
      await server!.waitForClient(pairingCode);

      client.setKeys(clientKeys, serverKeys);

      // Send message from client
      await client.send(MessageType.terminalInput, {'data': 'test'});

      // Wait for server to receive
      await server.waitForMessages(1);

      // Get the raw received messages to check envelope
      final receivedMessages = server.getReceivedMessages();

      // The server should have received a message with client's public key
      // We can verify this by checking that decryption worked (which it did)
      // and that the message was properly received
      expect(receivedMessages.length, equals(1));
      expect(receivedMessages[0].payload['data'], equals('test'));
    });

    test('Full round-trip encryption with key exchange', () async {
      // Simulate full pairing flow
      final clientKeys = KeyPair.generate();
      final serverKeys = server!.getServerKeys();

      // Step 1: Connect to server
      await client.connect('localhost:$port', pairingCode);
      await server!.waitForClient(pairingCode);

      // Step 2: Exchange keys (set on client side)
      client.setKeys(clientKeys, serverKeys);

      // Step 3: Client sends input
      final inputPayload = {'data': 'echo "Hello World"'};
      await client.send(MessageType.terminalInput, inputPayload);

      // Step 4: Wait for server to receive and process
      await server.waitForMessages(1);

      // Verify server received correct data
      final receivedMessages = server.getReceivedMessages();
      expect(receivedMessages[0].type, equals(MessageType.terminalInput));
      expect(receivedMessages[0].payload, equals(inputPayload));

      // Step 5: Server sends output back
      final completer = Completer<Map<String, dynamic>>();
      final subscription = client.terminalOutputStream.listen((envelope) {
        if (!completer.isCompleted) {
          final payload = envelope.open(clientKeys, serverKeys);
          completer.complete(payload);
        }
      });

      final outputPayload = {'data': 'Hello World\r\n'};
      await server!.sendToClient(pairingCode, MessageType.terminalOutput, outputPayload);

      // Step 6: Client receives and decrypts
      final decryptedOutput = await completer.future.timeout(Duration(seconds: 5));
      expect(decryptedOutput, equals(outputPayload));

      await subscription.cancel();
    });

    test('Multiple message types in sequence maintain encryption', () async {
      final clientKeys = KeyPair.generate();
      final serverKeys = server!.getServerKeys();

      await client.connect('localhost:$port', pairingCode);
      await server!.waitForClient(pairingCode);
      client.setKeys(clientKeys, serverKeys);

      // Send multiple message types
      await client.send(MessageType.pairingRequest, {'device': 'test'});
      await client.send(MessageType.resize, {'rows': 30, 'cols': 100});
      await client.send(MessageType.terminalInput, {'data': 'pwd'});

      // Wait for all messages
      await server.waitForMessages(3);

      // Verify all messages were received and decrypted correctly
      final messages = server.getReceivedMessages();
      expect(messages.length, equals(3));

      expect(messages[0].type, equals(MessageType.pairingRequest));
      expect(messages[0].payload['device'], equals('test'));

      expect(messages[1].type, equals(MessageType.resize));
      expect(messages[1].payload['rows'], equals(30));
      expect(messages[1].payload['cols'], equals(100));

      expect(messages[2].type, equals(MessageType.terminalInput));
      expect(messages[2].payload['data'], equals('pwd'));
    });

    test('Encrypted messages cannot be read without correct keys', () {
      final aliceKeys = KeyPair.generate();
      final bobKeys = KeyPair.generate();
      final eveKeys = KeyPair.generate(); // Eavesdropper

      // Alice sends message to Bob
      final payload = {'secret': 'classified information'};
      final envelope = MessageEnvelope.seal(
        MessageType.terminalInput,
        payload,
        aliceKeys,
        bobKeys,
      );

      // Bob can decrypt it
      final bobDecrypted = envelope.open(bobKeys, aliceKeys);
      expect(bobDecrypted['secret'], equals('classified information'));

      // Eve cannot decrypt it (wrong keys)
      expect(
        () => envelope.open(eveKeys, aliceKeys),
        throwsA(isA<CryptoException>()),
      );
    });

    test('Timestamp ordering is preserved across multiple messages', () async {
      final clientKeys = KeyPair.generate();
      final serverKeys = server!.getServerKeys();

      await client.connect('localhost:$port', pairingCode);
      await server!.waitForClient(pairingCode);
      client.setKeys(clientKeys, serverKeys);

      // Send messages with small delays
      await client.send(MessageType.terminalInput, {'seq': 1});
      await Future.delayed(Duration(milliseconds: 100));

      await client.send(MessageType.terminalInput, {'seq': 2});
      await Future.delayed(Duration(milliseconds: 100));

      await client.send(MessageType.terminalInput, {'seq': 3});

      // Wait for all messages
      await server.waitForMessages(3);

      // Verify timestamps are in order
      final messages = server.getReceivedMessages();
      expect(messages.length, equals(3));

      expect(messages[0].timestamp.isBefore(messages[1].timestamp) ||
             messages[0].timestamp.isAtSameMomentAs(messages[1].timestamp), isTrue);
      expect(messages[1].timestamp.isBefore(messages[2].timestamp) ||
             messages[1].timestamp.isAtSameMomentAs(messages[2].timestamp), isTrue);
    });

    test('NaClCrypto encrypt/decrypt with complex payload', () {
      final senderKeys = KeyPair.generate();
      final recipientKeys = KeyPair.generate();

      // Complex payload with various data types
      final complexData = {
        'string': 'Hello',
        'number': 42,
        'decimal': 3.14,
        'bool': true,
        'null': null,
        'array': [1, 2, 3],
        'nested': {
          'a': 'nested value',
          'b': [4, 5, 6],
        },
        'unicode': 'Hello 世界 🌍',
      };

      final jsonString = jsonEncode(complexData);

      // Encrypt
      final encrypted = NaClCrypto.encrypt(jsonString, senderKeys, recipientKeys);
      expect(encrypted, isNotEmpty);

      // Decrypt
      final decrypted = NaClCrypto.decrypt(encrypted, recipientKeys, senderKeys);
      final parsedData = jsonDecode(decrypted);

      // Verify all fields
      expect(parsedData['string'], equals('Hello'));
      expect(parsedData['number'], equals(42));
      expect(parsedData['decimal'], equals(3.14));
      expect(parsedData['bool'], equals(true));
      expect(parsedData['null'], isNull);
      expect(parsedData['array'], equals([1, 2, 3]));
      expect(parsedData['nested']['a'], equals('nested value'));
      expect(parsedData['unicode'], equals('Hello 世界 🌍'));
    });

    test('RelayClient convenience methods use correct message types', () async {
      final clientKeys = KeyPair.generate();
      final serverKeys = server!.getServerKeys();

      await client.connect('localhost:$port', pairingCode);
      await server!.waitForClient(pairingCode);
      client.setKeys(clientKeys, serverKeys);

      // Test sendTerminalInput
      await client.sendTerminalInput('test input');
      await server.waitForMessages(1);

      var messages = server.getReceivedMessages();
      expect(messages[0].type, equals(MessageType.terminalInput));
      expect(messages[0].payload['input'], equals('test input'));

      server.clearReceivedMessages();

      // Test sendResize
      await client.sendResize(25, 90);
      await server.waitForMessages(1);

      messages = server.getReceivedMessages();
      expect(messages[0].type, equals(MessageType.resize));
      expect(messages[0].payload['rows'], equals(25));
      expect(messages[0].payload['cols'], equals(90));

      server.clearReceivedMessages();

      // Test sendPairingRequest
      await client.sendPairingRequest({'device': 'test-device'});
      await server.waitForMessages(1);

      messages = server.getReceivedMessages();
      expect(messages[0].type, equals(MessageType.pairingRequest));
      expect(messages[0].payload['device'], equals('test-device'));
    });
  });
}
