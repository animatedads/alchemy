numeric digits 30
mem=.KL10Memory~new
mem~mapZeroPage(0,0)
mem~put(oct("100"),0) /* OP000: intentionally unsupported */
cpu=.KL10CPU~new~~loadImage(mem,oct("100"))
s=.KL10JournalSession~new(cpu)
signal on syntax name Missing
ignored=s~step
signal off syntax
say "FAIL missing opcode did not refuse"
exit 1
Missing:
signal off syntax
cp=s~lastRecoveryPoint
call true cp \== .nil,"recovery checkpoint retained"
call eq cpu~pc,oct("100"),"failed instruction rewound"
call eq cpu~instructionCount,0,"failed ICOUNT rewound"
source='use strict arg d,trace,nextPc; self~setAccumulator(1,42); trace["trialResult"]=42; return nextPc'
name=cpu~installLiveInstructionMethod(0,source)
call eq name,"OP000","extension method name"
tr=s~step
call eq tr["liveExtension"],"OP000","live extension executed"
call eq tr["trialResult"],42,"live extension trace"
call eq cpu~accumulator(1),42,"live extension machine result"
call eq cpu~pc,oct("101"),"same historical instruction continued"
call eq cpu~instructionCount,1,"patched instruction retired"
say "PASS test_journal_live_opcode_patch"
exit 0

oct: procedure
 use arg t
 t=changestr(",",t,""); n=0
 do i=1 to length(t); n=n*8+substr(t,i,1); end
 return n
eq: procedure
 use arg a,e,l
 if a \== e then do; say "FAIL" l "expected="e "actual="a; exit 1; end
 return
true: procedure
 use arg v,l
 if \v then do; say "FAIL" l; exit 1; end
 return
::requires "../KL10Journal.cls"
