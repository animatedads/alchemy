# Changelog

## v0.4

- Makes `PURE` provider execution genuinely concurrent across ooRexx activities: process-wide switch dispatch, broker invocation, resident object-provider invocation, and TCP-provider invocation no longer hold ooRexx object monitors across arbitrary provider work.
- Keeps registration/clear and `lastEvidence` publication guarded; broker invocation takes the broker monitor only long enough to snapshot the current immutable reference list.
- Keeps per-reference circuit state guarded with short critical sections around `canAttempt`, success, and failure accounting.
- Preserves `STATE_TRANSFORM` guarded semantics; the concurrency change is deliberately scoped to `PURE` operation execution.
- Defines `lastEvidence` as process-global observational evidence. Under concurrent calls the exact winning call is nondeterministic; each returned `RuntimeImplementationAttempt~evidence` remains call-specific.
- Adds a real ooRexx activity test proving at least two provider calls overlap through `RuntimeImplementationSwitch -> RuntimeImplementationBroker -> RuntimeObjectImplementationProvider`. The same test fails against v0.3, proving the old monitor serialization.
- `RuntimeTcpJsonProvider~invoke` is now unguarded and uses per-call sockets/state, permitting concurrent requests to a provider that supports them.
- Wire protocol remains `runtime.reference/0.1`; exact-byte and state-transform wire semantics are unchanged.

## v0.3

- Adds `RuntimeExactBytes` as an explicit provider-neutral exact-byte request value.
- Adds `RuntimeImplementationSwitch~exactBytes(data)` as the ordinary package construction surface.
- `RuntimeObjectImplementationProvider` receives exact bytes unchanged.
- `RuntimeTcpJsonProvider` recursively converts exact-byte values to `hex:<lowercase-hex>` only at the JSON transport boundary.
- Keeps TCP wire protocol `runtime.reference/0.1`; existing tagged-hex services remain compatible.
- Adds embedded-NUL resident-provider regression coverage.
- STATE_TRANSFORM, fallback, evidence and provider-priority semantics are otherwise unchanged from v0.2.

## v0.2

- Adds explicit `STATE_TRANSFORM` execution through versioned detached state snapshots and provider-produced mutation sets.
- Adds `RuntimeStateSnapshot`, `RuntimeStateTransition`, `RuntimeStateValidationResult`, `RuntimeStateCommitResult`, `RuntimeStateAdapter`, and `RuntimeHookStateAdapter`.
- Adds `RuntimeImplementationSwitch~invokeStateTransform` and broker state-transform execution.
- Adds exact state-contract, object-id, and base-version checks before mutation validation/commit.
- Adds `BEFORE_COMMIT_ONLY` fallback semantics.
- Forbids native fallback when a commit hook reports possible partial mutation or raises a condition during commit.
- Extends execution evidence with state contract, object identity, base version, and resulting version.
- Extends TCP/JSON provider requests with a top-level state snapshot for state transforms while retaining wire protocol `runtime.reference/0.1` for existing PURE provider compatibility.
- Adds live TCP state-transform tests and service-loss fallback tests.

## v0.1

- Adds generic semantic-operation implementation switching.
- Adds explicit execution classes and fallback-safety vocabulary.
- Adds provider-neutral object adapter suitable for BSF4ooRexx/Java adapters.
- Adds newline-delimited TCP/JSON reference provider.
- Adds per-reference failure circuit cooldown.
- Restricts automatic relocation to PURE operations until state/identity contracts are explicit.
