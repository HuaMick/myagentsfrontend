/// Represents the deployment environment for the application.
///
/// The environment determines which backend services (relay server, etc.)
/// the application connects to.
enum Environment {
  /// Development environment - connects to local services
  development,

  /// Production environment - connects to cloud-hosted services
  production,
}

/// Extension methods for Environment enum
extension EnvironmentExtension on Environment {
  /// Returns the human-readable name of the environment
  String get name {
    switch (this) {
      case Environment.development:
        return 'Development';
      case Environment.production:
        return 'Production';
    }
  }

  /// Returns true if this is the development environment
  bool get isDevelopment => this == Environment.development;

  /// Returns true if this is the production environment
  bool get isProduction => this == Environment.production;
}
