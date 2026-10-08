import 'package:Meetcha/widgets/meetcha_loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Meetcha loading screen dapat dirender', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MeetchaLoadingScreen()));

    expect(find.byType(MeetchaLoading), findsOneWidget);
    expect(find.bySemanticsLabel('Memuat'), findsOneWidget);
  });
}
