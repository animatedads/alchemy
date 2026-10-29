# GitHub source closure

As of 29 October 2026, the Help Desk consumer has a committed-source smoke path
that does not depend on unpacking the historical dev5 delivery ZIP.

The source-only smoke deliberately uses the accepted consumer baseline with the
published package roots it was built against:

- `packages/notnotes_mini_approval_app_v0.1-dev16`
- `packages/alchemy_notnotes_v0.1-dev15`
- `packages/oorexx_intention_service`
- `packages/oorexx_instrumentation_mesh`
- `packages/oorexx_instrumentation_intentions`

Run:

```sh
examples/initech_notnotes_helpdesk_v0.1-dev5/tools/run_github_source_smoke.sh
```

The smoke creates a disposable minimal TPS Report / TPS Report Review schema,
runs live semantic discovery, writes a real Business Log, reads live
instrumentation, closes the session into linked TPS process evidence, and proves
a later session can read that evidence. It does not require or publish the
historic Initech management-review customer data fixture.

This is a **consumer source-closure test**, not permission to retarget the
accepted dev5 baseline onto newer separately-owned NotNotes versions. Newer Mini
NotNotes, SQL persistence, Management Intention Discovery and related packages
must be adopted by a qualified successor deliberately.

Current specialist evolution observed in Library/GitHub:

- Management Intention Discovery: v0.1-dev9
- Instrumentation Intentions: v0.1-dev2

Those remain provider-owned contracts. The Help Desk must discover them through
their generic interfaces rather than acquiring infrastructure vocabulary or
execution authority.
