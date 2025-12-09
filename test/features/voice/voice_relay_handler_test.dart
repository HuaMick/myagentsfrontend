import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:myagents_frontend/features/voice/voice_relay_handler.dart';
import 'package:myagents_frontend/features/voice/voice_state.dart';
import 'package:myagents_frontend/core/networking/relay_client.dart';
import 'package:myagents_frontend/core/crypto/message_envelope.dart';
import 'package:myagents_frontend/core/crypto/key_pair.dart';

/// Mock implementation of RelayClient for testing
class MockRelayClient implements RelayClient {
  final StreamController<MessageEnvelope> _messageController =
      StreamController<MessageEnvelope>.broadcast();
  final List<_SentMessage> sentMessages = [];
  bool _isConnected = true;
  KeyPair? _ourKeys;
  KeyPair? _remoteKeys;

  @override
  bool get isConnected => _isConnected;

  @override
  bool get hasKeys => _ourKeys != null && _remoteKeys != null;

  void setConnected(bool connected) {
    _isConnected = connected;
  }

  @override
  void setKeys(KeyPair ourKeys, KeyPair remoteKeys) {
    _ourKeys = ourKeys;
    _remoteKeys = remoteKeys;
  }

  @override
  Future<void> send(MessageType type, Map<String, dynamic> payloadData) async {
    if (!_isConnected) {
      throw StateError('Not connected to relay server');
    }
    if (_ourKeys == null || _remoteKeys == null) {
      throw StateError('Encryption keys not set');
    }

    // Record the sent message
    sentMessages.add(_SentMessage(type, payloadData));
  }

  @override
  Stream<MessageEnvelope> getMessagesByType(MessageType type) {
    return _messageController.stream.where((msg) => msg.type == type);
  }

  /// Simulates receiving a message from the backend
  void simulateIncomingMessage(MessageType type, Map<String, dynamic> payload,
      KeyPair senderKeys, KeyPair recipientKeys) {
    final envelope = MessageEnvelope.seal(type, payload, senderKeys, recipientKeys);
    _messageController.add(envelope);
  }

  /// Simulates receiving a malformed message that will fail decryption
  void simulateMalformedMessage(MessageType type) {
    final envelope = MessageEnvelope(
      type: type,
      payload: 'invalid_base64_data',
      senderPublicKey: 'invalid_key',
    );
    _messageController.add(envelope);
  }

  Future<void> dispose() async {
    await _messageController.close();
  }

  // Unimplemented methods from RelayClient interface
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Helper class to track sent messages
class _SentMessage {
  final MessageType type;
  final Map<String, dynamic> payload;

  _SentMessage(this.type, this.payload);
}

/// Mock implementation of VoiceController for testing
class MockVoiceController extends VoiceController {
  final List<TranscriptEvent> transcriptEvents = [];
  final List<String> errorEvents = [];

  @override
  void onTranscriptReceived(String text, bool isFinal) {
    transcriptEvents.add(TranscriptEvent(text, isFinal));
    super.onTranscriptReceived(text, isFinal);
  }

  @override
  void onError(String message) {
    errorEvents.add(message);
    super.onError(message);
  }
}

/// Helper class to track transcript events
class TranscriptEvent {
  final String text;
  final bool isFinal;

