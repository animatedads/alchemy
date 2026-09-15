# Runtime Reference state-transform protocol

## Purpose

`STATE_TRANSFORM` exists for an ooRexx method whose semantics include mutation of `self` or state reachable from `self`, when deployment wants the computation to execute elsewhere without changing the public method API.

It is not distributed-object remoting. The canonical object remains local.

## Provider request

A provider receives the normal operation contract plus:

```json
{
  "arguments": { "...": "..." },
  "state": {
    "state_contract": "ThingState/1",
    "object_id": "thing-123",
    "base_version": "17",
    "values": { "...": "..." }
  }
}
```

On TCP the `arguments` and `state` members are emitted at the top level of the existing `runtime.reference/0.1` wire envelope.

The snapshot must contain detached values. A live ooRexx `self`, mutable alias into `self`, callback reference or provider-owned object handle is not a valid state snapshot.

## Provider response

A completed provider result carries a transition:

```json
{
  "state_contract": "ThingState/1",
  "object_id": "thing-123",
  "base_version": "17",
  "mutations": {
    "some_field": "new value"
  },
  "return_value": "method result"
}
```

The transition is only a proposal. Provider completion does not mean canonical state has changed.

## Local validation

Before commit Runtime Reference checks exact state contract, object identity and base version. The consumer adapter then validates semantic legality: allowed fields, types, invariants, child identities, alias constraints and current object version.

## Commit rule

The consumer adapter commits locally. It must return `RuntimeStateCommitResult`.

A successful commit may report the resulting state version. A failed commit must say whether the canonical object is definitely unchanged. If it cannot guarantee that, `unchanged` must be false and Runtime Reference will not permit native fallback.

An exception/condition raised after the commit phase begins is treated as `STATE_COMMIT_UNKNOWN`; fallback is forbidden because the framework cannot prove whether `self` was partially changed.

## What to inspect before declaring a method STATE_TRANSFORM

Inspect at least:

- direct `self~attribute=` writes;
- mutating `self~otherMethod` calls;
- aliases into collections or child objects reachable from `self`;
- passing `self` or a reachable mutable child to other code;
- returning `self` or a child where object identity matters;
- callbacks into the canonical object;
- condition/exception behavior;
- external I/O or transactions performed by the method;
- concurrency/version behavior between snapshot and commit.

If these cannot be represented by a detached state contract and an atomic local commit, keep the method `LOCAL_ONLY` or design a different semantic boundary.
