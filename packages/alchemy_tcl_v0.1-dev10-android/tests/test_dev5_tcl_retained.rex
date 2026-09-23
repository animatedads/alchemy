/* dev5: retained Rexx identity becomes a Tcl command target in a later call */
cb = .Callback~new

/* Call A: create durable bridge identity. */
token = AlchemyTclRetainRexx(cb)
if token = "RETAIN_FAILED" then call fail "retain", token

/* Call B: later native call enters resident Tcl. Tcl resolves its command
 * through the durable token and calls the exact Rexx object.
 */
r = AlchemyTclEvalRetained(token, -
    "set x [::alchemy::retained 20]; set ::dev5_seen $x; expr {$x + 3}")
if r \== "43" then call fail "Tcl retained callback", r

/* Prove Tcl continued after Rexx callback. */
r = AlchemyTclEval("set ::dev5_seen")
if r \== "40" then call fail "Tcl continuation", r

/* Call C: revoke/release. */
if \AlchemyTclReleaseRetained(token) then call fail "release", 0

/* Call D: same stale generation must fail through Tcl as a real error. */
r = AlchemyTclEvalRetained(token, "::alchemy::retained 21")
if left(r,10) \== "TCL_ERROR:" then call fail "stale Tcl invocation not error", r
if pos("STALE_OR_REVOKED",r) = 0 then call fail "stale fence missing", r

say "PASS later Tcl evaluation -> generation-fenced retained Rexx identity -> Tcl continuation; revoke fails closed"
exit 0

fail:
  use arg what, got
  say "FAIL" what "got="got
  exit 1

::class Callback
::method call
  use strict arg value
  return value * 2

::requires "alchemy_tcl" LIBRARY
