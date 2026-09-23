# Alchemy Tcl architecture

## 1. Semantic ownership

Alchemy Tcl is a semantic bridge, not a serialization bridge.

A Tcl interpreter owns its Tcl commands, namespaces, Tcl_Obj values and TclOO entities. A Rexx interpreter owns its Rexx objects/classes. Alchemy owns the crossing contract: identity handles, lifetime/generation, authority, conversion, error projection, callback/re-entry and evidence.

## 2. Core identities

A projected Tcl entity is bound to:

- Tcl runtime/provider identity
- resident interpreter identity
- entity kind
- native identity/command token where meaningful
- bridge generation
- lifecycle state

A textual Tcl value is never treated as sufficient identity for a command/object projection.

## 3. Tcl_Obj

Tcl_Obj has dual internal/string representations and reference-counted lifetime. The bridge must not use a string round trip as its universal conversion.

Value-like crossings may convert intentionally (integer, floating point, boolean, list, dict, byte array, string). Identity-bearing or semantically live entities remain projections.

## 4. Commands and UNKNOWN

Alchemy Foreign Object v0.2 remains the ooRexx-side composition point.

For a Rexx message projected toward Tcl:

1. Resolve whether the foreign Tcl member/command exists.
2. If absent, use `foreignUnknownFallback`.
3. If present, invoke it.
4. A Tcl `TCL_ERROR` is a foreign failure and MUST NOT fall through as member absence.

This preserves the shared Alchemy distinction between lookup miss and invocation failure.

## 5. Mutation

Tcl command rename, replacement and deletion are live semantic events.

A projection must not cache a raw command/function pointer indefinitely. Resolution is generation-aware. Deletion revokes the affected binding. Rename must either track the same semantic command identity where Tcl supplies sufficient evidence, or produce an explicit old-generation invalidation/new binding; it must never silently call an unrelated replacement.

TclOO method mutation follows the same shared live-target amendment rules.

## 6. Re-entry

Required path:

Rexx → Tcl → Rexx → Tcl

The foreign call occurs outside registry/lifecycle locks. The target is invocation-pinned before leaving the registry. Nested callbacks re-enter the owning Rexx interpreter using the bridge's supported thread/interpreter attachment policy.

## 7. Errors

Tcl completion codes are preserved as structured bridge outcomes:

- TCL_OK
- TCL_ERROR
- TCL_RETURN
- TCL_BREAK
- TCL_CONTINUE

For TCL_ERROR, preserve at minimum the result plus `errorInfo` and `errorCode` when available. Error is not absence.

## 8. Lifecycle

Common vocabulary:

`LIVE → REVOKING → REVOKED → RELEASED`

An invocation acquires a generation-bound pin. Revocation prevents new pins. Existing pinned calls finish according to policy. Interpreter shutdown revokes all projections owned by that interpreter. Stale generations never resolve to recycled entities.

## 9. Tcl → Rexx projection

A retained Rexx object is exposed as a Tcl command token. Tcl command invocation resolves the retained Rexx identity, pins it, converts arguments without collapsing omissions/empty/.nil distinctions, sends the Rexx message, converts the result and releases the pin.

Deletion of the Tcl command releases only the Tcl-side projection reference; it must not fabricate ownership of the Rexx object.

## 10. TclOO

TclOO is a richer adapter over the same resident interpreter. Objects/classes remain TclOO-authoritative. The adapter must preserve class/object identity, method dispatch, inheritance/mixins/filters where exposed, mutation and destruction rather than manufacturing a parallel Rexx class hierarchy.

## 11. Concurrency

Interpreter/thread affinity is adapter-owned. Shared registries may synchronize identity/lifecycle metadata, but no foreign Tcl invocation or Rexx callback occurs while holding a registry lock.

## 12. Non-goals

- subprocess `tclsh` RPC
- JSON as the object model
- pretending all Tcl values are objects with stable identity
- pretending all Rexx objects are Tcl strings
- swallowing TCL_ERROR as UNKNOWN
