numeric digits 30
cpu=.IBM370CPU~new
cpu~start

do r=0 to 15
  v=(r*286331153)//4294967296
  cpu~setGpr(r,v)
  call assertEq v,cpu~gprFast(r),"fast read r"r
end

do r=0 to 15
  v=(4294967295-r*16843009)//4294967296
  cpu~setGprFast(r,v)
  call assertEq v,cpu~gpr(r),"validated read after fast write r"r
end

/* The validated public API must still reject an impossible register field. */
trapped=0
signal on syntax name badPublic
dummy=cpu~gpr(16)
signal off syntax
call fail "public gpr unexpectedly accepted register 16"
badPublic:
  trapped=1
signal off syntax
if trapped=0 then call fail "public guard not observed"

/* Fast access must be state-identical to normal access. */
st=cpu~state
copy=.IBM370CPU~new
copy~restoreState(st)
do r=0 to 15
  call assertEq cpu~gpr(r),copy~gpr(r),"state round trip r"r
end

say "PASS test_cpu_fast_gpr_equivalence"
exit 0

assertEq: procedure
  parse arg expected,actual,label
  if expected \== actual then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end
return
fail: procedure
  parse arg msg
  say "FAIL" msg
  exit 1
::requires "IBM370Architecture.cls"
