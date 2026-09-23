/* Alchemy Tcl dev2 real ooRexx/Tcl crossing test */
provider = AlchemyTclProvider()
say "provider="provider

r = AlchemyTclEval("set ::alchemy_persist 40; incr ::alchemy_persist 2")
if r \== "42" then call fail "resident state", r

cb = .Callback~new
r = AlchemyTclRoundTrip("set a [::alchemy::rexx_callback 21]; expr {$a + 1}", cb)
if r \== "43" then call fail "Rexx->Tcl->Rexx->Tcl->Rexx", r

r = AlchemyTclEval("incr ::alchemy_persist")
if r \== "43" then call fail "resident state after callback", r

r = AlchemyTclPersistentRoundTrip("set ::alchemy_phase installed", -
    "set b [::alchemy::retained_rexx 30]; set ::alchemy_phase later; expr {$b + 2}", cb)
if r \== "62" then call fail "persistent Tcl command across separate evals", r

r = AlchemyTclEval("set ::alchemy_phase")
if r \== "later" then call fail "later Tcl evaluation state", r

say "PASS synchronous re-entry + persistent Tcl callback command across separate evaluations"
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
