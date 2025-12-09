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
- Voice-to-text input (push-to-talk with Deepgram Nova-3 backend)
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
│   ├── voice/               # Voice input (audio capture + relay)
│   │   ├── voice_state.dart         # UI state management
│   │   ├── audio_capture.dart       # Microphone recording
│   │   ├── voice_relay_handler.dart # Backend communication
│   │   └── voice_button.dart        # Voice UI widget
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

## Voice Feature

### Overview

The Voice Feature enables voice-to-text input for terminal commands using a push-to-talk interface. Users can hold a button to record their voice, and the speech is transcribed into text that is sent to the terminal as if it were typed.

### Architecture

The voice feature follows a clean separation between frontend and backend responsibilities:

**Frontend (MyAgentsFrontend)**:
- Captures audio from device microphone
- Displays real-time transcripts and visual feedback
- Streams audio chunks via E2E encrypted RelayClient
- NO API keys or transcription logic

**Backend (RemoteAgents)**:
- Holds Deepgram API key securely
- Receives encrypted audio frames from frontend
- Integrates with Deepgram Nova-3 for transcription
- Sends interim and final transcripts back to frontend

**Communication**:
- All audio data is E2E encrypted using NaCl/pinenacl
- Uses existing RelayClient WebSocket infrastructure
- Same encryption keys as terminal messages

### Voice Protocol

The voice feature uses four message types for communication:

**Message Types**:
- `voice.audio_frame`: Audio chunk from frontend to backend
  - Payload: `{data: base64_string}`
  - Sent continuously during recording
- `voice.transcript`: Transcript from backend to frontend
  - Payload: `{transcript: string, is_final: bool}`
  - `is_final: false` for interim (live) updates
  - `is_final: true` for final complete transcript
- `voice.control`: Control messages from frontend to backend
  - Payload: `{action: "start"|"stop"|"cancel"}`
  - Manages voice session lifecycle
- `voice.status`: Status updates from backend to frontend
  - Payload: `{status: "ready"|"error"|"processing", message: string?}`
  - Provides backend status and error notifications

**Audio Format**:
- Encoding: PCM16 (16-bit PCM)
- Sample Rate: 16000 Hz (16kHz)
- Channels: Mono (1 channel)
- Chunk Size: 4096 bytes
- Transmission: Base64-encoded via voice.audio_frame messages

**Transcript Format**:
- Interim transcripts: Live updates during recording (may change)
- Final transcripts: Complete stable result after recording stops
- Both are differentiated by the `is_final` boolean field

### Usage

**How to Use**:

1. Open the terminal screen with an active session
2. Locate the voice button (FloatingActionButton at bottom-right)
3. Press and hold the button to start recording
4. Speak your command clearly
5. Release the button to stop recording
6. Wait for the final transcript to appear in terminal input
7. The command executes as if typed

**Visual States**:

The voice button provides clear visual feedback for each state:

- **Idle** (Ready): Microphone icon, primary color
  - Tooltip: "Hold to record voice input"
- **Requesting Permission**: Loading indicator, disabled
  - Tooltip: "Requesting microphone permission..."
- **Recording** (Active): Microphone icon, RED color with pulsing animation
  - Tooltip: "Recording... Release to send"
- **Processing**: Loading spinner (CircularProgressIndicator)
  - Tooltip: "Processing audio..."
- **Success**: Checkmark icon, brief green flash
  - Tooltip: "Transcript received!"
- **Error**: Error icon, red color
  - Tooltip: Shows specific error message
  - Tap to dismiss and reset

**Permission Handling**:

The first time you use voice input, the app will request microphone permission:

- On permission granted: Recording starts immediately
- On permission denied: Error state with message "Microphone permission denied"
- To grant permission later: Check your device/browser settings

**Error Handling**:

The voice button handles various error scenarios:

