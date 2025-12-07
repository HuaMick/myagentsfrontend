import 'package:flutter/foundation.dart';

/// Connection status for remote terminal display.
///
/// This is separate from the networking ConnectionState to provide
/// terminal-specific status information to the UI.
enum RemoteTerminalConnectionStatus {
  /// Not connected to any remote terminal
  disconnected,

  /// Connection attempt is in progress
  connecting,

  /// Successfully connected and terminal is active
  connected,

  /// A connection error has occurred
  error,
}

/// Manages remote terminal display state with Provider-based state management.
///
/// RemoteTerminalState provides reactive state updates for the terminal UI including:
/// - Connection status (disconnected, connecting, connected, error)
/// - Terminal dimensions (rows and columns)
/// - Error messages for connection failures
///
/// Usage:
/// ```dart
/// // In widget tree
/// Consumer<RemoteTerminalState>(
///   builder: (context, state, child) {
///     if (state.isConnected) {
///       return TerminalView(...);
///     }
///     return CircularProgressIndicator();
///   },
/// )
/// ```
class RemoteTerminalState extends ChangeNotifier {
  RemoteTerminalConnectionStatus _connectionStatus =
      RemoteTerminalConnectionStatus.disconnected;
  int _rows = 24;
  int _cols = 80;
  String? _errorMessage;

  /// Gets the current connection status.
  RemoteTerminalConnectionStatus get connectionStatus => _connectionStatus;

  /// Gets the current terminal row count.
  int get rows => _rows;

  /// Gets the current terminal column count.
  int get cols => _cols;

  /// Gets the last error message, if any.
  String? get errorMessage => _errorMessage;

  /// Checks if terminal is connected.
  bool get isConnected =>
      _connectionStatus == RemoteTerminalConnectionStatus.connected;

  /// Checks if terminal is connecting.
  bool get isConnecting =>
      _connectionStatus == RemoteTerminalConnectionStatus.connecting;

  /// Checks if terminal has an error.
  bool get hasError => _connectionStatus == RemoteTerminalConnectionStatus.error;

  /// Checks if terminal is disconnected.
  bool get isDisconnected =>
      _connectionStatus == RemoteTerminalConnectionStatus.disconnected;

  /// Sets the connection status.
  ///
  /// Notifies listeners when the status changes.
  void setConnectionStatus(RemoteTerminalConnectionStatus status) {
    if (_connectionStatus != status) {
      _connectionStatus = status;
      if (status != RemoteTerminalConnectionStatus.error) {
        _errorMessage = null;
      }
      notifyListeners();
    }
  }

  /// Sets the terminal dimensions.
  ///
  /// Args:
  ///   rows: Number of terminal rows (min: 1)
  ///   cols: Number of terminal columns (min: 1)
  ///
  /// Notifies listeners when dimensions change.
  void setTerminalSize(int rows, int cols) {
    final newRows = rows.clamp(1, 1000);
    final newCols = cols.clamp(1, 1000);

    if (_rows != newRows || _cols != newCols) {
      _rows = newRows;
      _cols = newCols;
      notifyListeners();
    }
  }

  /// Sets an error message and transitions to error state.
  ///
  /// Args:
  ///   message: The error message to display
  void setError(String message) {
    _errorMessage = message;
    _connectionStatus = RemoteTerminalConnectionStatus.error;
    notifyListeners();
  }

  /// Clears the error message.
  ///
  /// Does not change the connection status; call setConnectionStatus
  /// separately if needed.
  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Resets the terminal state to initial values.
  void reset() {
    _connectionStatus = RemoteTerminalConnectionStatus.disconnected;
    _rows = 24;
    _cols = 80;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  String toString() {
    return 'TerminalState(status: $_connectionStatus, '
        'size: ${_cols}x$_rows, '
        'error: $_errorMessage)';
  }
}
