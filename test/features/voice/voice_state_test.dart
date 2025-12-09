import 'package:flutter_test/flutter_test.dart';
import 'package:myagents_frontend/features/voice/voice_state.dart';

void main() {
  group('VoiceController', () {
    late VoiceController controller;
    late List<void> listenerCallbacks;

    setUp(() {
      controller = VoiceController();
      listenerCallbacks = [];
      controller.addListener(() {
        listenerCallbacks.add(null);
      });
    });

    tearDown(() {
      controller.dispose();
    });

    group('State Transitions', () {
      test('idle -> requestingPermission on startRecording', () {
        expect(controller.currentState, VoiceState.idle);
        expect(listenerCallbacks.length, 0);

        controller.startRecording();

        expect(controller.currentState, VoiceState.requestingPermission);
        expect(listenerCallbacks.length, 1);
        expect(controller.interimTranscript, '');
        expect(controller.finalTranscript, '');
        expect(controller.errorMessage, null);
      });

      test('requestingPermission -> recording on permission granted', () {
        controller.startRecording();
        listenerCallbacks.clear();

        controller.onPermissionGranted();

        expect(controller.currentState, VoiceState.recording);
        expect(listenerCallbacks.length, 1);
      });

      test('requestingPermission -> error on permission denied via onError', () {
        controller.startRecording();
        listenerCallbacks.clear();

        controller.onError('Microphone permission denied');

        expect(controller.currentState, VoiceState.error);
        expect(controller.errorMessage, 'Microphone permission denied');
        expect(listenerCallbacks.length, 1);
      });

      test('recording -> processing on stopRecording', () {
        controller.startRecording();
        controller.onPermissionGranted();
        listenerCallbacks.clear();

        controller.stopRecording();

        expect(controller.currentState, VoiceState.processing);
        expect(listenerCallbacks.length, 1);
      });

      test('processing -> success on final transcript received', () {
        controller.startRecording();
        controller.onPermissionGranted();
        controller.stopRecording();
        listenerCallbacks.clear();

        controller.onTranscriptReceived('Hello world', true);

        expect(controller.currentState, VoiceState.success);
        expect(controller.finalTranscript, 'Hello world');
        expect(listenerCallbacks.length, 1);
      });

      test('processing -> error on backend error via onError', () {
        controller.startRecording();
        controller.onPermissionGranted();
        controller.stopRecording();
        listenerCallbacks.clear();

        controller.onError('Backend transcription failed');

        expect(controller.currentState, VoiceState.error);
        expect(controller.errorMessage, 'Backend transcription failed');
        expect(listenerCallbacks.length, 1);
      });
    });

    group('reset()', () {
      test('returns to idle from requestingPermission', () {
        controller.startRecording();
        listenerCallbacks.clear();

        controller.reset();

        expect(controller.currentState, VoiceState.idle);
        expect(controller.interimTranscript, '');
        expect(controller.finalTranscript, '');
        expect(controller.errorMessage, null);
        expect(listenerCallbacks.length, 1);
      });

      test('returns to idle from recording', () {
        controller.startRecording();
        controller.onPermissionGranted();
        controller.onTranscriptReceived('Test interim', false);
        listenerCallbacks.clear();

        controller.reset();

        expect(controller.currentState, VoiceState.idle);
        expect(controller.interimTranscript, '');
        expect(controller.finalTranscript, '');
        expect(controller.errorMessage, null);
        expect(listenerCallbacks.length, 1);
      });

      test('returns to idle from processing', () {
        controller.startRecording();
        controller.onPermissionGranted();
        controller.stopRecording();
        listenerCallbacks.clear();

        controller.reset();

        expect(controller.currentState, VoiceState.idle);
        expect(controller.interimTranscript, '');
        expect(controller.finalTranscript, '');
        expect(controller.errorMessage, null);
        expect(listenerCallbacks.length, 1);
      });

      test('returns to idle from success', () {
        controller.startRecording();
        controller.onPermissionGranted();
        controller.stopRecording();
        controller.onTranscriptReceived('Final text', true);
        listenerCallbacks.clear();

        controller.reset();

        expect(controller.currentState, VoiceState.idle);
        expect(controller.interimTranscript, '');
        expect(controller.finalTranscript, '');
        expect(controller.errorMessage, null);
        expect(listenerCallbacks.length, 1);
      });

      test('returns to idle from error', () {
        controller.startRecording();
        controller.onError('Test error');
        listenerCallbacks.clear();

        controller.reset();

        expect(controller.currentState, VoiceState.idle);
        expect(controller.interimTranscript, '');
        expect(controller.finalTranscript, '');
        expect(controller.errorMessage, null);
        expect(listenerCallbacks.length, 1);
      });

      test('can be called from idle (no-op)', () {
        expect(controller.currentState, VoiceState.idle);
        listenerCallbacks.clear();

        controller.reset();

        expect(controller.currentState, VoiceState.idle);
        expect(listenerCallbacks.length, 1);
      });
    });

    group('onTranscriptReceived()', () {
      test('updates interimTranscript when isFinal is false', () {
        controller.startRecording();
        controller.onPermissionGranted();
        listenerCallbacks.clear();

        controller.onTranscriptReceived('Hello', false);

        expect(controller.interimTranscript, 'Hello');
        expect(controller.finalTranscript, '');
        expect(controller.currentState, VoiceState.recording);
        expect(listenerCallbacks.length, 1);
      });

      test('updates interimTranscript multiple times during recording', () {
        controller.startRecording();
        controller.onPermissionGranted();
        listenerCallbacks.clear();

        controller.onTranscriptReceived('Hello', false);
        controller.onTranscriptReceived('Hello world', false);
        controller.onTranscriptReceived('Hello world how', false);

        expect(controller.interimTranscript, 'Hello world how');
        expect(controller.finalTranscript, '');
        expect(controller.currentState, VoiceState.recording);
        expect(listenerCallbacks.length, 3);
      });

      test('updates finalTranscript and transitions to success when isFinal is true', () {
        controller.startRecording();
        controller.onPermissionGranted();
        controller.stopRecording();
        listenerCallbacks.clear();

        controller.onTranscriptReceived('Final transcript', true);

        expect(controller.finalTranscript, 'Final transcript');
        expect(controller.currentState, VoiceState.success);
        expect(listenerCallbacks.length, 1);
      });

      test('final transcript does not overwrite interim transcript value', () {
        controller.startRecording();
        controller.onPermissionGranted();
        controller.onTranscriptReceived('Interim text', false);
        controller.stopRecording();
        listenerCallbacks.clear();

        controller.onTranscriptReceived('Final text', true);

        expect(controller.interimTranscript, 'Interim text');
        expect(controller.finalTranscript, 'Final text');
        expect(listenerCallbacks.length, 1);
      });

      test('can handle empty transcript strings', () {
        controller.startRecording();
        controller.onPermissionGranted();

        controller.onTranscriptReceived('', false);

        expect(controller.interimTranscript, '');
        expect(controller.finalTranscript, '');
      });
    });

    group('notifyListeners()', () {
      test('called on startRecording', () {
        listenerCallbacks.clear();
        controller.startRecording();
        expect(listenerCallbacks.length, 1);
      });

      test('called on onPermissionGranted', () {
        controller.startRecording();
        listenerCallbacks.clear();
        controller.onPermissionGranted();
        expect(listenerCallbacks.length, 1);
      });

      test('called on stopRecording', () {
        controller.startRecording();
        controller.onPermissionGranted();
        listenerCallbacks.clear();
        controller.stopRecording();
        expect(listenerCallbacks.length, 1);
      });

      test('called on reset', () {
        listenerCallbacks.clear();
        controller.reset();
        expect(listenerCallbacks.length, 1);
      });

      test('called on onTranscriptReceived with interim', () {
        controller.startRecording();
        controller.onPermissionGranted();
        listenerCallbacks.clear();
        controller.onTranscriptReceived('test', false);
        expect(listenerCallbacks.length, 1);
      });

      test('called on onTranscriptReceived with final', () {
        controller.startRecording();
        controller.onPermissionGranted();
        controller.stopRecording();
        listenerCallbacks.clear();
        controller.onTranscriptReceived('test', true);
        expect(listenerCallbacks.length, 1);
      });

      test('called on onError', () {
        controller.startRecording();
        listenerCallbacks.clear();
        controller.onError('Error message');
        expect(listenerCallbacks.length, 1);
      });
    });

    group('errorMessage storage', () {
      test('errorMessage is null initially', () {
        expect(controller.errorMessage, null);
      });

      test('errorMessage stored when onError called', () {
        controller.onError('Permission denied');
        expect(controller.errorMessage, 'Permission denied');
      });

      test('errorMessage cleared on reset', () {
        controller.onError('Some error');
        expect(controller.errorMessage, isNotNull);

        controller.reset();
        expect(controller.errorMessage, null);
      });

      test('errorMessage cleared on startRecording', () {
        controller.onError('Previous error');
        expect(controller.errorMessage, 'Previous error');

        controller.reset();
        controller.startRecording();
        expect(controller.errorMessage, null);
      });

      test('different error messages are stored correctly', () {
        controller.onError('Error 1');
        expect(controller.errorMessage, 'Error 1');

        controller.reset();
        controller.startRecording();
        controller.onError('Error 2');
        expect(controller.errorMessage, 'Error 2');
      });
    });

    group('State Guards', () {
      test('startRecording does nothing if not in idle state', () {
        controller.startRecording();
        controller.onPermissionGranted();
        listenerCallbacks.clear();

        controller.startRecording(); // Should be ignored

        expect(controller.currentState, VoiceState.recording);
        expect(listenerCallbacks.length, 0);
      });

      test('onPermissionGranted does nothing if not in requestingPermission state', () {
        controller.startRecording();
        controller.onPermissionGranted();
        listenerCallbacks.clear();

        controller.onPermissionGranted(); // Should be ignored

        expect(controller.currentState, VoiceState.recording);
        expect(listenerCallbacks.length, 0);
      });

      test('stopRecording does nothing if not in recording state', () {
        controller.startRecording();
        listenerCallbacks.clear();

        controller.stopRecording(); // Should be ignored

        expect(controller.currentState, VoiceState.requestingPermission);
        expect(listenerCallbacks.length, 0);
      });

      test('onError can be called from any state', () {
        // From idle
        controller.onError('Error from idle');
        expect(controller.currentState, VoiceState.error);

        controller.reset();
        controller.startRecording();

        // From requestingPermission
        controller.onError('Error from requesting');
        expect(controller.currentState, VoiceState.error);

        controller.reset();
        controller.startRecording();
        controller.onPermissionGranted();

        // From recording
        controller.onError('Error from recording');
        expect(controller.currentState, VoiceState.error);

        controller.reset();
        controller.startRecording();
        controller.onPermissionGranted();
        controller.stopRecording();

        // From processing
        controller.onError('Error from processing');
        expect(controller.currentState, VoiceState.error);

        controller.reset();
        controller.startRecording();
        controller.onPermissionGranted();
        controller.stopRecording();
        controller.onTranscriptReceived('test', true);

        // From success
        controller.onError('Error from success');
        expect(controller.currentState, VoiceState.error);
      });
    });

    group('Initial State', () {
      test('controller starts in idle state', () {
        expect(controller.currentState, VoiceState.idle);
      });

      test('transcripts are empty initially', () {
        expect(controller.interimTranscript, '');
        expect(controller.finalTranscript, '');
      });

      test('errorMessage is null initially', () {
        expect(controller.errorMessage, null);
      });
    });
  });
}
