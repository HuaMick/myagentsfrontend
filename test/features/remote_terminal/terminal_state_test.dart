import 'package:flutter_test/flutter_test.dart';
import 'package:myagents_frontend/features/remote_terminal/terminal_state.dart';

void main() {
  group('RemoteTerminalConnectionStatus enum', () {
    test('should have all 4 values: disconnected, connecting, connected, error',
        () {
      expect(RemoteTerminalConnectionStatus.values.length, 4);
      expect(RemoteTerminalConnectionStatus.values,
          contains(RemoteTerminalConnectionStatus.disconnected));
      expect(RemoteTerminalConnectionStatus.values,
          contains(RemoteTerminalConnectionStatus.connecting));
      expect(RemoteTerminalConnectionStatus.values,
          contains(RemoteTerminalConnectionStatus.connected));
      expect(RemoteTerminalConnectionStatus.values,
          contains(RemoteTerminalConnectionStatus.error));
    });
  });

  group('RemoteTerminalState constructor and initial state', () {
    test('should initialize with disconnected status', () {
      final state = RemoteTerminalState();
      expect(
          state.connectionStatus, RemoteTerminalConnectionStatus.disconnected);
    });

    test('should initialize with default terminal size 24x80', () {
      final state = RemoteTerminalState();
      expect(state.rows, 24);
      expect(state.cols, 80);
    });

    test('should initialize with null error message', () {
      final state = RemoteTerminalState();
      expect(state.errorMessage, isNull);
    });

    test('should initialize with isDisconnected true', () {
      final state = RemoteTerminalState();
      expect(state.isDisconnected, isTrue);
      expect(state.isConnected, isFalse);
      expect(state.isConnecting, isFalse);
      expect(state.hasError, isFalse);
    });
  });

  group('setConnectionStatus()', () {
    test('should update connection status and notify listeners', () {
      final state = RemoteTerminalState();
      int callCount = 0;
      state.addListener(() => callCount++);

      state.setConnectionStatus(RemoteTerminalConnectionStatus.connecting);

      expect(
          state.connectionStatus, RemoteTerminalConnectionStatus.connecting);
      expect(callCount, 1);
    });

    test('should not notify listeners when status is unchanged', () {
      final state = RemoteTerminalState();
      int callCount = 0;
      state.addListener(() => callCount++);

      // Set to same status (disconnected)
      state.setConnectionStatus(RemoteTerminalConnectionStatus.disconnected);

      expect(callCount, 0);
    });

    test('should clear error message when transitioning to non-error state',
        () {
      final state = RemoteTerminalState();
      state.setError('Test error');
      expect(state.errorMessage, 'Test error');

      state.setConnectionStatus(RemoteTerminalConnectionStatus.connecting);

      expect(state.errorMessage, isNull);
    });

    test('should preserve error message when transitioning to error state', () {
      final state = RemoteTerminalState();
      state.setError('Test error');

      state.setConnectionStatus(RemoteTerminalConnectionStatus.error);

      // No change since already in error state
      expect(state.errorMessage, 'Test error');
    });

    test('should transition through all states correctly', () {
      final state = RemoteTerminalState();
      int callCount = 0;
      state.addListener(() => callCount++);

      state.setConnectionStatus(RemoteTerminalConnectionStatus.connecting);
      expect(state.isConnecting, isTrue);
      expect(callCount, 1);

      state.setConnectionStatus(RemoteTerminalConnectionStatus.connected);
      expect(state.isConnected, isTrue);
      expect(callCount, 2);

      state.setConnectionStatus(RemoteTerminalConnectionStatus.error);
      expect(state.hasError, isTrue);
      expect(callCount, 3);

      state.setConnectionStatus(RemoteTerminalConnectionStatus.disconnected);
      expect(state.isDisconnected, isTrue);
      expect(callCount, 4);
    });
  });

  group('setTerminalSize()', () {
    test('should update rows and cols and notify listeners', () {
      final state = RemoteTerminalState();
      int callCount = 0;
      state.addListener(() => callCount++);

      state.setTerminalSize(30, 100);

      expect(state.rows, 30);
      expect(state.cols, 100);
      expect(callCount, 1);
    });

    test('should not notify listeners when size is unchanged', () {
      final state = RemoteTerminalState();
      int callCount = 0;
      state.addListener(() => callCount++);

      // Set to same size (24x80)
      state.setTerminalSize(24, 80);

      expect(callCount, 0);
    });

    test('should clamp rows to minimum of 1', () {
      final state = RemoteTerminalState();
      state.setTerminalSize(0, 80);
      expect(state.rows, 1);

      state.setTerminalSize(-5, 80);
      expect(state.rows, 1);
    });

    test('should clamp cols to minimum of 1', () {
      final state = RemoteTerminalState();
      state.setTerminalSize(24, 0);
      expect(state.cols, 1);

      state.setTerminalSize(24, -10);
      expect(state.cols, 1);
    });

    test('should clamp rows to maximum of 1000', () {
      final state = RemoteTerminalState();
      state.setTerminalSize(2000, 80);
      expect(state.rows, 1000);
    });

    test('should clamp cols to maximum of 1000', () {
      final state = RemoteTerminalState();
      state.setTerminalSize(24, 2000);
      expect(state.cols, 1000);
    });

    test('should clamp both dimensions simultaneously', () {
      final state = RemoteTerminalState();
      state.setTerminalSize(0, 2000);
      expect(state.rows, 1);
      expect(state.cols, 1000);

      state.setTerminalSize(5000, -100);
      expect(state.rows, 1000);
      expect(state.cols, 1);
    });

    test('should accept boundary values 1 and 1000', () {
      final state = RemoteTerminalState();

      state.setTerminalSize(1, 1);
      expect(state.rows, 1);
      expect(state.cols, 1);

      state.setTerminalSize(1000, 1000);
      expect(state.rows, 1000);
      expect(state.cols, 1000);
    });

    test('should notify only once when both dimensions change', () {
      final state = RemoteTerminalState();
      int callCount = 0;
      state.addListener(() => callCount++);

      state.setTerminalSize(50, 120);
      expect(callCount, 1);
    });
  });

  group('setError()', () {
    test('should set error message and transition to error state', () {
      final state = RemoteTerminalState();
      int callCount = 0;
      state.addListener(() => callCount++);

      state.setError('Connection failed');

      expect(state.errorMessage, 'Connection failed');
      expect(state.connectionStatus, RemoteTerminalConnectionStatus.error);
      expect(state.hasError, isTrue);
      expect(callCount, 1);
    });

    test('should overwrite previous error message', () {
      final state = RemoteTerminalState();
      state.setError('First error');
      state.setError('Second error');

      expect(state.errorMessage, 'Second error');
    });

    test('should notify listeners even when already in error state', () {
      final state = RemoteTerminalState();
      int callCount = 0;
      state.setError('First error');
      state.addListener(() => callCount++);

      state.setError('Second error');

      expect(callCount, 1);
    });

    test('should handle empty error message', () {
      final state = RemoteTerminalState();
      state.setError('');

      expect(state.errorMessage, '');
      expect(state.hasError, isTrue);
    });
  });

  group('clearError()', () {
    test('should clear error message and notify listeners', () {
      final state = RemoteTerminalState();
      state.setError('Test error');
      int callCount = 0;
      state.addListener(() => callCount++);

      state.clearError();

      expect(state.errorMessage, isNull);
      expect(callCount, 1);
    });

    test('should not notify listeners when error is already null', () {
      final state = RemoteTerminalState();
      int callCount = 0;
      state.addListener(() => callCount++);

      state.clearError();

      expect(callCount, 0);
    });

    test('should not change connection status', () {
      final state = RemoteTerminalState();
      state.setError('Test error');
      expect(state.hasError, isTrue);

      state.clearError();

      // Status remains error, only message is cleared
      expect(state.connectionStatus, RemoteTerminalConnectionStatus.error);
      expect(state.errorMessage, isNull);
    });
  });

  group('reset()', () {
    test('should reset all state to initial values', () {
      final state = RemoteTerminalState();
      // Modify all state
      state.setConnectionStatus(RemoteTerminalConnectionStatus.connected);
      state.setTerminalSize(50, 120);
      state.setError('Test error');

      state.reset();

      expect(
          state.connectionStatus, RemoteTerminalConnectionStatus.disconnected);
      expect(state.rows, 24);
      expect(state.cols, 80);
      expect(state.errorMessage, isNull);
    });

    test('should notify listeners', () {
      final state = RemoteTerminalState();
      state.setConnectionStatus(RemoteTerminalConnectionStatus.connected);
      int callCount = 0;
      state.addListener(() => callCount++);

      state.reset();

      expect(callCount, 1);
    });

    test('should notify listeners even when already at initial state', () {
      final state = RemoteTerminalState();
      int callCount = 0;
      state.addListener(() => callCount++);

      state.reset();

      // reset() always notifies
      expect(callCount, 1);
    });
  });

  group('Getter shortcuts', () {
    test('isConnected should return true only when connected', () {
      final state = RemoteTerminalState();

      expect(state.isConnected, isFalse);

      state.setConnectionStatus(RemoteTerminalConnectionStatus.connecting);
      expect(state.isConnected, isFalse);

      state.setConnectionStatus(RemoteTerminalConnectionStatus.connected);
      expect(state.isConnected, isTrue);

      state.setConnectionStatus(RemoteTerminalConnectionStatus.error);
      expect(state.isConnected, isFalse);
    });

    test('isConnecting should return true only when connecting', () {
      final state = RemoteTerminalState();

      expect(state.isConnecting, isFalse);

      state.setConnectionStatus(RemoteTerminalConnectionStatus.connecting);
      expect(state.isConnecting, isTrue);

      state.setConnectionStatus(RemoteTerminalConnectionStatus.connected);
      expect(state.isConnecting, isFalse);
    });

    test('hasError should return true only when in error state', () {
      final state = RemoteTerminalState();

      expect(state.hasError, isFalse);

      state.setError('Test error');
      expect(state.hasError, isTrue);

      state.setConnectionStatus(RemoteTerminalConnectionStatus.disconnected);
      expect(state.hasError, isFalse);
    });

    test('isDisconnected should return true only when disconnected', () {
      final state = RemoteTerminalState();

      expect(state.isDisconnected, isTrue);

      state.setConnectionStatus(RemoteTerminalConnectionStatus.connecting);
      expect(state.isDisconnected, isFalse);

      state.setConnectionStatus(RemoteTerminalConnectionStatus.disconnected);
      expect(state.isDisconnected, isTrue);
    });
  });

  group('toString()', () {
    test('should return formatted string representation', () {
      final state = RemoteTerminalState();
      final result = state.toString();

      expect(result, contains('TerminalState('));
      expect(result,
          contains('status: RemoteTerminalConnectionStatus.disconnected'));
      expect(result, contains('size: 80x24'));
      expect(result, contains('error: null'));
    });

    test('should include error message when present', () {
      final state = RemoteTerminalState();
      state.setError('Connection timeout');
      final result = state.toString();

      expect(result, contains('error: Connection timeout'));
    });

    test('should reflect current terminal size', () {
      final state = RemoteTerminalState();
      state.setTerminalSize(50, 120);
      final result = state.toString();

      expect(result, contains('size: 120x50'));
    });
  });

  group('ChangeNotifier integration', () {
    test('should allow adding multiple listeners', () {
      final state = RemoteTerminalState();
      int listener1Count = 0;
      int listener2Count = 0;

      state.addListener(() => listener1Count++);
      state.addListener(() => listener2Count++);

      state.setConnectionStatus(RemoteTerminalConnectionStatus.connecting);

      expect(listener1Count, 1);
      expect(listener2Count, 1);
    });

    test('should allow removing listeners', () {
      final state = RemoteTerminalState();
      int callCount = 0;
      void listener() => callCount++;

      state.addListener(listener);
      state.setConnectionStatus(RemoteTerminalConnectionStatus.connecting);
      expect(callCount, 1);

      state.removeListener(listener);
      state.setConnectionStatus(RemoteTerminalConnectionStatus.connected);
      expect(callCount, 1); // No additional calls
    });

    test('should handle dispose correctly', () {
      final state = RemoteTerminalState();
      int callCount = 0;
      state.addListener(() => callCount++);

      state.dispose();

      // After dispose, adding listeners or notifying should throw
      expect(() => state.addListener(() {}), throwsFlutterError);
    });
  });

  group('Edge cases', () {
    test('should handle rapid state changes', () {
      final state = RemoteTerminalState();
      final statuses = <RemoteTerminalConnectionStatus>[];
      state.addListener(() => statuses.add(state.connectionStatus));

      state.setConnectionStatus(RemoteTerminalConnectionStatus.connecting);
      state.setConnectionStatus(RemoteTerminalConnectionStatus.connected);
      state.setConnectionStatus(RemoteTerminalConnectionStatus.error);
      state.setConnectionStatus(RemoteTerminalConnectionStatus.disconnected);

      expect(statuses, [
        RemoteTerminalConnectionStatus.connecting,
        RemoteTerminalConnectionStatus.connected,
        RemoteTerminalConnectionStatus.error,
        RemoteTerminalConnectionStatus.disconnected,
      ]);
    });

    test('should handle terminal size of exactly 1', () {
      final state = RemoteTerminalState();
      state.setTerminalSize(1, 1);
      expect(state.rows, 1);
      expect(state.cols, 1);
    });

    test('should handle terminal size of exactly 1000', () {
      final state = RemoteTerminalState();
      state.setTerminalSize(1000, 1000);
      expect(state.rows, 1000);
      expect(state.cols, 1000);
    });

    test('should handle error with special characters', () {
      final state = RemoteTerminalState();
      const errorWithSpecialChars =
          'Error: Connection failed! @#\$%^&*() <script>alert("xss")</script>';
      state.setError(errorWithSpecialChars);
      expect(state.errorMessage, errorWithSpecialChars);
    });

    test('should handle error with unicode characters', () {
      final state = RemoteTerminalState();
      const unicodeError = 'Connection failed: 连接失败 🔌❌';
      state.setError(unicodeError);
      expect(state.errorMessage, unicodeError);
    });

    test('should handle very long error message', () {
      final state = RemoteTerminalState();
      final longError = 'Error: ' + 'x' * 10000;
      state.setError(longError);
      expect(state.errorMessage, longError);
    });
  });
}
