// Hand-written harness smoke; not derived from a feature.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

void main() {
  patrolTest('self-contained native harness', ($) async {
    await $.pumpWidgetAndSettle(
      const MaterialApp(home: Scaffold(body: Text('Ready'))),
    );
    expect(find.text('Ready'), findsOneWidget);
    await $.platform.mobile.pressHome();
  });
}
