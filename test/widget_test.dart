import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up_down/pages/login_page.dart';

void main() {
  testWidgets('Login page renders basic fields', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoginPage(),
      ),
    );

    expect(find.text('Login'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
