# RYTA observability interposition boundary — v0.29-work

## Rule

```text
logging / telemetry / method interposition = observation infrastructure
                                         != RYTA decision authority
                                         != Legal Effect authority
                                         != EvidencePromotion authority
```

Alchemy Objects v0.8 can join an already-active generic method-interposition
coordinator. ooRexx Logging v0.5 supplies such a coordinator. RYTA uses that
facility only through the optional `RYTALoggingIntegration.cls`; core RYTA does
not acquire a Logging dependency.

## One physical wrapper

When Logging is installed first, Alchemy joins provider
`ALCHEMY.EXECUTION_PROVENANCE` behind the existing physical wrapper. RYTA
acceptance requires one wrapper and two independently releasable providers.

When Alchemy is installed first, Logging retains the Alchemy object-specific
method as the implementation beneath its coordinator. Alchemy v0.8 must refuse
`uninstrumentMethod()` with `TELEMETRY_EXTERNAL_INTERPOSITION_ACTIVE` while that
outer coordinator still owns the current method. After Logging releases,
Alchemy can remove its direct layer normally.

## ooRexx scope preservation

An object-specific method installed with `SETMETHOD(..., "OBJECT")` executes at
object scope. Copying an inherited stateful `VirtualRYTA~evaluate` implementation
into that slot would therefore make its `EXPOSE` variables resolve in the wrong
scope.

The optional `RYTALoggedVirtualRYTA` subtype consequently declares a tiny
`evaluate` forwarding method on the adapter class. The forwarding method invokes
`EVALUATE` with explicit `.VirtualRYTA` scope, so the business implementation
continues to see VirtualRYTA-owned state. The forwarding surface remains GUARDED;
both Logging and Alchemy wrappers are verified to preserve that guarded
serialization property.

This is a RYTA integration rule, not a patch to Alchemy or Logging.

## Evidence boundaries

The Alchemy execution record may retain method identity, contract identity and
revision, implementation origin, timing/outcome, security profile and argument
count. It must not copy the raw RYTA world argument. Logging is a separate,
explicitly scoped structured-observability system; its event disclosure rules do
not become RYTA authority.

Acceptance compares state, winning rule, winning tier, execution status and
output count against an uninstrumented baseline under both interposition orders.
