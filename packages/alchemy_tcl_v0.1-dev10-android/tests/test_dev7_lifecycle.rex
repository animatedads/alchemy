cb=.NestedCallback~new
token=AlchemyTclRetainRexx(cb)
if token="RETAIN_FAILED" then call fail "retain",token
if \AlchemyTclProjectRetained("::alchemy::nested",token) then call fail "project",0
if AlchemyTclProjectionState("::alchemy::nested") \== "LIVE" then call fail "state",AlchemyTclProjectionState("::alchemy::nested")
/* Deadlock regression: Tcl -> Rexx -> nested Tcl -> Rexx return -> outer Tcl. */
r=AlchemyTclEvalProjected("set x [::alchemy::nested 20]; expr {$x + 1}")
if r \== "43" then call fail "nested re-entry",r
r=AlchemyTclEvalProjected("rename ::alchemy::nested {}; set x deleted")
if r \== "deleted" then call fail "delete",r
if AlchemyTclProjectionState("::alchemy::nested") \== "ABSENT" then call fail "deleted state",AlchemyTclProjectionState("::alchemy::nested")
if \AlchemyTclReleaseRetained(token) then call fail "release",0
say "PASS nested Tcl re-entry without deadlock; projection lifecycle/pin cleanup"
exit 0
fail:
 use arg what,got
 say "FAIL" what "got="got
 exit 1
::class NestedCallback
::method call
 use strict arg value
 nested=AlchemyTclEvalProjected("expr {20 + 22}")
 if nested \== "42" then return -999
 return nested
::requires "alchemy_tcl" LIBRARY
