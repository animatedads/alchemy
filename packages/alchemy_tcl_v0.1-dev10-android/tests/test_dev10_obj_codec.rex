/* dev10: Tcl_Obj vector dispatch must not reinterpret values as Tcl script. */
setup=AlchemyTclEval("proc ::echo1 {x} {return $x}; oo::class create ::EchoObj {method echo {x} {return $x}}; ::EchoObj create ::echoObj")
if setup \== "::echoObj" then call fail "setup",setup

/* These are hostile-to-script-concatenation values. Tcl_EvalObjv must carry
 * each as one exact Tcl value, with no command/substitution execution. */
v1="a b {c} ; set ::INJECTED yes"
r=AlchemyTclCommandObj1("::echo1",v1)
if r \== v1 then call fail "command value",r
r=AlchemyTclEval("info exists ::INJECTED")
if r \== "0" then call fail "script injection",r

v2='[expr {6*7}] $never ; error BOOM'
r=AlchemyTclOoCallObj1("::echoObj","echo",v2)
if r \== v2 then call fail "TclOO value",r

v3="line one" || '0a'x || "line two {x}; [set y]"
r=AlchemyTclOoCallObj1("::echoObj","echo",v3)
if r \== v3 then call fail "newline value",r

say "PASS Tcl_Obj vector codec preserves arbitrary values without script re-parse"
exit 0
fail:
 use arg what,got
 say "FAIL" what "got="got
 exit 1
::requires "alchemy_tcl" LIBRARY
