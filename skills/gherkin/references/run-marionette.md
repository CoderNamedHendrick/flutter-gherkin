# Marionette replay

Resolve features through the helper: `login`, `gherkin/features/login.feature`, a
folder, or `gherkin`. Validate the entire suite and all fixture adapters before launch.
Reject Patrol-only/manual-only steps. Route a scenario to Patrol only when explicitly
requested; never drop native steps. Apply environment restrictions to reconnects too:
verify the already-running app's launch facts, not just its websocket address.

Prefer loaded MCP capabilities with their actual advertised argument schemas. Launch
or reconnect, map a dedicated connection to the device and require a non-empty tree.
For shell-only agents use `marionette help-ai`, then the helper's `run-cli` with --uri.
CLI tree parsing is deliberately strict: changed or ambiguous multiline/quoted output
fails and asks for MCP/source/screenshot inspection. MCP may also return formatted text; if exact counts remain ambiguous, report unsupported rather than inferring success. v1 CLI fallback is single-device.

Build a key manifest once from app source (search ValueKey<String>, ValueKey and shared
key constants). It is a hint, not exhaustive for dynamically generated keys. Execute
named key actions directly. Observe exact-text action ambiguity, assertions and action
failure. Avoid whole-tree calls after every successful keyed action. Scroll-to exact
text must resolve an unambiguous destination; inspect if the backend reports ambiguity.

For each scenario, reapply Background and fixture/precondition steps. The environment
step asserts preflight, not an app action. Logged out expands the configured reset
adapter; never assume reinstall clears auth/keychain. Execute serially. Assertions use
fresh visible matches with bounded polling (five seconds), exact matching and explicit
counts. Capture screenshots at assertions and failures. At a failure, observe once,
collect logs where configured, stop that scenario and record remaining steps as not run.
Do not automatically retry mutating actions.

Store a per-scenario result and combined JSON report under a unique ignored evidence
run directory, with actual screenshot/log paths and unavailable-evidence warnings.
The CLI helper implements this loop. In MCP mode the agent follows the same contract
and writes the same fields: feature, scenario, status, ordered step kind/line/actor,
status, error, screenshot/log path. Do not dump secrets or whole widget trees into
reports. Redact known resolved placeholders from collected logs and inspect application
logging policy. Report only tests actually executed, including failed assertions.

Prefer key → exact text → widget type → coordinates during diagnosis. Only key/exact
text belong to the portable dialect. Type/coordinates are brittle investigative aids;
propose keys for any persistent feature and obtain approval before app edits.
