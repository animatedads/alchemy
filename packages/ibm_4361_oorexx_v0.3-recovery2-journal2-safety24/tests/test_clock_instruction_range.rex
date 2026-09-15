numeric digits 30
s=.IBM370Storage~new(65536,2048)
c=.IBM370Clock~new
s~storeHex(x2d('50'),'00001000')
/* 9,999 ordinary instructions: no interval tick, deterministic TOD. */
do i=1 to 9999
  junk=c~advanceInstructionRange(s,0,i-1,i)
end
call eq s~fetchHex(x2d('50'),4),'00001000','timer before boundary'
call eq c~todHex,d2x(9999*4096,16),'TOD 9999'
junk=c~advanceInstructionRange(s,0,9999,10000)
call eq s~fetchHex(x2d('50'),4),'00000D00','timer at boundary'
call eq c~todHex,d2x(10000*4096,16),'TOD 10000'
/* Range advance must be equivalent to boundary count. */
s2=.IBM370Storage~new(65536,2048); c2=.IBM370Clock~new
s2~storeHex(x2d('50'),'00001000')
junk=c2~advanceInstructionRange(s2,0,0,25000)
call eq s2~fetchHex(x2d('50'),4),'00000A00','range timer two ticks'
call eq c2~todHex,d2x(25000*4096,16),'range TOD'
say 'PASS test_clock_instruction_range'
exit 0

eq: procedure
 parse arg a,b,label
 if a \== b then do; say 'FAIL' label 'expected=' || b || ' actual=' || a; exit 1; end
 return
::requires 'IBM370Architecture.cls'
