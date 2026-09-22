# Upstream verification

Reviewed 2026-09-21. Recheck at installation time; versions here record evidence, not
installation pins. Test tooling uses a lockfile; target apps resolve compatible packages.

- [Open Agent Skills specification](https://agentskills.io/specification): single
  SKILL.md with name/description, optional resources, progressive disclosure.
- [Skills CLI](https://github.com/vercel-labs/skills): local and repository installation,
  `--skill gherkin -a universal`; no vendor plugin metadata.
- [Marionette package](https://pub.dev/packages/marionette_flutter) and
  [upstream docs](https://github.com/leancodepl/marionette_mcp/tree/main/docs): binding,
  design-system callbacks, CLI, logging and MCP schemas. Reviewed 0.6.0 API.
- [Patrol installation](https://patrol.leancode.co/documentation),
  [authoring](https://patrol.leancode.co/documentation/write-your-first-test),
  [compatibility](https://patrol.leancode.co/documentation/compatibility-table).
- [Patrol MCP](https://patrol.leancode.co/documentation/other/patrol-mcp) and
  [README](https://github.com/leancodepl/patrol/tree/master/packages/patrol_mcp).
- [Official Patrol skills](https://github.com/leancodepl/patrol/tree/master/skills)
  informed ordered setup and API inspection. Their project conventions are not
  prerequisites of this skill; no separate skill installation is required.

The development fixture resolved Marionette 0.6.0, Patrol 4.10.0, Patrol CLI 4.8.0,
Patrol MCP 0.2.1 with Flutter 3.44.9 / Dart 3.12.2. Live verification is recorded in
repository VALIDATION.md; this list is not a claim every platform passed.
