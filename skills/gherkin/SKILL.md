---
name: gherkin
description: Install Flutter Marionette tooling, record manual app interactions as Gherkin features, replay features, and generate deterministic Patrol tests. Use for gherkin install, doctor, record, run, or generate-patrol, or when asked to author Flutter end-to-end tests by demonstration.
license: MIT
compatibility: Requires Flutter with Dart 3.11 or newer and shell execution. Mobile runs need an emulator, simulator, or test device. MCP is optional.
metadata:
  version: "0.1.0"
---

# Flutter Gherkin

One skill; five agent workflows. These are natural-language invocations, not a globally installed `gherkin` executable. `$gherkin` works where explicit skill invocation is supported.

| Request | Read |
| --- | --- |
| `gherkin install` | [install](references/install.md), [configuration](references/configuration.md); [Patrol setup](references/patrol-install.md) only if selected |
| `gherkin doctor` | [doctor](references/doctor.md) |
| `gherkin record <flow>` | [record](references/record.md), [dialect](references/dialect.md) |
| `gherkin run <feature-or-folder>` | [Marionette replay](references/run-marionette.md), [dialect](references/dialect.md) |
| `gherkin generate-patrol <feature-or-folder>` | [generation](references/patrol-generation.md), [dialect](references/dialect.md) |

For exact helper commands read [tooling](references/tooling.md). Resolve this skill's installed directory, then run `dart pub get --enforce-lockfile` in its `scripts/` directory once. Invoke `dart run bin/gherkin.dart` there with an explicit `--root <project-root>`. The helpers locate assets relative to their own package, not a vendor installation path. Never install a second skill to provide these modes.

## Shared contract

- `.feature` files under project-root `gherkin/features/` are authoritative. Generated Patrol files belong in the Flutter app root’s `integration_test/` directory and are committed derived artifacts; use `check-generated` in CI. Evidence and local credentials are ignored.
- Validate the complete selected suite before driving a device or generating anything. The initial dialect is closed. Never reinterpret unknown prose, omit unsupported steps, or mistake a successful action for a verified outcome.
- Discover loaded MCP capabilities and use their advertised schemas. Prefer appropriate loaded Marionette/Patrol tools; use their CLI fallback when absent. No vendor tool prefixes are assumed. See [capabilities](references/capabilities.md).
- Detect the actual host before merging one agent's MCP config. Ask if ambiguous. Never configure every agent or overwrite an existing entry. Registration is not proof tools are loaded. Restart only blocks work that requires the new tools; CLI can continue.
- Marionette is mandatory. Install asks **1. Marionette only / 2. Marionette + Patrol**. Preserve the user's previous selection on subsequent runs.
- Inspect bootstrap before edits. Marionette must claim the binding first, only in non-release integration runs, never in widget/Patrol tests. Patrol pumps a separately created app root; it does not invoke app `main()`.
- Confirm app root, entrypoint, device, platforms, and allowed environment. Never assume flavors or a named staging environment. Production requires explicit config opt-in and renewed user confirmation for each execution.
- Record only user actions until they say finished. Do not infer business assertions from routes. Ask for meaningful assertions. Get approval before adding proposed keys to app code.
- Redact sensitive input at capture, before it reaches logs. Passwords, OTPs, card data and unclassified fields use placeholders. Never print resolved secrets or commit them.
- One driver per device. Multi-device steps execute serially with a dedicated live MCP connection per actor. Reject multi-device CLI replay and Patrol generation; see [multi-device](references/multi-device.md).
- No branch operations, commits, pushes, publishing, PRs, bug intake, trackers, or regression bookkeeping are part of this skill.

## Evidence and completion

Report per-scenario results plus suite totals, actual screenshot/log paths, unsupported steps, and any missing integration. A doctor heuristic is not a smoke test. Claim Marionette/Patrol operational only after the corresponding live smoke test passes. Document platform-specific limitations rather than marking an untested platform healthy. Current API/setup sources and verification procedure are in [upstream](references/upstream.md).
