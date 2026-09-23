# ooRexx Prolog Alchemy v0.1-dev12

Fourth executable checkpoint for the bidirectional ooRexx ↔ Prolog Alchemy runtime.

## Added in dev4

- Late atom materialisation: `.AlchemyPrologAtom` retains the original ooRexx object; native `ObjectToString()` is deferred until the term is actually assigned inside the owning Prolog engine.
- The query retains its complete materialisation/specification graph through query lifetime, so conversion does not replace source-object identity.
- Shared logical-variable identity throughout recursive compounds/lists. A repeated `.AlchemyPrologVariable` object maps to one native Prolog logical variable, including nested occurrences.
- Native query-open returns bindings for every distinct variable projection, allowing nested Rexx variable objects to observe the same live `term_t` across solutions.
- Generic Rexx arguments are wrapped as late atom specifications rather than eagerly calling `~string` while assembling the graph.
- Fixed the dev3 native source comment corruption in the recursive-term section.

## Semantic invariant

Specification, materialisation, solution/backtracking and release are distinct phases. Atom STRING conversion belongs to materialisation, not specification. Repeated references to one Rexx logical-variable projection remain one Prolog variable (`f(X,X)` is not `f(X,Y)`).

## Authority / dependency boundary

Alchemy Foreign Object remains an external dependency and is not forked. The supplied Alchemy Objects v0.8.1 inspector-repaired package is treated as the current Alchemy Objects authority; Prolog Alchemy does not vendor or amend it in this checkpoint.

## Threading invariant

Logical state belongs to a Prolog engine, not an OS thread. A live query and all term handles remain engine-affine. Concurrent entry to one engine remains forbidden.

## Qualification

`tests/test_contract.py` is dependency-free and checks the dev1-dev4 structural contracts. Native SWI-Prolog qualification still requires SWI-Prolog headers/library plus ooRexx headers/library.

## dev5 reverse callback increment

`runtime~rexxObject(object)` creates a Prolog term specification that retains the actual ooRexx object until the owning query reaches cut/close.  Native materialisation allocates an opaque integer handle and roots the object with `RequestGlobalReference()`; query release drops that root with `ReleaseGlobalReference()`.

The embedded SWI runtime registers `rexx_send/4` as a nondeterministic foreign predicate.  FIRST dispatches the requested message to the retained object using the active ooRexx call context and unifies the returned scalar into the Prolog result term.  REDO currently exhausts the single Rexx result; PRUNED accepts destruction of the choice point.  This deliberately establishes the real SWI FIRST/REDO/PRUNED lifecycle before adding Rexx-side multi-result continuations.

Current dev5 callback term conversion is intentionally narrow: atom/integer arguments and atom/integer results.  Structured callback conversion and a Rexx continuation protocol are later increments.  Failure, Prolog exception, unbound variables and object absence remain distinct concepts; dev5 does not map them to `.false`/`.nil` as a convenience.


## dev6 — productive Rexx backtracking

`rexx_send/4` now recognizes an explicitly nondeterministic Rexx result object by the `PROLOGNEXT` protocol.  `PROLOGNEXT` returns `[hasSolution, value]`.  The native bridge roots that live source on FIRST, advances it on REDO, and releases it on exhaustion or PRUNED. Scalar Rexx results remain deterministic.  This deliberately avoids pre-materialising a Rexx collection into Prolog answers: Prolog backtracking drives the live Rexx behaviour.

`AlchemyPrologSolutionSource` adapts an ooRexx Supplier to this protocol. Query cut/close establishes the active Rexx context while SWI prunes choice points, so continuation global references are released at the actual pruning boundary.


## dev7 — object-preserving callback projection and family fixture

Callback results no longer collapse arbitrary ooRexx objects through `ObjectToString()`.
Unless the returned object supplies an explicit Alchemy Prolog scalar specification, it is
rooted for the active query and represented to Prolog as `rexx_object(Id)`. Passing that
term back through `rexx_send/4` resolves the same retained ooRexx object. `callbackAtom()`
and `callbackInteger()` are explicit projections; atom `STRING` conversion remains late,
at native unification/materialisation time.

