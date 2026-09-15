# Security Effect v0.13 — Access Permissions integration

Security Effect, ooRexx Access Permissions and Alchemy Security Manager have deliberately separate jobs.

- **Security Effect** determines the security meaning, concern, constraint and disposition of the exact proposed invocation.
- **Access Permissions** determines whether the principal may invoke the exact method on the exact object under the operative Permission policy and retained Security assessment.
- **Alchemy Security Manager** enforces the resulting method decision at the interpreter checkpoint.

## Exact invocation binding

`SecurityMethodActionFactory~createInvocation` binds `OBJECT_ID`, `OBJECT_CLASS`, `METHOD`, `INVOCATION_ID`, `ARGUMENT_IDENTITY`, `CONTEXT_IDENTITY` and the exact invocation-evidence identity into the action evaluated by Bouncer. The resulting `SecurityDecisionTrace` retains the full action identity and Security snapshot identity. `SecurityPermissionBindingFactory~fromInvocationAssessment` freezes those values for downstream authority evaluation.

A sealed `SecurityInvocationPolicy` controls maximum age, future-clock tolerance, required argument/context identities and single-use behavior. `SecurityInvocationGuard` rejects changed arguments, changed session/workspace context, stale evidence and already-consumed bindings.

The optional `SecurityAccessPermissionsBridge~permissionRequestForInvocation` validates this evidence before constructing a Permission request. A Permission `DENY` does not consume the Security binding; a successful Permission `ALLOW` consumes it so the same Bouncer assessment cannot authorize another execution attempt.

## Live Security Manager path

`SecurityInvocationAlchemyPermissionPolicyAdapter` operates at the actual Alchemy `METHOD` checkpoint. It obtains the live object, method and argument array, asks a domain identity resolver for deterministic argument/context identities, creates a fresh unique invocation evidence object itself, obtains a Security assessment for that exact evidence, validates it, and only then calls `PermissionAuthority`.

This prevents an old Security `ALLOW` from being reused after argument substitution. The executable test authorizes `releasePayment(7)`, deliberately reuses the prior Security assessment for a later live `releasePayment(700000)`, and proves the Security Manager stops the second call before another Permission decision is produced.

The bridge grants no authority. Security `ALLOW` with no matching Permission rule remains default `DENY`; Permission `ALLOW` cannot override Security `HOLD` or `REVIEW_REQUIRED`; and an exact permission for one object does not float to another object of the same class.
