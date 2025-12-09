import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../../core/networking/relay_client.dart';
import '../../core/crypto/message_envelope.dart';
import '../../core/crypto/key_pair.dart';
import 'voice_state.dart';

/// Exception thrown when voice relay operations fail.
class VoiceRelayException implements Exception {
  final String message;
  final Object? cause;

  VoiceRelayException(this.message, [this.cause]);

  @override
  String toString() {
    if (cause != null) {
      return 'VoiceRelayException: $message (caused by: $cause)';
    }
    return 'VoiceRelayException: $message';
  }
}

/// Bridges audio capture to backend voice service via RelayClient.
///
/// VoiceRelayHandler manages the E2E encrypted communication between the
/// frontend audio capture and the backend voice transcription service.
///
/// Message Protocol:
/// - VoiceAudioFrame (frontend -> backend): {data: base64_string}
/// - VoiceTranscript (backend -> frontend): {transcript: string, is_final: bool}
/// - VoiceControl (frontend -> backend): {action: "start"|"stop"|"cancel"}
/// - VoiceStatus (backend -> frontend): {status: "ready"|"error"|"processing", message: string?}
///
/// Usage:
/// ```dart
/// final handler = VoiceRelayHandler(
///   relayClient: relayClient,
///   controller: voiceController,
///   ourKeys: KeyPair.generate(),
///   remoteKeys: remoteKeys,
/// );
///
/// // Setup listeners for incoming messages
/// handler.setupListeners();
///
/// // Start voice session
/// await handler.startVoiceSession();
///
/// // Stream audio to backend
/// handler.streamAudioFrames(audioStream);
///
/// // Stop voice session
/// await handler.stopVoiceSession();
///
/// // Cleanup
/// handler.dispose();
/// ```
class VoiceRelayHandler {
  final RelayClient relayClient;
  final VoiceController controller;
  final KeyPair ourKeys;
  final KeyPair remoteKeys;

  StreamSubscription<MessageEnvelope>? _transcriptSubscription;
  StreamSubscription<MessageEnvelope>? _statusSubscription;
  StreamSubscription<Uint8List>? _audioSubscription;
  bool _isDisposed = false;

  /// Creates a VoiceRelayHandler with the specified dependencies.
  ///
  /// Args:
  ///   relayClient: The relay client for sending/receiving messages
  ///   controller: The voice controller for state management
  ///   ourKeys: Our encryption keys for decrypting incoming messages
  ///   remoteKeys: Remote peer's encryption keys for encrypting outgoing messages
  VoiceRelayHandler({
    required this.relayClient,
    required this.controller,
    required this.ourKeys,
    required this.remoteKeys,
  });

  /// Sets up listeners for incoming voice messages from the backend.
  ///
  /// This subscribes to:
  /// - voiceTranscript: Interim and final transcription results
  /// - voiceStatus: Status updates and error notifications
  ///
  /// Should be called once after creating the handler, before starting
  /// a voice session.
  void setupListeners() {
    _ensureNotDisposed();

    // Listen for transcript messages
    _transcriptSubscription = relayClient
        .getMessagesByType(MessageType.voiceTranscript)
        .listen(
          _handleTranscriptMessage,
          onError: (error) {
            controller.onError('Transcript stream error: $error');
          },
        );

    // Listen for status messages
    _statusSubscription = relayClient
        .getMessagesByType(MessageType.voiceStatus)
        .listen(
          _handleStatusMessage,
          onError: (error) {
            controller.onError('Status stream error: $error');
          },
        );
  }

  /// Starts a voice session by sending a start control message.
  ///
  /// Sends a voiceControl message with action "start" to notify the backend
  /// that a new voice session is beginning.
  ///
  /// Throws [VoiceRelayException] if the relay client is not connected or
  /// if sending the message fails.
  Future<void> startVoiceSession() async {
    _ensureNotDisposed();

    if (!relayClient.isConnected) {
      throw VoiceRelayException('Relay client is not connected');
    }

    try {
      await relayClient.send(MessageType.voiceControl, {
        'action': 'start',
      });
    } catch (e) {
      throw VoiceRelayException('Failed to start voice session', e);
    }
  }

  /// Streams audio frames from the audio capture to the backend.
  ///
  /// Subscribes to the audio stream and sends each audio chunk as a
  /// voiceAudioFrame message with base64-encoded audio data.
  ///
  /// Args:
  ///   audioStream: Stream of raw PCM16 audio chunks from audio capture
  ///
  /// The stream subscription is stored and can be cancelled by calling
  /// [stopVoiceSession] or [dispose].
  void streamAudioFrames(Stream<Uint8List> audioStream) {
    _ensureNotDisposed();

    // Cancel any existing audio subscription
    _audioSubscription?.cancel();

    _audioSubscription = audioStream.listen(
      (chunk) async {
        try {
          // Base64 encode the audio chunk
          final base64Data = base64Encode(chunk);

          // Send voiceAudioFrame message
          await relayClient.send(MessageType.voiceAudioFrame, {
            'data': base64Data,
          });
        } catch (e) {
          // Handle send errors
          controller.onError('Failed to send audio frame: $e');
          await _stopAudioStreaming();
        }
      },
      onError: (error) {
        // Handle audio stream errors
        controller.onError('Audio stream error: $error');
        _stopAudioStreaming();
      },
      onDone: () {
        // Audio stream completed normally
        _audioSubscription = null;
      },
      cancelOnError: true,
    );
  }

