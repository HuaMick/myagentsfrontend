import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:myagents_frontend/main.dart';

/// Initialize the Flutter integration test binding.
///
/// This should be called at the start of each integration test file.
/// It ensures that the Flutter engine is properly initialized for testing.
Future<void> initializeApp(IntegrationTestWidgetsFlutterBinding binding) async {
  // Ensure binding is initialized
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  // Allow time for initialization
  await Future.delayed(const Duration(milliseconds: 100));
}

/// Pump the main MyAgentsApp widget into the test environment.
///
/// This helper launches the app and waits for it to settle.
///
/// Parameters:
/// - [tester]: The WidgetTester instance from the test
/// - [app]: Optional custom app widget. If not provided, uses MyAgentsApp
///
/// Example:
/// ```dart
/// await pumpApp(tester);
/// ```
Future<void> pumpApp(WidgetTester tester, {Widget? app}) async {
  await tester.pumpWidget(app ?? const MyAgentsApp());
  await tester.pumpAndSettle();
}

/// Wait for a widget to appear with a timeout.
///
/// This is useful for widgets that appear after async operations like
/// navigation, API calls, or delayed rendering.
///
/// Parameters:
/// - [tester]: The WidgetTester instance from the test
/// - [finder]: The Finder to wait for
/// - [timeout]: Maximum time to wait (default: 10 seconds)
///
/// Throws a [TimeoutException] if the widget doesn't appear within the timeout.
///
/// Example:
/// ```dart
/// await waitForWidget(tester, find.text('Welcome'));
/// ```
Future<void> waitForWidget(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final endTime = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(endTime)) {
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    if (finder.evaluate().isNotEmpty) {
      return;
    }

    await Future.delayed(const Duration(milliseconds: 100));
  }

  throw Exception(
    'Widget not found after ${timeout.inSeconds} seconds: $finder',
  );
}

/// Navigate to a specific route.
///
/// This helper uses GoRouter's navigation and waits for the transition
/// to complete.
///
/// Parameters:
/// - [tester]: The WidgetTester instance from the test
/// - [route]: The route path to navigate to (e.g., '/terminal')
///
/// Example:
/// ```dart
/// await navigateTo(tester, '/terminal');
/// ```
Future<void> navigateTo(WidgetTester tester, String route) async {
  // Find the navigator
  final BuildContext context = tester.element(find.byType(MaterialApp).first);

  // Navigate using GoRouter
  // Note: This assumes GoRouter is accessible from the context
  // If using a custom navigation approach, adjust accordingly
  Navigator.of(context).pushNamed(route);

  // Wait for navigation transition
  await tester.pumpAndSettle();
}

/// Enter text into a text field.
///
/// This helper focuses the field, enters text, and ensures the widget
/// tree is updated.
///
/// Parameters:
/// - [tester]: The WidgetTester instance from the test
/// - [finder]: The Finder for the text field
/// - [text]: The text to enter
///
/// Example:
/// ```dart
/// await enterText(tester, find.byKey(Key('pairing-code-field')), '123456');
/// ```
Future<void> enterText(
  WidgetTester tester,
  Finder finder,
  String text,
) async {
  // Ensure the widget exists
  expect(finder, findsOneWidget);

  // Tap to focus the field
  await tester.tap(finder);
  await tester.pumpAndSettle();

  // Enter the text
  await tester.enterText(finder, text);
  await tester.pumpAndSettle();
}

/// Tap a button and wait for the result.
///
/// This helper taps a button and waits for any animations or async
/// operations to complete.
///
/// Parameters:
/// - [tester]: The WidgetTester instance from the test
/// - [finder]: The Finder for the button
///
/// Example:
/// ```dart
/// await tapButton(tester, find.text('Connect'));
/// ```
Future<void> tapButton(WidgetTester tester, Finder finder) async {
  // Ensure the widget exists
  expect(finder, findsOneWidget);

  // Tap the button
  await tester.tap(finder);

  // Wait for any animations or async operations
  await tester.pumpAndSettle();
}

/// Wait for a specific duration and pump frames.
///
/// This is useful when waiting for delayed operations or animations.
///
/// Parameters:
/// - [tester]: The WidgetTester instance from the test
/// - [duration]: How long to wait
///
/// Example:
/// ```dart
/// await waitFor(tester, Duration(seconds: 2));
/// ```
Future<void> waitFor(WidgetTester tester, Duration duration) async {
  await tester.pump(duration);
  await tester.pumpAndSettle();
}

/// Scroll until a widget is visible.
///
/// This helper scrolls through a scrollable widget until the target
/// widget is found.
///
/// Parameters:
/// - [tester]: The WidgetTester instance from the test
/// - [finder]: The Finder for the widget to scroll to
/// - [scrollable]: The Finder for the scrollable widget (e.g., ListView)
/// - [offset]: The scroll offset per iteration (default: -200.0 for upward)
///
/// Example:
/// ```dart
/// await scrollUntilVisible(
///   tester,
///   find.text('Bottom Item'),
///   find.byType(ListView),
/// );
/// ```
Future<void> scrollUntilVisible(
  WidgetTester tester,
  Finder finder,
  Finder scrollable, {
  double offset = -200.0,
}) async {
  const maxScrolls = 50;
  var scrollCount = 0;

  while (finder.evaluate().isEmpty && scrollCount < maxScrolls) {
    await tester.drag(scrollable, Offset(0, offset));
    await tester.pumpAndSettle();
    scrollCount++;
  }

  if (finder.evaluate().isEmpty) {
    throw Exception('Widget not found after scrolling: $finder');
  }
}

/// Verify that a widget exists and is visible.
///
/// This is a convenience helper that combines finding and asserting.
///
/// Parameters:
/// - [finder]: The Finder for the widget
///
/// Example:
/// ```dart
/// verifyVisible(find.text('Welcome'));
/// ```
void verifyVisible(Finder finder) {
  expect(finder, findsOneWidget);
}

/// Verify that a widget does not exist.
///
/// This is a convenience helper for negative assertions.
///
/// Parameters:
/// - [finder]: The Finder for the widget
///
/// Example:
/// ```dart
/// verifyNotVisible(find.text('Error'));
/// ```
void verifyNotVisible(Finder finder) {
  expect(finder, findsNothing);
}

/// Take a screenshot during the test.
///
/// Screenshots are saved to the integration_test/screenshots directory.
///
/// Parameters:
/// - [binding]: The IntegrationTestWidgetsFlutterBinding instance
/// - [name]: The name for the screenshot file
///
/// Example:
/// ```dart
/// await takeScreenshot(binding, 'pairing_screen');
/// ```
Future<void> takeScreenshot(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  await binding.takeScreenshot(name);
}
