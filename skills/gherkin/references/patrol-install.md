# Optional Patrol installation

Only after the user selects Marionette + Patrol. Marionette remains the interactive
baseline. Inspect existing tests first. Consult current [setup](https://patrol.leancode.co/documentation),
[compatibility](https://patrol.leancode.co/documentation/compatibility-table) and
[MCP](https://patrol.leancode.co/documentation/other/patrol-mcp) before choosing versions.
Do not copy old package constraints. Resolve compatible patrol, patrol_cli and patrol_mcp;
record actual versions. For a missing CLI activate patrol_cli using the selected SDK;
run patrol doctor and inspect checks for selected platforms. Add patrol and patrol_mcp
as dev dependencies. A project-local `dart run patrol_cli:main` is also useful when
avoiding a global version conflict, but verify its current executable name first.

Merge the pubspec patrol block; preserve unrelated settings. Set app_name, Android
application ID and iOS bundle ID from actual build configuration. `patrol-directory`
sets test_directory without destroying other fields and refuses a conflicting existing
suite location. For nested apps it computes the relative path from pubspec to the
root's gherkin/generated/patrol. Keep generated tests inside the Flutter package where
possible so imports and analysis resolve normally.

## Android

Read the installed SDK/project's Gradle dialect before editing. Follow current official
native setup rather than replacing Gradle files. For Kotlin DSL merge into defaultConfig:

```kotlin
testInstrumentationRunner = "pl.leancode.patrol.PatrolJUnitRunner"
testInstrumentationRunnerArguments["clearPackageData"] = "true"
```

Groovy equivalents use `testInstrumentationRunner "..."` and
`testInstrumentationRunnerArguments clearPackageData: "true"`. In android.testOptions
set execution to ANDROIDX_TEST_ORCHESTRATOR (assignment in Kotlin, method syntax in
Groovy). Add androidTestUtil with the orchestrator version currently specified upstream.
Create the parameterized MainActivityTest.java runner from current upstream setup,
with the actual Java/Kotlin namespace and activity class. It obtains PatrolJUnitRunner
from InstrumentationRegistry, sets up the activity, waits for the app service, enumerates
Dart tests and dispatches each named test. Check namespace versus flavored applicationId
suffixes; these may differ. Avoid duplicate runner declarations and conflicting existing
test runners. Do not disable release shrinking as a shortcut. Verify min SDK/native
compatibility from the resolved package. Run on a fully booted emulator.

## iOS

Inspect CocoaPods versus SPM and existing test targets. Add/reuse a RunnerUITests UI
Testing Bundle targeting Runner, with matching deployment target (upstream minimum
currently 13). Integrate the current PATROL_INTEGRATION_TEST_IOS_RUNNER macro in its
Objective-C source and ensure source membership. Do not replace unit-test targets.

CocoaPods: nested RunnerUITests target inherits complete Runner dependencies. SPM:
link FlutterGeneratedPluginSwiftPackage into the UI-test target. Match Runner build
configuration xcconfig references, add Flutter xcode_backend build and embed_and_thin
phases in upstream-prescribed order, disable script sandboxing for the UI-test target,
and disable parallel UI test execution in every selected scheme/test plan. Include the
UI-test target in TestAction. Set TEST_TARGET_NAME, bundle ID, deployment target, device
family and signing appropriately; simulator smoke uses no physical-device signing.
Generate config with `flutter build ios --config-only <smoke-target>`, then pod install
when applicable. Verify Xcode target membership with xcodebuild, not textual markers.

Flavors need actual schemes and Debug-<flavor>, Profile-<flavor>, Release-<flavor>
configurations. Preserve existing app flavor semantics. If native setup cannot be
safely modified/verified, report the exact missing target/configuration and a proposed
patch; do not label iOS ready. Physical-device provisioning is separate.

## MCP and verification

Merge the selected host's project-local MCP entry using current patrol_mcp README.
Server command is selected Dart `run patrol_mcp`, PROJECT_ROOT is the app directory,
SHOW_TERMINAL=false. Set PATROL_FLUTTER_COMMAND to the chosen Flutter invocation.
Propagate flavor/define/environment flags through PATROL_FLAGS, using host-safe quoting
and ignored local files. Do not embed secret values in shared MCP config. Only one
Patrol develop session may own a device at a time.

Ignore **/test_bundle.dart and .patrol.env. First run a self-contained smoke test using
framework widgets and a native home-button action through Patrol CLI. Then run an app
root smoke with the binding-free bootstrap. Prefer loaded Patrol MCP run/status/
screenshot for one generated target and verify CLI independently; use patrol test for
full suites. A just-registered MCP server needs a host reload before tools are available;
CLI smoke can continue meanwhile. Report each channel/platform separately.

A successful smoke requires a successful final native process verdict and nonzero test count. Dart-level success followed by native teardown failure is not PASS. Collect native logs and report the exact platform/SDK failure without weakening the test or silently patching upstream dependencies.

For Android teardown failures, start `adb -s <selected-device> logcat -b all -v
threadtime -T 1` before the run and retain its output alongside verbose Patrol output
and fresh native JUnit XML. A Flutter-only or app-PID filter omits the shell/system
processes involved in instrumentation. `UiAutomation.disconnect` with
`DeadObjectException` means the remote Binder was unavailable; it does not establish
an app assertion failure, a particular Patrol version bug, or the reason the remote
process stopped. Inspect the preceding system/crash/events logs before selecting a fix.

Check boot completion, Package Manager responsiveness, free storage and competing
instrumentation sessions. After preserving failure evidence, a fresh disposable or
cold-booted emulator can distinguish persistent project failures from transient device
state. Do not wipe existing user data, swallow teardown exceptions, disable the
orchestrator or upgrade dependencies speculatively. Keep failed and successful runs
separate; recovery by rerun is not proof of the original trigger. Require the final
native process verdict and expected native test count before reporting recovery.
