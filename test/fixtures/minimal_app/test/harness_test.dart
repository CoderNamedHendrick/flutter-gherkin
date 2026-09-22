import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_app/app.dart';
import 'package:minimal_app/gherkin_harness/binding.dart';
import 'package:minimal_app/gherkin_harness/recorder.dart';

void main() {
  testWidgets('test binding is preserved with integration flags', (
    tester,
  ) async {
    final before = WidgetsBinding.instance;
    initializeGherkinBinding();
    expect(identical(before, WidgetsBinding.instance), true);
    await tester.pumpWidget(createApp());
    expect(find.byKey(const ValueKey<String>('submit')), findsOneWidget);
  });
  testWidgets('real focus/controller changes redact before the log sink', (
    tester,
  ) async {
    final lines = <String>[];
    final recorder = GherkinRecorder(
      publicTextKeys: {'name_field', 'password_field'},
      sink: lines.add,
    );
    await tester.pumpWidget(
      GherkinRecordingHarness(recorder: recorder, child: createApp()),
    );
    await tester.tap(find.byKey(const ValueKey<String>('name_field')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey<String>('name_field')),
      'Ada',
    );
    await tester.tap(find.byKey(const ValueKey<String>('password_field')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey<String>('password_field')),
      'never-log-this',
    );
    await tester.tap(find.byKey(const ValueKey<String>('submit')));
    await tester.pump();
    if (!gherkinRecordingEnabled) {
      expect(lines, isEmpty);
      return;
    }
    expect(lines.join(), isNot(contains('never-log-this')));
    final events = lines
        .map((line) => jsonDecode(line.substring(14)) as Map)
        .toList();
    expect(
      events.where((e) => e['action'] == 'enter_text' && e['value'] == 'Ada'),
      isNotEmpty,
    );
    expect(
      events.where(
        (e) =>
            e['action'] == 'enter_text' &&
            e['value'] == r'${fixture:password_field}',
      ),
      isNotEmpty,
    );
    expect(
      events.where((e) => e['action'] == 'tap' && e['key'] == 'submit'),
      isNotEmpty,
    );
  });
}
