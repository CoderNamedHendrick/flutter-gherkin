# Project configuration

`--root` is the test-owning project root. For monorepos, select a Flutter app explicitly;
`app_root` is relative to that root. The simplest placement is inside each app. All
features/evidence stay under the selected root's `gherkin/`, runtime code under the
Flutter app's `lib/gherkin_harness/`, and generated Patrol tests under the Flutter
app's `integration_test/` beside its `pubspec.yaml`, including for nested apps.
Scaffolding writes JSON-compatible YAML and never rewrites existing config. The parser accepts ordinary YAML too.

```yaml
version: 1
app_root: .
entrypoint: lib/main.dart
flutter_command: [flutter] # [fvm, flutter] or [puro, flutter]
flavor: null
environment: local
allowed_environments: [local]
production: false
dart_define_files: [] # paths relative to app_root; ignore files containing secrets
default_device: null # select actual device ID before launch
platforms: [android, ios]
suite: [login.feature] # relative to features; listed first, remaining files lexical
fixtures:
  logged_out:
    - 'I tap the widget keyed "logout"'
    - 'the widget keyed "login" is visible'
actors: {}
marionette:
  preference: auto # loaded MCP first, then CLI; mcp or cli pins a backend
patrol:
  enabled: false
  command: [patrol] # optional, or [dart, run, "patrol_cli:main"]
  preference: auto
  bootstrap: gherkin/support/patrol_bootstrap.dart # relative to root
agent:
  name: null
  config_path: null # selected project-relative file; registration != loaded
public_text_keys: []
sensitive_keys: []
```

Unknown top-level keys and invalid types fail validation. Relative paths cannot escape
the root, including through symlinks. Suite entries must exist. Folder runs include all
features in that folder; suite order applies before lexical remainder. Unconfigured
fixture selection fails before executing any scenario. Fixture adapters are nonrecursive
portable action/assertion lists; no arbitrary commands are executed from YAML.

`production` must be explicit. Production-like environment names require true; an
agent must also inspect dart-define files, endpoints and flavors, since names alone
cannot prove environment isolation. Production is allowed only when listed, marked
true, and reconfirmed for each run. `--confirm-production` records that fresh confirmation;
never infer it from a previous run. Patrol additionally checks compile-time environment
and production confirmation in its shared bootstrap.

Credentials remain in the invoking environment or ignored local define files. The
configuration contains references and test facts, never values. Recorder policy must
be passed into `GherkinRecorder` by the app: YAML does not magically configure a mobile
binary. Default recording redacts every text input; explicitly allowlist public fields.
