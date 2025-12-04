import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/io.dart';

import '../lib/core/crypto/key_pair.dart';
import '../lib/core/crypto/message_envelope.dart';
import 'mock_relay_server.dart';

void main() {
  group('MockRelayServer', () {
    late MockRelayServer server;

    setUp(() async {
      server = MockRelayServer(
        config: MockRelayServerConfig.verbose(),
      );
      await server.start();
    });

    tearDown(() async {
      await server.stop();
    });

    test('server starts and provides port', () {
      expect(server.getPort(), isPositive);
    });

    test('server accepts valid pairing code', () async {
      final pairingCode = 'ABC123';
      final port = server.getPort();
      final url = 'ws://localhost:$port/ws/client/$pairingCode';

      // Connect as client
      final channel = IOWebSocketChannel.connect(url);
      await channel.ready;

      // Verify connection
      await server.waitForClient(pairingCode);
      expect(server.isClientConnected(pairingCode), isTrue);

      await channel.sink.close();
    });

    test('server rejects invalid pairing code (wrong length)', () async {
      final pairingCode = 'ABC'; // Too short
      final port = server.getPort();
      final url = 'ws://localhost:$port/ws/client/$pairingCode';

      // Attempt to connect as client
      try {
        final channel = IOWebSocketChannel.connect(url);
        await channel.ready.timeout(const Duration(seconds: 2));
        fail('Should have rejected invalid pairing code');
      } on WebSocketChannelException catch (_) {
        // Expected - connection should be rejected
      } on TimeoutException catch (_) {
        // Also acceptable - connection never established
      }
    });

    test('server echoes terminal_input as terminal_output', () async {
      final pairingCode = 'TEST01';
      final port = server.getPort();
      final url = 'ws://localhost:$port/ws/client/$pairingCode';

      // Create client keys
      final clientKeys = KeyPair.generate();
      final serverKeys = server.getServerKeys();

      // Connect as client
      final channel = IOWebSocketChannel.connect(url);
      await channel.ready;
      await server.waitForClient(pairingCode);

      // Create and send terminal_input message
      final inputEnvelope = MessageEnvelope.seal(
        MessageType.terminalInput,
        {'data': 'echo hello\n'},
        clientKeys,
        serverKeys,
      );

      channel.sink.add(jsonEncode(inputEnvelope.toJson()));

      // Wait for echo response
      final responseData = await channel.stream.first.timeout(
        const Duration(seconds: 2),
      );

      // Parse response
      final responseJson = jsonDecode(responseData as String) as Map<String, dynamic>;
      final responseEnvelope = MessageEnvelope.fromJson(responseJson);

      // Decrypt response
      final responsePayload = responseEnvelope.open(clientKeys, serverKeys);

      // Verify echo
      expect(responseEnvelope.type, equals(MessageType.terminalOutput));
      expect(responsePayload['data'], equals('echo hello\n'));

      await channel.sink.close();
    });

    test('server handles resize message', () async {
      final pairingCode = 'RESIZE';
      final port = server.getPort();
      final url = 'ws://localhost:$port/ws/client/$pairingCode';

      // Create client keys
      final clientKeys = KeyPair.generate();
      final serverKeys = server.getServerKeys();

      // Connect as client
      final channel = IOWebSocketChannel.connect(url);
      await channel.ready;
      await server.waitForClient(pairingCode);

      // Create and send resize message
      final resizeEnvelope = MessageEnvelope.seal(
        MessageType.resize,
        {'rows': 24, 'cols': 80},
        clientKeys,
        serverKeys,
      );

      channel.sink.add(jsonEncode(resizeEnvelope.toJson()));

      // Wait for server to process
      await server.waitForMessages(1);

      // Verify server received the message
      final messages = server.getReceivedMessages();
      expect(messages.length, equals(1));
      expect(messages[0].type, equals(MessageType.resize));
      expect(messages[0].payload['rows'], equals(24));
      expect(messages[0].payload['cols'], equals(80));

      await channel.sink.close();
    });

    test('server handles force disconnect', () async {
      final pairingCode = 'DISCO1';
      final port = server.getPort();
      final url = 'ws://localhost:$port/ws/client/$pairingCode';

      // Connect as client
      final channel = IOWebSocketChannel.connect(url);
      await channel.ready;
      await server.waitForClient(pairingCode);

      expect(server.isClientConnected(pairingCode), isTrue);

      // Force disconnect
      await server.forceDisconnect(pairingCode);

      // Wait a bit for disconnect to propagate
      await Future.delayed(const Duration(milliseconds: 100));

      expect(server.isClientConnected(pairingCode), isFalse);

      await channel.sink.close();
    });

    test('server tracks received messages', () async {
      final pairingCode = 'TRACK1';
      final port = server.getPort();
      final url = 'ws://localhost:$port/ws/client/$pairingCode';

      // Create client keys
      final clientKeys = KeyPair.generate();
      final serverKeys = server.getServerKeys();

      // Connect as client
      final channel = IOWebSocketChannel.connect(url);
      await channel.ready;
      await server.waitForClient(pairingCode);

      // Send multiple messages
      for (int i = 0; i < 3; i++) {
        final envelope = MessageEnvelope.seal(
          MessageType.terminalInput,
          {'data': 'message $i\n'},
          clientKeys,
          serverKeys,
        );
        channel.sink.add(jsonEncode(envelope.toJson()));
      }

      // Wait for all messages
      await server.waitForMessages(3);

      // Verify all messages were received
      final messages = server.getReceivedMessages();
      expect(messages.length, equals(3));
      for (int i = 0; i < 3; i++) {
        expect(messages[i].pairingCode, equals(pairingCode));
        expect(messages[i].type, equals(MessageType.terminalInput));
        expect(messages[i].payload['data'], equals('message $i\n'));
      }

      await channel.sink.close();
    });
  });

  group('MockRelayServerConfig', () {
    test('verbose config enables logging', () {
      final config = MockRelayServerConfig.verbose();
      expect(config.verbose, isTrue);
      expect(config.echoTerminalInput, isTrue);
    });

    test('withRejectedCodes config rejects specific codes', () {
      final config = MockRelayServerConfig.withRejectedCodes({'BAD001', 'BAD002'});
      expect(config.rejectedPairingCodes, contains('BAD001'));
      expect(config.rejectedPairingCodes, contains('BAD002'));
    });

    test('noEcho config disables echo', () {
      final config = MockRelayServerConfig.noEcho();
      expect(config.echoTerminalInput, isFalse);
    });
  });

  group('MockRelayServer with rejected codes', () {
    late MockRelayServer server;

    setUp(() async {
      server = MockRelayServer(
        config: MockRelayServerConfig.withRejectedCodes({'REJECT'}),
      );
      await server.start();
    });

    tearDown(() async {
      await server.stop();
    });

    test('rejects configured pairing codes', () async {
      final pairingCode = 'REJECT';
      final port = server.getPort();
      final url = 'ws://localhost:$port/ws/client/$pairingCode';

      // Attempt to connect with rejected code
      try {
        final channel = IOWebSocketChannel.connect(url);
        await channel.ready.timeout(const Duration(seconds: 2));
        fail('Should have rejected pairing code');
      } on WebSocketChannelException catch (_) {
        // Expected - connection should be rejected
      } on TimeoutException catch (_) {
        // Also acceptable - connection never established
      }
    });
  });

  group('MockRelayServer test helpers', () {
    late MockRelayServer server;

    tearDown(() async {
      await server.stop();
    });

    test('startEchoServer creates echo server', () async {
      server = await MockRelayServerTestHelpers.startEchoServer();
      expect(server.getPort(), isPositive);
    });

    test('startWithRejectedCodes creates server with rejected codes', () async {
      server = await MockRelayServerTestHelpers.startWithRejectedCodes({'TEST'});
      expect(server.getPort(), isPositive);
    });

    test('startSilentServer creates non-echo server', () async {
      server = await MockRelayServerTestHelpers.startSilentServer();
      expect(server.getPort(), isPositive);
    });
  });
}
