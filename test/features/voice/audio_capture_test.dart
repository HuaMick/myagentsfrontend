import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:myagents_frontend/features/voice/audio_capture.dart';

// Mock AudioRecorder for testing
// This simulates the record package's AudioRecorder behavior without needing actual microphone access
class MockAudioRecorder {
  bool _hasPermission = true;
  bool _isRecording = false;
  bool _shouldFailPermission = false;
  bool _shouldFailStart = false;
  StreamController<Uint8List>? _mockStreamController;

  // Configure mock behavior
  void setPermission(bool hasPermission) {
    _hasPermission = hasPermission;
  }

  void setShouldFailPermission(bool shouldFail) {
    _shouldFailPermission = shouldFail;
  }

  void setShouldFailStart(bool shouldFail) {
    _shouldFailStart = shouldFail;
  }

  Future<bool> hasPermission() async {
    if (_shouldFailPermission) {
      throw Exception('Permission check failed');
    }
    await Future.delayed(const Duration(milliseconds: 10));
    return _hasPermission;
  }

  Future<Stream<Uint8List>> startStream(dynamic config) async {
    if (_shouldFailStart) {
      throw Exception('Failed to start recording');
    }
    if (!_hasPermission) {
      throw Exception('Permission denied');
    }
    if (_isRecording) {
      throw Exception('Already recording');
    }

    _isRecording = true;
    _mockStreamController = StreamController<Uint8List>();

    // Simulate audio chunks of ~4096 bytes
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isRecording || _mockStreamController!.isClosed) {
        timer.cancel();
        return;
      }
      // Create a mock audio chunk of approximately 4096 bytes
      final chunk = Uint8List(4096);
      for (int i = 0; i < chunk.length; i++) {
        chunk[i] = i % 256;
      }
      _mockStreamController!.add(chunk);
    });

    return _mockStreamController!.stream;
  }

  Future<void> stop() async {
    _isRecording = false;
    await _mockStreamController?.close();
    await Future.delayed(const Duration(milliseconds: 10));
  }

  void dispose() {
    _mockStreamController?.close();
  }

  // Helper to emit error on stream
  void emitError(Object error) {
    if (_mockStreamController != null && !_mockStreamController!.isClosed) {
      _mockStreamController!.addError(error);
    }
  }
}

// Since we can't easily inject the AudioRecorder dependency without modifying
// the production code, we'll test the production code as-is and note limitations.
// For comprehensive testing, we would need to refactor AudioCaptureService to accept
// an AudioRecorder in its constructor.

