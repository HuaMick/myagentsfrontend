# How to Run Integration Tests

## Quick Start

Run all integration tests:
```bash
flutter test integration_test/
```

Run only the complete journey tests:
```bash
flutter test integration_test/complete_journey_test.dart
```

## Device-Specific Testing

### Desktop (Linux/macOS/Windows)
```bash
flutter test integration_test/ -d linux
flutter test integration_test/ -d macos
flutter test integration_test/ -d windows
```

### Web (Chrome)
```bash
flutter test integration_test/ -d chrome
```

### Mobile Emulator
```bash
# List available devices
flutter devices

# Run on specific device
flutter test integration_test/ -d <device-id>
```

## Advanced Options

### Verbose Output
```bash
flutter test integration_test/ --verbose
```

### Run Specific Test
```bash
# Run a single test by name pattern
flutter test integration_test/ --name "complete user journey"
```

### Generate Coverage Report
```bash
flutter test --coverage integration_test/
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## Expected Results

All 15 tests should pass:
- 11 main test scenarios
- 4 extended scenarios

## Test Duration

Expected execution time:
- Complete suite: ~30-60 seconds
- Individual test: ~2-5 seconds each

## Troubleshooting

### "No devices found"
Make sure you have at least one device available:
```bash
flutter devices
```

For Chrome web testing:
```bash
flutter config --enable-web
```

### "Build failed"
Run flutter pub get first:
```bash
flutter pub get
```

### Tests timeout
Some tests attempt real connections which will timeout. This is expected behavior as the tests are designed to verify UI behavior even when connections fail.

### Flutter version issues
Ensure you're using a compatible Flutter version:
```bash
flutter --version
```

Recommended: Flutter 3.x or later

## CI/CD Integration

Example GitHub Actions workflow:

```yaml
name: Integration Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.x'
      - run: flutter pub get
      - run: flutter test integration_test/
```

## Pre-commit Hook

Add to `.git/hooks/pre-commit`:

```bash
#!/bin/bash
flutter analyze integration_test/
if [ $? -ne 0 ]; then
  echo "Integration test analysis failed"
  exit 1
fi
```

## Notes

- These tests focus on UI flow, not actual network communication
- Real WebSocket connections will timeout (expected)
- Tests use mocked/simulated dependencies
- No external services required
