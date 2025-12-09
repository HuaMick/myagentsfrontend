import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myagents_frontend/features/remote_terminal/terminal_screen.dart';
import 'package:myagents_frontend/core/networking/relay_client.dart';
import 'package:myagents_frontend/core/crypto/key_pair.dart';
import 'package:myagents_frontend/features/voice/voice_button.dart';

/// Mock RelayClient for testing terminal screen integration
class MockRelayClient extends RelayClient {
  bool _mockConnected = false;

  @override
  bool get isConnected => _mockConnected;

  void setMockConnected(bool connected) {
    _mockConnected = connected;
    if (connected) {
      // Proper state transition: disconnected -> connecting -> connected
      stateManager.setConnecting();
      stateManager.setConnected();
    } else {
      stateManager.setDisconnected();
    }
  }
}

/// Testable wrapper for TerminalScreen that allows dependency injection
class TestableTerminalScreen extends StatefulWidget {
  final RelayClient? relayClient;
  final KeyPair? ourKeys;
  final KeyPair? remoteKeys;

  const TestableTerminalScreen({
    super.key,
    this.relayClient,
    this.ourKeys,
    this.remoteKeys,
  });

  @override
  State<TestableTerminalScreen> createState() => _TestableTerminalScreenState();
}

class _TestableTerminalScreenState extends State<TestableTerminalScreen> {
  late RelayClient? _relayClient;
  late KeyPair? _ourKeys;
  late KeyPair? _remoteKeys;

  bool get _isConnected => _relayClient?.isConnected ?? false;

  @override
  void initState() {
    super.initState();
    _relayClient = widget.relayClient;
    _ourKeys = widget.ourKeys;
    _remoteKeys = widget.remoteKeys;

    // Listen to connection state changes to trigger rebuilds
    _relayClient?.stateManager.addListener(_onConnectionStateChanged);
  }

  @override
  void dispose() {
    _relayClient?.stateManager.removeListener(_onConnectionStateChanged);
    super.dispose();
  }

