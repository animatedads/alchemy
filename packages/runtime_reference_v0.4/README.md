# ooRexx Runtime Reference v0.4

`runtime.reference/0.4` is the execution-location switch layer for the ooRexx framework. A caller continues to invoke the same class and method while deployment can bind that semantic operation to an alternate resident or remote implementation. The owning package retains its native ooRexx implementation and, when the operation contract permits it, uses that implementation as fallback.

Runtime Reference remains separate from Runtime Registry. Runtime Registry selects an immutable module generation; Runtime Reference selects where/how an operation inside that selected API executes.


## v0.4: concurrent PURE execution

v0.4 removes accidental ooRexx object-monitor serialization from the `PURE` execution hot path. `RuntimeImplementationSwitch~invokePure`, `RuntimeImplementationBroker~invoke`, `RuntimeObjectImplementationProvider~invoke`, and `RuntimeTcpJsonProvider~invoke` permit concurrent activities. Arbitrary provider execution therefore occurs outside Runtime Reference monitors.

Mutable coordination remains short-held and explicit:

- broker `register` / `clear` remain guarded; invocation snapshots the currently published reference array under a brief guarded lookup and then releases the broker monitor before provider execution;
- per-reference circuit health remains guarded around attempt/failure/success accounting;
- `lastEvidence` publication is guarded; it is process-global observational state and is intentionally not a per-activity diagnostic slot;
- each returned `RuntimeImplementationAttempt` carries the call-specific evidence and is the authoritative evidence for concurrent consumers;
- `STATE_TRANSFORM` remains on its existing guarded path because canonical-state snapshot/commit concurrency is a separate semantic problem.

A real activity regression test starts eight ooRexx workers through the process-wide switch and uses an unguarded provider target with a short in-flight delay. It requires measured provider overlap >= 2. The same test fails against v0.3, where the broker/provider monitor serialized calls.


## v0.3: exact byte values

v0.3 adds `.RuntimeExactBytes` and `.RuntimeImplementationSwitch~exactBytes(data)` for provider-neutral binary request values. Resident object providers receive the original ooRexx byte string unchanged. `RuntimeTcpJsonProvider` recursively normalizes exact-byte values to tagged lowercase `hex:<...>` strings before JSON serialization. The TCP wire protocol remains `runtime.reference/0.1`, preserving compatibility with existing providers that already consume tagged hex values.

This avoids forcing an in-process provider through text/JSON encoding merely because the same semantic operation may also have a TCP implementation. Embedded NUL and high-bit bytes are part of the contract and are tested.

## v0.2: explicit state-transform boundary

v0.2 adds controlled relocation for methods that would otherwise mutate `self` or state reachable from it. It does **not** send a live ooRexx object to the provider and does not allow arbitrary remote `self~` calls.

The state-transform protocol is:

```text
canonical local object
        |
        | explicit adapter snapshot
        v
versioned detached state
        |
        | provider computes only
        v
proposed mutation set + return value
        |
        | local validation
        v
atomic local commit
        |
        v
canonical local object
```

The provider receives a detached `RuntimeStateSnapshot` containing a state-contract id, object identity, base version and explicit values. It returns an inert `RuntimeStateTransition` containing the same identity/version coordinates plus a proposed mutation `Directory` and return value. Only the consumer-owned `RuntimeStateAdapter` may validate and commit those mutations to the canonical object.

`RuntimeHookStateAdapter` is a convenience adapter for objects which explicitly expose:

- `runtimeReferenceSnapshot(stateContract)`
- `runtimeReferenceValidateTransition(snapshot, transition)`
- `runtimeReferenceCommitTransition(snapshot, transition)`

The commit hook owns the semantic knowledge needed to deal with real `self~attribute=` writes, aliases, invariants and version advancement. A failed commit must either guarantee that the object is unchanged or explicitly report `unchanged=.false`. Runtime Reference forbids automatic native fallback whenever a commit may have partially changed state.

## Execution classes

- `PURE`: value/request in, value out. Automatic reference execution remains supported.
- `READ_ONLY_OBJECT`: reserved for a later explicit read-only snapshot API.
- `STATE_TRANSFORM`: supported through `invokeStateTransform`; detached snapshot and atomic local commit are mandatory.
- `REMOTE_OBJECT`: provider owns object identity/state; still deliberately unsupported pending provider-owned identity and failover semantics.
- `LOCAL_ONLY`: relocation is forbidden.

Generic `RuntimeImplementationBroker~invoke` continues to refuse non-PURE contracts. Stateful relocation is possible only through the explicit state-transform entry point, which prevents a deployment flag from accidentally turning an ordinary method with hidden `self` effects into RPC.

## Fallback safety

v0.2 adds `BEFORE_COMMIT_ONLY`. It is the natural default for `STATE_TRANSFORM` because a conforming provider computes against a detached snapshot and cannot mutate canonical object state. Provider outage, malformed results, state-contract/object/version mismatches, mutation rejection and optimistic state conflict can therefore fall back while no local commit has happened.

Once commit begins, fallback depends on the adapter result:

- committed: reference execution is complete;
- not committed and `unchanged=.true`: fallback may proceed if the contract permits it;
- not committed and `unchanged=.false`: fallback is forbidden;
- adapter condition during commit: outcome is `STATE_COMMIT_UNKNOWN` and fallback is forbidden.

This specifically protects methods that perform multiple `self~` writes or call mutating methods midstream: uncertain partial local mutation is never followed by an automatic second execution of the native implementation.

## Identity and optimistic concurrency

Every snapshot carries:

- `state_contract`
- `object_id`
- `base_version`
- `values`

Every provider transition must echo the first three fields and provide `mutations`. A mismatched contract, object identity or base version is rejected before commit. The adapter then checks the canonical object again immediately before committing, allowing it to return `STATE_CONFLICT` if another local actor changed the object after the snapshot was taken.

Successful evidence additionally records state contract, object identity, base version and resulting version.

## Providers, not languages

The provider abstraction is unchanged:

- `RuntimeObjectImplementationProvider` can wrap any resident object, including a BSF4ooRexx -> Java adapter.
- `RuntimeTcpJsonProvider` can reach a continuously running Python, Java, ooRexx, C/native or other service.
- deployments may register multiple providers in priority order.

For a state transform an object provider receives a request with `arguments` and `state`. The TCP provider emits those as separate top-level JSON members alongside the semantic operation contract.

## Wire compatibility

The component API is now `runtime.reference/0.4`, but `RuntimeReferenceBuild~WIRE_PROTOCOL_VERSION` remains `runtime.reference/0.1`. v0.1's newline-delimited TCP/JSON envelope was already sufficiently generic to carry the new `state` member, so existing v0.1 PURE providers remain wire-compatible. This was verified by running ooRexx Crypto v0.2's unchanged Python crypto service against Runtime Reference v0.2.

## Native fallback invariant

A reference implementation remains an override, not the definition of a capability. Native ooRexx code must stay real and independently tested. No broker, no reference, service failure, invalid provider proposal, or safe pre-commit conflict must leave the package unable to execute its native implementation.

A legitimate completed `false`, `0`, empty string or empty collection is still a completed result and never means fallback.

## Tests

```sh
REXX=/path/to/rexx ./run_tests.sh
```

The suite covers concurrent PURE dispatch and provider overlap, circuit behavior, state-transform success, invalid mutation rejection, stale transition rejection, unsafe partial-commit fallback suppression, live TCP state execution and TCP-service disappearance/native fallback.
