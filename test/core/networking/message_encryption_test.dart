import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:myagents_frontend/core/crypto/key_pair.dart';
import 'package:myagents_frontend/core/crypto/message_envelope.dart';
import 'package:myagents_frontend/core/crypto/nacl_crypto.dart';
import 'package:myagents_frontend/core/networking/relay_client.dart';
import '../../mock_relay_server.dart';

/// Test Agent 2 - Message Encryption/Decryption Tests
///
/// This test suite validates:
/// 1. KeyPair generation for client and server
/// 2. RelayClient connection with client KeyPair
/// 3. Sending terminal_input messages from client
/// 4. Verifying messages are encrypted (Base64 payload, not plaintext)
/// 5. Server decrypting messages and echoing back
/// 6. Client receiving terminal_output and decrypting correctly
/// 7. Verifying decrypted payload matches original
void main() {
  group('Message Encryption/Decryption Tests', () {
    late MockRelayServer server;
    late RelayClient client;
    late KeyPair clientKeys;
    late KeyPair serverKeys;
    late int serverPort;

    setUp(() async {
      // Create server and client instances
      server = MockRelayServer(
        config: MockRelayServerConfig.verbose(),
      );
      client = RelayClient();

      // Generate KeyPairs for client and server
      clientKeys = KeyPair.generate();

      // Start server (server generates its own keys)
      serverPort = await server!.start();
      serverKeys = server!.getServerKeys();

      // Wait for server to be ready
      await Future.delayed(const Duration(milliseconds: 100));
    });

    tearDown(() async {
      // Clean up resources
      await client.dispose();
      await server!.stop();
    });

    test('Generate KeyPairs for client and server', () {
      // Verify client keys are valid
      expect(clientKeys.publicKeyBytes.length, equals(32),
          reason: 'Client public key should be 32 bytes');
      expect(clientKeys.privateKeyBytes.length, equals(32),
          reason: 'Client private key should be 32 bytes');

      // Verify server keys are valid
      expect(serverKeys.publicKeyBytes.length, equals(32),
          reason: 'Server public key should be 32 bytes');
      expect(serverKeys.privateKeyBytes.length, equals(32),
          reason: 'Server private key should be 32 bytes');

      // Verify keys are different
      expect(clientKeys.publicKeyBytes, isNot(equals(serverKeys.publicKeyBytes)),
          reason: 'Client and server should have different public keys');
    });

    test('Connect RelayClient with client KeyPair', () async {
      const pairingCode = 'TEST01';

      // Connect client to server
      await client.connect('localhost:$serverPort', pairingCode);

      // Set encryption keys
      client.setKeys(clientKeys, serverKeys);

      // Wait for connection to establish
      await Future.delayed(const Duration(milliseconds: 500));

      // Verify client is connected
      expect(client.isConnected, isTrue,
          reason: 'Client should be connected to server');

      // Verify keys are set
      expect(client.hasKeys, isTrue,
          reason: 'Client should have encryption keys set');

      // Verify server has client connected
      expect(server!.isClientConnected(pairingCode), isTrue,
          reason: 'Server should have client connected');
    });

    test('Send terminal_input message and verify encryption', () async {
      const pairingCode = 'TEST02';
      const inputData = 'ls -la';

      // Connect and setup keys
      await client.connect('localhost:$serverPort', pairingCode);
      client.setKeys(clientKeys, serverKeys);
      await Future.delayed(const Duration(milliseconds: 500));

      // Clear server messages
      server.clearReceivedMessages();

      // Send terminal_input message using 'data' field (not 'input')
      await client.send(MessageType.terminalInput, {'data': inputData});

      // Wait for message to be received
      await server.waitForMessages(1);

      // Get received messages
      final messages = server.getReceivedMessages();
      expect(messages.length, equals(1),
          reason: 'Server should have received 1 message');

      final receivedMessage = messages.first;

      // Verify message type
      expect(receivedMessage.type, equals(MessageType.terminalInput),
          reason: 'Message type should be terminal_input');

      // Verify decrypted payload
      expect(receivedMessage.payload['data'], equals(inputData),
          reason: 'Decrypted payload should match original input');
    });

    test('Verify message payload is encrypted (Base64, not plaintext)', () async {
      const pairingCode = 'TEST03';
      const inputData = 'echo "Hello World"';

      // Setup connection
      await client.connect('localhost:$serverPort', pairingCode);
      client.setKeys(clientKeys, serverKeys);
      await Future.delayed(const Duration(milliseconds: 500));

      // Create a completer to capture raw WebSocket message
      final rawMessageCompleter = Completer<String>();

      // Listen to client's message stream to capture raw envelope
      final messageSubscription = client.messageStream.listen((_) {});

      // Send message and capture it
      final envelope = MessageEnvelope.seal(
        MessageType.terminalInput,
        {'data': inputData},
        clientKeys,
        serverKeys,
      );

      // Verify payload is encrypted (Base64)
      expect(envelope.payload, isNotEmpty,
          reason: 'Payload should not be empty');

      // Verify payload is Base64 encoded
      expect(() => base64Decode(envelope.payload), returnsNormally,
          reason: 'Payload should be valid Base64');

      // Verify payload does NOT contain plaintext
      expect(envelope.payload.contains(inputData), isFalse,
          reason: 'Encrypted payload should not contain plaintext');
      expect(envelope.payload.contains('echo'), isFalse,
          reason: 'Encrypted payload should not contain plaintext keywords');
      expect(envelope.payload.contains('Hello'), isFalse,
          reason: 'Encrypted payload should not contain plaintext content');

      // Verify payload is sufficiently long (encryption adds overhead)
      final decodedPayload = base64Decode(envelope.payload);
      expect(decodedPayload.length, greaterThan(40),
          reason: 'Encrypted payload should be at least nonce(24) + MAC(16) bytes');

      await messageSubscription.cancel();
    });

    test('Server decrypts message and echoes back terminal_output', () async {
      const pairingCode = 'TEST04';
      const inputData = 'pwd';

      // Setup connection
      await client.connect('localhost:$serverPort', pairingCode);
      client.setKeys(clientKeys, serverKeys);
      await Future.delayed(const Duration(milliseconds: 500));

      // Setup listener for terminal_output
      final outputCompleter = Completer<MessageEnvelope>();
      final outputSubscription = client.terminalOutputStream.listen((msg) {
        if (!outputCompleter.isCompleted) {
          outputCompleter.complete(msg);
        }
      });

      // Send terminal_input
      await client.send(MessageType.terminalInput, {'data': inputData});

      // Wait for echo response (with timeout)
      final outputEnvelope = await outputCompleter.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('No terminal_output received'),
      );

      // Verify message type
      expect(outputEnvelope.type, equals(MessageType.terminalOutput),
          reason: 'Response should be terminal_output type');

      // Decrypt and verify payload
      final decryptedPayload = outputEnvelope.open(clientKeys, serverKeys);
      expect(decryptedPayload, isNotNull,
          reason: 'Decrypted payload should not be null');
      expect(decryptedPayload['data'], isNotNull,
          reason: 'Decrypted payload should contain data field');

      // Verify echo (mock server echoes input)
      expect(decryptedPayload['data'], equals(inputData),
          reason: 'Echoed data should match original input');

      await outputSubscription.cancel();
    });

    test('Client receives and decrypts terminal_output correctly', () async {
      const pairingCode = 'TEST05';
      const inputData = 'whoami';

      // Setup connection
      await client.connect('localhost:$serverPort', pairingCode);
      client.setKeys(clientKeys, serverKeys);
      await Future.delayed(const Duration(milliseconds: 500));

      // Track received messages
      final receivedMessages = <Map<String, dynamic>>[];
      final messageSubscription = client.terminalOutputStream.listen((envelope) {
        try {
          final decrypted = envelope.open(clientKeys, serverKeys);
          receivedMessages.add(decrypted);
        } catch (e) {
          fail('Failed to decrypt message: $e');
        }
      });

      // Send terminal_input
      await client.send(MessageType.terminalInput, {'data': inputData});

      // Wait for message to be received and decrypted
      await Future.delayed(const Duration(seconds: 2));

      // Verify message was received and decrypted
      expect(receivedMessages.length, greaterThanOrEqualTo(1),
          reason: 'Should have received at least 1 decrypted message');

      final firstMessage = receivedMessages.first;
      expect(firstMessage['data'], equals(inputData),
          reason: 'Decrypted data should match original input');

      await messageSubscription.cancel();
    });

    test('Verify decrypted payload matches original across multiple messages', () async {
      const pairingCode = 'TEST06';
      final testMessages = [
        'echo "test1"',
        'ls -la /home',
        'cat /etc/hosts',
        'grep pattern file.txt',
      ];

      // Setup connection
      await client.connect('localhost:$serverPort', pairingCode);
      client.setKeys(clientKeys, serverKeys);
      await Future.delayed(const Duration(milliseconds: 500));

      // Track received messages
      final receivedMessages = <String>[];
      final messageSubscription = client.terminalOutputStream.listen((envelope) {
        final decrypted = envelope.open(clientKeys, serverKeys);
        receivedMessages.add(decrypted['data'] as String);
      });

      // Send multiple messages
      for (final msg in testMessages) {
        await client.sendTerminalInput(msg);
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // Wait for all messages to be echoed back
      await Future.delayed(const Duration(seconds: 2));

      // Verify all messages were received and match
      expect(receivedMessages.length, equals(testMessages.length),
          reason: 'Should receive echo for all sent messages');

      for (int i = 0; i < testMessages.length; i++) {
        expect(receivedMessages[i], equals(testMessages[i]),
            reason: 'Message $i should match original');
      }

      await messageSubscription.cancel();
    });

    test('End-to-end encryption: Verify sender public key in received messages', () async {
      const pairingCode = 'TEST07';
      const inputData = 'test message';

      // Setup connection
      await client.connect('localhost:$serverPort', pairingCode);
      client.setKeys(clientKeys, serverKeys);
      await Future.delayed(const Duration(milliseconds: 500));

      // Listen for messages and verify sender public key
      final messageCompleter = Completer<MessageEnvelope>();
      final messageSubscription = client.terminalOutputStream.listen((envelope) {
        if (!messageCompleter.isCompleted) {
          messageCompleter.complete(envelope);
        }
      });

      // Send message
      await client.send(MessageType.terminalInput, {'data': inputData});

      // Wait for response
      final responseEnvelope = await messageCompleter.future.timeout(
        const Duration(seconds: 5),
      );

      // Verify sender public key is server's public key
      final senderPublicKeyBase64 = responseEnvelope.senderPublicKey;
      final senderPublicKeyBytes = base64Decode(senderPublicKeyBase64);

      expect(senderPublicKeyBytes, equals(serverKeys.publicKeyBytes),
          reason: 'Sender public key should be server\'s public key');

      // Verify we can decrypt with server's public key
      final decrypted = responseEnvelope.open(clientKeys, serverKeys);
      expect(decrypted, isNotNull,
          reason: 'Should be able to decrypt with server keys');

      await messageSubscription.cancel();
    });

    test('Encryption prevents message tampering (MAC verification)', () async {
      const pairingCode = 'TEST08';
      const inputData = 'secure message';

      // Setup connection
      await client.connect('localhost:$serverPort', pairingCode);
      client.setKeys(clientKeys, serverKeys);
      await Future.delayed(const Duration(milliseconds: 500));

      // Create encrypted envelope
      final envelope = MessageEnvelope.seal(
        MessageType.terminalInput,
        {'data': inputData},
        clientKeys,
        serverKeys,
      );

      // Tamper with encrypted payload (flip a bit)
      final originalPayload = envelope.payload;
      final tamperedBytes = base64Decode(originalPayload);
      if (tamperedBytes.isNotEmpty) {
        tamperedBytes[tamperedBytes.length - 1] ^= 0x01; // Flip last bit
      }
      final tamperedPayload = base64Encode(tamperedBytes);

      // Create tampered envelope
      final tamperedEnvelope = MessageEnvelope(
        type: envelope.type,
        payload: tamperedPayload,
        senderPublicKey: envelope.senderPublicKey,
        timestamp: envelope.timestamp,
      );

      // Attempt to decrypt tampered message (should fail)
      expect(
        () => tamperedEnvelope.open(serverKeys, clientKeys),
        throwsA(isA<CryptoException>()),
        reason: 'Decrypting tampered message should throw CryptoException',
      );
    });

    test('Multiple message types are encrypted correctly', () async {
      const pairingCode = 'TEST09';

      // Setup connection
      await client.connect('localhost:$serverPort', pairingCode);
      client.setKeys(clientKeys, serverKeys);
      await Future.delayed(const Duration(milliseconds: 500));

      // Clear server messages
      server.clearReceivedMessages();

      // Send terminal_input
      await client.send(MessageType.terminalInput, {'data': 'test input'});
      await Future.delayed(const Duration(milliseconds: 300));

      // Send resize
      await client.send(MessageType.resize, {'rows': 24, 'cols': 80});
      await Future.delayed(const Duration(milliseconds: 300));

      // Get received messages
      final messages = server.getReceivedMessages();
      expect(messages.length, equals(2),
          reason: 'Server should have received 2 messages');

      // Verify terminal_input message
      final inputMsg = messages.firstWhere((m) => m.type == MessageType.terminalInput);
      expect(inputMsg.payload['data'], equals('test input'),
          reason: 'Terminal input payload should be decrypted correctly');

      // Verify resize message
      final resizeMsg = messages.firstWhere((m) => m.type == MessageType.resize);
      expect(resizeMsg.payload['rows'], equals(24),
          reason: 'Resize rows should be decrypted correctly');
      expect(resizeMsg.payload['cols'], equals(80),
          reason: 'Resize cols should be decrypted correctly');
    });

    test('Large payloads are encrypted and decrypted correctly', () async {
      const pairingCode = 'TEST10';

      // Create a large payload (10KB)
      final largeInput = 'A' * 10240;

      // Setup connection
      await client.connect('localhost:$serverPort', pairingCode);
      client.setKeys(clientKeys, serverKeys);
      await Future.delayed(const Duration(milliseconds: 500));

      // Clear server messages
      server.clearReceivedMessages();

      // Send large message
      await client.sendTerminalInput(largeInput);

      // Wait for message to be received
      await server.waitForMessages(1);

      // Verify message was received and decrypted correctly
      final messages = server.getReceivedMessages();
      expect(messages.length, equals(1),
          reason: 'Server should have received 1 message');

      final receivedMessage = messages.first;
      expect(receivedMessage.payload['data'], equals(largeInput),
          reason: 'Large payload should be decrypted correctly');
      expect(receivedMessage.payload['data'].length, equals(10240),
          reason: 'Payload size should match original');
    });

    test('Special characters in payload are encrypted and decrypted correctly', () async {
      const pairingCode = 'TEST11';
      const specialInput = r'Test: !@#$%^&*()_+{}|:"<>?[];,./~`\n\t\r\x00';

      // Setup connection
      await client.connect('localhost:$serverPort', pairingCode);
      client.setKeys(clientKeys, serverKeys);
      await Future.delayed(const Duration(milliseconds: 500));

      // Clear server messages
      server.clearReceivedMessages();

      // Send message with special characters
      await client.send(MessageType.terminalInput, {'data': specialInput});

      // Wait for message
      await server.waitForMessages(1);

      // Verify special characters preserved
      final messages = server.getReceivedMessages();
      expect(messages.first.payload['data'], equals(specialInput),
          reason: 'Special characters should be preserved through encryption');
    });

    test('Unicode characters in payload are encrypted and decrypted correctly', () async {
      const pairingCode = 'TEST12';
      const unicodeInput = 'Hello 世界 🌍 Привет مرحبا';

      // Setup connection
      await client.connect('localhost:$serverPort', pairingCode);
      client.setKeys(clientKeys, serverKeys);
      await Future.delayed(const Duration(milliseconds: 500));

      // Clear server messages
      server.clearReceivedMessages();

      // Send message with unicode
      await client.send(MessageType.terminalInput, {'data': unicodeInput});

      // Wait for message
      await server.waitForMessages(1);

      // Verify unicode preserved
      final messages = server.getReceivedMessages();
      expect(messages.first.payload['data'], equals(unicodeInput),
          reason: 'Unicode characters should be preserved through encryption');
    });

    test('Empty payload is encrypted and decrypted correctly', () async {
      const pairingCode = 'TEST13';
      const emptyInput = '';

      // Setup connection
      await client.connect('localhost:$serverPort', pairingCode);
      client.setKeys(clientKeys, serverKeys);
      await Future.delayed(const Duration(milliseconds: 500));

      // Clear server messages
      server.clearReceivedMessages();

      // Send empty message
      await client.send(MessageType.terminalInput, {'data': emptyInput});

      // Wait for message
      await server.waitForMessages(1);

      // Verify empty payload handled correctly
      final messages = server.getReceivedMessages();
      expect(messages.first.payload['data'], equals(emptyInput),
          reason: 'Empty payload should be handled correctly');
    });

    test('Encryption uses proper NaCl crypto layer', () async {
      const testData = 'test message for crypto verification';

      // Test direct encryption/decryption with NaClCrypto
      final encrypted = NaClCrypto.encrypt(testData, clientKeys, serverKeys);

      // Verify encrypted format
      expect(encrypted, isNotEmpty,
          reason: 'Encrypted data should not be empty');
      expect(() => base64Decode(encrypted), returnsNormally,
          reason: 'Encrypted data should be valid Base64');
      expect(encrypted, isNot(contains(testData)),
          reason: 'Encrypted data should not contain plaintext');

      // Test decryption
      final decrypted = NaClCrypto.decrypt(encrypted, serverKeys, clientKeys);
      expect(decrypted, equals(testData),
          reason: 'Decrypted data should match original');

      // Verify encryption is bidirectional
      final encrypted2 = NaClCrypto.encrypt(testData, serverKeys, clientKeys);
      final decrypted2 = NaClCrypto.decrypt(encrypted2, clientKeys, serverKeys);
      expect(decrypted2, equals(testData),
          reason: 'Reverse encryption should also work');
    });

    test('Different nonces produce different ciphertexts', () async {
      const testData = 'same message';

      // Encrypt same message twice
      final encrypted1 = NaClCrypto.encrypt(testData, clientKeys, serverKeys);
      final encrypted2 = NaClCrypto.encrypt(testData, clientKeys, serverKeys);

      // Verify ciphertexts are different (due to random nonce)
      expect(encrypted1, isNot(equals(encrypted2)),
          reason: 'Same plaintext should produce different ciphertexts due to random nonce');

      // Verify both decrypt to same plaintext
      final decrypted1 = NaClCrypto.decrypt(encrypted1, serverKeys, clientKeys);
      final decrypted2 = NaClCrypto.decrypt(encrypted2, serverKeys, clientKeys);
      expect(decrypted1, equals(testData),
          reason: 'First encryption should decrypt correctly');
      expect(decrypted2, equals(testData),
          reason: 'Second encryption should decrypt correctly');
    });
  });
}
