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

## License

Apache-2.0
