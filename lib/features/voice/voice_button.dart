import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/networking/relay_client.dart';
import '../../core/crypto/key_pair.dart';
import 'voice_state.dart';
import 'audio_capture.dart';
import 'voice_relay_handler.dart';

/// UI widget for voice input with push-to-talk interaction.
///
/// VoiceButton provides a FloatingActionButton-style interface for recording
/// audio and sending it to the backend for transcription. The button uses
/// push-to-talk interaction: hold to record, release to send final transcript.
///
/// Visual States:
/// - idle: Microphone icon, primary color
/// - requestingPermission: Loading indicator, disabled
/// - recording: Microphone icon, RED color with pulsing animation
/// - processing: Loading spinner
/// - success: Checkmark icon, brief green flash
/// - error: Error icon, red, with tooltip showing error message
///
/// Usage:
/// ```dart
/// VoiceButton(
///   relayClient: relayClient,
///   ourKeys: ourKeys,
///   remoteKeys: remoteKeys,
///   onTranscriptComplete: (transcript) {
///     // Handle the final transcript
///     print('Received: $transcript');
///   },
/// )
/// ```
class VoiceButton extends StatefulWidget {
  /// The relay client for communication with backend
  final RelayClient relayClient;

  /// Our encryption keys for E2E communication
  final KeyPair ourKeys;

  /// Remote peer's encryption keys for E2E communication
  final KeyPair remoteKeys;

  /// Callback fired when final transcript is received from backend
  final Function(String) onTranscriptComplete;

  const VoiceButton({
    super.key,
    required this.relayClient,
    required this.ourKeys,
    required this.remoteKeys,
    required this.onTranscriptComplete,
  });

  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton>
    with SingleTickerProviderStateMixin {
  late VoiceController _controller;
  late AudioCaptureService _audioCapture;
  late VoiceRelayHandler _relayHandler;

  // Animation controller for pulsing recording animation
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;

  // Timer for auto-reset after success/error
  Timer? _resetTimer;

  // Track if we're currently recording
  bool _isRecording = false;

  // Store audio stream for cleanup
  Stream<Uint8List>? _audioStream;

  @override
  void initState() {
    super.initState();

    // Initialize controller and services
    _controller = VoiceController();
    _audioCapture = AudioCaptureService();
    _relayHandler = VoiceRelayHandler(
      relayClient: widget.relayClient,
      controller: _controller,
      ourKeys: widget.ourKeys,
      remoteKeys: widget.remoteKeys,
    );

    // Setup relay handler listeners for incoming messages
    _relayHandler.setupListeners();

    // Setup pulsing animation for recording state
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Listen to controller state changes
    _controller.addListener(_onControllerStateChanged);
  }

  @override
  void dispose() {
    // Cancel any pending reset timer
    _resetTimer?.cancel();

    // Stop animation
    _pulseAnimationController.dispose();

    // Remove controller listener
    _controller.removeListener(_onControllerStateChanged);

    // Dispose services
    _relayHandler.dispose();
    _audioCapture.dispose();
    _controller.dispose();

    super.dispose();
  }

  /// Handles controller state changes to trigger animations and callbacks
  void _onControllerStateChanged() {
    final state = _controller.currentState;

    // Start pulsing animation when recording starts
    if (state == VoiceState.recording && !_pulseAnimationController.isAnimating) {
      _pulseAnimationController.repeat(reverse: true);
    }

    // Stop pulsing animation when recording ends
    if (state != VoiceState.recording && _pulseAnimationController.isAnimating) {
      _pulseAnimationController.stop();
      _pulseAnimationController.reset();
    }

    // Handle final transcript on success
    if (state == VoiceState.success) {
      final transcript = _controller.finalTranscript;
      if (transcript.isNotEmpty) {
        // Fire callback within 200ms requirement
        widget.onTranscriptComplete(transcript);
      }

      // Auto-reset to idle after 1 second
      _resetTimer?.cancel();
      _resetTimer = Timer(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _controller.reset();
        }
      });
    }

