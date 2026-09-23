# dev5 — retained Rexx identity as a Tcl command target

dev5 joins the dev3 Tcl crossing to the dev4 durable identity registry.

Sequence:

1. one Rexx native call retains an exact Rexx object and returns an opaque id:generation token;
2. a later Rexx native call enters the resident Tcl interpreter;
3. `::alchemy::retained` resolves that previously retained generation-bound target;
4. Tcl invokes the exact Rexx object using the later call's fresh context;
5. Tcl resumes after the callback and completes;
6. Rexx revokes/releases the retained target;
7. a later Tcl attempt through the old generation fails closed with TCL_ERROR / STALE_OR_REVOKED.

The registry mutex is not held while dispatching Rexx.

## Still not claimed

This does not yet attach arbitrary Tcl-created OS threads to ooRexx. It establishes the safe owning-thread path: a later Tcl evaluation entered from Rexx can call a durable Rexx identity without persisting RexxCallContext.