`examples/family_qualification.pl` is the first relational qualification fixture. It
intentionally does not infer motherhood from marriage: motherhood requires the declared
`female/1` and `parent/2` evidence. The companion Rexx fixture records the live-object
qualification shape for a host with both SWI-Prolog and ooRexx available.

## dev8 maintainability review

This checkpoint is intentionally behaviour-preserving.  It adds method-level
comments to the public ooRexx surface and documents the ownership/lifetime
helpers in the native bridge.  The review also replaces manual thread-local
callback-context save/restore with `ActiveQueryScope`, so nested re-entry and
exceptional exits restore the previous callback authority automatically.

Naming remains deliberately split between **specification** objects on the
Rexx side and **materialised** engine-owned terms on the native side.  Atom
`STRING` conversion remains late; retained Rexx identities remain query-owned;
and Prolog `term_t` / `qid_t` handles remain engine-affine.

## dev9 — live relationship source and re-entry consistency

The reverse object route is now representation-consistent: `rexx_send/4` accepts both
query-root retained ids and the `rexx_object(Id)` term emitted when a callback returns an
arbitrary ooRexx object.  A returned Person can therefore be passed straight back to
`rexx_send/4` without flattening or handle surgery.

Engine serialization now uses a recursive mutex.  This does **not** permit concurrent
entry to one SWI engine; it permits the owning thread to perform the documented nested
Rexx -> Prolog -> Rexx -> Prolog re-entry without deadlocking itself while retaining
serialization against other threads.  SWI engine affinity remains the authority.

`examples/family_live_relations.pl` and `examples/family_live_book.rex` define the first
live-state qualification shape.  Parent/sex evidence is requested from retained ooRexx
objects at query execution time.  `parentsOf` is productive: Prolog backtracking drives
an ooRexx Supplier through `PROLOGNEXT`.  Mutating the FamilyBook between two queries
must change the second query's answers; no family relation is cached or stringified.
Marriage remains independent evidence and never implies motherhood.

## dev10 - engine mobility contract

Dev10 makes the threading model an explicit qualification surface.  Logical
state belongs to `PL_engine_t`, not to the OS thread temporarily executing it.
`EngineScope` performs scoped attach/restore for every native operation, while
queries strongly retain their owner engine.  A live query may therefore be
continued by another native thread only by entering the same engine; `qid_t`
and `term_t` handles are never transplanted to a different engine.

`AlchemyPrologQuery~ownerEngineId` and `AlchemyPrologEngine~isClosed` expose
narrow lifecycle evidence for tests.  See `docs/THREADING.md` for the positive
and negative native acceptance matrix.  Dependency-free contract tests do not
constitute a native SWI multithread runtime pass.


## dev11 lifecycle hardening

dev11 separates **revocation** from **destruction**. Engines carry a monotonic lifecycle generation; queries capture that generation when opened. Revocation serializes with invocation, marks the engine revoked, and advances the generation so subsequent semantic use of an existing query fails deterministically as stale. Revocation deliberately leaves native query state intact so callers can still release/cut the query before engine destruction. Engine close continues to reject any live query. See `docs/LIFECYCLE.md`.

This is a structural/lifetime checkpoint. A native SWI multithread race pass is still required before claiming runtime concurrency qualification.

## dev12 — lifecycle observability and review repair

dev12 adds passive evidence surfaces for the native lifecycle race matrix: engine active-invocation count, engine live-query count and live-query retained-object count. `InvocationPin` is RAII, independent of registry ownership, acquired after engine serialization and released on every exit path. These counters are qualification evidence, not coordination APIs.

A review also removes query-only `ownerEngineId` / `ownerGeneration` methods that had accidentally been duplicated onto `AlchemyPrologObject`. Foreign-object projection again exposes only its own engine/native-term state; query lifecycle evidence remains on `AlchemyPrologQuery`.

See `docs/NATIVE_RACE_QUALIFICATION.md`. Native SWI execution is still required before claiming concurrency qualification.
