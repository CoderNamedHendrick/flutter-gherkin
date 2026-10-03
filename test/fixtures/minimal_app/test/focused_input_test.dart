import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minimal_app/gherkin_harness/recorder.dart';
import '../integration_test/focused_test.dart' as generated;

void main() {
  testWidgets(
    'generated finder enters and clears SearchAnchor text with callbacks',
    (tester) async {
      final changes = <String>[];
      final controller = SearchController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchAnchor(
              searchController: controller,
              viewOnChanged: changes.add,
              builder: (context, controller) => TextButton(
                onPressed: controller.openView,
                child: const Text('Open search'),
              ),
              suggestionsBuilder: (context, controller) => [
                Text('Query: ${controller.text}'),
              ],
            ),
          ),
        ),
      );
      expect(generated.gherkinFocusedField, throwsA(isA<TestFailure>()));
      await tester.tap(find.text('Open search'));
      await tester.pumpAndSettle();
      await tester.enterText(generated.gherkinFocusedField(), 'movie');
      await tester.pump();
      expect(controller.text, 'movie');
      expect(changes, ['movie']);
      expect(find.text('Query: movie'), findsOneWidget);
      await tester.enterText(generated.gherkinFocusedField(), '');
      await tester.pump();
      expect(changes, ['movie', '']);
      expect(controller.text, isEmpty);
    },
  );

  testWidgets(
    'focus switches preserve distinct unkeyed recorder sessions without leaking input',
    (tester) async {
      final first = FocusNode();
      final second = FocusNode();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      final lines = <String>[];
      final changes = <String>[];
      await tester.pumpWidget(
        GherkinRecordingHarness(
          recorder: GherkinRecorder(sink: lines.add),
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  TextField(
                    focusNode: first,
                    onChanged: (value) => changes.add('first:$value'),
                  ),
                  TextField(
                    focusNode: second,
                    obscureText: true,
                    onChanged: (value) => changes.add('second:$value'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      first.requestFocus();
      await tester.pump();
      await tester.enterText(generated.gherkinFocusedField(), 'private-first');
      second.requestFocus();
      await tester.pump();
      await tester.enterText(generated.gherkinFocusedField(), 'private-second');
      expect(changes, ['first:private-first', 'second:private-second']);
      expect(lines.join(), isNot(contains('private-')));
      if (gherkinRecordingEnabled) {
        final entries = lines
            .map((line) => jsonDecode(line.substring(14)) as Map)
            .where((event) => event['action'] == 'enter_text')
            .toList();
        expect(entries, hasLength(2));
        expect(entries[0]['focus'], isNot(entries[1]['focus']));
        expect(entries[0]['value'], isNot(entries[1]['value']));
        expect(
          entries.every((e) => e['key'] == null && e['sensitive'] == true),
          true,
        );
      } else {
        expect(lines, isEmpty);
      }
      second.unfocus();
      await tester.pump();
      expect(generated.gherkinFocusedField, throwsA(isA<TestFailure>()));
    },
  );
}
