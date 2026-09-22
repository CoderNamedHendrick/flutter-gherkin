# Validation status

Verified locally on 2026-09-21 with Flutter 3.44.9, Dart 3.12.2 and iOS 26.5 simulators;
Android API 36 follow-up verification on 2026-09-22.
The helper lockfile requires Dart >=3.11. The app resolved Marionette 0.6.0,
Patrol 4.10.0, Patrol CLI 4.8.0 and Patrol MCP 0.2.1.

| Check | Result |
| --- | --- |
| Open Agent Skills structural validation | PASS with official skills-ref |
| Local npx skills installation | PASS, one skill, universal target |
| Cross-agent installation layouts | PASS for Claude Code, Cursor, Copilot, Gemini CLI, Codex |
| Clean copied installation, locked dependency setup, helper execution | PASS |
| 0.1.0 release ZIP | PASS, deterministic 31-file archive, license included, caches excluded |
| Clean release extraction and npx skills installation | PASS; installed helper analysis, 24 tests and feature validation passed |
| Dart formatting and static analysis | PASS |
| Helper tests | PASS, 24 tests: parsing, config, support, recording, redaction, escaping, generation, stale/orphan checks, idempotency, preservation, discovery, capability decisions, doctor immutability, symlinks |
| Flutter harness tests | PASS with flags enabled and disabled |
| Widget test binding isolation | PASS even with INTEGRATION_TEST=true |
| Minimal real Flutter fixture | Integrated, analyzed and executed |
| Flavored real Flutter fixture | local/preview detection, scaffold idempotency and analysis PASS |
| Marionette iOS tree | PASS, non-empty through CLI and MCP protocol |
| Marionette iOS feature replay | PASS: actions, visibility, exact count, absence, screenshots |
| Recording instrumentation | PASS: actual widget/controller events, JSONL conversion and replay |
| Patrol iOS native harness smoke | PASS, self-contained widget plus native home button |
| Generated Patrol iOS test via CLI | PASS, one test, zero failures |
| Android Kotlin DSL native build | PASS |
| Generated Patrol Android API 36 execution | PASS on fresh Pixel 6 and Pixel 9a emulators; earlier teardown failure investigated below |
| Complete Android native fixture suite | PASS, 4/4 including two native Home actions |
| Android smoke verdict regression tests | PASS, rejects nonzero native exit, missing/incomplete reports, failures, errors and skips |
| Generated Patrol iOS test via MCP | PASS, run/status reported success, develop session quit |
| Committed Patrol output in sync | PASS, byte-for-byte regeneration checked |

The MCP tests connect directly to the real stdio servers and discover their advertised
schemas. They do not register servers in the user's coding-agent settings. Cross-agent
installation verifies package layouts, not every host's MCP configuration/reload UI.

The recording smoke uses automated fixture interaction to exercise the same pointer/
focus capture path. A human demonstration and assertion-confirmation conversation was
not fabricated. Those remain agent workflow steps. Multi-device segment ordering and
connection isolation are tested deterministically; a coordinated two-human-account live
scenario has not been exercised. Physical devices and arbitrary custom routers/design
systems are not certified by these fixtures.

Doctor deliberately separates static heuristics, known version compatibility, active
CLI probes and checks that require agent/device observation. It does not call a source
marker or registered server a successful smoke test. Native iOS fixture setup uses SPM;
CocoaPods setup is documented but was not exercised here. Android/Groovy and FVM/Puro
workflow guidance is included; live coverage is recorded below when available.

## Reproduce

Run `dart tooling/verify.dart` for static and Flutter fixture tests. Native smoke requires
an explicitly selected device. Use the installed skill's documented launch/run helpers;
run the fixture's generated login_test.dart via `dart run patrol_cli:main test` with
`--dart-define=GHERKIN_ENVIRONMENT=local`. `tooling/mcp_smoke.py` is a development-only
protocol client for the same test through Patrol MCP. Fixture-native Xcode setup can
be reproduced with `ruby tooling/configure_fixture_ios.rb` (xcodeproj gem required);
it is deliberately scoped to that fixture and never used to patch arbitrary apps.

