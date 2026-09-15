numeric digits 30
s1=.IBM370Storage~new(65536); s2=.IBM370Storage~new(65536)
c1=.IBM370Clock~new("0000000000001000","TEST")
c2=.IBM370Clock~new("0000000000001000","TEST")
s1~storeHex(x2d("50"),"00000100"); s2~storeHex(x2d("50"),"00000100")
/* Cross exactly one interval-timer quantum boundary. */
c1~advanceOneInstruction(s1,0,10000)
c2~advanceInstructionRange(s2,0,9999,10000)
call eq c1~todHex,c2~todHex,"TOD"
call eq s1~fetchHex(x2d("50"),4),s2~fetchHex(x2d("50"),4),"interval timer"
call eq c1~intervalTimerPending,c2~intervalTimerPending,"pending flag"
/* Ordinary non-boundary instruction. */
c1~advanceOneInstruction(s1,0,10001)
c2~advanceInstructionRange(s2,0,10000,10001)
call eq c1~todHex,c2~todHex,"TOD ordinary"
call eq s1~fetchHex(x2d("50"),4),s2~fetchHex(x2d("50"),4),"timer ordinary"
say 'PASS test_clock_one_instruction_equivalence'
exit 0
eq: procedure
 parse arg a,b,label
 if a \== b then do; say 'FAIL' label 'expected='||b 'actual='||a; exit 1; end
 return
::requires 'IBM370Architecture.cls'
