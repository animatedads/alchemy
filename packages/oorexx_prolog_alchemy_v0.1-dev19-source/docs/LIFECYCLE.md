# Prolog Alchemy lifecycle contract — dev11

## Vocabulary

- **owner runtime** — SWI-Prolog owns engine/query/term semantics; ooRexx owns retained Rexx objects.
- **generation** — monotonic engine lifecycle generation captured by each query at open.
- **invocation pin** — a native operation resolves a shared engine/query record and holds the engine mutex for the complete SWI entry.
- **revocation** — prevents new/continued semantic use, increments generation, but does not destroy SWI state beneath live queries.
- **release** — query close/cut invalidates terms and releases retained Rexx roots exactly once.
- **shutdown** — engine destruction is allowed only after every owned query is released.

## Race rules

1. Invocation and revoke serialize on the engine mutex. An invocation already holding the lock completes; a later invocation sees revoked/stale state.
2. Revocation increments `generation`. Existing queries retain `ownerGeneration` and fail deterministically on semantic use.
3. Revocation does **not** erase query records or destroy choice points. `close`/`cut` remains the cleanup path.
4. Engine shutdown rejects live queries, revoked or otherwise. This prevents use-after-destroy of `qid_t`/`term_t`.
5. Query close owns retained-object release. Registry removal plus the query `closed` flag prevents a second successful release.
6. Foreign calls execute outside `registryMu`; the registry lock protects maps only. Engine serialization is independent.
7. Same-thread nested re-entry remains permitted by the recursive engine mutex; other threads serialize behind the active invocation.

## Native acceptance still required

The dependency-free tests verify the structural contract only. Native SWI/ooRexx qualification must race next-solution against revoke, query cleanup against shutdown, nested callbacks against competing entry, and confirm deterministic stale-generation errors and exactly-once retained-object release.