    // Handle error state - auto-reset after 500ms
    if (state == VoiceState.error) {
      _resetTimer?.cancel();
      _resetTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          _controller.reset();
        }
      });
    }

    // Trigger rebuild
    if (mounted) {
      setState(() {});
    }
  }

  /// Handles long press start - begins recording
  Future<void> _onLongPressStart(LongPressStartDetails details) async {
    // Ignore if already recording or in error state
    if (_isRecording || _controller.currentState == VoiceState.error) {
      return;
    }

    try {
      // Start recording process
      _controller.startRecording();

      // Check microphone permission
      final hasPermission = await _audioCapture.requestPermission();
      if (!hasPermission) {
        _controller.onError('Microphone permission denied');
        return;
      }

      // Permission granted - update controller
      _controller.onPermissionGranted();

      // Start audio capture
      _audioStream = await _audioCapture.startRecording();

      // Send start control to backend
      await _relayHandler.startVoiceSession();

      // Stream audio frames to backend
      _relayHandler.streamAudioFrames(_audioStream!);

      _isRecording = true;
    } catch (e) {
      // Handle errors during recording start
      _controller.onError('Failed to start recording: $e');
      _isRecording = false;
    }
  }

  /// Handles long press end - stops recording and waits for final transcript
  Future<void> _onLongPressEnd(LongPressEndDetails details) async {
    if (!_isRecording) {
      return;
    }

    try {
      // Stop audio capture
      await _audioCapture.stopRecording();

      // Send stop control to backend
      await _relayHandler.stopVoiceSession();

      // Update controller to processing state (waits for final transcript)
      _controller.stopRecording();

      _isRecording = false;
    } catch (e) {
      // Handle errors during recording stop
      _controller.onError('Failed to stop recording: $e');
      _isRecording = false;
    }
  }

  /// Handles long press cancel - cancels recording
  Future<void> _onLongPressCancel() async {
    if (!_isRecording) {
      return;
    }

    try {
      // Stop audio capture
      await _audioCapture.stopRecording();

      // Send cancel control to backend (optional, but cleaner)
      try {
        await _relayHandler.cancelVoiceSession();
      } catch (_) {
        // Ignore cancel errors - we're already canceling
      }

      // Reset controller to idle
      _controller.reset();

      _isRecording = false;
    } catch (e) {
      // Handle errors during cancel
      _controller.onError('Failed to cancel recording: $e');
      _isRecording = false;
    }
  }

  /// Handles tap on error state - dismisses error and resets
  void _onTapError() {
    if (_controller.currentState == VoiceState.error) {
      _controller.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = _controller.currentState;

    return Tooltip(
      message: _getTooltipMessage(state),
      child: ScaleTransition(
        scale: state == VoiceState.recording ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
        child: ScaleTransition(
          scale: state == VoiceState.success
              ? _buildSuccessBounceAnimation()
              : const AlwaysStoppedAnimation(1.0),
          child: GestureDetector(
            onLongPressStart: state == VoiceState.idle ? _onLongPressStart : null,
            onLongPressEnd: _isRecording ? _onLongPressEnd : null,
            onLongPressCancel: _isRecording ? _onLongPressCancel : null,
            onTap: state == VoiceState.error ? _onTapError : null,
            child: FloatingActionButton(
              onPressed: () {}, // Prevent default behavior, use GestureDetector instead
              backgroundColor: _getBackgroundColor(state, theme),
              foregroundColor: Colors.white,
              elevation: 6,
              child: _buildIcon(state),
            ),
          ),
        ),
      ),
    );
  }

  /// Gets the tooltip message based on current state
  String _getTooltipMessage(VoiceState state) {
    switch (state) {
      case VoiceState.idle:
        return 'Hold to record voice input';
      case VoiceState.requestingPermission:
        return 'Requesting microphone permission...';
      case VoiceState.recording:
        return 'Recording... Release to send';
      case VoiceState.processing:
        return 'Processing audio...';
      case VoiceState.success:
        return 'Transcript received!';
      case VoiceState.error:
        return _controller.errorMessage ?? 'Error occurred';
    }
  }

  /// Gets the background color based on current state
  Color _getBackgroundColor(VoiceState state, ThemeData theme) {
    switch (state) {
      case VoiceState.idle:
        return theme.colorScheme.primary;
      case VoiceState.requestingPermission:
        return theme.colorScheme.primary.withValues(alpha: 0.5);
      case VoiceState.recording:
        return Colors.red;
      case VoiceState.processing:
        return theme.colorScheme.primary;
      case VoiceState.success:
        return Colors.green;
      case VoiceState.error:
        return Colors.red;
    }
  }

  /// Builds the icon based on current state
  Widget _buildIcon(VoiceState state) {
    switch (state) {
      case VoiceState.idle:
        return const Icon(Icons.mic, size: 28);
      case VoiceState.requestingPermission:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
      case VoiceState.recording:
        return const Icon(Icons.mic, size: 28);
      case VoiceState.processing:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
      case VoiceState.success:
        return const Icon(Icons.check, size: 28);
      case VoiceState.error:
        return const Icon(Icons.error, size: 28);
    }
  }

  /// Builds the success bounce animation
  Animation<double> _buildSuccessBounceAnimation() {
    // Create a temporary animation controller for success bounce
    // This is a simple approach - in production you might want to manage this differently
    return TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: const Interval(0.0, 1.0),
      ),
    );
  }
}
