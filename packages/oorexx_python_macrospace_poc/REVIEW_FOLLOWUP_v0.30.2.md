# v0.30.2 review follow-up

This is a qualification/maintainability checkpoint over v0.30.1, not a new
foreign-object semantic generation.

## Corrected here

`run-tests.sh` had fallen behind the focused qualification performed in the
v0.24-v0.30 line.  In particular a normal aggregate run did not execute every
current lifetime, rollback and live-surgery torture.  The aggregate harness now
runs the complete current set so a green top-level result cannot accidentally
mean only the older POC demonstrations passed.

The added aggregate set is:

- Python object lifetime
- Python class-handle lifetime
- returned foreign proxy lifetime
- Rexx-held foreign proxy lifetime
- registry construction/rollback ownership
- Python type authority
- Python-under-Rexx live method surgery
- Rexx-under-Python live callable surgery
- concurrent dual-runtime live surgery/revocation

## Shared-foundation findings deliberately NOT patched here

The 18 September design review identifies two important shared Alchemy gates.
They are intentionally not repaired in this Python package because doing so
would create another bridge-private fork of common semantics.

1. Stable cooperative interposition/coordinator semantics must be owned by the
   shared Alchemy Objects / Logging layer.  Direct raw SETMETHOD can displace a
   coordinator; a Python-only workaround would be architecturally wrong.
2. Sparse Rexx argument positions need an explicit positional-count + omission
   representation in the shared calling contract.  Existing one-slot tests
   prove OMITTED != .nil != empty, but do not prove leading/middle/trailing
   sparse positions through locked-method extraction.

## Next acceptance gates

When the shared foundation containing those contracts is available, rebase this
bridge without copying it locally and require:

- class and instance target amendment/removal beneath a stable coordinator;
- overlap an invocation with amendment and revocation;
- observer detach/rebind with honest integrity state;
- leading, middle and trailing omitted arguments independently of `.nil`, empty
  string and ordinary values;
- the same sparse vector through a nested Python -> Rexx -> Python call;
- exact dependency identities/hashes recorded for the qualified run.

## Qualification status

Source/harness maintenance only in this environment.  The native ooRexx SDK is
not mounted here, so this checkpoint does not claim a fresh native rebuild or
runtime rerun.  v0.30 remains the last recorded native-qualified semantic base;
v0.30.1 contains the subsequent ownership hardening; v0.30.2 makes the complete
current regression set unavoidable in the aggregate harness.