  TranscriptEvent(this.text, this.isFinal);
}

void main() {
  group('VoiceRelayHandler', () {
    late MockRelayClient mockRelayClient;
    late MockVoiceController mockController;
    late KeyPair ourKeys;
    late KeyPair remoteKeys;
    late VoiceRelayHandler handler;

    setUp(() {
      mockRelayClient = MockRelayClient();
      mockController = MockVoiceController();
      ourKeys = KeyPair.generate();
      remoteKeys = KeyPair.generate();

      // Set keys on mock relay client
      mockRelayClient.setKeys(ourKeys, remoteKeys);

      handler = VoiceRelayHandler(
        relayClient: mockRelayClient,
        controller: mockController,
        ourKeys: ourKeys,
        remoteKeys: remoteKeys,
      );
    });

    tearDown(() {
      handler.dispose();
      mockRelayClient.dispose();
    });

    group('startVoiceSession', () {
      test('sends voiceControl message with action: "start"', () async {
        // Act
        await handler.startVoiceSession();

        // Assert
        expect(mockRelayClient.sentMessages.length, equals(1));
        expect(mockRelayClient.sentMessages[0].type, equals(MessageType.voiceControl));
        expect(mockRelayClient.sentMessages[0].payload['action'], equals('start'));
      });

      test('throws VoiceRelayException when relay client is not connected', () async {
        // Arrange
        mockRelayClient.setConnected(false);

        // Act & Assert
        expect(
          () => handler.startVoiceSession(),
          throwsA(isA<VoiceRelayException>()
              .having((e) => e.message, 'message', 'Relay client is not connected')),
        );
      });

      test('throws VoiceRelayException when send fails', () async {
        // Arrange - create a handler with a client that throws on send
        final failingClient = MockRelayClient();
        failingClient.setKeys(ourKeys, remoteKeys);
        final failingHandler = VoiceRelayHandler(
          relayClient: failingClient,
          controller: mockController,
          ourKeys: ourKeys,
          remoteKeys: remoteKeys,
        );

        // Override send to throw
        failingClient.setConnected(false);

        // Act & Assert
        expect(
          () => failingHandler.startVoiceSession(),
          throwsA(isA<VoiceRelayException>()),
        );

        failingHandler.dispose();
        failingClient.dispose();
      });
    });

    group('streamAudioFrames', () {
      test('sends voiceAudioFrame for each audio chunk', () async {
        // Arrange
        final chunk1 = Uint8List.fromList([1, 2, 3, 4]);
        final chunk2 = Uint8List.fromList([5, 6, 7, 8]);
        final audioController = StreamController<Uint8List>();

        // Act
        handler.streamAudioFrames(audioController.stream);
        audioController.add(chunk1);
        audioController.add(chunk2);

        // Wait for async processing
        await Future.delayed(Duration(milliseconds: 100));

        // Assert
        expect(mockRelayClient.sentMessages.length, equals(2));
        expect(mockRelayClient.sentMessages[0].type, equals(MessageType.voiceAudioFrame));
        expect(mockRelayClient.sentMessages[1].type, equals(MessageType.voiceAudioFrame));

        // Cleanup
        await audioController.close();
      });

      test('audio chunks are base64-encoded before sending', () async {
        // Arrange
        final chunk = Uint8List.fromList([1, 2, 3, 4, 5]);
        final expectedBase64 = base64Encode(chunk);
        final audioController = StreamController<Uint8List>();

        // Act
        handler.streamAudioFrames(audioController.stream);
        audioController.add(chunk);

        // Wait for async processing
        await Future.delayed(Duration(milliseconds: 100));

        // Assert
        expect(mockRelayClient.sentMessages.length, equals(1));
        expect(mockRelayClient.sentMessages[0].payload['data'], equals(expectedBase64));

        // Cleanup
        await audioController.close();
      });

      test('cancels previous audio subscription when called again', () async {
        // Arrange
        final controller1 = StreamController<Uint8List>();
        final controller2 = StreamController<Uint8List>();

        // Act
        handler.streamAudioFrames(controller1.stream);
        handler.streamAudioFrames(controller2.stream);

        controller1.add(Uint8List.fromList([1, 2, 3]));
        controller2.add(Uint8List.fromList([4, 5, 6]));

        await Future.delayed(Duration(milliseconds: 100));

        // Assert - only messages from controller2 should be sent
        expect(mockRelayClient.sentMessages.length, equals(1));
        expect(mockRelayClient.sentMessages[0].payload['data'],
               equals(base64Encode(Uint8List.fromList([4, 5, 6]))));

        // Cleanup
        await controller1.close();
        await controller2.close();
      });

      test('handles audio stream errors by calling controller.onError', () async {
        // Arrange
        final audioController = StreamController<Uint8List>();

        // Act
        handler.streamAudioFrames(audioController.stream);
        audioController.addError(Exception('Audio stream error'));

        // Wait for error processing
        await Future.delayed(Duration(milliseconds: 100));

        // Assert
        expect(mockController.errorEvents.length, equals(1));
        expect(mockController.errorEvents[0], contains('Audio stream error'));

        // Cleanup
        await audioController.close();
      });

      test('handles send errors by calling controller.onError', () async {
        // Arrange
        final audioController = StreamController<Uint8List>();

        // Start streaming
        handler.streamAudioFrames(audioController.stream);

        // Disconnect client to cause send failure
        mockRelayClient.setConnected(false);
        audioController.add(Uint8List.fromList([1, 2, 3]));

        // Wait for error processing
        await Future.delayed(Duration(milliseconds: 100));

        // Assert
        expect(mockController.errorEvents.length, equals(1));
        expect(mockController.errorEvents[0], contains('Failed to send audio frame'));

        // Cleanup
        await audioController.close();
      });
    });

    group('stopVoiceSession', () {
      test('sends voiceControl message with action: "stop"', () async {
        // Act
        await handler.stopVoiceSession();

        // Assert
        expect(mockRelayClient.sentMessages.length, equals(1));
        expect(mockRelayClient.sentMessages[0].type, equals(MessageType.voiceControl));
        expect(mockRelayClient.sentMessages[0].payload['action'], equals('stop'));
      });

      test('cancels audio subscription', () async {
        // Arrange
        final audioController = StreamController<Uint8List>();
        handler.streamAudioFrames(audioController.stream);

        // Add initial chunk
        audioController.add(Uint8List.fromList([1, 2, 3]));
        await Future.delayed(Duration(milliseconds: 50));

        // Act
        await handler.stopVoiceSession();

        // Clear sent messages
        mockRelayClient.sentMessages.clear();

        // Add another chunk after stopping
        audioController.add(Uint8List.fromList([4, 5, 6]));
        await Future.delayed(Duration(milliseconds: 50));

        // Assert - no new audio frames should be sent
        expect(mockRelayClient.sentMessages.length, equals(0));

        // Cleanup
        await audioController.close();
      });

      test('does not throw when relay client is disconnected', () async {
        // Arrange
        mockRelayClient.setConnected(false);

        // Act & Assert - should not throw
        await handler.stopVoiceSession();
      });
    });

    group('voiceTranscript reception', () {
      setUp(() {
        handler.setupListeners();
      });

      test('updates controller with interim transcript', () async {
        // Arrange
        const interimText = 'Hello world';

        // Act
        mockRelayClient.simulateIncomingMessage(
          MessageType.voiceTranscript,
          {'transcript': interimText, 'is_final': false},
          remoteKeys,
          ourKeys,
        );

        // Wait for processing
        await Future.delayed(Duration(milliseconds: 50));

        // Assert
        expect(mockController.transcriptEvents.length, equals(1));
        expect(mockController.transcriptEvents[0].text, equals(interimText));
        expect(mockController.transcriptEvents[0].isFinal, equals(false));
        expect(mockController.interimTranscript, equals(interimText));
      });

      test('updates controller with final transcript', () async {
        // Arrange
        const finalText = 'Complete sentence';

        // Act
        mockRelayClient.simulateIncomingMessage(
          MessageType.voiceTranscript,
          {'transcript': finalText, 'is_final': true},
          remoteKeys,
          ourKeys,
        );

        // Wait for processing
        await Future.delayed(Duration(milliseconds: 50));

        // Assert
        expect(mockController.transcriptEvents.length, equals(1));
        expect(mockController.transcriptEvents[0].text, equals(finalText));
        expect(mockController.transcriptEvents[0].isFinal, equals(true));
        expect(mockController.finalTranscript, equals(finalText));
        expect(mockController.currentState, equals(VoiceState.success));
      });

      test('handles missing transcript field', () async {
        // Act
        mockRelayClient.simulateIncomingMessage(
          MessageType.voiceTranscript,
          {'is_final': false},
          remoteKeys,
          ourKeys,
        );

        // Wait for processing
        await Future.delayed(Duration(milliseconds: 50));

        // Assert
        expect(mockController.errorEvents.length, equals(1));
        expect(mockController.errorEvents[0],
               contains('Received transcript message without transcript field'));
      });

      test('handles missing is_final field', () async {
        // Act
        mockRelayClient.simulateIncomingMessage(
          MessageType.voiceTranscript,
          {'transcript': 'test'},
          remoteKeys,
          ourKeys,
        );

        // Wait for processing
        await Future.delayed(Duration(milliseconds: 50));

        // Assert
        expect(mockController.errorEvents.length, equals(1));
        expect(mockController.errorEvents[0],
               contains('Received transcript message without is_final field'));
      });

      test('handles decryption errors', () async {
        // Act - send malformed message
        mockRelayClient.simulateMalformedMessage(MessageType.voiceTranscript);

        // Wait for processing
        await Future.delayed(Duration(milliseconds: 50));

        // Assert
        expect(mockController.errorEvents.length, equals(1));
        expect(mockController.errorEvents[0],
               contains('Failed to process transcript message'));
      });
    });

    group('voiceStatus error handling', () {
      setUp(() {
        handler.setupListeners();
      });

      test('calls controller.onError for error status', () async {
        // Act
        mockRelayClient.simulateIncomingMessage(
          MessageType.voiceStatus,
          {'status': 'error', 'message': 'Backend failure'},
          remoteKeys,
          ourKeys,
        );

        // Wait for processing
        await Future.delayed(Duration(milliseconds: 50));

        // Assert
        expect(mockController.errorEvents.length, equals(1));
        expect(mockController.errorEvents[0], equals('Backend failure'));
      });

      test('uses default error message when message field is missing', () async {
        // Act
        mockRelayClient.simulateIncomingMessage(
          MessageType.voiceStatus,
          {'status': 'error'},
          remoteKeys,
          ourKeys,
        );

        // Wait for processing
        await Future.delayed(Duration(milliseconds: 50));

        // Assert
        expect(mockController.errorEvents.length, equals(1));
        expect(mockController.errorEvents[0], equals('Unknown backend error'));
      });

      test('handles ready status without error', () async {
        // Act
        mockRelayClient.simulateIncomingMessage(
          MessageType.voiceStatus,
          {'status': 'ready'},
          remoteKeys,
          ourKeys,
        );

        // Wait for processing
        await Future.delayed(Duration(milliseconds: 50));

        // Assert - no errors should be reported
        expect(mockController.errorEvents.length, equals(0));
      });

      test('handles processing status without error', () async {
        // Act
        mockRelayClient.simulateIncomingMessage(
          MessageType.voiceStatus,
          {'status': 'processing'},
          remoteKeys,
          ourKeys,
        );

        // Wait for processing
        await Future.delayed(Duration(milliseconds: 50));

        // Assert - no errors should be reported
        expect(mockController.errorEvents.length, equals(0));
      });

      test('handles unknown status without error', () async {
        // Act
        mockRelayClient.simulateIncomingMessage(
          MessageType.voiceStatus,
          {'status': 'unknown_status'},
          remoteKeys,
          ourKeys,
        );

        // Wait for processing
        await Future.delayed(Duration(milliseconds: 50));

        // Assert - no errors should be reported
        expect(mockController.errorEvents.length, equals(0));
      });

      test('handles missing status field', () async {
        // Act
        mockRelayClient.simulateIncomingMessage(
          MessageType.voiceStatus,
          {'message': 'test'},
          remoteKeys,
          ourKeys,
        );

        // Wait for processing
        await Future.delayed(Duration(milliseconds: 50));

        // Assert
        expect(mockController.errorEvents.length, equals(1));
        expect(mockController.errorEvents[0],
               contains('Received status message without status field'));
      });
    });

    group('dispose', () {
      test('cancels all subscriptions', () async {
        // Arrange
        handler.setupListeners();
        final audioController = StreamController<Uint8List>();
        handler.streamAudioFrames(audioController.stream);

        // Act
        handler.dispose();

        // Send messages after dispose
        audioController.add(Uint8List.fromList([1, 2, 3]));
        mockRelayClient.simulateIncomingMessage(
          MessageType.voiceTranscript,
          {'transcript': 'test', 'is_final': false},
          remoteKeys,
          ourKeys,
        );

        await Future.delayed(Duration(milliseconds: 50));

        // Assert - no messages should be processed
        expect(mockRelayClient.sentMessages.length, equals(0));
        expect(mockController.transcriptEvents.length, equals(0));

        // Cleanup
        await audioController.close();
      });

      test('can be called multiple times safely', () {
        // Act & Assert - should not throw
        handler.dispose();
        handler.dispose();
      });

      test('operations throw VoiceRelayException after dispose', () async {
        // Arrange
        handler.dispose();

        // Act & Assert
        expect(
          () => handler.startVoiceSession(),
          throwsA(isA<VoiceRelayException>()
              .having((e) => e.message, 'message',
                      contains('has been disposed and cannot be used'))),
        );

        expect(
          () => handler.stopVoiceSession(),
          throwsA(isA<VoiceRelayException>()),
        );

        expect(
          () => handler.streamAudioFrames(Stream.empty()),
          throwsA(isA<VoiceRelayException>()),
        );
      });
    });

    group('cancelVoiceSession', () {
      test('sends voiceControl message with action: "cancel"', () async {
        // Act
        await handler.cancelVoiceSession();

        // Assert
        expect(mockRelayClient.sentMessages.length, equals(1));
        expect(mockRelayClient.sentMessages[0].type, equals(MessageType.voiceControl));
        expect(mockRelayClient.sentMessages[0].payload['action'], equals('cancel'));
      });

      test('cancels audio subscription', () async {
        // Arrange
        final audioController = StreamController<Uint8List>();
        handler.streamAudioFrames(audioController.stream);

        // Add initial chunk
        audioController.add(Uint8List.fromList([1, 2, 3]));
        await Future.delayed(Duration(milliseconds: 50));

        // Act
        await handler.cancelVoiceSession();

        // Clear sent messages
        mockRelayClient.sentMessages.clear();

        // Add another chunk after canceling
        audioController.add(Uint8List.fromList([4, 5, 6]));
        await Future.delayed(Duration(milliseconds: 50));

        // Assert - no new audio frames should be sent
        expect(mockRelayClient.sentMessages.length, equals(0));

        // Cleanup
        await audioController.close();
      });
    });

    group('VoiceRelayException', () {
      test('has correct format without cause', () {
        final exception = VoiceRelayException('Test error');
        expect(exception.toString(), equals('VoiceRelayException: Test error'));
      });

      test('has correct format with cause', () {
        final cause = Exception('Root cause');
        final exception = VoiceRelayException('Test error', cause);
        expect(exception.toString(), contains('VoiceRelayException: Test error'));
        expect(exception.toString(), contains('caused by'));
        expect(exception.toString(), contains('Root cause'));
      });
    });

    group('setupListeners', () {
      test('throws after dispose', () {
        // Arrange
        handler.dispose();

        // Act & Assert
        expect(
          () => handler.setupListeners(),
          throwsA(isA<VoiceRelayException>()),
        );
      });

      test('handles transcript stream errors', () async {
        // Arrange
        handler.setupListeners();

        // We can't easily simulate stream errors with our current mock,
        // but we verify that error handlers are set up by checking that
        // the handler doesn't crash on malformed messages
        mockRelayClient.simulateMalformedMessage(MessageType.voiceTranscript);

        await Future.delayed(Duration(milliseconds: 50));

        // Assert - should have an error but not crash
        expect(mockController.errorEvents.length, greaterThan(0));
      });

      test('handles status stream errors', () async {
        // Arrange
        handler.setupListeners();

        // Similar to above - verify error handling
        mockRelayClient.simulateMalformedMessage(MessageType.voiceStatus);

        await Future.delayed(Duration(milliseconds: 50));

        // Assert - should have an error but not crash
        expect(mockController.errorEvents.length, greaterThan(0));
      });
    });

    group('integration scenarios', () {
      test('complete voice session workflow', () async {
        // Arrange
        handler.setupListeners();
        final audioController = StreamController<Uint8List>();

        // Act - Start session
        await handler.startVoiceSession();

        // Stream audio
        handler.streamAudioFrames(audioController.stream);
        audioController.add(Uint8List.fromList([1, 2, 3]));
        audioController.add(Uint8List.fromList([4, 5, 6]));

        // Receive interim transcript
        mockRelayClient.simulateIncomingMessage(
          MessageType.voiceTranscript,
          {'transcript': 'Hello', 'is_final': false},
          remoteKeys,
          ourKeys,
        );

        await Future.delayed(Duration(milliseconds: 50));

        // Receive final transcript
        mockRelayClient.simulateIncomingMessage(
          MessageType.voiceTranscript,
          {'transcript': 'Hello world', 'is_final': true},
          remoteKeys,
          ourKeys,
        );

        // Stop session
        await handler.stopVoiceSession();

        await Future.delayed(Duration(milliseconds: 50));

        // Assert
        expect(mockRelayClient.sentMessages.length, greaterThanOrEqualTo(3));
        expect(mockController.transcriptEvents.length, equals(2));
        expect(mockController.interimTranscript, equals('Hello'));
        expect(mockController.finalTranscript, equals('Hello world'));

        // Cleanup
        await audioController.close();
      });

      test('handles errors during active session', () async {
        // Arrange
        handler.setupListeners();
        final audioController = StreamController<Uint8List>();

        // Act - Start session
        await handler.startVoiceSession();

        // Stream audio
        handler.streamAudioFrames(audioController.stream);
        audioController.add(Uint8List.fromList([1, 2, 3]));

        await Future.delayed(Duration(milliseconds: 50));

        // Simulate backend error
        mockRelayClient.simulateIncomingMessage(
          MessageType.voiceStatus,
          {'status': 'error', 'message': 'Transcription failed'},
          remoteKeys,
          ourKeys,
        );

        await Future.delayed(Duration(milliseconds: 50));

        // Assert
        expect(mockController.errorEvents.length, equals(1));
        expect(mockController.errorEvents[0], equals('Transcription failed'));
        expect(mockController.currentState, equals(VoiceState.error));

        // Cleanup
        await audioController.close();
      });
    });
  });
}
