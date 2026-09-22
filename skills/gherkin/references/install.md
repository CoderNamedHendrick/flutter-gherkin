# Install Marionette and the recorder

1. Run doctor (even before config exists), then inspect. Enumerate candidate pubspecs
   in monorepos, entrypoints, flavors, binding sites and toolchain selection. Ask the
   user to select when there is more than one plausible app. Follow FVM/Puro pins.
2. Ask **1. Marionette only / 2. Marionette + Patrol** unless already answered. Confirm
   relevant platforms, allowed test environment, define files, entrypoint and device.
   Read existing config before proposing changes; never assume staging or flavors.
3. Summarize concrete intended package, bootstrap, harness, native and MCP changes.
   Install prerequisites in dependency order: Flutter/SDK, pub dependencies, bridge,
   app integration, host config, device. Do not modify unrelated global configuration.
4. Check current [Marionette setup](https://github.com/leancodepl/marionette_mcp/blob/main/docs/flutter-setup.md)
   and [configuration](https://github.com/leancodepl/marionette_mcp/blob/main/docs/configuration.md).
   Run the selected Flutter command's `pub add marionette_flutter`. Resolve current
   compatible versions through pub; preserve existing constraints when compatible.
   For missing tools use `dart pub global activate marionette_mcp` and/or
   `dart pub global activate marionette_cli`; respect the selected Dart SDK. A local
   PUB_CACHE is supported. Avoid reactivating tools that already satisfy compatibility.
5. Run `scaffold` with explicit project facts. Existing files stay byte-for-byte intact.
   If upgrading templates, show a diff and merge deliberately. Scaffold does not claim
   installation complete. Do not overwrite config or bootstrap with a template.
6. Inspect main(), plugin initialization, zones, dependency setup and existing tests.
   Adapt `lib/gherkin_harness/binding.dart`: initialize before any other binding/plugin
   in eligible debug/profile integration runs. Existing widget tests are excluded by
   FLUTTER_TEST. Patrol never calls this entrypoint. If another binding already exists,
   fail with a diagnostic rather than replacing it. Keep the release/default path
   equivalent to the original. Preserve zone requirements and existing error handlers.
7. Wrap the root only when `gherkinRecordingEnabled` with `GherkinRecordingHarness`.
   Pass reviewed public/sensitive field policy. In normal runs keep the original root.
   Optionally attach `GherkinNavigatorObserver` to a conventional Navigator; custom
   routers must call `recorder.navigation(stableRouteName)` explicitly. Do not record
   route URIs with parameters or credentials. Annotate custom controls via Marionette
   isInteractiveWidget/extractText; keep shouldStopTraversal unset unless proven safe.
   Never expose sensitive field values via custom extractText callbacks.
8. Factor a binding-free `createApp()` (including injectable initialization as needed)
   for Patrol. Preserve production setup, and omit global error-handler replacement
   in test bootstrap. If architecture cannot be identified safely, leave that portion
   pending and supply a precise proposed patch with file/line context. Do not speculate.
9. Follow [capabilities](capabilities.md) to select one MCP host or CLI. Register only
   selected project entries and preserve other servers. Report restart requirements.
10. Format/analyze and run existing widget tests. Boot/select a real test device. Launch
    with INTEGRATION_TEST=true, connect, and require a **non-empty** interactive tree.
    Tap an innocuous fixture control and assert its explicit output. Exercise recorder
    mode separately and verify JSONL/redaction. Inspect logs; add the appropriate
    logging/logger adapter only when it fits the app's logging stack.
11. If selected, follow [Patrol installation](patrol-install.md). Rerun doctor and
    install again: no duplicated dependencies, binding calls, entries or ignored paths.
    Report changed files, resolved versions, smoke results and pending work separately.

Never use the installed recorder as a guarantee the application's own logging is safe.
Disable sensitive application logs for test accounts and keep all evidence ignored.
