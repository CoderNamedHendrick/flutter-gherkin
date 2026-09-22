# Read-only doctor

Run the helper without flags first; `--json` emits checks and overall status. Missing
config/root/tooling is expected before first install. The helper never remediates.
`--probe` runs device/emulator enumeration and patrol doctor; no installers.

Supplement its static checks with host-advertised capabilities. The helper cannot
observe a coding agent's loaded MCP tools. Configuration markers are heuristics,
not proof of connectivity, binding order or native target membership.

Report PASS, FAIL — required, or WARN — optional or selected-mode only for:
Flutter/Dart + selected FVM/Puro SDK, root, resolved dependencies, devices, Marionette
Flutter/CLI/MCP, selected-host registration and loaded tools, binding order, recorder
mount/policy, config/directories, Patrol CLI and doctor, pubspec test directory/IDs,
Android runner/orchestrator, iOS UI-test target/scheme/build phases, Patrol MCP,
resolved version compatibility, and smoke readiness.

The helper checks known resolved Patrol/CLI ranges and distinguishes an active PATH CLI from the project-resolved CLI under --probe. Unknown versions remain WARN. Check pubspec.lock and the active Flutter SDK against the current official compatibility table. Record actual CLI version. A tool on PATH, package constraint, cached smoke
report, or source marker alone must not yield an overall operational PASS. Missing
Patrol is optional for Marionette-only; it becomes required for selected Patrol runs.
Do not report a failing Android diagnostic as an iOS failure or vice versa.