Ignored evidence from this verification is in `.test-work/` and the minimal app's
`gherkin/evidence/`. It includes CLI logs, MCP results, converted recording draft,
scenario JSON reports and screenshots. Build caches and simulator-specific results
are not distributable skill assets.

## Android teardown investigation

A fresh disposable Android 16/API 36 emulator was created inside ignored test data.
The generated test compiled and its three actions and assertions passed. During native
instrumentation teardown, UiAutomation.disconnect threw RuntimeException caused by
DeadObjectException. Gradle/Patrol exited with failure; this is **not** a passing Android
smoke. The first attempt on an existing emulator was separately blocked by insufficient
internal storage; no existing emulator data was erased. The disposable emulator was
stopped after collecting logs. See `.test-work/android-teardown.log` and
`.test-work/patrol-android-fresh.log` for the failure.

Follow-up on 2026-09-22 traced the failure to Android framework
`Instrumentation.finish()`: it calls `UiAutomation.disconnect()` **before** delivering
the final instrumentation result. The remote `IUiAutomationConnection.disconnect()`
transaction raised `DeadObjectException`, so teardown threw instead of completing that
result delivery. This explains why the Dart tests passed while Patrol/Gradle failed.
The [Android framework source](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android16-release/core/java/android/app/Instrumentation.java)
confirms that ordering. The [`am instrument` source](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android16-release/cmds/am/src/com/android/commands/am/Instrument.java)
creates the remote UiAutomationConnection in the instrumentation-launching process.

The original capture retained Flutter and AndroidRuntime output, not the preceding
shell/system/events logs. It cannot establish why that remote Binder became unavailable.
Android documents that [DeadObjectException](https://developer.android.com/reference/android/os/DeadObjectException)
can reflect process death or a low-level Binder error. An emulator/process lifecycle
failure is the working diagnosis; a particular OS/Patrol bug, memory kill or dependency
incompatibility has not been proven.

The unchanged generated login test subsequently passed on a fresh, cold-booted API 36
Pixel 6 profile (1/1), followed by the complete fixture suite (4/4). A separate fresh
Pixel 9a profile, matching the failed run's device profile and visible software-rendered
emulator setup, also passed the complete suite (4/4). Each run returned exit zero and
Gradle BUILD SUCCESSFUL. Both native Home actions were exercised. Versions remained
Patrol 4.10.0, Patrol CLI 4.8.0, AndroidX runner/orchestrator 1.5.1, emulator 36.5.10
and Google Play arm64 API 36 system image revision 7. No dependency, app, generated test
or native runner patch was needed for these passes.

Two further consecutive Pixel 9a suite runs through the diagnostic smoke tool each
passed 4/4, with exit code zero and uninterrupted system-log capture. One took 101
seconds, so success was not confined to fast runs. In total, five invocations completed
17 native test executions successfully. The two machine-readable verdicts are in
`.test-work/android-smoke-1790063129803957000/run-{1,2}/verdict.json`. The disposable
emulators were stopped and their temporary disk images removed after verification.

`tooling/android_smoke.py` now records all logcat buffers from before execution, verbose
Patrol output, device facts, fresh native JUnit XML and a JSON verdict per run. It checks
the expected four native tests and fails on process failure, missing/stale reports,
failures, errors, skips or interrupted log capture. Repeat mode stops at the first
failure rather than retrying until green. Its verdict regression tests include the
original failure shape: all tests pass in XML but the process exits unsuccessfully.

Reproduce on a selected disposable emulator with:

```sh
python3 tooling/android_smoke.py --device <emulator-serial> --repeat 2
```

Evidence for the investigation is retained under `.test-work/android-investigation/`
and timestamped `.test-work/android-smoke-*/`. The original failure remains preserved
separately. A successful rerun resolves the immediate Android verification blocker;
it does not prove the original trigger or guarantee it cannot recur. No exception was
suppressed and no upstream package was patched. Groovy native execution and real
FVM/Puro SDK switching remain unverified; their discovery/configuration paths have tests.
