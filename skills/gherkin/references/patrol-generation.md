# Deterministic Patrol generation

Features remain authoritative; commit generated Dart initially so CI can run it
without the skill. Validate all selected features, fixtures, backend support and draft
status before writing. Actor switching and manual photo-picker steps are rejected,
not reduced to incomplete tests. Existing app bootstrap integration is required.

Run generate-patrol. Write tests to `integration_test/` in the Flutter app root
(`app_root`), alongside `pubspec.yaml`. One file per feature, one patrolTest per
scenario, with feature + scenario display name and inherited tags. Background steps repeat per scenario. Nested
feature folders are mirrored, avoiding basename collisions. The generated header names
the source and digests source/config inputs. No timestamp appears in generated output.
Dart strings escape quotes, backslashes, controls and dollar interpolation. Helpers
format output with the selected Dart formatter; use a consistent SDK in CI.

The shared gherkin/support/patrol_bootstrap.dart exposes startApp, resolveValue and
assertVisible. Inspect/adapt this once: startApp checks environment and fresh production
confirmation, initializes services in a test-safe way, and pumps a binding-free app
factory. Never call normal main(), another binding, runApp(), or replace FlutterError
handlers. resolveValue maps only declared placeholders to ignored dart-define values.
Never hardcode secret values in generated output. assertVisible polls bounded hittable
finder counts, matching Marionette visibility semantics.

Generated key finders use ValueKey<String>; exact-text steps use find.text. Patrol
settles tap/entry/scroll itself; only explicit waits and assertion polling add waits.
Native calls use $.platform.mobile, verified against the installed package source.
Inspect existing project API patterns and analyze generated files before execution.
Permission “if visible” guards do not imply permission state when no dialog appears.

Run check-generated against the full suite in CI. It regenerates into temporary files,
formats, then compares full bytes (including input hash) without touching committed
output. New/edited features/config, changed compiler output or formatting differences
fail. Full-suite checking also flags orphaned generated tests after deleting/renaming a feature;
never delete unrelated hand-written tests automatically.

After analysis, prefer the loaded Patrol server's advertised run capability for one
target. Verify reported completion/status and capture evidence. CLI fallback uses patrol.command (default patrol):
`patrol test -t integration_test/login_test.dart` from the Flutter root, with
configured device, flavor and dart-define files including GHERKIN_ENVIRONMENT. Do not
pass INTEGRATION_TEST=true to the normal application main in Patrol. Run whole suites
with patrol test. Tests are not executed by `flutter test`.
