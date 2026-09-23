# dev7 lifecycle / re-entry
Projection state now uses LIVE -> REVOKING -> REVOKED -> RELEASED vocabulary. Invocation pins protect ClientData from deletion during dispatch. Projection and retained-object registry locks are not held across Rexx dispatch.

The resident Tcl serialization lock is recursive specifically for legitimate same-owner-thread re-entry: Tcl -> Rexx callback -> Tcl. The test is a deadlock regression for that path.

External Tcl-created thread attachment remains out of scope.
