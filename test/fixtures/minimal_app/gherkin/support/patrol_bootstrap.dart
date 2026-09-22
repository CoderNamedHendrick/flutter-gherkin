import 'package:minimal_app/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

// Replace this implementation after inspecting the app bootstrap.
// Import a binding-free createApp() factory. Never call the normal app main().
Future<void> startApp(
  PatrolIntegrationTester $, {
  required String environment,
  required bool production,
}) async {
  if (const String.fromEnvironment('GHERKIN_ENVIRONMENT') != environment) {
    throw StateError(
      'Pass the explicitly allowed GHERKIN_ENVIRONMENT via dart-define',
    );
  }
  if (production && !const bool.fromEnvironment('GHERKIN_CONFIRM_PRODUCTION')) {
    throw StateError('Production needs renewed user confirmation for this run');
  }
  await $.pumpWidgetAndSettle(createApp());
}

// Dart process environment variables are not available inside a mobile app.
// Supply values via an ignored --dart-define-from-file and a reviewed finite map.
// Example: case r'${env:TEST_PASSWORD}': return const String.fromEnvironment('TEST_PASSWORD');
String resolveValue(String placeholder) =>
    throw StateError('Unmapped secret/fixture placeholder (value suppressed)');

Future<void> assertVisible(
  PatrolIntegrationTester $,
  Finder finder,
  int? count,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (true) {
    final actual = finder.hitTestable().evaluate().length;
    if (count == null ? actual > 0 : actual == count) return;
    if (DateTime.now().isAfter(deadline)) {
      throw TestFailure(
        'Visible match count: expected ${count ?? 'at least one'}, found $actual',
      );
    }
    await $.pump(const Duration(milliseconds: 100));
  }
}
