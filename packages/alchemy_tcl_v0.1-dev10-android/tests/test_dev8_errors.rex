/* dev8: preserve Tcl completion/error evidence rather than flattening it. */
ok=AlchemyTclEvalDetailed("expr {6 * 7}")
if left(ok,5) \== "rc=0;" then call fail "success rc",ok
if pos("result=2:42;",ok)=0 then call fail "success result",ok
if pos("errorCode=0:;",ok)=0 then call fail "success errorCode",ok
if pos("errorInfo=0:;",ok)=0 then call fail "success errorInfo",ok

bad=AlchemyTclEvalDetailed("proc inner {} {error {boom from Tcl}}; proc outer {} {inner}; outer")
if left(bad,5) \== "rc=1;" then call fail "error rc",bad
if pos("result=13:boom from Tcl;",bad)=0 then call fail "error result",bad
if pos("errorCode=",bad)=0 then call fail "errorCode missing",bad
if pos("NONE",bad)=0 then call fail "errorCode value",bad
if pos("errorInfo=",bad)=0 then call fail "errorInfo missing",bad
if pos("inner",bad)=0 | pos("outer",bad)=0 then call fail "Tcl stack evidence",bad

say "PASS structured Tcl completion preserves result, errorCode and errorInfo"
exit 0
fail:
 use arg what,got
 say "FAIL" what "got="got
 exit 1
::requires "alchemy_tcl" LIBRARY