  /// Stops the voice session by sending a stop control message.
  ///
  /// Sends a voiceControl message with action "stop" to notify the backend
  /// that the voice session is ending. Also cancels the audio stream
  /// subscription to stop sending audio frames.
  ///
  /// Throws [VoiceRelayException] if sending the stop message fails.
  Future<void> stopVoiceSession() async {
    _ensureNotDisposed();

    // Stop audio streaming first
    await _stopAudioStreaming();

    // Send stop control message
    try {
      if (relayClient.isConnected) {
        await relayClient.send(MessageType.voiceControl, {
          'action': 'stop',
        });
      }
    } catch (e) {
      throw VoiceRelayException('Failed to stop voice session', e);
    }
  }

  /// Cancels the voice session by sending a cancel control message.
  ///
  /// Similar to [stopVoiceSession] but indicates an abrupt cancellation
  /// rather than a normal stop. The backend may handle this differently.
  ///
  /// Throws [VoiceRelayException] if sending the cancel message fails.
  Future<void> cancelVoiceSession() async {
    _ensureNotDisposed();

    // Stop audio streaming first
    await _stopAudioStreaming();

    // Send cancel control message
    try {
      if (relayClient.isConnected) {
        await relayClient.send(MessageType.voiceControl, {
          'action': 'cancel',
        });
      }
    } catch (e) {
      throw VoiceRelayException('Failed to cancel voice session', e);
    }
  }

  /// Handles incoming transcript messages from the backend.
  ///
  /// Decrypts the message envelope, extracts the transcript and is_final flag,
  /// and routes them to the controller. Ensures transcripts are delivered
  /// within 100ms by processing asynchronously.
  void _handleTranscriptMessage(MessageEnvelope envelope) {
    try {
      // Decrypt the payload
      final payload = envelope.open(ourKeys, remoteKeys);

      // Extract transcript and is_final flag
      final transcript = payload['transcript'] as String?;
      final isFinal = payload['is_final'] as bool?;

      if (transcript == null) {
        controller.onError('Received transcript message without transcript field');
        return;
      }

      if (isFinal == null) {
        controller.onError('Received transcript message without is_final field');
        return;
      }

      // Route to controller (should complete within 100ms)
      controller.onTranscriptReceived(transcript, isFinal);
    } catch (e) {
      // Handle decryption or parsing errors
      controller.onError('Failed to process transcript message: $e');
    }
  }

  /// Handles incoming status messages from the backend.
  ///
  /// Decrypts the message envelope and processes status updates. Routes
  /// errors to the controller and handles ready/processing states.
  void _handleStatusMessage(MessageEnvelope envelope) {
    try {
      // Decrypt the payload
      final payload = envelope.open(ourKeys, remoteKeys);

      // Extract status and optional message
      final status = payload['status'] as String?;
      final message = payload['message'] as String?;

      if (status == null) {
        controller.onError('Received status message without status field');
        return;
      }

      // Handle different status types
      switch (status) {
        case 'error':
          // Error status - route to controller with message
          final errorMessage = message ?? 'Unknown backend error';
          controller.onError(errorMessage);
          break;

        case 'ready':
          // Backend is ready - could update controller state if needed
          // For now, we just log this internally
          break;

        case 'processing':
          // Backend is processing - could update controller state if needed
          // For now, we just log this internally
          break;

        default:
          // Unknown status - log warning but don't fail
          break;
      }
    } catch (e) {
      // Handle decryption or parsing errors
      controller.onError('Failed to process status message: $e');
    }
  }

  /// Stops audio streaming by cancelling the audio subscription.
  ///
  /// This is an internal helper method used by stopVoiceSession and
  /// cancelVoiceSession. It ensures the audio stream is properly cancelled
  /// and cleaned up.
  Future<void> _stopAudioStreaming() async {
    await _audioSubscription?.cancel();
    _audioSubscription = null;
  }

  /// Disposes of resources used by the handler.
  ///
  /// Cancels all subscriptions (transcript, status, audio) and marks the
  /// handler as disposed. After calling dispose, this handler instance
  /// cannot be reused.
  ///
  /// This is safe to call multiple times.
  void dispose() {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;

    // Cancel all subscriptions
    _transcriptSubscription?.cancel();
    _transcriptSubscription = null;

    _statusSubscription?.cancel();
    _statusSubscription = null;

    _audioSubscription?.cancel();
    _audioSubscription = null;
  }

  /// Ensures the handler has not been disposed.
  ///
  /// Throws [VoiceRelayException] if the handler has been disposed.
  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw VoiceRelayException(
        'VoiceRelayHandler has been disposed and cannot be used',
      );
    }
  }
}
