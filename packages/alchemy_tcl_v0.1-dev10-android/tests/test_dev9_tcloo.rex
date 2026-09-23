setup=AlchemyTclEval("oo::class create ::Counter { variable n; constructor {start} {set n $start}; method add {x} {incr n $x}; method value {} {return $n} }; ::Counter create ::counter 10")
if setup \== "::counter" then call fail "create",setup
if AlchemyTclOoExists("::counter") \== "1" then call fail "exists",AlchemyTclOoExists("::counter")
if AlchemyTclOoClass("::counter") \== "::Counter" then call fail "class",AlchemyTclOoClass("::counter")
r=AlchemyTclOoCall1("::counter","add","5")
if r \== "15" then call fail "dispatch",r
if AlchemyTclEval("::counter value") \== "15" then call fail "live state",AlchemyTclEval("::counter value")
r=AlchemyTclEval("oo::define ::Counter method add {x} {my variable n; incr n [expr {$x * 2}]}; set x amended")
if r \== "amended" then call fail "amend",r
if AlchemyTclOoCall1("::counter","add","5") \== "25" then call fail "amended dispatch",AlchemyTclOoCall1("::counter","add","5")
r=AlchemyTclEval("rename ::counter ::renamedCounter; set x renamed")
if r \== "renamed" then call fail "rename",r
if AlchemyTclOoExists("::counter") \== "0" then call fail "old name",AlchemyTclOoExists("::counter")
if AlchemyTclOoExists("::renamedCounter") \== "1" then call fail "new name",AlchemyTclOoExists("::renamedCounter")
if AlchemyTclOoClass("::renamedCounter") \== "::Counter" then call fail "renamed class",AlchemyTclOoClass("::renamedCounter")
if AlchemyTclOoCall1("::renamedCounter","add","1") \== "27" then call fail "renamed dispatch",AlchemyTclOoCall1("::renamedCounter","add","1")
r=AlchemyTclEval("::renamedCounter destroy; set x destroyed")
if r \== "destroyed" then call fail "destroy",r
if AlchemyTclOoExists("::renamedCounter") \== "0" then call fail "absence",AlchemyTclOoExists("::renamedCounter")
say "PASS TclOO live object/class authority; method amendment; rename; destruction"
exit 0
fail:
 use arg what,got
 say "FAIL" what "got="got
 exit 1
::requires "alchemy_tcl" LIBRARY
