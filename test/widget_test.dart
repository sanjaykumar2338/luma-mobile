// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luma_mobile/main.dart';
import 'package:luma_mobile/ui/luma_design.dart';

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

  testWidgets('premium navigation exposes the handoff destinations',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: lumaTheme(),
        home: Scaffold(
            bottomNavigationBar: LumaBottomBar(index: 0, onChanged: (_) {}))));

    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.bySemanticsLabel('New study'), findsOneWidget);
    expect(find.text('Plans'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
  });

  testWidgets('design system renders the dark hero and accent CTA',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: lumaTheme(),
        home: Scaffold(
            body: Padding(
                padding: const EdgeInsets.all(24),
                child: LumaDarkCard(
                    child: LumaAccentButton(
                        label: 'Continue study', onPressed: () {}))))));

    expect(find.text('Continue study'), findsOneWidget);
    expect(find.byType(LumaDarkCard), findsOneWidget);
    expect(find.byType(LumaAccentButton), findsOneWidget);
  });
}
