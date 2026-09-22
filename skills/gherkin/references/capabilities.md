# Capability selection and MCP configuration

Inspect actual loaded tools and schemas; names are chosen by each host. Required
Marionette capabilities: connect, interactive tree, tap, text entry, scroll, screenshot;
logs are optional. Patrol needs run, status, quit and ideally screenshot/native tree.
Loaded tools win under preference:auto; CLI is fallback. preference:mcp requires a
loaded server, preference:cli uses CLI. Registration alone cannot satisfy capability
checks. The chooseBackend helper tests these decisions.

Before writing configuration, identify the host from explicit user context or its
advertised runtime identity. Repository config files alone can belong to multiple
agents and are not reliable host detection. Ask which host if ambiguous. Read and
merge only its selected project config. Preserve unrelated entries and refuse to
replace a same-name server with different command/arguments without resolving the
conflict. No global mass edits, no copied user paths.

Current upstream examples (verify host docs before writing):

| Host | Project file | Shape |
| --- | --- | --- |
| Claude Code | .mcp.json | mcpServers mapping |
| Cursor | .cursor/mcp.json | mcpServers mapping |
| Gemini CLI | .gemini/settings.json | mcpServers among other settings |
| Copilot CLI | .mcp.json | mcpServers mapping |
| Copilot in VS Code | .vscode/mcp.json | servers mapping; type: stdio |
| Codex | host-supported project MCP configuration | consult current host format; do not assume JSON |
| Other | host documentation | use advertised format or CLI |

Marionette stdio command: marionette_mcp (or the current documented `marionette mcp`).
Patrol stdio command: dart, args [run, patrol_mcp], environment PROJECT_ROOT set to
selected Flutter app, SHOW_TERMINAL=false. Under FVM run server through fvm dart too;
PATROL_FLUTTER_COMMAND governs spawned Flutter, not server Dart. Under Puro inspect
its actual command behavior before selecting it. Avoid shell-dependent wrapper syntax.

Record selected host/path in config. Verify registration through host tooling or parsed
configuration, then verify loaded capabilities. If restart is needed, explain exactly
what was registered and how to reload that host; do not give another agent's restart
command. Stop only work dependent on those newly loaded tools; use CLI otherwise.
