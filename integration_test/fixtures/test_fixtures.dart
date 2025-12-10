import 'package:myagents_frontend/core/crypto/key_pair.dart';

/// Test pairing codes for E2E browser testing.
///
/// Pairing codes are 6 uppercase alphanumeric characters used to establish
/// secure connections between the client and relay server.
class TestPairingCodes {
  /// A valid pairing code for testing successful connections
  static const String valid = 'ABCD12';

  /// A second valid pairing code for testing multiple connections
  static const String valid2 = 'XYZ789';

  /// An invalid pairing code (lowercase, too short)
  static const String invalid = 'abc';

  /// An invalid pairing code containing special characters
  static const String special = 'AB!@12';

  /// An invalid pairing code that is too long
  static const String tooLong = 'ABCDEFG';

  /// An empty pairing code
  static const String empty = '';
}

/// Pre-generated X25519 key pairs for deterministic testing.
///
/// These keys use NaCl/X25519 cryptography and are stored as Base64-encoded
/// 32-byte values. Using pre-generated keys ensures test reproducibility.
class TestKeyPairs {
  /// Alice's key pair for testing client-side encryption
  ///
  /// Private key: 32 bytes (Base64)
  /// Public key: 32 bytes (Base64) derived from private key
  static KeyPair get aliceKeys => KeyPair.fromBase64({
        'privateKey': 'YJ0UcVhQQrLqkZ7xN3xKHqMxGvRqZxJKQGkCqH9WC2Q=',
        'publicKey': 'LxR2H0Y4P+hLJ7JQqKZOGd2qF8mXJWKqF6YvZQkZ4Hs=',
      });

  /// Bob's key pair for testing relay/agent-side encryption
  ///
  /// Private key: 32 bytes (Base64)
  /// Public key: 32 bytes (Base64) derived from private key
  static KeyPair get bobKeys => KeyPair.fromBase64({
        'privateKey': 'eH5YcRhLLrNqZ7xK3xNHqMxGvRqZxJKQGkCqH9WC2Y=',
        'publicKey': 'M8S3J1Z5Q/iMK8KRrLaPHe3rG9nYKXLrG7ZwaTla5It=',
      });

  /// Charlie's key pair for testing three-way scenarios
  ///
  /// Private key: 32 bytes (Base64)
  /// Public key: 32 bytes (Base64) derived from private key
  static KeyPair get charlieKeys => KeyPair.fromBase64({
        'privateKey': 'iI6ZdSiMMsOrbx8L4yOIrNyHwSrbySLRHlDrsI8XD3Z=',
        'publicKey': 'N9T4K2a6R/jNL9LSsMbQIf4sH+oZLYMsH8axbUmb6Ju=',
      });

  /// Generates a new random key pair for testing scenarios that need unique keys
  ///
  /// This is useful for tests that require non-deterministic key generation
  /// or when testing key generation functionality itself.
  static KeyPair generateRandom() => KeyPair.generate();
}

/// Test terminal messages with various PTY output scenarios.
///
/// These messages simulate real terminal output including ANSI escape codes
/// for colors, cursor positioning, and screen manipulation.
class TestTerminalMessages {
  /// Simple terminal output without formatting
  static const String simpleOutput = 'Hello, World!\n';

  /// Terminal output with ANSI color codes (green text)
  static const String withAnsi = '\x1b[32mGreen text\x1b[0m';

  /// Multi-line terminal output
  static const String multiLine = 'Line 1\nLine 2\nLine 3\n';

  /// Typical shell prompt
  static const String prompt = r'user@host:~$ ';

  /// ANSI code to clear screen and move cursor to home
  static const String clearScreen = '\x1b[2J\x1b[H';

  /// ANSI codes for bold red error text
  static const String errorText = '\x1b[1;31mError: Command failed\x1b[0m\n';

  /// Command execution example
  static const String commandExecution = r'user@host:~$ ls -la' '\n';

  /// Directory listing output
  static const String directoryListing = '''
total 24
drwxr-xr-x 3 user user 4096 Dec  9 12:00 .
drwxr-xr-x 5 user user 4096 Dec  9 11:00 ..
-rw-r--r-- 1 user user  220 Dec  9 12:00 .bashrc
drwxr-xr-x 2 user user 4096 Dec  9 12:00 Documents
-rw-r--r-- 1 user user  807 Dec  9 12:00 .profile
''';

  /// Long output that might require scrolling
  static const String longOutput = '''
Line 1
Line 2
Line 3
Line 4
Line 5
Line 6
Line 7
Line 8
Line 9
Line 10
Line 11
Line 12
Line 13
Line 14
Line 15
Line 16
Line 17
Line 18
Line 19
Line 20
''';

  /// Terminal resize sequence
  static const String resizeSequence = '\x1b[8;24;80t';

  /// Cursor movement and text at specific position
  static const String cursorPositioning = '\x1b[5;10H' 'Text at row 5, col 10';

