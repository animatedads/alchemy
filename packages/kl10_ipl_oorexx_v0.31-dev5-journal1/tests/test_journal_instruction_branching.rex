numeric digits 30
mem=.KL10Memory~new
mem~mapZeroPage(0,0)
mem~put(oct("100"),oct("476000000200")) /* SETOM 200 */
mem~put(oct("200"),oct("123456"))
cpu=.KL10CPU~new~~loadImage(mem,oct("100"))
s=.KL10JournalSession~new(cpu)
old=cpu~memory~physicalWord(oct("200"))
t1=s~step
call eq cpu~pc,oct("101"),"first branch PC"
call eq cpu~memory~physicalWord(oct("200")),oct("777777777777"),"first branch write"
s~restore(t1["journalBefore"])
call eq cpu~pc,oct("100"),"rewound PC"
call eq cpu~instructionCount,0,"rewound ICOUNT"
call eq cpu~memory~physicalWord(oct("200")),old,"rewound memory"
t2=s~step
call eq cpu~pc,oct("101"),"second branch PC"
call eq cpu~memory~physicalWord(oct("200")),oct("777777777777"),"second branch write"
/* Both futures remain restorable. */
s~restore(t1["journalAfter"])
call eq cpu~memory~physicalWord(oct("200")),oct("777777777777"),"old future retained"
s~restore(t2["journalAfter"])
call eq cpu~memory~physicalWord(oct("200")),oct("777777777777"),"new future retained"
call true mem~journalState~retainedNodeCount>=2,"memory has retained branches"
say "PASS test_journal_instruction_branching"
exit 0

oct: procedure
 use arg t
 t=changestr(",",t,""); n=0
 do i=1 to length(t); n=n*8+substr(t,i,1); end
 return n
eq: procedure
 use arg a,e,l
 if a \= e then do; say "FAIL" l "expected="e "actual="a; exit 1; end
 return
true: procedure
 use arg v,l
 if \v then do; say "FAIL" l; exit 1; end
 return
::requires "../KL10Journal.cls"
