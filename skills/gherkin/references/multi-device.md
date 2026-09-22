# Multi-device: constrained first release

Single-device is the default. Grammar supports `Given I use actor "alice"` and later
`When I use actor "bob"`. Actor config contains device, connection and account_env:

```yaml
actors:
  alice: {device: simulator-a, connection: marionette-a, account_env: ALICE_ACCOUNT}
  bob: {device: simulator-b, connection: marionette-b, account_env: BOB_ACCOUNT}
```

Allocate one actual loaded Marionette server/connection per actor, with distinct device
and account references. Connection names are logical labels resolved against advertised
capabilities, not hardcoded tool prefixes. Launch each device with separate logs and
VM URI. Verify both trees without reconnecting one server to another device. Execute
steps serially in scenario order through the selected actor. The first device action
needs an actor selection. Restore scenario preconditions for each actor explicitly.
Never run simultaneous drivers on a shared server or silently reconnect on switches.

The CLI helper and Patrol generator reject actor steps: a single Patrol test cannot
represent coordinated multiple apps/devices. Agent-driven MCP replay supports the
serial protocol; live multi-device coverage is tracked separately in repository validation.

Recording per-device logs has no shared sequence clock. Ask the user to announce every
switch and record a segment manifest of actor/session/start_seq/end_seq in that order.
Convert each single-actor session separately, select the announced sequence ranges,
insert actor steps, and show the assembled scenario for confirmation before replay.
Do not sort device timestamps globally or guess interleaving. Use `stitch-recordings --manifest gherkin/local.segments.json --name flow --confirmed-order`
after confirmation. The helper consumes explicit segments, rejects overlapping ranges,
and produces a draft with actor switches. It never infers order. Manifest shape:

```json
{"logs":{"alice":"gherkin/evidence/alice.log","bob":"gherkin/evidence/bob.log"},
 "segments":[{"actor":"alice","session":"session-a","start_seq":0,"end_seq":5},
             {"actor":"bob","session":"session-b","start_seq":0,"end_seq":3}]}
```

