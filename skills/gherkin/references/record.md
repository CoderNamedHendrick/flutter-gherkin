# Record a manual flow

Resolve config and guard environment first. Select/boot the configured simulator or
emulator and wait for boot readiness. Use the launch helper with --record, which sets
INTEGRATION_TEST=true and GHERKIN_RECORD=true. Do not say recording is live until the
app is visible and recorder integration was smoke-tested. Announce:
“Recording is live. Perform your flow on the selected device; say done when finished.”
Then wait for the user. Do not drive their demonstration, invent actions or stop early.

The debug-only harness observes pointer down/up and controller changes. Tap targets
are captured before callbacks can navigate. Each event includes session, sequence,
UTC timestamp, actor, action, stable key when available, type, coordinates and optional
sanitized route context. Public labels are opt-in. All field values are redacted by
default; password/OTP/card hints and explicit sensitive keys always redact even when
allowlisted. On-screen recording indicator is not supplied; the agent announces state.

On done, stop recording/retain the log and invoke parse-recording. It sorts sequence
numbers, rejects mixed sessions, collapses consecutive changes within the same field/focus session,
drops navigation-only noise and deduplicates fixture events only with the same explicit
interaction ID. A tap/navigation/focus boundary preserves distinct edits; it does not merge
unrelated fixture taps heuristically. Use recorder.fixture() from a deterministic
fixture selector; suppress its low-level taps through an app-specific reviewed hook if
needed. Unknown gestures become unresolved gaps; scrolling needs recorder.scrollTo(key)
or a user-confirmed explicit dialect step. Raw scroll deltas are not semantic targets.

The output is a valid `@draft` feature, with gaps listed separately. Propose stable
ValueKey<String> names using widget type and source context. Ask approval before
editing app keys. Do not use diagnostic coordinates as portable test steps. Ask the
user for meaningful Then assertions; navigation is not evidence of business success.
Resolve gaps and references, remove @draft, validate and replay through Marionette.
If any step remains unrepresentable, leave draft and report the precise limitation.
Never replace an existing feature silently.

Custom routers must expose stable route context manually when an observer cannot be
wired safely. Do not claim automatic route capture for every router. Multi-device
recording requires explicit user-confirmed interleave segments; see multi-device.md.

Unkeyed input becomes a focused-field step with a placeholder, not a request to add a
key to an inaccessible framework field. Focus-session IDs distinguish consecutive
unkeyed edits; older logs without IDs are kept separate conservatively. Confirm that
the preceding flow really establishes focus before removing `@draft`. Keep unresolved
placeholders until mapped to fixtures/env values or explicitly reviewed public literals.
A redacted recording cannot recover the original text. Do not enable blanket public
capture for focused fields. Repeated conversion requires a new draft name or an explicit
merge; do not delete an existing feature just to rerun conversion.

Recorder redaction covers recorder events only. The launch helper separately filters
known credential values from environment/dart-define files, credential URL query
parameters, and Basic/Bearer authorization headers before persisting stdout/stderr.
Replay evidence also filters resolved input placeholders. This is best-effort filtering,
not a guarantee for arbitrary app logging or screenshots; inspect the app's logger and
avoid logging credentials at their source. Gitignored logs are still local files.

Hot reload preserves existing State objects, including initialized `late final` fields.
Use hot restart when validating changes to those initializers or startup integration;
re-establish the scenario preconditions after restarting.
