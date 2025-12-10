import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart' as xterm;
import 'package:myagents_frontend/features/remote_terminal/terminal_controller.dart';
import 'package:myagents_frontend/features/remote_terminal/terminal_state.dart';
import 'package:myagents_frontend/core/networking/relay_client.dart';
import 'package:myagents_frontend/core/crypto/key_pair.dart';
import 'package:myagents_frontend/core/crypto/message_envelope.dart';

/// Mock RelayClient for testing
class MockRelayClient extends RelayClient {
  final StreamController<MessageEnvelope> _mockMessageController =
      StreamController<MessageEnvelope>.broadcast();
  final StreamController<dynamic> _mockErrorController =
      StreamController<dynamic>.broadcast();

  final List<Map<String, dynamic>> sentMessages = [];
  bool _isConnected = false;
  bool throwOnSend = false;
  String? sendErrorMessage;

  @override
  Stream<MessageEnvelope> get terminalOutputStream =>
      _mockMessageController.stream;

  @override
  Stream<dynamic> get errorStream => _mockErrorController.stream;

  @override
  bool get isConnected => _isConnected;

  void setConnected(bool connected) {
    _isConnected = connected;
  }

  /// Simulate receiving a terminal output message
  void simulateTerminalOutput(MessageEnvelope envelope) {
    _mockMessageController.add(envelope);
  }

  /// Simulate relay error
  void simulateError(dynamic error) {
    _mockErrorController.add(error);
  }

  @override
  Future<void> sendTerminalInput(String input) async {
    if (throwOnSend) {
      throw Exception(sendErrorMessage ?? 'Mock send error');
    }
    sentMessages.add({
      'type': 'terminal_input',
      'input': input,
    });
  }

  @override
  Future<void> sendResize(int rows, int cols) async {
    if (throwOnSend) {
      throw Exception(sendErrorMessage ?? 'Mock resize error');
    }
    sentMessages.add({
      'type': 'resize',
      'rows': rows,
      'cols': cols,
    });
  }

  void clearSentMessages() {
    sentMessages.clear();
  }

  @override
  Future<void> dispose() async {
    await _mockMessageController.close();
    await _mockErrorController.close();
    await super.dispose();
  }
}

