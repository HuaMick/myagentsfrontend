import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PairingScreen extends StatelessWidget {
  const PairingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pairing')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Pairing Screen Placeholder'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.go('/terminal'),
              child: const Text('Go to Terminal'),
            ),
          ],
        ),
      ),
    );
  }
}