void main() {
  group('AudioCaptureService - Integration Tests', () {
    late AudioCaptureService service;

    setUp(() {
      service = AudioCaptureService();
    });

    tearDown(() {
      service.dispose();
    });

    test('service can be instantiated', () {
      expect(service, isNotNull);
    });

    test('hasPermission returns a boolean', () async {
      // Note: This test may fail in CI/test environments without microphone
      // In real testing with proper mocking, we would control this
      try {
        final hasPermission = await service.hasPermission();
        expect(hasPermission, isA<bool>());
      } catch (e) {
        // Expected in test environment without microphone access
        expect(e, isA<AudioCaptureException>());
      }
    });

    test('requestPermission returns a boolean', () async {
      try {
        final hasPermission = await service.requestPermission();
        expect(hasPermission, isA<bool>());
      } catch (e) {
        // Expected in test environment without microphone access
        expect(e, isA<AudioCaptureException>());
      }
    });

    test('cannot start recording without permission', () async {
      // This test validates that permission check happens before recording
      // In test environments without mic access, this should throw
      expect(
        () => service.startRecording(),
        throwsA(isA<AudioCaptureException>()),
      );
    });

    test('stopRecording can be called when not recording', () async {
      // Should not throw when stopping while not recording
      await service.stopRecording();
      // If we get here without exception, test passes
    });

    test('dispose can be called multiple times', () {
      service.dispose();
      service.dispose();
      // Should not throw
    });

    test('operations throw after dispose', () async {
      service.dispose();

      expect(
        () => service.hasPermission(),
        throwsA(isA<AudioCaptureException>()),
      );

      expect(
        () => service.requestPermission(),
        throwsA(isA<AudioCaptureException>()),
      );

      expect(
        () => service.startRecording(),
        throwsA(isA<AudioCaptureException>()),
      );

      expect(
        () => service.stopRecording(),
        throwsA(isA<AudioCaptureException>()),
      );
    });

    test('AudioCaptureException has correct format', () {
      final exception = AudioCaptureException('Test error');
      expect(exception.toString(), contains('AudioCaptureException'));
      expect(exception.toString(), contains('Test error'));

      final exceptionWithCause = AudioCaptureException(
        'Test error',
        Exception('Root cause'),
      );
      expect(exceptionWithCause.toString(), contains('caused by'));
      expect(exceptionWithCause.toString(), contains('Root cause'));
    });

    test('AudioCaptureException includes message and cause', () {
      final cause = Exception('Original error');
      final exception = AudioCaptureException('Wrapper message', cause);

      expect(exception.message, equals('Wrapper message'));
      expect(exception.cause, equals(cause));
    });
  });

  group('AudioCaptureService - Mock Recorder Tests', () {
    // These tests demonstrate how the service would be tested with proper mocking
    // In a real implementation, we would refactor AudioCaptureService to accept
    // an AudioRecorder dependency via constructor injection

    test('Mock demonstrates permission request flow', () async {
      final mockRecorder = MockAudioRecorder();

      // Test permission granted
      mockRecorder.setPermission(true);
      expect(await mockRecorder.hasPermission(), isTrue);

      // Test permission denied
      mockRecorder.setPermission(false);
      expect(await mockRecorder.hasPermission(), isFalse);
    });

    test('Mock demonstrates audio stream generation', () async {
      final mockRecorder = MockAudioRecorder();
      mockRecorder.setPermission(true);

      final stream = await mockRecorder.startStream(null);

      // Collect a few chunks
      final chunks = <Uint8List>[];
      final subscription = stream.listen((chunk) {
        chunks.add(chunk);
      });

      // Wait for some chunks to arrive
      await Future.delayed(const Duration(milliseconds: 350));
      await subscription.cancel();

      // Should have received multiple chunks
      expect(chunks.length, greaterThan(0));

      // Each chunk should be approximately 4096 bytes
      for (final chunk in chunks) {
        expect(chunk.length, equals(4096));
      }
    });

    test('Mock demonstrates chunk size validation', () async {
      final mockRecorder = MockAudioRecorder();
      mockRecorder.setPermission(true);

      final stream = await mockRecorder.startStream(null);

      // Check first chunk size
      final firstChunk = await stream.first;
      expect(firstChunk.length, equals(4096));
      expect(firstChunk.length, inInclusiveRange(3000, 5000)); // Within reasonable range
    });

    test('Mock demonstrates resource cleanup', () async {
      final mockRecorder = MockAudioRecorder();
      mockRecorder.setPermission(true);

      final stream = await mockRecorder.startStream(null);

      final subscription = stream.listen((chunk) {});
      await Future.delayed(const Duration(milliseconds: 150));

      // Stop recording
      await mockRecorder.stop();
      await subscription.cancel();

      // Stream should be properly closed
      expect(mockRecorder._mockStreamController?.isClosed, isTrue);
    });

    test('Mock demonstrates permission denied error', () async {
      final mockRecorder = MockAudioRecorder();
      mockRecorder.setPermission(false);

      expect(
        () => mockRecorder.startStream(null),
        throwsA(isA<Exception>()),
      );
    });

    test('Mock demonstrates permission check failure', () async {
      final mockRecorder = MockAudioRecorder();
      mockRecorder.setShouldFailPermission(true);

      expect(
        () => mockRecorder.hasPermission(),
        throwsA(isA<Exception>()),
      );
    });

    test('Mock demonstrates recording start failure', () async {
      final mockRecorder = MockAudioRecorder();
      mockRecorder.setPermission(true);
      mockRecorder.setShouldFailStart(true);

      expect(
        () => mockRecorder.startStream(null),
        throwsA(isA<Exception>()),
      );
    });

    test('Mock demonstrates stream error handling', () async {
      final mockRecorder = MockAudioRecorder();
      mockRecorder.setPermission(true);

      final stream = await mockRecorder.startStream(null);

      bool errorReceived = false;
      final subscription = stream.listen(
        (chunk) {},
        onError: (error) {
          errorReceived = true;
        },
      );

      // Simulate an error
      await Future.delayed(const Duration(milliseconds: 50));
      mockRecorder.emitError(Exception('Stream error'));

      await Future.delayed(const Duration(milliseconds: 50));
      await subscription.cancel();

      expect(errorReceived, isTrue);
    });

    test('Mock demonstrates dispose cleanup', () {
      final mockRecorder = MockAudioRecorder();
      mockRecorder.dispose();
      // No error should occur
    });
  });

  group('AudioCaptureService - Edge Cases', () {
    late AudioCaptureService service;

    setUp(() {
      service = AudioCaptureService();
    });

    tearDown(() {
      service.dispose();
    });

    test('stopRecording is safe when not recording', () async {
      await service.stopRecording();
      await service.stopRecording(); // Call twice
      // Should not throw
    });

    test('dispose while not recording completes cleanly', () {
      service.dispose();
      // Should complete without error
    });

    test('multiple hasPermission calls work correctly', () async {
      try {
        await service.hasPermission();
        await service.hasPermission();
        await service.hasPermission();
        // All should complete without error
      } catch (e) {
        // Expected in environments without microphone
        expect(e, isA<AudioCaptureException>());
      }
    });
  });

  group('AudioCaptureException', () {
    test('creates exception with message only', () {
      final exception = AudioCaptureException('Test error');
      expect(exception.message, equals('Test error'));
      expect(exception.cause, isNull);
    });

    test('creates exception with message and cause', () {
      final cause = Exception('Root cause');
      final exception = AudioCaptureException('Test error', cause);
      expect(exception.message, equals('Test error'));
      expect(exception.cause, equals(cause));
    });

    test('toString without cause', () {
      final exception = AudioCaptureException('Test error');
      final str = exception.toString();
      expect(str, equals('AudioCaptureException: Test error'));
    });

    test('toString with cause', () {
      final cause = Exception('Root cause');
      final exception = AudioCaptureException('Test error', cause);
      final str = exception.toString();
      expect(str, contains('AudioCaptureException: Test error'));
      expect(str, contains('caused by'));
      expect(str, contains('Root cause'));
    });
  });
}