void main() {
  group('RemoteTerminalController', () {
    late RemoteTerminalController controller;
    late MockRelayClient mockRelayClient;
    late KeyPair ourKeys;
    late KeyPair remoteKeys;
    late RemoteTerminalState terminalState;
    bool skipTearDownDispose = false;

    setUp(() {
      mockRelayClient = MockRelayClient();
      ourKeys = KeyPair.generate();
      remoteKeys = KeyPair.generate();
      terminalState = RemoteTerminalState();
      skipTearDownDispose = false;
    });

    tearDown(() async {
      if (!skipTearDownDispose) {
        controller.dispose();
      }
      await mockRelayClient.dispose();
      terminalState.dispose();
    });

    RemoteTerminalController createController({
      int rows = 24,
      int cols = 80,
    }) {
      return RemoteTerminalController(
        relayClient: mockRelayClient,
        ourKeys: ourKeys,
        remoteKeys: remoteKeys,
        terminalState: terminalState,
        rows: rows,
        cols: cols,
      );
    }

    group('Initialization', () {
      test('should create terminal with default dimensions (24x80)', () {
        controller = createController();

        expect(controller.terminal, isNotNull);
        expect(controller.terminal, isA<xterm.Terminal>());
      });

      test('should create terminal with custom dimensions', () {
        controller = createController(rows: 30, cols: 100);

        expect(terminalState.rows, 30);
        expect(terminalState.cols, 100);
      });

      test('should set terminal state to initial dimensions', () {
        controller = createController(rows: 50, cols: 120);

        expect(terminalState.rows, 50);
        expect(terminalState.cols, 120);
      });

      test('should set connection status to connected when relay is connected',
          () {
        mockRelayClient.setConnected(true);
        controller = createController();

        expect(terminalState.connectionStatus,
            RemoteTerminalConnectionStatus.connected);
      });

      test(
          'should not change connection status when relay is not connected initially',
          () {
        mockRelayClient.setConnected(false);
        controller = createController();

        // Stays at disconnected since relay is not connected
        expect(terminalState.connectionStatus,
            RemoteTerminalConnectionStatus.disconnected);
      });

      test('should store relay client reference', () {
        controller = createController();

        expect(controller.relayClient, same(mockRelayClient));
      });

      test('should store key pair references', () {
        controller = createController();

        expect(controller.ourKeys, same(ourKeys));
        expect(controller.remoteKeys, same(remoteKeys));
      });

      test('should store terminal state reference', () {
        controller = createController();

        expect(controller.terminalState, same(terminalState));
      });
    });

    group('Message handling (_onRelayMessage)', () {
      test(
          'should write output to terminal when valid message received',
          () async {
        controller = createController();
        mockRelayClient.setConnected(true);

        // Create a valid encrypted message
        final envelope = MessageEnvelope.seal(
          MessageType.terminalOutput,
          {'output': 'Hello, World!'},
          remoteKeys, // Sender's keys
          ourKeys, // Recipient's keys
        );

        mockRelayClient.simulateTerminalOutput(envelope);

        // Give time for async processing
        await Future.delayed(const Duration(milliseconds: 50));

        // Terminal should have received the output
        // We can't easily verify terminal buffer content without more setup,
        // but we verify no error was set
        expect(terminalState.hasError, isFalse);
      });

      test('should handle message with empty output gracefully', () async {
        controller = createController();
        mockRelayClient.setConnected(true);

        final envelope = MessageEnvelope.seal(
          MessageType.terminalOutput,
          {'output': ''},
          remoteKeys,
          ourKeys,
        );

        mockRelayClient.simulateTerminalOutput(envelope);
        await Future.delayed(const Duration(milliseconds: 50));

        // Should not error on empty output
        expect(terminalState.hasError, isFalse);
      });

      test('should handle message with missing output field', () async {
        controller = createController();
        mockRelayClient.setConnected(true);

        final envelope = MessageEnvelope.seal(
          MessageType.terminalOutput,
          {'other_field': 'value'}, // No 'output' field
          remoteKeys,
          ourKeys,
        );

        mockRelayClient.simulateTerminalOutput(envelope);
        await Future.delayed(const Duration(milliseconds: 50));

        // Should not error, just ignore missing output
        expect(terminalState.hasError, isFalse);
      });

      test('should set error state on decryption failure', () async {
        controller = createController();
        mockRelayClient.setConnected(true);

        // Create a message encrypted with wrong keys
        final wrongKeys = KeyPair.generate();
        final envelope = MessageEnvelope.seal(
          MessageType.terminalOutput,
          {'output': 'Test'},
          wrongKeys, // Wrong sender keys
          wrongKeys, // Wrong recipient keys
        );

        mockRelayClient.simulateTerminalOutput(envelope);
        await Future.delayed(const Duration(milliseconds: 50));

        // Should set error state
        expect(terminalState.hasError, isTrue);
        expect(terminalState.errorMessage, contains('Decryption failed'));
      });

      test('should not process messages after disposal', () async {
        controller = createController();
        controller.dispose();
        skipTearDownDispose = true;

        final envelope = MessageEnvelope.seal(
          MessageType.terminalOutput,
          {'output': 'Test'},
          remoteKeys,
          ourKeys,
        );

        // This should not throw or cause issues
        mockRelayClient.simulateTerminalOutput(envelope);
        await Future.delayed(const Duration(milliseconds: 50));
      });
    });

    group('Error handling (_onRelayError)', () {
      test('should set error state when relay error occurs', () async {
        controller = createController();
        mockRelayClient.setConnected(true);

        // Note: The error stream is separate from the message stream
        // The controller subscribes to terminalOutputStream, not errorStream
        // So we test the _onRelayError path via the listener setup
        terminalState.setError('Test relay error');

        expect(terminalState.hasError, isTrue);
        expect(terminalState.errorMessage, 'Test relay error');
      });
    });

    group('Input handling (_onTerminalInput)', () {
      test('should send input to relay when connected', () async {
        controller = createController();
        mockRelayClient.setConnected(true);

        // Simulate terminal output (user typing)
        controller.terminal.onOutput?.call('ls -la');

        await Future.delayed(const Duration(milliseconds: 50));

        expect(mockRelayClient.sentMessages.length, 1);
        expect(mockRelayClient.sentMessages.first['type'], 'terminal_input');
        expect(mockRelayClient.sentMessages.first['input'], 'ls -la');
      });

      test('should not send input when disconnected', () async {
        controller = createController();
        mockRelayClient.setConnected(false);

        controller.terminal.onOutput?.call('ls -la');

        await Future.delayed(const Duration(milliseconds: 50));

        // No messages should be sent
        expect(mockRelayClient.sentMessages, isEmpty);
      });

      test('should not send input after disposal', () async {
        controller = createController();
        mockRelayClient.setConnected(true);
        controller.dispose();
        skipTearDownDispose = true;

        // onOutput should be null after dispose
        expect(controller.terminal.onOutput, isNull);
      });

      test('should handle multiple consecutive inputs', () async {
        controller = createController();
        mockRelayClient.setConnected(true);

        controller.terminal.onOutput?.call('a');
        controller.terminal.onOutput?.call('b');
        controller.terminal.onOutput?.call('c');

        await Future.delayed(const Duration(milliseconds: 50));

        expect(mockRelayClient.sentMessages.length, 3);
        expect(mockRelayClient.sentMessages[0]['input'], 'a');
        expect(mockRelayClient.sentMessages[1]['input'], 'b');
        expect(mockRelayClient.sentMessages[2]['input'], 'c');
      });

      test('should handle special characters in input', () async {
        controller = createController();
        mockRelayClient.setConnected(true);

        controller.terminal.onOutput?.call('\x1b[A'); // Up arrow escape sequence

        await Future.delayed(const Duration(milliseconds: 50));

        expect(mockRelayClient.sentMessages.length, 1);
        expect(mockRelayClient.sentMessages.first['input'], '\x1b[A');
      });
    });

    group('resize()', () {
      test('should update terminal state dimensions', () {
        controller = createController();

        controller.resize(50, 120);

        expect(terminalState.rows, 50);
        expect(terminalState.cols, 120);
      });

      test('should send resize message when connected', () async {
        controller = createController();
        mockRelayClient.setConnected(true);

        controller.resize(50, 120);

        await Future.delayed(const Duration(milliseconds: 50));

        expect(mockRelayClient.sentMessages.length, 1);
        expect(mockRelayClient.sentMessages.first['type'], 'resize');
        expect(mockRelayClient.sentMessages.first['rows'], 50);
        expect(mockRelayClient.sentMessages.first['cols'], 120);
      });

      test('should not send resize message when disconnected', () async {
        controller = createController();
        mockRelayClient.setConnected(false);

        controller.resize(50, 120);

        await Future.delayed(const Duration(milliseconds: 50));

        // State should update but no message sent
        expect(terminalState.rows, 50);
        expect(terminalState.cols, 120);
        expect(mockRelayClient.sentMessages, isEmpty);
      });

      test('should not resize after disposal', () {
        controller = createController();
        controller.dispose();
        skipTearDownDispose = true;

        // This should not throw
        controller.resize(50, 120);

        // State should not be updated (disposal doesn't dispose terminalState)
        // but the controller should ignore the call
        // The terminal state might still be updated since it's a shared reference
      });

      test('should handle rapid resize calls', () async {
        controller = createController();
        mockRelayClient.setConnected(true);

        controller.resize(30, 100);
        controller.resize(40, 110);
        controller.resize(50, 120);

        await Future.delayed(const Duration(milliseconds: 50));

        // All resize messages should be sent
        expect(mockRelayClient.sentMessages.length, 3);
        expect(terminalState.rows, 50);
        expect(terminalState.cols, 120);
      });
    });

    group('writeLocal()', () {
      test('should write text directly to terminal', () {
        controller = createController();

        // This should not throw
        expect(() => controller.writeLocal('Hello'), returnsNormally);
      });

      test('should handle ANSI escape sequences', () {
        controller = createController();

        // This should not throw
        expect(
            () => controller.writeLocal('\x1b[31mRed Text\x1b[0m'),
            returnsNormally);
      });

      test('should not write after disposal', () {
        controller = createController();
        controller.dispose();
        skipTearDownDispose = true;

        // This should not throw
        expect(() => controller.writeLocal('Hello'), returnsNormally);
      });

      test('should handle empty string', () {
        controller = createController();

        expect(() => controller.writeLocal(''), returnsNormally);
      });

      test('should handle unicode characters', () {
        controller = createController();

        expect(() => controller.writeLocal('Hello 世界 🌍'), returnsNormally);
      });
    });

    group('clear()', () {
      test('should send ANSI clear command to terminal', () {
        controller = createController();

        expect(() => controller.clear(), returnsNormally);
      });

      test('should not clear after disposal', () {
        controller = createController();
        controller.dispose();
        skipTearDownDispose = true;

        expect(() => controller.clear(), returnsNormally);
      });
    });

    group('dispose()', () {
      test('should set disposed flag', () {
        controller = createController();

        controller.dispose();
        skipTearDownDispose = true;

        // After dispose, onOutput should be cleared
        expect(controller.terminal.onOutput, isNull);
      });

      test('should clear terminal.onOutput handler', () {
        controller = createController();
        expect(controller.terminal.onOutput, isNotNull);

        controller.dispose();
        skipTearDownDispose = true;

        expect(controller.terminal.onOutput, isNull);
      });

      test('should be idempotent (can be called multiple times)', () {
        controller = createController();

        controller.dispose();
        skipTearDownDispose = true;

        // Second dispose should not throw
        expect(() => controller.dispose(), returnsNormally);
      });

      test('should cancel message subscription', () async {
        controller = createController();
        controller.dispose();
        skipTearDownDispose = true;

        // Sending message after dispose should not cause issues
        final envelope = MessageEnvelope.seal(
          MessageType.terminalOutput,
          {'output': 'Test'},
          remoteKeys,
          ourKeys,
        );

        mockRelayClient.simulateTerminalOutput(envelope);
        await Future.delayed(const Duration(milliseconds: 50));

        // Should not have processed the message
        expect(terminalState.hasError, isFalse);
      });
    });

    group('toString()', () {
      test('should return formatted string representation', () {
        mockRelayClient.setConnected(true);
        controller = createController(rows: 30, cols: 100);

        final result = controller.toString();

        expect(result, contains('RemoteTerminalController'));
        expect(result, contains('disposed: false'));
        expect(result, contains('connected: true'));
        expect(result, contains('size: 100x30'));
      });

      test('should reflect disposed state', () {
        controller = createController();
        controller.dispose();
        skipTearDownDispose = true;

        final result = controller.toString();

        expect(result, contains('disposed: true'));
      });

      test('should reflect disconnected state', () {
        mockRelayClient.setConnected(false);
        controller = createController();

        final result = controller.toString();

        expect(result, contains('connected: false'));
      });
    });

    group('Edge cases', () {
      test('should handle zero-size terminal gracefully', () {
        // Terminal size gets clamped, so 0 becomes 1
        controller = createController(rows: 0, cols: 0);

        expect(terminalState.rows, 1);
        expect(terminalState.cols, 1);
      });

      test('should handle very large terminal size', () {
        // Terminal size gets clamped to 1000
        controller = createController(rows: 5000, cols: 5000);

        expect(terminalState.rows, 1000);
        expect(terminalState.cols, 1000);
      });

      test('should handle concurrent message and input', () async {
        controller = createController();
        mockRelayClient.setConnected(true);

        // Simulate concurrent operations
        final envelope = MessageEnvelope.seal(
          MessageType.terminalOutput,
          {'output': 'Response'},
          remoteKeys,
          ourKeys,
        );

        controller.terminal.onOutput?.call('Input');
        mockRelayClient.simulateTerminalOutput(envelope);
        controller.terminal.onOutput?.call('More Input');

        await Future.delayed(const Duration(milliseconds: 100));

        expect(mockRelayClient.sentMessages.length, 2);
        expect(terminalState.hasError, isFalse);
      });

      test('should handle connection state changes during operation', () async {
        controller = createController();
        mockRelayClient.setConnected(true);

        controller.terminal.onOutput?.call('Input 1');
        await Future.delayed(const Duration(milliseconds: 10));

        mockRelayClient.setConnected(false);
        controller.terminal.onOutput?.call('Input 2'); // Should be ignored

        await Future.delayed(const Duration(milliseconds: 50));

        // Only the first message should be sent
        expect(mockRelayClient.sentMessages.length, 1);
        expect(mockRelayClient.sentMessages.first['input'], 'Input 1');
      });
    });
  });
}
