# Native lifecycle race qualification — dev12

This is the runtime acceptance plan. Dependency-free source tests do not satisfy it.

## Passive evidence hooks

- `engine~activeInvocations` — semantic entries currently pinned after engine serialization.
- `engine~liveQueryCount` — unreleased queries owned by the engine.
- `query~retainedObjectCount` — query-owned Rexx global references still present in the retained-object registry.

They are evidence surfaces, not coordination APIs.

## R1 — invocation versus revoke

Block a Rexx callback under test control, enter `nextSolution` on thread A, then request revoke on thread B. B must serialize behind A. The already-pinned invocation may complete; revocation then advances generation once. Later semantic use of the old query must fail revoked/stale.

## R2 — cleanup versus shutdown

Keep a query and retained Rexx identity live. Engine close must reject while `liveQueryCount > 0`. Query close/cut releases its roots; only then may engine close succeed. No root may be released twice.

## R3 — nested callback versus competing entry

Thread A performs Rexx -> Prolog -> Rexx -> Prolog on the same engine while thread B attempts entry. A's recursive same-thread entry must complete; B waits until the outer entry leaves. No registry lock is held across the foreign call.

## R4 — same-engine mobility

Continue one nondeterministic query first on thread A and then thread B using the same engine/query. Variable identity and solution order survive. A query is never transplanted to another engine.

## Required receipt

Record exact ooRexx build, SWI-Prolog version/build flags, bridge SHA-256, host/OS, test-source hash, generation before/after revoke, retained-root counts, result counts and bounded timing. A structural PASS is not a native concurrency PASS.