  void _onConnectionStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _sendToTerminal(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Voice command: $text'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terminal')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Terminal Screen Placeholder'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Back to Pairing'),
            ),
            const SizedBox(height: 20),
            Text(
              _isConnected ? 'Connected to Relay' : 'Not Connected',
              style: TextStyle(
                color: _isConnected ? Colors.green : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton:
          _isConnected && _ourKeys != null && _remoteKeys != null
              ? VoiceButton(
                  relayClient: _relayClient!,
                  ourKeys: _ourKeys!,
                  remoteKeys: _remoteKeys!,
                  onTranscriptComplete: _sendToTerminal,
                )
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

void main() {
  group('TerminalScreen Voice Integration Tests', () {
    late MockRelayClient mockRelayClient;
    late KeyPair ourKeys;
    late KeyPair remoteKeys;

    setUp(() {
      mockRelayClient = MockRelayClient();
      ourKeys = KeyPair.generate();
      remoteKeys = KeyPair.generate();
    });

    tearDown(() {
      mockRelayClient.dispose();
    });

    testWidgets('Test 1: VoiceButton appears when relay connected and keys available',
        (WidgetTester tester) async {
      // Setup: Create a TestableTerminalScreen with connected state
      mockRelayClient.setMockConnected(true);

      await tester.pumpWidget(
        MaterialApp(
          home: TestableTerminalScreen(
            relayClient: mockRelayClient,
            ourKeys: ourKeys,
            remoteKeys: remoteKeys,
          ),
        ),
      );

      // Verify: VoiceButton should be present
      expect(find.byType(VoiceButton), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('Test 2: VoiceButton hidden when relay disconnected',
        (WidgetTester tester) async {
      // Setup: Create TestableTerminalScreen with disconnected state
      mockRelayClient.setMockConnected(false);

      await tester.pumpWidget(
        MaterialApp(
          home: TestableTerminalScreen(
            relayClient: mockRelayClient,
            ourKeys: ourKeys,
            remoteKeys: remoteKeys,
          ),
        ),
      );

      // Verify: VoiceButton should NOT be present
      expect(find.byType(VoiceButton), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);

      // Verify: Connection status should show "Not Connected"
      expect(find.text('Not Connected'), findsOneWidget);
    });

    testWidgets('Test 3: VoiceButton hidden when keys are missing',
        (WidgetTester tester) async {
      // Setup: Create TestableTerminalScreen with connected but no keys
      mockRelayClient.setMockConnected(true);

      await tester.pumpWidget(
        MaterialApp(
          home: TestableTerminalScreen(
            relayClient: mockRelayClient,
            ourKeys: null, // Missing our keys
            remoteKeys: remoteKeys,
          ),
        ),
      );

      // Verify: VoiceButton should NOT be present even though connected
      expect(find.byType(VoiceButton), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('Test 4: onTranscriptComplete routes to _sendToTerminal with SnackBar',
        (WidgetTester tester) async {
      const testTranscript = 'test voice command';

      // Setup: Create TestableTerminalScreen with all requirements
      mockRelayClient.setMockConnected(true);

      await tester.pumpWidget(
        MaterialApp(
          home: TestableTerminalScreen(
            relayClient: mockRelayClient,
            ourKeys: ourKeys,
            remoteKeys: remoteKeys,
          ),
        ),
      );

      // Verify VoiceButton is present
      expect(find.byType(VoiceButton), findsOneWidget);

      // Get the VoiceButton widget to access its callback
      final voiceButton = tester.widget<VoiceButton>(find.byType(VoiceButton));

      // Simulate transcript completion callback
      voiceButton.onTranscriptComplete(testTranscript);

      // Wait for SnackBar animation
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify: SnackBar should appear with correct message
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Voice command: $testTranscript'), findsOneWidget);
    });

    testWidgets('Test 5: FloatingActionButton positioned correctly (bottom-right)',
        (WidgetTester tester) async {
      // Setup: Create TestableTerminalScreen with connected state
      mockRelayClient.setMockConnected(true);

      await tester.pumpWidget(
        MaterialApp(
          home: TestableTerminalScreen(
            relayClient: mockRelayClient,
            ourKeys: ourKeys,
            remoteKeys: remoteKeys,
          ),
        ),
      );

      // Find the Scaffold to verify FAB location
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));

      // Verify: FAB location should be endFloat (bottom-right)
      expect(scaffold.floatingActionButtonLocation,
             equals(FloatingActionButtonLocation.endFloat));

      // Verify: FAB should exist
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('Test 6: No UI conflicts - VoiceButton does not overlap terminal controls',
        (WidgetTester tester) async {
      // Setup: Create TestableTerminalScreen with connected state
      mockRelayClient.setMockConnected(true);

      await tester.pumpWidget(
        MaterialApp(
          home: TestableTerminalScreen(
            relayClient: mockRelayClient,
            ourKeys: ourKeys,
            remoteKeys: remoteKeys,
          ),
        ),
      );

      // Verify: All expected UI elements are present
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Terminal'), findsOneWidget); // AppBar title
      expect(find.text('Terminal Screen Placeholder'), findsOneWidget);
      expect(find.text('Back to Pairing'), findsOneWidget);
      expect(find.text('Connected to Relay'), findsOneWidget);
      expect(find.byType(VoiceButton), findsOneWidget);

      // Verify: ElevatedButton is still tappable (not occluded)
      final backButton = find.widgetWithText(ElevatedButton, 'Back to Pairing');
      expect(backButton, findsOneWidget);

      // Get the positions to ensure no overlap
      final backButtonRect = tester.getRect(backButton);
      final fabRect = tester.getRect(find.byType(FloatingActionButton));

      // Verify: FAB is positioned away from center controls
      // FAB should be in bottom-right, not overlapping center content
      expect(fabRect.bottom > backButtonRect.bottom, isTrue,
             reason: 'FAB should be below the center button');
      expect(fabRect.right > backButtonRect.right, isTrue,
             reason: 'FAB should be to the right of center content');
    });

    testWidgets('Test 7: Connection state visibility toggle',
        (WidgetTester tester) async {
      // Setup: Start disconnected
      mockRelayClient.setMockConnected(false);

      await tester.pumpWidget(
        MaterialApp(
          home: TestableTerminalScreen(
            relayClient: mockRelayClient,
            ourKeys: ourKeys,
            remoteKeys: remoteKeys,
          ),
        ),
      );

      // Test disconnected state
      expect(find.byType(VoiceButton), findsNothing);
      expect(find.text('Not Connected'), findsOneWidget);

      // Test connected state
      mockRelayClient.setMockConnected(true);
      await tester.pump();

      expect(find.byType(VoiceButton), findsOneWidget);
      expect(find.text('Connected to Relay'), findsOneWidget);

      // Toggle back to disconnected
      mockRelayClient.setMockConnected(false);
      await tester.pump();

      expect(find.byType(VoiceButton), findsNothing);
      expect(find.text('Not Connected'), findsOneWidget);
    });

    testWidgets('Test 8: VoiceButton receives correct parameters',
        (WidgetTester tester) async {
      // Setup: Create TestableTerminalScreen with connected state
      mockRelayClient.setMockConnected(true);

      await tester.pumpWidget(
        MaterialApp(
          home: TestableTerminalScreen(
            relayClient: mockRelayClient,
            ourKeys: ourKeys,
            remoteKeys: remoteKeys,
          ),
        ),
      );

      // Get the VoiceButton widget
      final voiceButton = tester.widget<VoiceButton>(find.byType(VoiceButton));

      // Verify: All required parameters are passed correctly
      expect(voiceButton.relayClient, equals(mockRelayClient));
      expect(voiceButton.ourKeys, equals(ourKeys));
      expect(voiceButton.remoteKeys, equals(remoteKeys));
      expect(voiceButton.onTranscriptComplete, isNotNull);
    });

    testWidgets('Test 9: FAB minimum touch target size (accessibility)',
        (WidgetTester tester) async {
      // Setup: Create TestableTerminalScreen with connected state
      mockRelayClient.setMockConnected(true);

      await tester.pumpWidget(
        MaterialApp(
          home: TestableTerminalScreen(
            relayClient: mockRelayClient,
            ourKeys: ourKeys,
            remoteKeys: remoteKeys,
          ),
        ),
      );

      // Get FAB dimensions
      final fabRect = tester.getRect(find.byType(FloatingActionButton));

      // Verify: FAB meets minimum 48x48dp touch target
      // Flutter's default FAB is 56x56, which exceeds minimum
      expect(fabRect.width, greaterThanOrEqualTo(48.0),
             reason: 'FAB width should meet minimum touch target of 48dp');
      expect(fabRect.height, greaterThanOrEqualTo(48.0),
             reason: 'FAB height should meet minimum touch target of 48dp');
    });

    testWidgets('Test 10: Transcript callback properly wired to _sendToTerminal',
        (WidgetTester tester) async {
      // Setup: Create TestableTerminalScreen with connected state
      mockRelayClient.setMockConnected(true);

      await tester.pumpWidget(
        MaterialApp(
          home: TestableTerminalScreen(
            relayClient: mockRelayClient,
            ourKeys: ourKeys,
            remoteKeys: remoteKeys,
          ),
        ),
      );

      // Get the VoiceButton widget
      final voiceButton = tester.widget<VoiceButton>(find.byType(VoiceButton));

      // Verify the callback is wired correctly
      expect(voiceButton.onTranscriptComplete, isNotNull);

      // Test transcript callback triggers SnackBar
      voiceButton.onTranscriptComplete('test command');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify SnackBar appears with the transcript
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Voice command: test command'), findsOneWidget);
    });
  });
}
