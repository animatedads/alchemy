# Architecture

The adapter is a projection boundary, not a second semantic engine.

1. LLM Gopher sphere packs publish `service` objects for the six read-only SSC capabilities.
2. `gopher-ssc` asks the unchanged Gopher v0.21 Finder to resolve the requested capability for the caller role and sphere.
3. Only a returned ServiceProxy whose implementation id is the exact expected `external.semantic-source-control.machine.<operation>` is accepted.
4. The adapter invokes only the corresponding fixed machine-protocol operation using an argv array.
5. SSC remains authoritative for identity, history, semantic comparison, impact, and external-operation tracking state.

A Finder denial or absence never falls through to a direct machine invocation. Machine-protocol infrastructure failures are distinct from semantic negative results such as `NOT_FOUND`, `UNCHANGED`, or `REVIEW_REQUIRED`.
