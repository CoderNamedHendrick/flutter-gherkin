# Deterministic helpers

Run from the installed skill's `scripts/` directory. `dart pub get --enforce-lockfile`
resolves pinned helper dependencies. Use the project's selected SDK (FVM/Puro Dart if
needed). Runtime package requires Dart >=3.11. Assets resolve via package URI, so a
copied universal installation and vendor-specific directories both work.

```text
dart run bin/gherkin.dart doctor --root <root> --json
dart run bin/gherkin.dart doctor --root <root> --probe
dart run bin/gherkin.dart inspect --root <root>
dart run bin/gherkin.dart scaffold --root <root> --app . --environment <allowed> [--patrol]
dart run bin/gherkin.dart patrol-directory --root <root>
dart run bin/gherkin.dart validate login --root <root>
dart run bin/gherkin.dart launch --root <root> --device <id> [--record]
dart run bin/gherkin.dart vm-uri --root <root> --log <launch-log>
dart run bin/gherkin.dart parse-recording --root <root> --log <log> --name login
dart run bin/gherkin.dart run-cli login --root <root> --uri <ws-uri>
dart run bin/gherkin.dart generate-patrol login --root <root>
dart run bin/gherkin.dart check-generated gherkin --root <root>
```

Install/record/run are agent workflows, not unattended single commands. `scaffold`
creates owned directories/templates only; the agent installs packages, reviews bootstrap
and native changes, selects MCP config and proves the smoke test. It never blindly
patches main(). `launch` is a foreground long-lived process: use the host's background
process facility, retain its PID, and stop it when finished. JSON status includes log
path and websocket URI. It does not boot an arbitrary emulator for you.

`validate` reports syntax and per-step support; execution/generation enforce backend,
fixture and draft restrictions. `generate-patrol` formats then analyzes in the app SDK;
analysis failure leaves files for inspection but reports failure, never success.
`check-generated` compares complete regenerated formatted bytes, including input digest.
Exit 0 success, 1 failed checks/scenarios, 2 invalid config/input or unavailable operation.

Doctor without `--probe` reads files and PATH only. `--probe` asks SDK tools for devices,
emulators and Patrol diagnostics; those tools may maintain their own caches. Neither
mode installs dependencies or edits project/config files.
