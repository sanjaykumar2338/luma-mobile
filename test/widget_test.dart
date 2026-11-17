// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma_mobile/main.dart';

void main() {
  testWidgets('empty states provide actionable user-facing copy',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: EmptyState(
                title: 'No sermons yet',
                message: 'Submit a sermon to begin.'))));

    expect(find.text('No sermons yet'), findsOneWidget);
    expect(find.text('Submit a sermon to begin.'), findsOneWidget);
  });
}
