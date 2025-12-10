# Integration Tests

This directory contains end-to-end integration tests for the MyAgents Flutter frontend application.

## Test Structure

```
integration_test/
├── complete_journey_test.dart  # Complete user journey E2E tests
├── helpers/
│   └── test_helpers.dart       # Reusable test helper functions
├── fixtures/
│   └── test_fixtures.dart      # Test data and constants
└── README.md                   # This file
```

## Test Files

### complete_journey_test.dart

Comprehensive end-to-end tests covering the complete user journey from app launch to terminal interaction. This test suite includes:

**Main Test Scenarios:**

1. **Complete Happy Path** - Full user journey with simulated connection
   - App launches to pairing screen
   - Pairing code entry and validation
   - Connection attempt
   - UI state transitions

2. **Error Recovery Flow** - Testing error handling and recovery
   - Connection error simulation
   - Error message display
   - Retry functionality
   - State reset on error

3. **Multiple Navigation Cycles** - State management verification
   - Multiple code entry attempts
   - State reset between attempts
   - No state contamination

4. **Deep Link Entry** - Direct navigation to terminal route
   - Direct /terminal route access
   - Proper dependency injection
   - Redirect behavior when not connected

5. **Input Validation** - Comprehensive pairing code validation
   - Special character filtering
   - Case conversion (lowercase → uppercase)
   - Length limiting (6 characters max)
   - Button enable/disable based on validity

6. **Terminal Screen UI** - Terminal screen elements with mocked dependencies
   - UI element verification
   - Connection status display
   - Navigation controls

7. **Disconnect Flow** - Navigation from terminal back to pairing
   - Disconnect button functionality
   - Proper cleanup
   - State reset

8. **Theme and Styling** - UI appearance verification
   - Theme application
   - Font sizes and weights
   - Layout constraints

9. **Connection State Transitions** - UI feedback during connection
   - Loading indicators
   - Status messages
   - Error handling

10. **Accessibility** - Accessibility features
    - Focus management
    - Semantic labels
    - Screen reader support

11. **Memory Management** - Resource cleanup verification
    - Controller disposal
    - No memory leaks
    - Proper resource cleanup

**Extended Scenarios:**

12. **Rapid Code Changes** - Input debouncing and consistency
13. **App Lifecycle** - Pause and resume behavior
14. **Screen Rotation** - Responsive layout testing
15. **Back Button Handling** - Navigation stack management

## Running Tests

### Run all integration tests

```bash
flutter test integration_test/
```

### Run specific test file

```bash
flutter test integration_test/complete_journey_test.dart
```

### Run on a specific device

```bash
flutter test integration_test/ -d <device_id>
```

### Run with Chrome (for web)

```bash
flutter test integration_test/ -d chrome
```

### Run with verbose output

```bash
flutter test integration_test/ --verbose
```

## Test Helpers

The test suite uses helper functions from `helpers/test_helpers.dart`:

- **pumpApp()** - Launches the app and waits for it to settle
- **waitForWidget()** - Waits for a widget to appear with timeout
- **navigateTo()** - Navigates to a specific route
- **enterText()** - Enters text into a text field
- **tapButton()** - Taps a button and waits for result
- **waitFor()** - Waits for a specific duration
- **scrollUntilVisible()** - Scrolls until a widget is visible
- **verifyVisible()** - Verifies a widget exists and is visible
- **verifyNotVisible()** - Verifies a widget does not exist
- **takeScreenshot()** - Takes a screenshot during the test

## Test Fixtures

Test data is provided by `fixtures/test_fixtures.dart`:

### TestPairingCodes
- `valid` - Valid 6-character pairing code (ABCD12)
- `valid2` - Second valid code for multi-connection tests (XYZ789)
- `invalid` - Invalid code (too short)
- `special` - Invalid code with special characters
- `tooLong` - Invalid code (too long)
- `empty` - Empty string

### TestKeyPairs
- `aliceKeys` - Pre-generated key pair for client side
- `bobKeys` - Pre-generated key pair for relay/agent side
- `charlieKeys` - Third key pair for three-way scenarios
- `generateRandom()` - Generate new random key pair

### TestTerminalMessages
- Terminal output samples with ANSI codes
- Error messages
- Multi-line output
- Special sequences (clear screen, cursor positioning, etc.)

### TestErrorMessages
- Connection error messages
- Timeout messages
- Authentication errors
- Network errors

### TestUrls
- WebSocket URL construction helpers
- Test server endpoints
- Default and alternative ports

### TestPayloads
- Terminal input/output payloads
- Resize payloads
- Pairing request payloads
- Terminal dimension constants

### TestTimeouts
- Consistent timeout durations for async operations
- Short, medium, long, and very long timeouts
- WebSocket connection timeouts
- Message delivery timeouts

## Test Philosophy

These tests focus on:

1. **UI Flow Testing** - Verifying the user interface responds correctly to user actions
2. **State Management** - Ensuring state is properly managed across screens
3. **Navigation** - Testing route transitions and deep linking
4. **Input Validation** - Comprehensive validation of user input
5. **Error Handling** - Proper error display and recovery
6. **Resource Management** - No memory leaks, proper cleanup
7. **Accessibility** - Basic accessibility features

These tests do NOT include:

- **Real WebSocket Connections** - Network calls are simulated or mocked
- **Full Integration** - Complete end-to-end with real relay server (separate test suite)
- **Performance Testing** - Response time and performance metrics
- **Load Testing** - Multiple concurrent connections

## Continuous Integration

These tests are designed to run in CI/CD pipelines:

- Fast execution (no real network calls)
- Deterministic results (no flaky tests)
- No external dependencies required
- Can run headless

## Troubleshooting

### Tests fail with "Widget not found"
- Check that you're using the correct Finders
- Ensure `pumpAndSettle()` has completed
- Use `waitForWidget()` for widgets that appear after async operations

### Tests timeout
- Increase timeout values in `TestTimeouts`
- Check for infinite animations
- Verify async operations complete

### Flaky tests
- Add appropriate `pumpAndSettle()` calls
- Use deterministic test data
- Avoid real network calls
- Use `waitForWidget()` instead of fixed delays

### Memory leaks
- Ensure all controllers are disposed
- Check for dangling stream subscriptions
- Verify cleanup in `dispose()` methods

## Best Practices

1. **Use test helpers** - Leverage the helper functions for consistency
2. **Use test fixtures** - Use predefined test data from fixtures
3. **Clear test names** - Use descriptive test names that explain what is being tested
4. **Test one thing** - Each test should verify one specific behavior
5. **Clean up** - Always dispose of resources in test tearDown
6. **Avoid sleeps** - Use `pumpAndSettle()` instead of fixed delays
7. **Mock dependencies** - Don't rely on external services
8. **Document complex tests** - Add comments for non-obvious test logic

## Future Enhancements

Potential additions to the test suite:

- [ ] Screenshot comparison tests
- [ ] Performance benchmarking
- [ ] Accessibility audit automation
- [ ] Golden file tests for UI consistency
- [ ] Multi-device testing matrix
- [ ] Internationalization (i18n) testing
- [ ] Network condition simulation (slow, offline, etc.)
- [ ] Full E2E with mock relay server
- [ ] Terminal I/O simulation with PTY emulation
- [ ] Clipboard operations testing
- [ ] Keyboard shortcuts testing
