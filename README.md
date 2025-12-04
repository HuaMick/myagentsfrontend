# MyAgents Frontend

Flutter web and mobile frontend for MyAgents remote terminal access.

## Overview

MyAgentsFrontend provides a cross-platform frontend for remotely controlling Claude Code terminal sessions:
- **Web**: Primary development target
- **iOS/Android**: Future expansion using same codebase

## Architecture

```
MyAgentsFrontend (Flutter)
    │
    │ WSS (E2E encrypted)
    ▼
RemoteAgents Relay Server
    │
    │ WSS (E2E encrypted)
    ▼
Desktop CLI (Claude Code in PTY)
```

## Features

- Remote terminal view (xterm)
- E2E encrypted communication (NaCl/pinenacl)
- Voice-to-text input (Deepgram Nova-3)
- Session pairing via codes

## Related Repositories

- **RemoteAgents**: Python backend (relay server + terminal PTY wrapper)
- **MyAgents**: Python CLI integration

## Installation

```bash
# Prerequisites
flutter --version  # Ensure Flutter is installed

# Clone and setup
cd /home/code/myagents
git clone <repo> MyAgentsFrontend
cd MyAgentsFrontend
flutter pub get

# Run web
flutter run -d chrome
```

## Project Structure

```
lib/
├── main.dart
├── core/                    # Shared infrastructure
│   ├── config/
│   ├── crypto/              # E2E encryption (pinenacl)
│   ├── networking/          # WebSocket client
│   └── theme/
│
├── features/
│   ├── remote_terminal/     # Terminal display + input
│   ├── voice/               # Deepgram voice-to-text
│   └── pairing/             # Session pairing UI
│
└── routing/
```

## Development

```bash
# Run web in debug mode
flutter run -d chrome

# Run tests
flutter test

# Analyze code
flutter analyze

# Build web release
flutter build web
```

## Pairing Feature

### Overview

The pairing feature enables users to connect to remote Claude Code terminal sessions through a simple, secure flow:

1. User enters a 6-character alphanumeric pairing code
2. Frontend establishes an encrypted WebSocket connection to the relay server
3. Upon successful connection, user is automatically redirected to the terminal screen

The pairing feature follows a clean, separation-of-concerns architecture with three main components:

- **PairingState**: Immutable state model that represents the current pairing status, code validation, and error handling
- **PairingController**: Business logic layer that orchestrates key generation, relay connection, and state transitions
- **PairingScreen**: UI layer that provides the user interface and responds to state changes

This architecture ensures testability, maintainability, and clear data flow throughout the pairing process.

### Using the Pairing Screen

#### Navigation

The pairing screen is the initial route (`/`) of the application. When the app launches, users land directly on the pairing screen.

#### User Flow

1. **Enter Pairing Code**: User types a 6-character alphanumeric code in the input field
   - Code is automatically converted to uppercase
   - Only alphanumeric characters (A-Z, 0-9) are accepted
   - Input is limited to 6 characters
   - Real-time validation ensures code format is correct

2. **Connect**: Once a valid code is entered, the "Connect" button becomes enabled
   - Click the button to initiate connection
   - A loading spinner appears during connection attempt
   - Status message displays "Connecting to session..."

3. **Redirect**: Upon successful connection
   - Status message changes to "Connected! Redirecting..."
   - Automatic navigation to `/terminal` route
   - Terminal screen loads with active session

#### Behind the Scenes

When the user clicks "Connect", the following happens:

1. **Key Generation**: A new X25519 key pair is generated for end-to-end encryption
2. **Relay Connection**: WebSocket connection established to `wss://relay.remoteagents.dev/ws/client/{pairingCode}`
3. **State Management**: Connection state transitions from `idle` → `connecting` → `connected`
4. **Navigation**: React to connection success by navigating to terminal screen
5. **Error Handling**: If connection fails, appropriate error message is displayed:
   - "Invalid pairing code" (404 from relay)
   - "Connection timeout - please check your network" (timeout)
   - "Network error - please check your connection" (network issues)
   - "Failed to establish connection: ..." (WebSocket errors)

### Pairing State Management

#### PairingState Model

`PairingState` is an immutable class that represents the current state of the pairing flow:

```dart
class PairingState {
  final String pairingCode;
  final ConnectionState connectionState;
  final String? errorMessage;
}
```

**State Transitions**:
- Initial state: `pairingCode: ''`, `connectionState: idle`, `errorMessage: null`
- User types code: Updates `pairingCode`, resets to `idle`, clears error
- Connect initiated: Sets `connectionState: connecting`, clears error
- Success: Sets `connectionState: connected`, clears error
- Failure: Sets `connectionState: error`, sets `errorMessage`

#### ConnectionState Enum

The `ConnectionState` enum tracks the connection lifecycle:

```dart
enum ConnectionState {
  idle,        // Initial state, no connection attempt
  connecting,  // Connection in progress
  connected,   // Successfully connected
  error,       // Connection failed with error
}
```

