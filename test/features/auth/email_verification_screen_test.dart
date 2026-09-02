import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pulse/features/auth/presentation/email_verification_screen.dart';

void main() {
  testWidgets('verification screen exposes check and resend recovery actions', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: EmailVerificationScreen())));
    expect(find.text('i’ve verified'), findsOneWidget);
    expect(find.text('resend email'), findsOneWidget);
  });
}
