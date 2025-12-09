import 'package:flutter/foundation.dart';

/// Represents the UI state of the voice recording interface.
///
/// This is LOCAL UI STATE ONLY - no business logic or Deepgram integration.
/// Backend handles all transcription logic via RemoteAgents workflows.
enum VoiceState {
  /// Ready to record. Initial state before any recording has started.
  idle,

  /// Awaiting microphone permission from the user.
  /// Transitions to [recording] on permission granted, or [error] on denial.
  requestingPermission,

  /// Actively capturing audio. Microphone is on and recording user speech.
  /// Interim transcripts may be received from backend during this state.
  recording,

  /// Waiting for final transcript from backend after recording has stopped.
  /// Recording has ended but backend is still processing the audio.
  processing,

  /// Transcript received successfully from backend.
  /// Final transcript is now available.
  success,

  /// Permission denied or backend error occurred.
  /// Error details are available via [VoiceController.errorMessage].
  error,
}

/// Manages the UI state for voice recording.
///
/// This controller handles state transitions and transcript updates for the
/// voice UI. It does NOT handle audio capture or Deepgram integration -
/// those responsibilities belong to other components.
///
/// State transitions:
/// - idle -> requestingPermission (on start)
/// - requestingPermission -> recording (on permission granted)
/// - requestingPermission -> error (on permission denied)
/// - recording -> processing (on stop)
/// - processing -> success (on final transcript)
/// - processing -> error (on backend error)
/// - any state -> idle (on reset)
class VoiceController extends ChangeNotifier {
  VoiceState _currentState = VoiceState.idle;
  String _interimTranscript = '';
  String _finalTranscript = '';
  String? _errorMessage;

  /// The current UI state of the voice recording interface.
  VoiceState get currentState => _currentState;

  /// Live text from backend, updated in real-time during recording.
  /// This represents partial transcription results that may change.
  String get interimTranscript => _interimTranscript;

  /// Completed text from backend after recording is finished.
  /// This is the final, stable transcription result.
  String get finalTranscript => _finalTranscript;

  /// Error details if [currentState] is [VoiceState.error].
  /// Null if no error has occurred.
  String? get errorMessage => _errorMessage;

  /// Starts the recording process.
  ///
  /// Transitions from [VoiceState.idle] to [VoiceState.requestingPermission].
  /// The actual permission request and state progression to [VoiceState.recording]
  /// should be triggered by external audio capture logic.
  void startRecording() {
    if (_currentState != VoiceState.idle) {
      return;
    }

    _currentState = VoiceState.requestingPermission;
    _interimTranscript = '';
    _finalTranscript = '';
    _errorMessage = null;
    notifyListeners();
  }

  /// Called when microphone permission is granted.
  ///
  /// Transitions from [VoiceState.requestingPermission] to [VoiceState.recording].
  void onPermissionGranted() {
    if (_currentState != VoiceState.requestingPermission) {
      return;
    }

    _currentState = VoiceState.recording;
    notifyListeners();
  }

  /// Stops the recording process.
  ///
  /// Transitions from [VoiceState.recording] to [VoiceState.processing].
  /// Backend will now process the audio and send the final transcript.
  void stopRecording() {
    if (_currentState != VoiceState.recording) {
      return;
    }

    _currentState = VoiceState.processing;
    notifyListeners();
  }

  /// Resets the controller to its initial state.
  ///
  /// Can be called from any state to return to [VoiceState.idle].
  /// Clears all transcripts and error messages.
  void reset() {
    _currentState = VoiceState.idle;
    _interimTranscript = '';
    _finalTranscript = '';
    _errorMessage = null;
    notifyListeners();
  }

  /// Updates the transcript received from backend.
  ///
  /// If [isFinal] is false, updates [interimTranscript] with live results.
  /// If [isFinal] is true, updates [finalTranscript] and transitions to
  /// [VoiceState.success].
  ///
  /// Parameters:
  /// - [text]: The transcript text from backend
  /// - [isFinal]: Whether this is the final transcript or an interim result
  void onTranscriptReceived(String text, bool isFinal) {
    if (isFinal) {
      _finalTranscript = text;
      _currentState = VoiceState.success;
    } else {
      _interimTranscript = text;
    }
    notifyListeners();
  }

  /// Handles errors from permission denial or backend failures.
  ///
  /// Transitions to [VoiceState.error] and stores the error message.
  /// Can be called from [VoiceState.requestingPermission] (permission denied)
  /// or [VoiceState.processing] (backend error).
  ///
  /// Parameters:
  /// - [message]: Description of the error that occurred
  void onError(String message) {
    _errorMessage = message;
    _currentState = VoiceState.error;
    notifyListeners();
  }
}
