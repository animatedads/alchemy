# Security continuation and irreversible commit revalidation

Security Effect v0.14 closes the gap between **method admission** and an eventual
irreversible side effect.

A fresh `SecurityInvocationEvidence` proves only that Bouncer assessed one exact
method invocation.  Some methods create a staged operation which is committed
later.  The customer's security state, session context or staged business state
may change before that commit.

The v0.14 contract is therefore:

```text
admit exact start invocation
        |
        v
SecurityInvocationValidation
        |
        +-- host-owned origin execution evidence
        |   (the admitted operation actually started)
        v
SecurityContinuationEvidence
(origin execution evidence + operation id + stable business intent)
        |
        | work may be staged
        v
SecurityCommitEvidence
(exact staged-state identity + live context + observation time)
        |
        v
fresh COMMIT method invocation
        |
        v
fresh SecuritySnapshot
        |
        v
SecurityAssessment for COMMIT
        |
        v
SecurityContinuationGuard
        |
        v
Access Permissions decision for exact COMMIT method
        |
        v
physical commit / publication
```

None of `SecurityContinuationEvidence`, `SecurityCommitEvidence` or
`SecurityCommitValidation` grants permission.  They prove only that the Security
meaning presented to the Permission authority still belongs to this exact
operation and this exact staged state.

A continuation additionally requires an `originExecutionEvidenceIdentity`.  This
is a reference to host/enforcement evidence that the originally Security-validated
operation was actually admitted/started.  Security Effect does not reinterpret
that reference as authority: Access Permissions or another host authority remains
responsible for the underlying admission.  The requirement simply prevents a
pre-authority Bouncer validation from being presented later as if it proved that
work began.

## Fixed continuation policy

`SecurityContinuationPolicy` is sealed/versioned under
`security.continuation.policy/0.1`.  It controls:

- maximum lifetime of the overall continuation;
- maximum age of commit-state evidence;
- future-clock tolerance;
- whether staged-state identity is mandatory;
- whether invocation context identity is mandatory;
- whether successful commit is single-use.

It is a fixed reviewable algorithm.  There is no runtime LLM decision.

## New evidence after method admission

A start method can legitimately be `ALLOW` at 10:00.  If new evidence at 10:01
establishes an account takeover, the COMMIT assessment at 10:02 may be `HOLD`.
The old start-method `ALLOW` does not survive as a bearer capability.

This is deliberately stronger than invocation freshness.  Invocation freshness
protects one method checkpoint against argument/context substitution.  Commit
revalidation protects a longer-lived operation against **time-of-check versus
time-of-irreversible-use** drift.

## Staged-state identity

The host supplies a deterministic identity for the state it is about to
publish, for example a transaction plan hash, journal generation, aggregate
revision, settlement instruction identity or another domain-native semantic
identity.  Bouncer does not prescribe the representation.

The identity in `SecurityCommitEvidence` must equal the live identity presented
at commit.  A transaction assessed for `AMOUNT=20,000` therefore cannot publish
a later staged state containing `AMOUNT=2,000,000` under the old assessment.

## Access Permissions boundary

The optional `SecurityContinuationAccessPermissionsBridge` requires both:

1. fresh Security invocation evidence for the COMMIT method itself; and
2. valid continuation/commit revalidation.

Only then is a `PermissionRequest` constructed.  `PermissionAuthority` remains
the component that decides whether that exact subject/object/class/COMMIT method
is authorized.  A Permission denial consumes neither security validation.  A
successful Permission allow consumes both single-use validations.  If a race or
unexpected failure occurs after commit-continuation consumption has begun, the
bridge fails closed and does not restore replayability merely to make retry more
convenient.

This keeps the architecture:

```text
Security meaning != Permission authority != physical enforcement
```
