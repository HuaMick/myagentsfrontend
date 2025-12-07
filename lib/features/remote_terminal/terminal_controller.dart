import 'dart:async';
import 'package:xterm/xterm.dart' as xterm;
import '../../core/networking/relay_client.dart';
import '../../core/crypto/key_pair.dart';
import '../../core/crypto/message_envelope.dart';
import 'terminal_state.dart';

/// Manages terminal lifecycle and bridges xterm widget with RelayClient.
///
/// RemoteTerminalController handles:
/// - Terminal instance management (create, resize, dispose)
/// - Message routing between xterm and RelayClient
/// - Encryption/decryption of terminal I/O
/// - Terminal event propagation (output, input, resize)
///
/// Usage:
/// ```dart
/// final controller = RemoteTerminalController(
///   relayClient: relayClient,
///   ourKeys: ourKeys,
///   remoteKeys: remoteKeys,
///   terminalState: terminalState,
/// );
///
/// // In widget
/// TerminalView(controller.terminal)
///
/// // Cleanup
/// controller.dispose();
/// ```
class RemoteTerminalController {
  /// The xterm Terminal instance for rendering.
  final xterm.Terminal terminal;

  /// The relay client for network communication.
  final RelayClient relayClient;

  /// Our encryption keys.
  final KeyPair ourKeys;

  /// Remote peer's encryption keys.
  final KeyPair remoteKeys;

  /// Terminal state manager for UI updates.
  final RemoteTerminalState terminalState;

  /// Subscription for relay messages.
  StreamSubscription<MessageEnvelope>? _messageSubscription;

  /// Flag to track if controller has been disposed.
  bool _disposed = false;

  /// Creates a RemoteTerminalController with the specified dependencies.
  ///
  /// Args:
  ///   relayClient: The relay client for network communication
  ///   ourKeys: Our encryption key pair
  ///   remoteKeys: Remote peer's encryption key pair
  ///   terminalState: Terminal state manager for UI updates
  ///   rows: Initial terminal rows (default: 24)
  ///   cols: Initial terminal columns (default: 80)
  RemoteTerminalController({
    required this.relayClient,
    required this.ourKeys,
    required this.remoteKeys,
    required this.terminalState,
    int rows = 24,
    int cols = 80,
  }) : terminal = xterm.Terminal(maxLines: 10000) {
    _initialize(rows, cols);
  }

  /// Initializes the controller by setting up subscriptions.
  void _initialize(int rows, int cols) {
    // Set initial terminal size
    terminal.resize(cols, rows);
    terminalState.setTerminalSize(rows, cols);

    // Subscribe to relay messages for terminal output
    _messageSubscription = relayClient.terminalOutputStream.listen(
      _onRelayMessage,
      onError: _onRelayError,
    );

    // Set up terminal output handler for user input
    terminal.onOutput = (String data) {
      if (!_disposed) {
        _onTerminalInput(data);
      }
    };

    // Update terminal state to connected if relay is connected
    if (relayClient.isConnected) {
      terminalState.setConnectionStatus(RemoteTerminalConnectionStatus.connected);
    }
  }

  /// Handles incoming terminal output messages from relay.
  ///
  /// Decrypts the message payload and writes to terminal buffer.
  void _onRelayMessage(MessageEnvelope envelope) {
    if (_disposed) return;

    try {
      // Decrypt the message payload
      final payload = envelope.open(ourKeys, remoteKeys);

      // Extract terminal output from payload
      final output = payload['output'] as String?;
      if (output != null && output.isNotEmpty) {
        terminal.write(output);
      }
    } catch (e) {
      // Log decryption error but don't crash
      // Display error in terminal for visibility
      terminal.write('\r\n[Error: Failed to decrypt message: $e]\r\n');
      terminalState.setError('Decryption failed: $e');
    }
  }

  /// Handles relay errors.
  void _onRelayError(dynamic error) {
    if (_disposed) return;

    terminalState.setError('Relay error: $error');
    terminal.write('\r\n[Connection error: $error]\r\n');
  }

  /// Handles user input from terminal and sends to relay.
  ///
  /// Encrypts the input and sends as terminal_input message.
  void _onTerminalInput(String input) {
    if (_disposed) return;

    if (!relayClient.isConnected) {
      // Don't send if not connected
      return;
    }

    try {
      // Send terminal input to relay
      relayClient.sendTerminalInput(input).catchError((e) {
        terminalState.setError('Failed to send input: $e');
      });
    } catch (e) {
      terminalState.setError('Failed to encrypt input: $e');
    }
  }

  /// Resizes the terminal and notifies the relay.
  ///
  /// Args:
  ///   rows: New number of terminal rows
  ///   cols: New number of terminal columns
  void resize(int rows, int cols) {
    if (_disposed) return;

    // Update terminal dimensions
    terminal.resize(cols, rows);
    terminalState.setTerminalSize(rows, cols);

    // Send resize message to relay if connected
    if (relayClient.isConnected) {
      relayClient.sendResize(rows, cols).catchError((e) {
        // Log but don't fail on resize error
        terminalState.setError('Failed to send resize: $e');
      });
    }
  }

  /// Writes text directly to the terminal.
  ///
  /// Useful for displaying local messages or notifications.
  void writeLocal(String text) {
    if (!_disposed) {
      terminal.write(text);
    }
  }

  /// Clears the terminal screen.
  void clear() {
    if (!_disposed) {
      terminal.write('\x1b[2J\x1b[H');
    }
  }

  /// Disposes of the controller and releases resources.
  ///
  /// Cancels all stream subscriptions and marks as disposed.
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    // Cancel relay message subscription
    _messageSubscription?.cancel();
    _messageSubscription = null;

    // Clear terminal output handler
    terminal.onOutput = null;
  }

  @override
  String toString() {
    return 'RemoteTerminalController(disposed: $_disposed, '
        'connected: ${relayClient.isConnected}, '
        'size: ${terminalState.cols}x${terminalState.rows})';
  }
}
