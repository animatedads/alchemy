# Acceptance ladder

## A. Native Tcl residency
- [x] Discover Tcl shared library dynamically.
- [x] Create and initialize resident interpreter.
- [x] Repeated evaluation uses the same interpreter state.
- [x] Command rename is observed live.
- [x] Old command name no longer resolves after rename.
- [x] Interpreter is destroyed cleanly.

## B. Rexx → Tcl native crossing
- [ ] Load Alchemy Tcl as an ooRexx native package.
- [ ] Create/own a resident Tcl interpreter from Rexx.
- [ ] Invoke Tcl command with exact argument boundaries.
- [ ] Preserve structured Tcl errors.

## C. Tcl → Rexx
- [ ] Retain a Rexx object and expose it as a Tcl command.
- [ ] Invoke Rexx from Tcl.
- [ ] Release projection exactly once.

## D. Same-interpreter re-entry
- [ ] Rexx → Tcl → retained Rexx callback → Tcl → Rexx.
- [ ] Nested error round trip.
- [ ] No registry lock held over foreign invocation.

## E. Live mutation
- [ ] Rename Tcl command with live Rexx projection.
- [ ] Replace Tcl command.
- [ ] Delete Tcl command.
- [ ] TclOO method replace/remove.
- [ ] Stale generation cannot resolve to recycled target.

## F. Shared Alchemy qualification
- [ ] Existing Rexx UNKNOWN is preserved.
- [ ] Foreign absence falls through.
- [ ] Present Tcl command returning TCL_ERROR does not fall through.
- [ ] Invocation vs release/revoke/shutdown races.
- [ ] Sparse/empty/nil argument semantics explicitly qualified.

## dev2 observed gate
- [x] Native ooRexx package loads.
- [x] Rexx invokes resident Tcl.
- [x] Tcl invokes the exact Rexx callback object synchronously.
- [x] Tcl continues after callback and returns to Rexx.
- [x] Resident Tcl state persists before/after callback crossing.
