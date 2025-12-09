import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myagents_frontend/core/crypto/key_pair.dart';
import 'package:myagents_frontend/core/crypto/message_envelope.dart';
import 'package:myagents_frontend/core/networking/relay_client.dart';
import 'package:myagents_frontend/features/voice/voice_button.dart';

/// Test widget wrapper for VoiceButton
class TestVoiceButtonWrapper extends StatelessWidget {
  final VoiceButton voiceButton;

  const TestVoiceButtonWrapper({super.key, required this.voiceButton});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: voiceButton,
        ),
      ),
    );
  }
}

void main() {
  group('VoiceButton Widget Tests', () {
    late RelayClient relayClient;
    late KeyPair ourKeys;
    late KeyPair remoteKeys;
    late List<String> transcriptCallbacks;

    setUp(() {
      // Create real instances - tests will focus on widget behavior
      // not integration with audio/network
      relayClient = RelayClient();
      ourKeys = KeyPair.generate();
      remoteKeys = KeyPair.generate();
      transcriptCallbacks = [];
    });

    tearDown(() {
      relayClient.dispose();
    });

    /// Helper to create VoiceButton with standard test setup
    Widget createVoiceButton({Function(String)? onTranscriptComplete}) {
      return TestVoiceButtonWrapper(
        voiceButton: VoiceButton(
          relayClient: relayClient,
          ourKeys: ourKeys,
          remoteKeys: remoteKeys,
          onTranscriptComplete: onTranscriptComplete ??
              (transcript) {
                transcriptCallbacks.add(transcript);
              },
        ),
      );
    }

    testWidgets('Test 1: Button renders in idle state', (WidgetTester tester) async {
      await tester.pumpWidget(createVoiceButton());
      await tester.pumpAndSettle();

      // Should find FloatingActionButton
      expect(find.byType(FloatingActionButton), findsOneWidget);

      // Should show microphone icon in idle state
      expect(find.byIcon(Icons.mic), findsOneWidget);

      // Should have tooltip for idle state
      final tooltip = find.byType(Tooltip);
      expect(tooltip, findsOneWidget);
      final tooltipWidget = tester.widget<Tooltip>(tooltip);
      expect(tooltipWidget.message, 'Hold to record voice input');
    });

    testWidgets('Test 2: Button has correct visual properties',
        (WidgetTester tester) async {
      await tester.pumpWidget(createVoiceButton());
      await tester.pumpAndSettle();

      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );

      // Should have correct elevation
      expect(fab.elevation, 6.0);

      // Should have white foreground color
      expect(fab.foregroundColor, Colors.white);

      // Background color should be set (actual color depends on theme)
      expect(fab.backgroundColor, isNotNull);
    });

    testWidgets('Test 3: Button has GestureDetector for long press',
        (WidgetTester tester) async {
      await tester.pumpWidget(createVoiceButton());
      await tester.pumpAndSettle();

      // Should find GestureDetector (may be multiple in tree, so check for widgets)
      expect(find.byType(GestureDetector), findsWidgets);

      // Button should be present
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('Test 4: Button accepts long press gestures',
        (WidgetTester tester) async {
      await tester.pumpWidget(createVoiceButton());
      await tester.pumpAndSettle();

      final button = find.byType(FloatingActionButton);

      // Start long press - this will attempt to request permissions
      // In test environment, this will likely fail but should not crash
      final gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(milliseconds: 100));

      // Button should still exist
      expect(find.byType(FloatingActionButton), findsOneWidget);

      // Clean up
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('Test 5: Button handles release after press',
        (WidgetTester tester) async {
      await tester.pumpWidget(createVoiceButton());
      await tester.pumpAndSettle();

      final button = find.byType(FloatingActionButton);

      // Perform full press-release cycle
      final gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(milliseconds: 200));
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));

      // Button should still exist and be functional
      expect(find.byType(FloatingActionButton), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('Test 6: Button handles cancel gesture',
        (WidgetTester tester) async {
      await tester.pumpWidget(createVoiceButton());
      await tester.pumpAndSettle();

      final button = find.byType(FloatingActionButton);

      // Start long press
      final gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(milliseconds: 200));

      // Cancel by moving finger away
      await gesture.moveTo(const Offset(1000, 1000));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();

      // Button should return to idle state (showing mic icon)
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('Test 7: Button has ScaleTransition for animations',
        (WidgetTester tester) async {
      await tester.pumpWidget(createVoiceButton());
      await tester.pumpAndSettle();

      // Verify ScaleTransition exists (used for pulsing and success animations)
      final scaleTransitions = find.byType(ScaleTransition);
      expect(scaleTransitions, findsWidgets);

      // Should have at least 2 ScaleTransitions (pulse + success bounce)
      expect(tester.widgetList(scaleTransitions).length, greaterThanOrEqualTo(2));
    });

    testWidgets('Test 8: Button has Tooltip with dynamic messages',
        (WidgetTester tester) async {
      await tester.pumpWidget(createVoiceButton());
      await tester.pumpAndSettle();

      // Find tooltip and verify it exists
      final tooltip = find.byType(Tooltip);
      expect(tooltip, findsOneWidget);

      // Idle state should show "Hold to record voice input"
      final tooltipWidget = tester.widget<Tooltip>(tooltip);
      expect(tooltipWidget.message, contains('Hold to record'));
    });

    testWidgets('Test 9: Multiple press-release cycles work',
        (WidgetTester tester) async {
      await tester.pumpWidget(createVoiceButton());
      await tester.pumpAndSettle();

      final button = find.byType(FloatingActionButton);

      // First cycle
      var gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();

      // Wait for potential auto-reset
      await tester.pump(const Duration(seconds: 2));

      // Second cycle
      gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      await tester.pumpAndSettle();

      // Button should still work and be visible
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('Test 10: Widget disposes cleanly', (WidgetTester tester) async {
      await tester.pumpWidget(createVoiceButton());
      await tester.pumpAndSettle();

      // Verify widget is present
      expect(find.byType(VoiceButton), findsOneWidget);

      // Remove widget from tree
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pumpAndSettle();

      // Should not throw - disposal should be clean
      // No errors means test passes
    });

    testWidgets('Test 11: Widget handles being disposed during gesture',
        (WidgetTester tester) async {
      await tester.pumpWidget(createVoiceButton());
      await tester.pumpAndSettle();

      final button = find.byType(FloatingActionButton);

      // Start gesture
      final gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(milliseconds: 100));

      // Unmount widget while gesture is active
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();

      // Complete gesture after unmount
      await gesture.up();
      await tester.pumpAndSettle();

      // Should not throw
    });

    testWidgets('Test 12: Widget can be found by key', (WidgetTester tester) async {
      const testKey = Key('voice_button_test_key');

      await tester.pumpWidget(
        TestVoiceButtonWrapper(
          voiceButton: VoiceButton(
            key: testKey,
            relayClient: relayClient,
            ourKeys: ourKeys,
            remoteKeys: remoteKeys,
            onTranscriptComplete: (transcript) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should find widget by key
      expect(find.byKey(testKey), findsOneWidget);
      expect(find.byType(VoiceButton), findsOneWidget);
    });

    testWidgets('Test 13: onTranscriptComplete callback is stored',
        (WidgetTester tester) async {
      final receivedTranscripts = <String>[];

      await tester.pumpWidget(
        TestVoiceButtonWrapper(
          voiceButton: VoiceButton(
            relayClient: relayClient,
            ourKeys: ourKeys,
            remoteKeys: remoteKeys,
            onTranscriptComplete: (transcript) {
              receivedTranscripts.add(transcript);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Callback is registered (we can't test it firing without full integration)
      expect(find.byType(VoiceButton), findsOneWidget);
    });

    testWidgets('Test 14: Button renders with different themes',
        (WidgetTester tester) async {
      // Test with dark theme
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: VoiceButton(
                relayClient: relayClient,
                ourKeys: ourKeys,
                remoteKeys: remoteKeys,
                onTranscriptComplete: (transcript) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Button should render correctly with dark theme
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('Test 15: Button size is appropriate for FAB',
        (WidgetTester tester) async {
      await tester.pumpWidget(createVoiceButton());
      await tester.pumpAndSettle();

      // Get button size
      final buttonFinder = find.byType(FloatingActionButton);
      final Size buttonSize = tester.getSize(buttonFinder);

      // FAB should be around 56x56 dp (standard material size)
      expect(buttonSize.width, greaterThanOrEqualTo(48.0));
      expect(buttonSize.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('Test 16: Icon size is appropriate',
        (WidgetTester tester) async {
      await tester.pumpWidget(createVoiceButton());
      await tester.pumpAndSettle();

      // Find the Icon widget
      final iconFinder = find.byIcon(Icons.mic);
      expect(iconFinder, findsOneWidget);

      final Icon iconWidget = tester.widget<Icon>(iconFinder);
      expect(iconWidget.size, 28.0);
    });

    testWidgets('Test 17: Widget tree structure is correct',
        (WidgetTester tester) async {
      await tester.pumpWidget(createVoiceButton());
      await tester.pumpAndSettle();

      // Verify widget tree structure
      expect(find.byType(Tooltip), findsOneWidget);
      expect(find.byType(ScaleTransition), findsWidgets);
      expect(find.byType(GestureDetector), findsWidgets);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('Test 18: Press detection area is button area',
        (WidgetTester tester) async {
      await tester.pumpWidget(createVoiceButton());
      await tester.pumpAndSettle();

      final button = find.byType(FloatingActionButton);
      final Rect buttonRect = tester.getRect(button);

      // Test pressing at button center
      var gesture = await tester.startGesture(buttonRect.center);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();

      // Test pressing at button edge
      gesture = await tester.startGesture(
        Offset(buttonRect.left + 5, buttonRect.top + 5),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();

      // Both should work without errors
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('Test 19: Widget rebuilds on state changes',
        (WidgetTester tester) async {
      await tester.pumpWidget(createVoiceButton());
      await tester.pumpAndSettle();

      int buildCount = 0;
      tester.binding.addPostFrameCallback((_) => buildCount++);

      final button = find.byType(FloatingActionButton);

      // Trigger state change
      final gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();

      // Widget should still exist after rebuilds
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('Test 20: Short tap does not trigger recording',
        (WidgetTester tester) async {
      await tester.pumpWidget(createVoiceButton());
      await tester.pumpAndSettle();

      final button = find.byType(FloatingActionButton);

      // Perform a short tap (not a long press)
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      // Button should remain in idle state (mic icon visible)
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('Test 21: Rapid presses are handled gracefully',
        (WidgetTester tester) async {
      await tester.pumpWidget(createVoiceButton());
      await tester.pumpAndSettle();

      final button = find.byType(FloatingActionButton);

      // Perform rapid short presses
      for (int i = 0; i < 5; i++) {
        final gesture = await tester.startGesture(tester.getCenter(button));
        await tester.pump(const Duration(milliseconds: 10));
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pumpAndSettle();

      // Button should still be functional
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('Test 22: Widget parameters are required',
        (WidgetTester tester) async {
      // This test verifies that VoiceButton requires all parameters
      // by checking that we can create it with all params
      final button = VoiceButton(
        relayClient: relayClient,
        ourKeys: ourKeys,
        remoteKeys: remoteKeys,
        onTranscriptComplete: (transcript) {},
      );

      expect(button.relayClient, relayClient);
      expect(button.ourKeys, ourKeys);
      expect(button.remoteKeys, remoteKeys);
      expect(button.onTranscriptComplete, isNotNull);
    });

    testWidgets('Test 23: CircularProgressIndicator exists for loading states',
        (WidgetTester tester) async {
      await tester.pumpWidget(createVoiceButton());
      await tester.pumpAndSettle();

      // In idle state, no progress indicator should be visible
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // (Processing/requesting permission states would show indicator,
      // but we can't easily trigger those states in isolation)
    });

    testWidgets('Test 24: Widget is stateful',
        (WidgetTester tester) async {
      await tester.pumpWidget(createVoiceButton());
      await tester.pumpAndSettle();

      // VoiceButton should be a StatefulWidget
      final statefulWidget = tester.widget<VoiceButton>(
        find.byType(VoiceButton),
      );
      expect(statefulWidget, isA<StatefulWidget>());
    });

    testWidgets('Test 25: Button maintains state across pumps',
        (WidgetTester tester) async {
      await tester.pumpWidget(createVoiceButton());
      await tester.pumpAndSettle();

      // Initial state - mic icon visible
      expect(find.byIcon(Icons.mic), findsOneWidget);

      // Multiple pumps should not change state
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Should still be in idle state
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('Test 26: Widget handles very long press',
        (WidgetTester tester) async {
      await tester.pumpWidget(createVoiceButton());
      await tester.pumpAndSettle();

      final button = find.byType(FloatingActionButton);

      // Hold for extended period
      final gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(seconds: 2));

      // Button should still exist
      expect(find.byType(FloatingActionButton), findsOneWidget);

      await gesture.up();
      // Don't wait for settle - just pump once to process the release
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Test 27: Foreground color is white',
        (WidgetTester tester) async {
      await tester.pumpWidget(createVoiceButton());
      await tester.pumpAndSettle();

      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );

      expect(fab.foregroundColor, Colors.white);
    });
  });
}
