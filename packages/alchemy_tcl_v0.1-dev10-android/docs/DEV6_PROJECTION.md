# dev6 persistent Tcl projection

dev6 promotes the retained Rexx target into a Tcl-owned command projection.

The Tcl command persists in the resident interpreter independently of the Rexx call that created it. Its ClientData contains only projection metadata and the generation-bound retained token; it never contains a persisted RexxCallContext.

During `AlchemyTclEvalProjected`, the current call context is installed thread-locally for the dynamic extent of Tcl evaluation. A projected Tcl command resolves the retained target under the identity registry lock, drops that lock, and only then dispatches Rexx.

Tcl remains authoritative for command naming and deletion. `rename old new` keeps the same Tcl command/client data live; `rename name {}` invokes Tcl's delete callback and destroys the projection record. Target revocation is independent: a still-existing Tcl command whose retained generation was released fails closed as `STALE_OR_REVOKED`.

The projection records an invocation pin around dispatch. dev6 does not yet defer deletion/release against an overlapping concurrent invocation; that is the next lifecycle hardening step.

## Qualification
dev3-dev5 were observed PASS on Android/aarch64 Termux with Tcl 8.6. dev6 is packaged as the next target qualification.