  /// Progress bar with ANSI codes
  static const String progressBar =
      '\x1b[32m[##########          ] 50%\x1b[0m\r';

  /// Tab character handling
  static const String withTabs = 'Column1\tColumn2\tColumn3\n';

  /// Carriage return without newline (overwriting)
  static const String carriageReturn = 'Loading...\rComplete!';

  /// Backspace characters
  static const String withBackspace = 'Helllo\b\bo';
}

/// Test error messages for various failure scenarios.
///
/// These messages represent common error conditions in the RemoteAgents
/// protocol and connection lifecycle.
class TestErrorMessages {
  /// Connection failed to establish
  static const String connectionFailed = 'Failed to connect';

  /// Connection timeout occurred
  static const String timeout = 'Connection timeout';

  /// Invalid pairing code provided
  static const String invalidCode = 'Invalid pairing code';

  /// Disconnected from server
  static const String disconnected = 'Disconnected from server';

  /// WebSocket connection error
  static const String websocketError = 'WebSocket connection error';

  /// Encryption error
  static const String encryptionError = 'Failed to encrypt message';

  /// Decryption error
  static const String decryptionError = 'Failed to decrypt message';

  /// Authentication failed
  static const String authenticationFailed = 'Authentication failed';

  /// Server unavailable
  static const String serverUnavailable = 'Server is unavailable';

  /// Network error
  static const String networkError = 'Network error occurred';

  /// Invalid message format
  static const String invalidMessage = 'Invalid message format';

  /// Session expired
  static const String sessionExpired = 'Session has expired';
}

/// Test URLs and connection parameters for E2E testing.
///
/// Provides helpers to construct WebSocket URLs and connection strings
/// for various test scenarios.
class TestUrls {
  /// Default WebSocket port for testing
  static const int defaultPort = 8765;

  /// Localhost hostname for local testing
  static const String localhost = 'localhost';

  /// Alternative test port
  static const int alternativePort = 9000;

  /// Constructs a WebSocket URL for client connections
  ///
  /// Args:
  ///   port: The WebSocket server port
  ///   code: The pairing code (6 uppercase alphanumeric characters)
  ///
  /// Returns: A ws:// URL for connecting to the relay server
  static String wsUrl(int port, String code) =>
      'ws://$localhost:$port/ws/client/$code';

  /// Constructs a WebSocket URL using default port
  static String defaultWsUrl(String code) => wsUrl(defaultPort, code);

  /// Constructs a WebSocket URL for agent connections
  static String agentWsUrl(int port, String code) =>
      'ws://$localhost:$port/ws/agent/$code';

  /// Constructs a secure WebSocket URL (wss://)
  static String secureWsUrl(String host, int port, String code) =>
      'wss://$host:$port/ws/client/$code';

  /// Example production relay URL format
  static String productionUrl(String code) =>
      'wss://relay.myagents.example.com/ws/client/$code';
}

/// Test message payloads for various message types.
///
/// Provides sample payloads that match the RemoteAgents protocol format.
class TestPayloads {
  /// Terminal input payload (client -> relay -> agent)
  static Map<String, dynamic> terminalInput(String input) => {
        'data': input,
      };

  /// Terminal output payload (agent -> relay -> client)
  static Map<String, dynamic> terminalOutput(String output) => {
        'data': output,
      };

  /// Terminal resize payload
  static Map<String, dynamic> resize(int rows, int cols) => {
        'rows': rows,
        'cols': cols,
      };

  /// Pairing request payload
  static Map<String, dynamic> pairingRequest(String clientPublicKey) => {
        'client_public_key': clientPublicKey,
      };

  /// Default terminal dimensions
  static const int defaultRows = 24;
  static const int defaultCols = 80;

  /// Large terminal dimensions
  static const int largeRows = 50;
  static const int largeCols = 200;

  /// Small terminal dimensions
  static const int smallRows = 10;
  static const int smallCols = 40;
}

/// Test timeout values for various operations.
///
/// Provides consistent timeout durations for testing async operations.
class TestTimeouts {
  /// Short timeout for fast operations (e.g., local encryption)
  static const Duration short = Duration(milliseconds: 100);

  /// Medium timeout for network operations
  static const Duration medium = Duration(seconds: 2);

  /// Long timeout for connection establishment
  static const Duration long = Duration(seconds: 5);

  /// Very long timeout for E2E test scenarios
  static const Duration veryLong = Duration(seconds: 10);

  /// Timeout for WebSocket connection
  static const Duration websocketConnect = Duration(seconds: 3);

  /// Timeout for message delivery
  static const Duration messageDelivery = Duration(seconds: 1);

  /// Delay for simulating slow network
  static const Duration slowNetwork = Duration(milliseconds: 500);

  /// Delay for simulating typing
  static const Duration typing = Duration(milliseconds: 50);
}
