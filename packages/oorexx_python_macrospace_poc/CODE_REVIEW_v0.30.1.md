# v0.30.1 focused code review

## Scope

Focused review of the native CPython/ooRexx boundary introduced and stressed in
v0.24-v0.30, with emphasis on ownership, lock scope, rollback, callback pinning,
thread attachment, and comments around non-obvious contracts.

## Corrected in this pass

1. **Python registry rollback was not retain-count aware.**  A failed
   `wrap_python_object()` directly DECREFed/erased the registry entry.  If the
   object already had another logical owner this could invalidate that owner and
   leave the reverse identity map stale.  Teardown is now centralized and
   counted.
2. **Malformed method-case metadata could leak one retain.**  Validation now
   occurs before ownership is acquired.
3. **`py_object_call()` used a borrowed registry pointer after unlocking.**  A
   concurrent release could invalidate it.  The callback now INCREF-pins the
   target while holding the registry mutex and drops the pin after invocation.
4. **Registry teardown logic was duplicated.**  Normal release and rollback now
   share `release_python_object_locked()` / `release_python_object_handle()`.
5. **Non-obvious methods lacked local contracts.**  Comments now identify
   package bootstrap timing, global-reference ownership, attached-thread/GIL
   behaviour, callback pinning, transactional proxy construction, and live
   callable dispatch.

## Deliberately retained boundaries

- Python and ooRexx keep their own mutation/locking semantics; there is no
  cross-runtime application-object mutex.
- `RexxLiveCallable` pins its target per invocation and does not cache a Rexx
  Method object, preserving live method replacement.
- Stale Python registry release remains harmless by design.
- The shared `AlchemyForeignObject.cls` is still bundled in this POC package for
  historical compatibility.  The architectural target remains an external
  authoritative dependency rather than a forked copy.

## Follow-up hardening

The older convenience `lookup()` + `tc->SendMessage*` helpers predate the
revocation-race work.  They are appropriate for the POC's single-owner calls but
should eventually be migrated to the same explicit per-invocation Rexx pinning
pattern used by `RexxLiveCallable` before general concurrent handle revocation is
advertised for every helper.  This pass does not silently widen that contract.

Likewise, foreign exceptions are still flattened in the legacy `PYCALL`
external-function path.  A future error-channel pass should preserve structured
Python exception identity/details without `PyErr_Print()` side effects.
