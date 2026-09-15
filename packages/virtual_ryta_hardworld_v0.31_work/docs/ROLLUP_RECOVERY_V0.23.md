# Promoted recovery roll-up v0.23

## Purpose

v0.23 moves the reconstructed RYTA line from the earlier `oorexx-libs.zip`
recovery anchor onto `oorexx-libs(20260822-020835).zip` without discarding the
v0.20/v0.21/v0.22 history.

The upstream `current/` tree is authoritative for package selection. It is never
edited in place. `CURRENT_STACK_LOCK.sha256` pins that tree exactly.

## Directly relevant promotions

```text
Camera                 v0.33 -> v0.34
Runtime Registry       v0.8  -> v0.11
Queue Fabric            v0.5  -> v0.8.1
NoSQLServer             v0.73 -> v0.75
DB Skeleton             v0.39 -> v0.40
msqlshim                v0.10 -> v0.12
```

Structured Relation v0.9, Legal Effect v0.7, cursor probe v0.1 and base
HardWorld v0.19 are unchanged by hash.

The bundle also adds or promotes CivicPort, KL10 IPL, Terminal Machine, Work
Load Units and current test applications. Those are recovery-set members, not
automatically authority-bearing RYTA dependencies.

## Runtime evidence blocker closed

Runtime Registry v0.11 exposes detached runtime execution evidence through the
public `RuntimeLease~executionEvidence` surface. The existing RYTA v0.20 Legal
runtime test passes without a compatibility shim.

This evidence is provenance:

```text
LEGAL_RUNTIME_EXECUTION
```

It is not legal authority. The legal authority string remains bound to Legal
Effect's certified semantic/execution/verification closure.

## Queue boundary retained

Queue Fabric v0.8.1 remains compatible with the v0.21 executor contract. Stable
transport replay identity and receipt validation remain distinct from a
consumer execution attempt. RYTA still journals START before applying an
authority-bearing promotion and COMPLETE afterward; START-only recovery remains
`PREVIOUS_EXECUTION_UNCERTAIN`.

## Reducer ambiguity remains independent

Legal Effect v0.7's known insertion-order reducer ambiguity is still guarded by
`LEGAL_STATUS_REDUCTION_AMBIGUOUS`. Runtime Registry provenance does not turn
ambiguous legal semantics into authority.

## Test entry point

`tests/run_current_stack_rollup_v023.sh`