State transitions follow this flow:
```
idle → connecting → connected (success)
idle → connecting → error (failure)
error → idle (when code changes)
```

#### Validation Helpers

**isValidCode**: Returns `true` if the pairing code meets requirements
- Exactly 6 characters long
- Contains only alphanumeric characters (A-Z, 0-9)

```dart
bool get isValidCode {
  if (pairingCode.length != 6) return false;
  return RegExp(r'^[a-zA-Z0-9]+$').hasMatch(pairingCode);
}
```

**canConnect**: Returns `true` if a connection attempt can be made
- Code is valid (6 alphanumeric characters)
- Not currently connecting

```dart
bool get canConnect {
  return isValidCode && connectionState != ConnectionState.connecting;
}
```

#### copyWith() and clearError Parameter

The `copyWith()` method creates a new state instance with updated fields. The `clearError` parameter provides explicit control over error message clearing:

```dart
// Update code, clear error
state.copyWith(pairingCode: 'ABC123', clearError: true)

// Set connection state to connecting, clear error
state.copyWith(connectionState: ConnectionState.connecting, clearError: true)

// Set error state with message
state.copyWith(
  connectionState: ConnectionState.error,
  errorMessage: 'Invalid pairing code',
)
```

When `clearError: true` is set, `errorMessage` is explicitly set to `null` regardless of other parameters.

### Testing the Pairing Feature

#### Test Location

Unit tests are located in the `test/features/pairing/` directory:
- `pairing_state_test.dart`: Tests for PairingState model and validation
- `pairing_controller_test.dart`: Tests for PairingController business logic
- `pairing_screen_test.dart`: Tests for PairingScreen UI and user interactions
- `pairing_controller_integration_success_test.dart`: Integration tests for successful connection
- `pairing_controller_integration_error_test.dart`: Integration tests for error scenarios

#### Running Tests

```bash
# Run all tests
flutter test

# Run only pairing tests
flutter test test/features/pairing/

# Run specific test file
flutter test test/features/pairing/pairing_state_test.dart

# Run with coverage
flutter test --coverage
```

#### Test Coverage

The test suite covers:
- State validation and transitions
- Code formatting and input handling
- Connection success and failure scenarios
- Error message handling
- UI rendering and user interactions
- Navigation on successful connection
- Proper cleanup and disposal

### Code Examples

#### Using PairingController Programmatically

```dart
import 'package:myagents_frontend/features/pairing/pairing_controller.dart';

// Create controller instance
final controller = PairingController();

// Update pairing code
controller.updateCode('ABC123');

// Check if code is valid
if (controller.state.isValidCode) {
  print('Code is valid: ${controller.state.pairingCode}');
}

// Attempt connection when ready
if (controller.state.canConnect) {
  await controller.connect();
}

// Check connection result
if (controller.state.connectionState == ConnectionState.connected) {
  print('Connected successfully!');
  // Access relay client
  final relayClient = controller.relayClient;
  final clientKeys = controller.clientKeys;
} else if (controller.state.connectionState == ConnectionState.error) {
  print('Connection failed: ${controller.state.errorMessage}');
}

// Clean up when done
controller.dispose();
```

#### Listening to State Changes

```dart
import 'package:myagents_frontend/features/pairing/pairing_controller.dart';

final controller = PairingController();

// Add listener for state changes
controller.addListener(() {
  final state = controller.state;
  print('Pairing State: ${state.connectionState}');

  switch (state.connectionState) {
    case ConnectionState.idle:
      print('Ready to connect');
      break;
    case ConnectionState.connecting:
      print('Connecting...');
      break;
    case ConnectionState.connected:
      print('Connected! Relay client ready.');
      // Navigate to terminal or perform other actions
      break;
    case ConnectionState.error:
      print('Error: ${state.errorMessage}');
      break;
  }
});

// Update code (triggers listener)
controller.updateCode('ABC123');

// Connect (triggers listener multiple times)
await controller.connect();

// Remove listener when done
controller.removeListener(listenerFunction);
controller.dispose();
```

#### Using with Provider in Widget

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myagents_frontend/features/pairing/pairing_controller.dart';

class MyPairingWidget extends StatefulWidget {
  @override
  State<MyPairingWidget> createState() => _MyPairingWidgetState();
}

class _MyPairingWidgetState extends State<MyPairingWidget> {
  late final PairingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PairingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PairingController>.value(
      value: _controller,
      child: Consumer<PairingController>(
        builder: (context, controller, child) {
          final state = controller.state;

          return Column(
            children: [
              TextField(
                onChanged: controller.updateCode,
              ),
              ElevatedButton(
                onPressed: state.canConnect ? controller.connect : null,
                child: Text('Connect'),
              ),
              if (state.errorMessage != null)
                Text(state.errorMessage!, style: TextStyle(color: Colors.red)),
            ],
          );
        },
      ),
    );
  }
}
```

## License

Apache-2.0
