# Alchemy Tcl v0.1-dev1

First executable foundation for a resident, bidirectional Tcl ↔ ooRexx Alchemy bridge.

API identity: `alchemy.tcl/0.1`

## Architectural rule

Tcl remains Tcl-authoritative. The bridge does not flatten Tcl into a subprocess, JSON, or an OO-shaped RPC model. Tcl interpreters, commands, Tcl_Obj values, namespaces, TclOO objects/classes, errors, traces and mutation retain their native semantics. ooRexx objects likewise remain live ooRexx objects when projected into Tcl.

This development cut deliberately proves the native Tcl residency/lifecycle seam before claiming the full ooRexx crossing.

## Shared dependency contract

The intended bridge composes with, rather than vendors:

- ooRexx 5.3.0 r13196
- Alchemy Foreign Object v0.2
- Alchemy Objects v0.8.1+
- Crypto v0.8.3 where authority/evidence sealing is required
- Foreign Runtime v0.22.6+
- the selected Tcl runtime

`RxMath` and other ooRexx distribution facilities, if required by the selected Alchemy dependency closure, are discovered from that ooRexx distribution.

## dev1 executable milestone

`native/tcl_resident_probe.c` dynamically discovers Tcl at runtime (no Tcl development headers are required), creates a resident interpreter, initializes Tcl, evaluates commands repeatedly in the same interpreter, proves state survives calls, renames a command, observes the old name disappear and the new name remain live, and destroys the interpreter.

This is intentionally a foundation probe, not a claim that Rexx ↔ Tcl callbacks are complete.

## Next gate

The next development cut must bind the resident interpreter to the ooRexx native package API and prove:

`Rexx → Tcl → retained Rexx callback → Tcl → Rexx`

inside one resident interpreter, with explicit owner-runtime identity, generation, invocation pinning, release/revocation and structured Tcl error propagation.

## dev2

Adds the first real ooRexx native package crossing. `AlchemyTclRoundTrip` installs a temporary Tcl command backed by the exact Rexx callback object for the synchronous invocation and proves Rexx → resident Tcl → Rexx callback → Tcl → Rexx. This is deliberately scoped; asynchronous/long-lived Tcl callbacks require the shared retained-identity lifecycle registry and are not claimed by dev2.

## dev3

Adds a deliberately bounded persistent-command qualification. A Tcl command backed by the exact Rexx callback object is installed, one Tcl evaluation completes, and a distinct later Tcl evaluation invokes that still-registered command successfully.

This is an important lifetime step, but it is **not** described as cross-Rexx-call retention: the Rexx call context is still valid because both Tcl evaluations occur within the dynamic extent of one native Rexx routine. A future cross-call retained-object implementation must reacquire a valid interpreter/thread context rather than storing a `RexxCallContext *`.

## dev4

Adds a generation-fenced retained Rexx identity registry using ooRexx `RequestGlobalReference` / `ReleaseGlobalReference`, following the already-qualified Rust Alchemy ownership pattern. The test returns from the retaining native routine, invokes the exact object from a later native call, releases it, verifies stale-token rejection, and verifies exactly-once release. No `RexxCallContext *` is persisted.

## dev5

Joins resident Tcl to the dev4 retained-identity registry. A Rexx object retained by an earlier native call becomes the semantic target of `::alchemy::retained` in a later Tcl evaluation; Tcl calls it, resumes, and returns. After release, the same generation fails closed through Tcl as `TCL_ERROR:STALE_OR_REVOKED`. Android execution remains pending until the Architect returns to the phone.

## dev6

Persistent Tcl command projections over generation-fenced retained Rexx identity. Tcl rename/delete remain authoritative; the exact target is resolved at invocation time and registry locks are dropped before Rexx dispatch. The Android runner now repairs executable bits after unzip.

## dev7
Lifecycle/pin hardening and same-owner-thread nested Tcl re-entry. The Android runner repairs ZIP executable bits.

## dev7.1 repair

Fixes the dev7 Android compile failure: raw Tcl_SetResult ABI type, correct TCL_VOLATILE sentinel value 1, and explicit unused ooRexx contexts. This repaired source was compiled and all dev3-dev7 tests were run by the assistant against the supplied ooRexx 5.3.0 r13196 runtime and host Tcl 8.6 before packaging.

## dev8

Adds structured Tcl completion evidence: raw completion code, result, `errorCode`, and `errorInfo`, captured immediately and length-framed without flattening Tcl's native error semantics.

## dev9

TclOO-authoritative reverse object seam. TclOO instances remain live Tcl command identities; Rexx delegates class lookup and method dispatch to Tcl. Qualification covers state mutation, post-projection method amendment, rename, and destruction without synthesizing a Rexx class hierarchy.

## dev10

Adds the first Tcl_Obj value-codec seam using `Tcl_NewStringObj` + `Tcl_EvalObjv`. New command/TclOO dispatch no longer constructs Tcl source, so argument values containing whitespace, braces, semicolons, newlines, `$` or `[...]` are not reparsed as script.
