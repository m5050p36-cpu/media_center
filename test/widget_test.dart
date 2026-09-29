import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Smoke test - Material widget renders', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Media Center')),
        ),
      ),
    );
    expect(find.text('Media Center'), findsOneWidget);
  });
}
