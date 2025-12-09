import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';

/// Exception thrown when audio capture operations fail.
///
/// This includes permission denials, recording failures, and resource errors.
class AudioCaptureException implements Exception {
  final String message;
  final Object? cause;

  AudioCaptureException(this.message, [this.cause]);

  @override
  String toString() {
    if (cause != null) {
      return 'AudioCaptureException: $message (caused by: $cause)';
    }
    return 'AudioCaptureException: $message';
  }
}

/// Service for capturing raw audio from the device microphone.
///
/// Handles microphone permission requests, audio recording, and provides
/// a stream of raw PCM16 audio chunks for sending to the backend.
///
/// Audio Configuration (matches backend expectations):
/// - Format: PCM16 (16-bit PCM)
/// - Sample rate: 16000 Hz
/// - Channels: mono (1 channel)
/// - Chunk size: ~4096 bytes
///
/// Usage:
/// ```dart
/// final service = AudioCaptureService();
///
/// // Request permission
/// final hasPermission = await service.requestPermission();
/// if (!hasPermission) {
///   // Handle permission denial
///   return;
/// }
///
/// // Start recording
/// final audioStream = await service.startRecording();
/// audioStream.listen((chunk) {
///   // Send chunk to backend
/// });
///
/// // Stop recording
/// await service.stopRecording();
///
/// // Cleanup
/// service.dispose();
/// ```
class AudioCaptureService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamController<Uint8List>? _audioStreamController;
  StreamSubscription<Uint8List>? _recordingSubscription;
  bool _isRecording = false;
  bool _isDisposed = false;

  /// Requests microphone permission from the user.
  ///
  /// Returns `true` if permission is granted, `false` if denied.
  /// This should be called before attempting to start recording.
  ///
  /// Throws [AudioCaptureException] if the permission request fails.
  Future<bool> requestPermission() async {
    _ensureNotDisposed();

    try {
      final hasPermission = await _recorder.hasPermission();
      return hasPermission;
    } catch (e) {
      throw AudioCaptureException(
        'Failed to request microphone permission',
        e,
      );
    }
  }

  /// Checks if microphone permission has been granted.
  ///
  /// Returns `true` if permission is currently granted, `false` otherwise.
  /// This is a non-blocking check of the current permission status.
  ///
  /// Throws [AudioCaptureException] if the permission check fails.
  Future<bool> hasPermission() async {
    _ensureNotDisposed();

    try {
      return await _recorder.hasPermission();
    } catch (e) {
      throw AudioCaptureException(
        'Failed to check microphone permission',
        e,
      );
    }
  }

  /// Starts audio recording and returns a stream of audio chunks.
  ///
  /// Audio is captured in PCM16 format at 16kHz mono with chunks of
  /// approximately 4096 bytes. The stream will emit audio data until
  /// [stopRecording] is called.
  ///
  /// Must have microphone permission before calling this method.
  /// Call [requestPermission] first if permission status is unknown.
  ///
  /// Returns a [Stream<Uint8List>] that emits raw PCM16 audio chunks.
  ///
  /// Throws [AudioCaptureException] if:
  /// - Permission is denied
  /// - Recording is already in progress
  /// - Recording fails to start
  Future<Stream<Uint8List>> startRecording() async {
    _ensureNotDisposed();

    if (_isRecording) {
      throw AudioCaptureException('Recording is already in progress');
    }

    // Check permission before attempting to record
    final hasPermission = await this.hasPermission();
    if (!hasPermission) {
      throw AudioCaptureException(
        'Microphone permission denied. Please grant permission in settings.',
      );
    }

    try {
      // Create stream controller for audio chunks
      _audioStreamController = StreamController<Uint8List>.broadcast();

      // Configure recording parameters
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 256000,
        streamBufferSize: 4096,
      );

      // Start recording and get the audio stream
      final recordStream = await _recorder.startStream(config);

      // Subscribe to the recording stream and forward chunks
      _recordingSubscription = recordStream.listen(
        (chunk) {
          if (!_audioStreamController!.isClosed) {
            _audioStreamController!.add(chunk);
          }
        },
        onError: (error) {
          if (!_audioStreamController!.isClosed) {
            _audioStreamController!.addError(
              AudioCaptureException('Recording stream error', error),
            );
          }
        },
        onDone: () {
          if (!_audioStreamController!.isClosed) {
            _audioStreamController!.close();
          }
        },
        cancelOnError: true,
      );

      _isRecording = true;
      return _audioStreamController!.stream;
    } catch (e) {
      // Clean up on failure
      await _cleanupRecording();
      throw AudioCaptureException('Failed to start audio recording', e);
    }
  }

  /// Stops the current audio recording session.
  ///
  /// This will end the audio stream returned by [startRecording] and
  /// release the microphone. After calling this, [startRecording] can
  /// be called again to start a new recording session.
  ///
  /// Safe to call even if not currently recording.
  ///
  /// Throws [AudioCaptureException] if stopping the recording fails.
  Future<void> stopRecording() async {
    _ensureNotDisposed();

    if (!_isRecording) {
      return; // Not recording, nothing to stop
    }

    try {
      await _recorder.stop();
      await _cleanupRecording();
    } catch (e) {
      throw AudioCaptureException('Failed to stop audio recording', e);
    }
  }

  /// Cleans up resources used by the audio capture service.
  ///
  /// This should be called when the service is no longer needed.
  /// After calling dispose, this service instance cannot be reused.
  void dispose() {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;

    // Stop recording if in progress (don't await, just fire and forget)
    if (_isRecording) {
      _recorder.stop().then((_) {
        _cleanupRecording();
      }).catchError((_) {
        // Ignore errors during disposal
      });
    } else {
      _cleanupRecording();
    }

    _recorder.dispose();
  }

  /// Cleans up recording-related resources.
  Future<void> _cleanupRecording() async {
    _isRecording = false;

    // Cancel subscription to recording stream
    await _recordingSubscription?.cancel();
    _recordingSubscription = null;

    // Close audio stream controller
    await _audioStreamController?.close();
    _audioStreamController = null;
  }

  /// Ensures the service has not been disposed.
  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw AudioCaptureException(
        'AudioCaptureService has been disposed and cannot be used',
      );
    }
  }
}
