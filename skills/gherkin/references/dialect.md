# Closed dialect v1

English `Feature`, optional single `Background` before scenarios, named `Scenario`,
`Given/When/Then/And/But`, standalone `#` comments and `@tags` are supported.
Quoted arguments use JSON escapes (`\"`, `\\`, `\n`, `\r`, `\t`). No inline comments,
Scenario Outline, Examples, Rules, docstrings, data tables, free prose or translations.
Names must be non-empty and scenario names unique within a feature. And/But inherit
the previous keyword. Assertions belong to Then; actions cannot be Then.

| Step body (prepend appropriate keyword) | Support |
| --- | --- |
| `the app is running in the integration environment` | Both; preflight enforces config |
| `I am logged out` | Both; expands required `logged_out` fixture adapter |
| `I tap the widget keyed "key"` | Both |
| `I tap the exact text "text"` | Both; exactly one target for actions |
| `I enter "value" into the widget keyed "key"` | Both |
| `I scroll to the widget keyed "key"` | Both |
| `I scroll to the exact text "text"` | Both |
| `I wait 100 milliseconds` | Both; integer 0–30000 |
| `I select the fixture "name"` | Both; configured concrete step sequence |
| `I use actor "alice"` | Marionette MCP only |
| `the widget keyed "key" is visible` | Both |
| `the exact text "text" is visible` | Both |
| `the widget keyed "key" is absent` | Both |
| `the exact text "text" is absent` | Both |
| `the widget keyed "key" appears exactly 2 times` | Both |
| `the exact text "text" appears exactly 2 times` | Both |
| `I grant the permission dialog if visible` | Patrol |
| `I deny the permission dialog if visible` | Patrol |
| `I press the device home button` | Patrol |
| `I open notifications` | Patrol |
| `I tap the native notification with text "text"` | Patrol; exact native selector |
| `I select the system photo "fixture-id"` | Manual-only; rejected by automated backends |

System photo picker items vary across OS/device/media libraries. v1 does not pretend
this is deterministic. Use a named in-app fixture adapter, or propose an explicit
platform adapter and test it before expanding compiler support.

Visibility means a currently hittable on-screen match. Absent means zero visible
matches, not absence from offscreen application state. Counts count exposed matches;
custom wrappers can expose duplicate text. Prefer a key on the intended control.
Marionette must expose the widget via configuration before absence/count assertions
are meaningful. Assertions poll up to five seconds; a successful tap alone proves no outcome.

```gherkin
Feature: Login
  Background:
    Given the app is running in the integration environment
    And I am logged out
  Scenario: User logs in
    When I tap the widget keyed "login_phone_field"
    And I enter "5551234567" into the widget keyed "login_phone_field"
    And I tap the widget keyed "login_send_code"
    Then the widget keyed "login_otp_field" is visible
```

`${env:TEST_PASSWORD}` and `${fixture:login_otp_field}` are whole-value references,
not string interpolation. Marionette resolves env references from its process and
fixture values from `GHERKIN_FIXTURE_<UPPER_SNAKE_ID>`. Patrol bootstrap maps a finite
set of references to compile-time dart-defines from ignored local files. Never insert
resolved secrets into generated Dart or report messages. Literal input into sensitive
keys is rejected. Additional sensitive fields belong in recorder/config policy.

`@draft` is reserved: syntax validation is possible, but execution/generation reject it.
A recorded action list remains draft until gaps are resolved and assertions confirmed.
