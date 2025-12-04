// Basic Flutter widget test for MyAgents Frontend
//
// Tests that the app renders correctly with its initial state.

import 'package:flutter_test/flutter_test.dart';

import 'package:myagents_frontend/main.dart';

void main() {
  testWidgets('MyAgentsApp renders pairing screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyAgentsApp());

    // Verify the app renders with Pairing screen (initial route)
    expect(find.text('Pairing'), findsOneWidget);
    expect(find.text('Go to Terminal'), findsOneWidget);
  });
}
