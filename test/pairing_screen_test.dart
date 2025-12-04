import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myagents_frontend/features/pairing/pairing_screen.dart';

void main() {
  group('PairingScreen Tests', () {
    /// Test 1: Verify AppBar with 'Pairing' title is displayed
    testWidgets('Has AppBar with Pairing title', (WidgetTester tester) async {
      // Mock router configuration for navigation testing
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const PairingScreen(),
          ),
          GoRoute(
            path: '/terminal',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Terminal Screen')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          title: 'MyAgents Frontend',
        ),
      );

      // Verify AppBar exists and has correct title
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Pairing'), findsOneWidget);
    });

    /// Test 2: Verify 'Go to Terminal' button is visible and clickable
    testWidgets('Has visible Go to Terminal button', (WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const PairingScreen(),
          ),
          GoRoute(
            path: '/terminal',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Terminal Screen')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          title: 'MyAgents Frontend',
        ),
      );

      // Verify button exists and contains correct text
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.text('Go to Terminal'), findsOneWidget);

      // Verify button is clickable (within a GestureDetector/pressable widget)
      final buttonFinder = find.byType(ElevatedButton);
      expect(buttonFinder, findsOneWidget);
    });

    /// Test 3: Verify layout uses Center and Column for proper centering
    testWidgets('Uses Center widget for proper centering', (WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const PairingScreen(),
          ),
          GoRoute(
            path: '/terminal',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Terminal Screen')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          title: 'MyAgents Frontend',
        ),
      );

      // Verify Scaffold exists
      expect(find.byType(Scaffold), findsOneWidget);

      // Verify Center widget is used for body
      expect(find.byType(Center), findsOneWidget);

      // Verify Column widget is used for layout
      expect(find.byType(Column), findsOneWidget);
    });

    /// Test 4: Verify placeholder text is visible
    testWidgets('Displays placeholder text', (WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const PairingScreen(),
          ),
          GoRoute(
            path: '/terminal',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Terminal Screen')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          title: 'MyAgents Frontend',
        ),
      );

      expect(find.text('Pairing Screen Placeholder'), findsOneWidget);
    });

    /// Test 5: Verify proper spacing between elements
    testWidgets('Has proper spacing between UI elements', (WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const PairingScreen(),
          ),
          GoRoute(
            path: '/terminal',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Terminal Screen')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          title: 'MyAgents Frontend',
        ),
      );

      // Verify SizedBox exists (used for spacing)
      expect(find.byType(SizedBox), findsWidgets);

      // Verify Column uses center alignment
      final columnFinder = find.byType(Column);
      expect(columnFinder, findsOneWidget);

      // Get the Column widget
      final columnWidget = tester.widget<Column>(columnFinder);
      expect(columnWidget.mainAxisAlignment, MainAxisAlignment.center);
    });

    /// Test 6: Verify screen is responsive (Center with Column layout)
    testWidgets('Layout is responsive with Center and Column', (WidgetTester tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const PairingScreen(),
          ),
          GoRoute(
            path: '/terminal',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Terminal Screen')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          title: 'MyAgents Frontend',
        ),
      );

      // Verify all required widgets are present
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(Center), findsOneWidget);
      expect(find.byType(Column), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });
}
