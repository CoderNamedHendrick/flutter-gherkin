# Flutter Gherkin

One agent-neutral Agent Skill for Flutter UI testing: install Marionette, record a
manual flow as Gherkin, replay it, and optionally generate persistent Patrol tests.
Features are the source of truth. This repository is an Agent Skills package, not an
agent plugin or a global CLI.

```sh
npx skills add CoderNamedHendrick/flutter-gherkin --skill gherkin -a universal
# Local installation, from the target project:
npx skills add /path/to/flutter-gherkin --skill gherkin -a universal
```

The skill is available from [CoderNamedHendrick/flutter-gherkin](https://github.com/CoderNamedHendrick/flutter-gherkin).
The distribution is named `flutter-gherkin`; the installed skill remains `gherkin`.
Use `$gherkin` where supported, or ask your agent naturally:

```text
gherkin install
gherkin doctor
gherkin record login
gherkin run login
gherkin run gherkin
gherkin generate-patrol login
```

Install offers Marionette only or Marionette + Patrol. Marionette drives Flutter;
Patrol adds native OS automation and generated Dart tests. Loaded MCP capabilities are
preferred, with CLI fallback. Each host's configuration is selected explicitly.

```text
gherkin/
  config.yaml
  README.md
  features/
  fixtures/
  evidence/{screenshots,logs}/
  support/
integration_test/       # generated Patrol tests, inside the Flutter app
lib/gherkin_harness/     # inside the Flutter app
```

Commit features, configuration without secrets, bootstrap and generated Patrol tests.
Ignore evidence, local credentials and Patrol bundles. Run `check-generated` in CI.

The [closed dialect](skills/gherkin/references/dialect.md) supports keys, exact text,
text entry, scroll targets, bounded waits, fixtures and explicit assertions. Native
steps have declared support. Unknown steps fail. Recording produces a draft and asks
for assertions; it does not infer business intent. Sensitive fields are redacted before
logging. Arbitrary routers need a route hook; arbitrary gestures and system photo pickers
are not automatically compiled. Multi-device MCP replay is a serial agent workflow;
CLI and Patrol generation reject actor switching.

Installation is agent-guided: helpers scaffold deterministic files, while the agent
inspects application bootstrap and native projects before integrating them. No generic
textual main() patch is applied. See [validation status](VALIDATION.md) for verified
platforms and remaining limitations. No bug intake, branch operations, commits, PRs,
trackers or company-specific setup are included.

## Development

Requires Dart >=3.11; mobile verification additionally needs Flutter and native SDKs.

```sh
cd skills/gherkin/scripts
dart pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed bin lib test
dart analyze
dart test
```

[Tooling reference](skills/gherkin/references/tooling.md) describes helper arguments
and exit codes. Validate the skill with `skills-ref validate skills/gherkin` and test
`npx skills add` in an isolated project directory. The Flutter fixture has focused
harness tests; run these with both INTEGRATION_TEST and GHERKIN_RECORD dart-defines.
Run mobile smoke tests only on selected test devices, never production. A new dialect
step needs parser/support, generator, replay, escaping and behavior tests. Consult
current primary docs before changing native APIs or setup; do not freeze old versions
from examples. Do not commit build caches, logs or local simulator identifiers.

Run `dart tooling/verify.dart` from the repository root for the combined static and
Flutter fixture checks. The declared minimum helper SDK is Dart 3.11 (the lockfile's
minimum); the mobile fixture was executed on Dart 3.12.2. For local installation from
a development checkout, exclude `.dart_tool` caches or use a clean source copy; the
Skills CLI may otherwise copy them too. Always run the documented locked pub setup
after installation.

For Android native verification, boot a disposable emulator and run
`python3 tooling/android_smoke.py --device <emulator-serial> --repeat 2`.
This runs all four fixture tests serially and requires both Patrol process success
and fresh, passing native JUnit reports. It retains full system logcat, CLI output
and verdicts under ignored `.test-work/`, and stops at the first failed run.
It does not create, wipe or restart emulators. Python 3 is needed only for this
repository development tool. Test its verdict checks with
`python3 -m unittest discover -s tooling -p 'test_android_smoke.py'`.