- **Permission Denied**: Clear error message, instructions to grant in settings
- **Backend Errors**: Display error message from backend (e.g., "Deepgram API error")
- **Network Errors**: Connection issues show "Failed to send audio frame" or "Audio stream error"
- **Timeout Errors**: If backend doesn't respond, processing state continues (manual reset available)

All errors can be dismissed by tapping the error button, which resets to idle state.

### Component Overview

The voice feature is implemented with four main components:

**VoiceState** (`lib/features/voice/voice_state.dart`):
- Manages UI state for the voice recording interface
- Defines 6 states: idle, requestingPermission, recording, processing, success, error
- VoiceController class extends ChangeNotifier for reactive UI updates
- Stores interim transcript (live updates) and final transcript (complete result)
- Handles state transitions with validation
- Pure UI state management - no business logic

**AudioCapture** (`lib/features/voice/audio_capture.dart`):
- Captures raw audio from device microphone
- Uses `record` package for cross-platform audio recording
- Manages microphone permission requests
- Provides Stream<Uint8List> of PCM16 audio chunks (4096 bytes)
- Handles resource cleanup and disposal
- Throws AudioCaptureException on errors with clear messages

**VoiceRelayHandler** (`lib/features/voice/voice_relay_handler.dart`):
- Bridges audio capture to backend voice service
- Sends audio frames via RelayClient using voice.audio_frame messages
- Receives transcripts via voice.transcript messages
- Manages voice session lifecycle (start, stop, cancel)
- Routes transcripts to VoiceController for UI updates
- Handles E2E encryption using existing KeyPair infrastructure

**VoiceButton** (`lib/features/voice/voice_button.dart`):
- UI widget for voice input (FloatingActionButton style)
- Push-to-talk interaction: hold to record, release to send
- Integrates all voice components (state, audio, relay)
- Provides visual feedback with animations
- Fires onTranscriptComplete callback with final transcript
- Auto-resets after success/error

**Terminal Integration** (`lib/features/remote_terminal/terminal_screen.dart`):
- VoiceButton appears as FloatingActionButton in terminal screen
- Only visible when relay is connected
- Final transcripts route directly to terminal input
- Identical behavior to keyboard input

### Dependencies

**Audio Recording**:
- `record` package (^5.0.0): Cross-platform audio recording
  - Handles microphone access and permission requests
  - Provides PCM16 audio stream
  - Supports iOS, Android, and Web

**E2E Encrypted Communication**:
- Existing `RelayClient` (`lib/core/networking/relay_client.dart`)
  - WebSocket-based communication with backend
  - E2E encryption using NaCl/pinenacl
  - Message routing by type
- Existing `KeyPair` and `MessageEnvelope` (`lib/core/crypto/`)
  - X25519 key pairs for encryption
  - Seal/open methods for E2E encrypted messages

**Backend Voice Service**:
- RemoteAgents voice backend (see RemoteAgents repository)
  - Deepgram Nova-3 integration for transcription
  - Voice session management
  - Transcript streaming (interim + final)
  - Refer to RemoteAgents plan: `docs/plans/live/251209_remoteagents-backlog.yml`

### Development Notes

**Testing Strategy**:
- Unit tests for VoiceState transitions
- Mock AudioRecorder for audio capture tests
- Mock RelayClient for integration tests
- Widget tests for VoiceButton UI states
- Integration tests for terminal screen

**Performance Considerations**:
- State transitions complete within 100ms
- Permission requests complete within 2 seconds
- Audio chunks streamed with minimal buffering
- Transcript routing completes within 100ms
- Error propagation within 50ms

**Security**:
- No API keys stored in frontend code
- All audio data E2E encrypted during transmission
- Microphone permission requested explicitly
- Audio capture only active during recording

## CI/CD

This project uses Google Cloud Build for continuous integration. See [CI_CD.md](CI_CD.md) for setup and details.

**Quick Links:**
- [CI/CD Documentation](CI_CD.md) - Setup, monitoring, and troubleshooting
- [Trigger Reference](TRIGGERS.md) - Trigger configuration details

## License

Apache-2.0
