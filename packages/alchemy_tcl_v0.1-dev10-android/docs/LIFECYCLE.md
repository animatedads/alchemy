# Tcl/Rexx lifetime boundary

## What dev3 proves

A Tcl command can remain registered across multiple resident-interpreter evaluations and continue to target the exact Rexx callback object while the owning native Rexx invocation remains active.

## What dev3 refuses to assume

A `RexxCallContext *` is not treated as a durable callback capability. dev3 therefore does not retain that pointer after the native routine returns.

## Required cross-call design

Long-lived Tcl -> Rexx callbacks require:
1. a retained/global Rexx object identity owned through supported ooRexx APIs;
2. owner interpreter/runtime identity;
3. generation and lifecycle state;
4. invocation pin acquired before leaving the registry;
5. a supported mechanism to obtain/attach an execution context for the callback thread;
6. foreign invocation outside registry locks;
7. revoke that blocks new pins;
8. shutdown that invalidates interpreter-owned projections;
9. exactly-once release of bridge ownership;
10. deterministic stale/revoked errors.

This boundary is intentionally shared with the other Alchemy language bridges rather than invented as Tcl-only lifetime machinery.
