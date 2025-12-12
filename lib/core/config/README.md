# Environment Configuration

This directory contains the environment configuration system for the MyAgents Frontend application.

## Overview

The environment configuration system allows the application to connect to different backend services based on the deployment environment (development or production).

## Files

- `environment.dart` - Defines the `Environment` enum (development, production)
- `environment_config.dart` - Contains environment-specific configuration values

## Configuration

### Development Environment
- Relay URL: `localhost:8080`
- WebSocket Protocol: `ws://` (non-secure)
- Use Case: Local development and testing

### Production Environment
- Relay URL: `relay.remoteagents.dev`
- WebSocket Protocol: `wss://` (secure)
- Use Case: Cloud deployment (Google Cloud Run)

## Usage

### In Application Code

```dart
import 'package:myagents_frontend/core/config/environment_config.dart';

// Get current environment configuration
final config = EnvironmentConfig.current;

// Access configuration values
print('Environment: ${config.environment.name}');
print('Relay URL: ${config.relayUrl}');
print('Secure WebSocket: ${config.useSecureWebSocket}');

// Get full WebSocket URL
final wsUrl = config.getRelayWebSocketUrl('ABC123');
// Development: ws://localhost:8080/ws/client/ABC123
// Production: wss://relay.remoteagents.dev/ws/client/ABC123
```

### Building for Different Environments

Use the `--dart-define` flag to specify the environment at build time:

#### Development Build (Default)
```bash
# Default - no flag needed
flutter build apk

# Or explicitly specify
flutter build apk --dart-define=ENVIRONMENT=development
flutter build ios --dart-define=ENVIRONMENT=development
flutter run --dart-define=ENVIRONMENT=development
```

#### Production Build
```bash
flutter build apk --dart-define=ENVIRONMENT=production
flutter build ios --dart-define=ENVIRONMENT=production
flutter build web --dart-define=ENVIRONMENT=production
```

### Running Tests

#### Run All Tests (Development Environment)
```bash
flutter test
```

#### Run Tests with Production Environment
```bash
flutter test --dart-define=ENVIRONMENT=production
```

#### Run Specific Environment Config Tests
```bash
flutter test test/core/config/environment_config_test.dart
```

## Adding New Configuration Values

To add new environment-specific configuration:

1. Add the field to `EnvironmentConfig` class:
```dart
class EnvironmentConfig {
  final String myNewConfig;

  const EnvironmentConfig({
    // ... existing fields
    required this.myNewConfig,
  });
}
```

2. Update both `development` and `production` instances:
```dart
static const development = EnvironmentConfig(
  // ... existing values
  myNewConfig: 'dev-value',
);

static const production = EnvironmentConfig(
  // ... existing values
  myNewConfig: 'prod-value',
);
```

3. Add tests in `test/core/config/environment_config_test.dart`

## CI/CD Integration

### Example GitHub Actions Workflow

```yaml
name: Build and Deploy

jobs:
  build-production:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - name: Build production APK
        run: flutter build apk --dart-define=ENVIRONMENT=production
      - name: Upload artifact
        uses: actions/upload-artifact@v3
        with:
          name: production-apk
          path: build/app/outputs/flutter-apk/app-release.apk
```

### Example Cloud Build Configuration

```yaml
steps:
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'run'
      - '--rm'
      - '-v'
      - '/workspace:/workspace'
      - 'cirrusci/flutter:stable'
      - 'flutter'
      - 'build'
      - 'web'
      - '--dart-define=ENVIRONMENT=production'
```

## Architecture Notes

- Configuration is determined at **build time** using compile-time constants
- The `ENVIRONMENT` dart-define value is read via `String.fromEnvironment()`
- Default environment is `development` if not specified
- This approach ensures zero runtime overhead and prevents accidental production connections during development

## Related Files

- `/lib/features/pairing/pairing_controller.dart` - Uses `EnvironmentConfig.current.relayUrl`
- `/lib/core/networking/relay_client.dart` - Handles WebSocket connections
- `/test/core/config/environment_config_test.dart` - Configuration tests
