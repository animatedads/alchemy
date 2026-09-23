/* dev6: durable Tcl command projection, Tcl rename/delete, stale target */
cb=.Callback~new
token=AlchemyTclRetainRexx(cb)
if token="RETAIN_FAILED" then call fail "retain",token

if \AlchemyTclProjectRetained("::alchemy::object1",token) then call fail "project",0

r=AlchemyTclEvalProjected("::alchemy::object1 20")
if r \== "40" then call fail "initial projection",r

/* Tcl itself remains authoritative for command identity/name. */
r=AlchemyTclEvalProjected("rename ::alchemy::object1 ::alchemy::renamed; ::alchemy::renamed 21")
if r \== "42" then call fail "rename/live dispatch",r

/* Original name is truly absent after Tcl rename. */
r=AlchemyTclEvalProjected("::alchemy::object1 1")
if left(r,10) \== "TCL_ERROR:" then call fail "old name survived rename",r

/* Retained target revocation is independent of Tcl command existence. */
if \AlchemyTclReleaseRetained(token) then call fail "release target",0
r=AlchemyTclEvalProjected("::alchemy::renamed 22")
if pos("STALE_OR_REVOKED",r)=0 then call fail "stale target not fenced",r

/* Tcl delete callback owns projection cleanup. */
r=AlchemyTclEvalProjected("rename ::alchemy::renamed {}; set ::dev6_deleted yes")
if r \== "yes" then call fail "delete",r
r=AlchemyTclEvalProjected("::alchemy::renamed 1")
if left(r,10) \== "TCL_ERROR:" then call fail "deleted command survived",r

say "PASS persistent Tcl projection; Tcl rename/delete authoritative; retained target generation fenced"
exit 0
fail:
  use arg what,got
  say "FAIL" what "got="got
  exit 1

::class Callback
::method call
  use strict arg value
  return value*2
::requires "alchemy_tcl" LIBRARY
