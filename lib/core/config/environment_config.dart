import 'environment.dart';

/// Configuration values for different environments.
///
/// This class provides environment-specific configuration such as API URLs,
/// relay server URLs, and other environment-dependent settings.
///
/// Configuration is determined at build time using --dart-define flags:
/// ```bash
/// # Development build (default)
/// flutter build --dart-define=ENVIRONMENT=development
///
/// # Production build
/// flutter build --dart-define=ENVIRONMENT=production
/// ```
///
/// Usage:
/// ```dart
/// final config = EnvironmentConfig.current;
/// print('Relay URL: ${config.relayUrl}');
/// print('Environment: ${config.environment.name}');
/// ```
class EnvironmentConfig {
  /// The current environment
  final Environment environment;

  /// The relay server URL (without protocol)
  final String relayUrl;

  /// Whether to use secure WebSocket connections (wss://)
  final bool useSecureWebSocket;

  /// Creates a new EnvironmentConfig instance.
  const EnvironmentConfig({
    required this.environment,
    required this.relayUrl,
    required this.useSecureWebSocket,
  });

  /// Development environment configuration
  static const development = EnvironmentConfig(
    environment: Environment.development,
    relayUrl: 'localhost:8080',
    useSecureWebSocket: false,
  );

  /// Production environment configuration
  static const production = EnvironmentConfig(
    environment: Environment.production,
    relayUrl: 'relay.remoteagents.dev',
    useSecureWebSocket: true,
  );

  /// Gets the current environment configuration based on build-time defines.
  ///
  /// Reads the ENVIRONMENT dart-define value to determine which configuration
  /// to use. Defaults to development if not specified.
  static EnvironmentConfig get current {
    // Read environment from compile-time constant
    const environmentName = String.fromEnvironment(
      'ENVIRONMENT',
      defaultValue: 'development',
    );

    // Return appropriate config based on environment
    switch (environmentName.toLowerCase()) {
      case 'production':
        return production;
      case 'development':
      default:
        return development;
    }
  }

  /// Returns the full WebSocket URL for the relay server.
  ///
  /// Automatically prepends the correct protocol (ws:// or wss://) based on
  /// the useSecureWebSocket setting.
  ///
  /// Args:
  ///   pairingCode: The pairing code for the WebSocket connection
  ///
  /// Returns: Full WebSocket URL in the format:
  ///   ws[s]://{relayUrl}/ws/client/{pairingCode}
  String getRelayWebSocketUrl(String pairingCode) {
    final protocol = useSecureWebSocket ? 'wss' : 'ws';
    return '$protocol://$relayUrl/ws/client/$pairingCode';
  }

  @override
  String toString() {
    return 'EnvironmentConfig('
        'environment: ${environment.name}, '
        'relayUrl: $relayUrl, '
        'useSecureWebSocket: $useSecureWebSocket)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EnvironmentConfig &&
        other.environment == environment &&
        other.relayUrl == relayUrl &&
        other.useSecureWebSocket == useSecureWebSocket;
  }

  @override
  int get hashCode {
    return Object.hash(environment, relayUrl, useSecureWebSocket);
  }
}
