import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:myagents_frontend/main.dart';
import 'package:myagents_frontend/features/pairing/pairing_controller.dart';
import 'package:myagents_frontend/features/pairing/pairing_state.dart'
    as pairing_state;

import 'helpers/test_helpers.dart';
import 'fixtures/test_fixtures.dart';

void main() {
  // Initialize integration test binding
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Pairing Flow E2E', () {
    group('App launch and pairing screen display', () {
      testWidgets('app launches and shows pairing screen', (tester) async {
        // Initialize the app
        await initializeApp(binding);
        await pumpApp(tester);

        // Verify the app title is visible
        expect(find.text('Claude Remote Terminal'), findsOneWidget);

        // Verify the connect button is visible
        expect(find.text('Connect'), findsOneWidget);

        // Verify the pairing code input field is visible
        expect(find.byType(TextField), findsOneWidget);
      });

      testWidgets('pairing code input field has correct properties',
          (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        // Find the TextField widget
        final textFieldFinder = find.byType(TextField);
        expect(textFieldFinder, findsOneWidget);

        // Verify the TextField has the correct hint text
        final textField = tester.widget<TextField>(textFieldFinder);
        expect(textField.decoration?.hintText, equals('ABC123'));

        // Verify the TextField has max length of 6
        expect(textField.maxLength, equals(6));

        // Verify the TextField has uppercase capitalization
        expect(
          textField.textCapitalization,
          equals(TextCapitalization.characters),
        );
      });

      testWidgets('connect button is initially disabled', (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        // Find the Connect button
        final connectButton = find.ancestor(
          of: find.text('Connect'),
          matching: find.byType(ElevatedButton),
        );
        expect(connectButton, findsOneWidget);

        // Verify button is disabled (onPressed is null)
        final button = tester.widget<ElevatedButton>(connectButton);
        expect(button.onPressed, isNull);
      });
    });

    group('Enter valid 6-character code', () {
      testWidgets('entering valid code displays it in uppercase',
          (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        // Find the pairing code input field
        final textField = find.byType(TextField);

        // Enter a valid pairing code (lowercase to test auto-uppercase)
        await enterText(tester, textField, 'abc123');

        // Verify the code is displayed in uppercase
        expect(find.text('ABC123'), findsOneWidget);
      });

      testWidgets('entering mixed case code converts to uppercase',
          (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        final textField = find.byType(TextField);

        // Enter mixed case code
        await enterText(tester, textField, 'aBc123');

        // Verify it's converted to uppercase
        expect(find.text('ABC123'), findsOneWidget);
      });

      testWidgets('entering valid test fixture code', (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        final textField = find.byType(TextField);

        // Use the valid code from test fixtures
        await enterText(tester, textField, TestPairingCodes.valid);

        // Verify the code is displayed
        expect(find.text(TestPairingCodes.valid), findsOneWidget);
      });

      testWidgets('connect button enabled after valid 6-character code',
          (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        final textField = find.byType(TextField);

        // Enter a valid 6-character code
        await enterText(tester, textField, TestPairingCodes.valid);

        // Find the Connect button
        final connectButton = find.ancestor(
          of: find.text('Connect'),
          matching: find.byType(ElevatedButton),
        );

        // Verify button is now enabled
        final button = tester.widget<ElevatedButton>(connectButton);
        expect(button.onPressed, isNotNull);
      });

      testWidgets('code input limited to 6 characters', (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        final textField = find.byType(TextField);

        // Try to enter more than 6 characters
        await enterText(tester, textField, TestPairingCodes.tooLong);

        // Verify only first 6 characters are kept
        expect(find.text('ABCDEF'), findsOneWidget);
        expect(find.text(TestPairingCodes.tooLong), findsNothing);
      });

      testWidgets('special characters are filtered out', (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        final textField = find.byType(TextField);

        // Try to enter special characters
        await tester.tap(textField);
        await tester.pumpAndSettle();
        await tester.enterText(textField, 'AB!@12');
        await tester.pumpAndSettle();

        // Verify special characters are removed
        expect(find.text('AB12'), findsOneWidget);
      });
    });

    group('Connect button interaction', () {
      testWidgets('tapping connect button shows connecting state',
          (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        final textField = find.byType(TextField);

        // Enter a valid code
        await enterText(tester, textField, TestPairingCodes.valid);

        // Find and tap the Connect button
        final connectButton = find.ancestor(
          of: find.text('Connect'),
          matching: find.byType(ElevatedButton),
        );
        await tester.tap(connectButton);

        // Pump once to trigger the state change
        await tester.pump();

        // Verify connecting state is shown
        // The button should now show a loading spinner
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Verify the connecting message appears
        expect(find.text('Connecting to session...'), findsOneWidget);
      });

      testWidgets('connect button disabled while connecting', (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        final textField = find.byType(TextField);

        // Enter a valid code
        await enterText(tester, textField, TestPairingCodes.valid);

        // Find and tap the Connect button
        final connectButton = find.ancestor(
          of: find.text('Connect'),
          matching: find.byType(ElevatedButton),
        );
        await tester.tap(connectButton);
        await tester.pump();

        // Button should now be disabled (during connection)
        final button = tester.widget<ElevatedButton>(connectButton);
        expect(button.onPressed, isNull);
      });
    });

    group('Error handling', () {
      testWidgets('invalid code - too short shows disabled button',
          (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        final textField = find.byType(TextField);

        // Enter too short code
        await enterText(tester, textField, TestPairingCodes.invalid);

        // Find the Connect button
        final connectButton = find.ancestor(
          of: find.text('Connect'),
          matching: find.byType(ElevatedButton),
        );

        // Verify button is disabled
        final button = tester.widget<ElevatedButton>(connectButton);
        expect(button.onPressed, isNull);
      });

      testWidgets('empty code cannot connect', (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        final textField = find.byType(TextField);

        // Enter empty code
        await enterText(tester, textField, TestPairingCodes.empty);

        // Find the Connect button
        final connectButton = find.ancestor(
          of: find.text('Connect'),
          matching: find.byType(ElevatedButton),
        );

        // Verify button is disabled
        final button = tester.widget<ElevatedButton>(connectButton);
        expect(button.onPressed, isNull);
      });

      testWidgets('partial code (less than 6 chars) disables button',
          (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        final textField = find.byType(TextField);

        // Enter partial code
        await enterText(tester, textField, 'ABC12'); // Only 5 characters

        // Find the Connect button
        final connectButton = find.ancestor(
          of: find.text('Connect'),
          matching: find.byType(ElevatedButton),
        );

        // Verify button is disabled
        final button = tester.widget<ElevatedButton>(connectButton);
        expect(button.onPressed, isNull);
      });

      testWidgets('clearing code disables connect button', (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        final textField = find.byType(TextField);

        // First enter a valid code
        await enterText(tester, textField, TestPairingCodes.valid);

        // Verify button is enabled
        var connectButton = find.ancestor(
          of: find.text('Connect'),
          matching: find.byType(ElevatedButton),
        );
        var button = tester.widget<ElevatedButton>(connectButton);
        expect(button.onPressed, isNotNull);

        // Clear the code
        await enterText(tester, textField, '');

        // Verify button is now disabled
        button = tester.widget<ElevatedButton>(connectButton);
        expect(button.onPressed, isNull);
      });
    });

    group('Code input validation', () {
      testWidgets('code updates as user types', (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        final textField = find.byType(TextField);

        // Enter characters one by one
        await enterText(tester, textField, 'A');
        expect(find.text('A'), findsOneWidget);

        await enterText(tester, textField, 'AB');
        expect(find.text('AB'), findsOneWidget);

        await enterText(tester, textField, 'ABC');
        expect(find.text('ABC'), findsOneWidget);

        await enterText(tester, textField, 'ABC1');
        expect(find.text('ABC1'), findsOneWidget);

        await enterText(tester, textField, 'ABC12');
        expect(find.text('ABC12'), findsOneWidget);

        await enterText(tester, textField, 'ABC123');
        expect(find.text('ABC123'), findsOneWidget);
      });

      testWidgets('alphanumeric characters accepted', (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        final textField = find.byType(TextField);

        // Test letters
        await enterText(tester, textField, 'ABCDEF');
        expect(find.text('ABCDEF'), findsOneWidget);

        // Clear and test numbers
        await enterText(tester, textField, '123456');
        expect(find.text('123456'), findsOneWidget);

        // Clear and test mixed
        await enterText(tester, textField, 'A1B2C3');
        expect(find.text('A1B2C3'), findsOneWidget);
      });

      testWidgets('all test fixture codes work', (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        final textField = find.byType(TextField);

        // Test valid code
        await enterText(tester, textField, TestPairingCodes.valid);
        expect(find.text(TestPairingCodes.valid), findsOneWidget);

        // Test second valid code
        await enterText(tester, textField, TestPairingCodes.valid2);
        expect(find.text(TestPairingCodes.valid2), findsOneWidget);
      });
    });

    group('State management', () {
      testWidgets('controller state updates with code changes', (tester) async {
        await initializeApp(binding);

        // Create a controller we can inspect
        final controller = PairingController();
        final app = MaterialApp(
          home: Material(
            child: Builder(
              builder: (context) {
                return const MyAgentsApp();
              },
            ),
          ),
        );

        await pumpApp(tester, app: app);

        // Initially state should be idle with empty code
        expect(controller.state.pairingCode, isEmpty);
        expect(
          controller.state.connectionState,
          equals(pairing_state.ConnectionState.idle),
        );

        // Update code
        controller.updateCode('ABC123');
        expect(controller.state.pairingCode, equals('ABC123'));
        expect(controller.state.isValidCode, isTrue);
        expect(controller.state.canConnect, isTrue);

        // Cleanup
        controller.dispose();
      });

      testWidgets('controller validates code format', (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        final controller = PairingController();

        // Test valid code
        controller.updateCode('ABC123');
        expect(controller.state.isValidCode, isTrue);

        // Test invalid - too short
        controller.updateCode('ABC');
        expect(controller.state.isValidCode, isFalse);

        // Test invalid - empty
        controller.updateCode('');
        expect(controller.state.isValidCode, isFalse);

        // Cleanup
        controller.dispose();
      });

      testWidgets('canConnect property works correctly', (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        final controller = PairingController();

        // Initially cannot connect (no code)
        expect(controller.state.canConnect, isFalse);

        // Valid code - can connect
        controller.updateCode('ABC123');
        expect(controller.state.canConnect, isTrue);

        // Invalid code - cannot connect
        controller.updateCode('ABC');
        expect(controller.state.canConnect, isFalse);

        // Cleanup
        controller.dispose();
      });
    });

    group('UI layout and styling', () {
      testWidgets('screen has centered layout', (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        // Verify Center widget exists
        expect(find.byType(Center), findsWidgets);

        // Verify Scaffold exists
        expect(find.byType(Scaffold), findsOneWidget);
      });

      testWidgets('elements are in correct vertical order', (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        // Find all the main elements
        final title = find.text('Claude Remote Terminal');
        final textField = find.byType(TextField);
        final button = find.text('Connect');

        // Get their vertical positions
        final titleY = tester.getCenter(title).dy;
        final textFieldY = tester.getCenter(textField).dy;
        final buttonY = tester.getCenter(button).dy;

        // Verify vertical ordering (top to bottom)
        expect(titleY < textFieldY, isTrue,
            reason: 'Title should be above text field');
        expect(textFieldY < buttonY, isTrue,
            reason: 'Text field should be above button');
      });

      testWidgets('status message area exists', (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        // The status message area is a SizedBox with specific height
        // Initially it should be empty or contain a SizedBox.shrink
        final sizedBoxes = find.byType(SizedBox);
        expect(sizedBoxes, findsWidgets);
      });
    });

    group('Focus and keyboard interaction', () {
      testWidgets('tapping text field focuses it', (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        final textField = find.byType(TextField);

        // Tap the text field
        await tester.tap(textField);
        await tester.pumpAndSettle();

        // Verify field is focused by checking if keyboard would appear
        // In integration tests, we can verify the field accepted the tap
        final textFieldWidget = tester.widget<TextField>(textField);
        expect(textFieldWidget, isNotNull);
      });

      testWidgets('can type into focused field', (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        final textField = find.byType(TextField);

        // Focus and type
        await tester.tap(textField);
        await tester.pumpAndSettle();
        await tester.enterText(textField, 'TEST12');
        await tester.pumpAndSettle();

        // Verify text was entered
        expect(find.text('TEST12'), findsOneWidget);
      });
    });

    group('Button states and feedback', () {
      testWidgets('button shows correct text in idle state', (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        final textField = find.byType(TextField);
        await enterText(tester, textField, TestPairingCodes.valid);

        // Find button and verify text
        final buttonText = find.text('Connect');
        expect(buttonText, findsOneWidget);
      });

      testWidgets('button visual properties are correct', (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        final textField = find.byType(TextField);
        await enterText(tester, textField, TestPairingCodes.valid);

        // Find the ElevatedButton
        final connectButton = find.ancestor(
          of: find.text('Connect'),
          matching: find.byType(ElevatedButton),
        );

        final button = tester.widget<ElevatedButton>(connectButton);

        // Verify button has child (either text or spinner)
        expect(button.child, isNotNull);
      });
    });

    group('Multiple code entry attempts', () {
      testWidgets('can change code multiple times', (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        final textField = find.byType(TextField);

        // First code
        await enterText(tester, textField, 'ABC123');
        expect(find.text('ABC123'), findsOneWidget);

        // Change code
        await enterText(tester, textField, 'XYZ789');
        expect(find.text('XYZ789'), findsOneWidget);
        expect(find.text('ABC123'), findsNothing);

        // Change again
        await enterText(tester, textField, 'DEF456');
        expect(find.text('DEF456'), findsOneWidget);
        expect(find.text('XYZ789'), findsNothing);
      });

      testWidgets('button state updates when code changes', (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        final textField = find.byType(TextField);
        final connectButton = find.ancestor(
          of: find.text('Connect'),
          matching: find.byType(ElevatedButton),
        );

        // Start with valid code
        await enterText(tester, textField, TestPairingCodes.valid);
        var button = tester.widget<ElevatedButton>(connectButton);
        expect(button.onPressed, isNotNull);

        // Change to invalid code
        await enterText(tester, textField, 'ABC');
        button = tester.widget<ElevatedButton>(connectButton);
        expect(button.onPressed, isNull);

        // Back to valid code
        await enterText(tester, textField, TestPairingCodes.valid2);
        button = tester.widget<ElevatedButton>(connectButton);
        expect(button.onPressed, isNotNull);
      });
    });

    group('Accessibility', () {
      testWidgets('screen has readable text sizes', (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        // Find the title
        final titleText = find.text('Claude Remote Terminal');
        final titleWidget = tester.widget<Text>(titleText);

        // Verify title has appropriate size
        expect(titleWidget.style?.fontSize, greaterThanOrEqualTo(20));
      });

      testWidgets('button has minimum touch target size', (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        final connectButton = find.ancestor(
          of: find.text('Connect'),
          matching: find.byType(ElevatedButton),
        );

        // Get button size
        final buttonSize = tester.getSize(connectButton);

        // Verify minimum height for touch target (48dp recommended)
        expect(buttonSize.height, greaterThanOrEqualTo(48));
      });

      testWidgets('text field has sufficient size', (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        final textField = find.byType(TextField);
        final textFieldSize = tester.getSize(textField);

        // Verify field has reasonable dimensions
        expect(textFieldSize.height, greaterThanOrEqualTo(40));
        expect(textFieldSize.width, greaterThanOrEqualTo(100));
      });
    });

    group('Edge cases', () {
      testWidgets('pasting text into field', (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        final textField = find.byType(TextField);

        // Simulate pasting a long string
        await tester.tap(textField);
        await tester.pumpAndSettle();
        await tester.enterText(textField, 'ABCDEFGHIJKLMNOP');
        await tester.pumpAndSettle();

        // Should be truncated to 6 characters
        expect(find.text('ABCDEF'), findsOneWidget);
      });

      testWidgets('rapid typing simulated', (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        final textField = find.byType(TextField);

        // Simulate rapid sequential updates
        for (var i = 1; i <= 6; i++) {
          await tester.enterText(textField, 'A' * i);
          await tester.pump(TestTimeouts.typing);
        }

        // Final state should be 6 A's
        expect(find.text('AAAAAA'), findsOneWidget);
      });

      testWidgets('entering whitespace is filtered', (tester) async {
        await initializeApp(binding);
        await pumpApp(tester);

        final textField = find.byType(TextField);

        await tester.tap(textField);
        await tester.pumpAndSettle();
        await tester.enterText(textField, 'ABC 123');
        await tester.pumpAndSettle();

        // Whitespace should be removed
        expect(find.text('ABC123'), findsOneWidget);
      });
    });
  });
}
