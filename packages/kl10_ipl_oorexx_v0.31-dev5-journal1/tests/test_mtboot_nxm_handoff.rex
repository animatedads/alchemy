/* Real checkpoint-derived first NXM sizing probe. */
numeric digits 30
parse arg statePath
if statePath="" then do
 say "usage: rexx test_mtboot_nxm_handoff.rex pre-paging.kl10state"
 exit 2
end
cpu=.KL10State~new~load(statePath)
ignored=cpu~step                       /* CONO PAG,060765 */
ignored=cpu~step                       /* JRST 772350 */

cpu~setAccumulator(oct("10"),oct("000741"))
cpu~setAccumulator(oct("12"),oct("001000"))
ignored=cpu~restoreCoreState(oct("772371"),cpu~flags,cpu~halted,cpu~instructionCount,cpu~processorMode)

do i=1 to 7
 ignored=cpu~step
end
call eq cpu~pc,oct("772400"),"first probe instruction"
do i=1 to 4
 tr=cpu~step
 call eq tr["mnemonic"],"SKIP","NXM probe mnemonic"
 call eq tr["nxm"],1,"NXM operand abort"
end
call eq cpu~apr~irqFlags,oct("002000"),"APR NXM visible"

tr=cpu~step                              /* CONSZ APR,002000 */
call eq tr["mnemonic"],"CONSZ","APR test"
call eq tr["ioSkip"],0,"NXM prevents CONSZ skip"
call eq cpu~pc,oct("772405"),"NXM path enters SKIPA"

ignored=cpu~step                         /* SKIPA -> 772407 */
ignored=cpu~step                         /* CAIGE -> 772411 */
ignored=cpu~step                         /* MOVEI AC10,741 */
ignored=cpu~step                         /* AOS AC12 */
ignored=cpu~step                         /* CAMG */
ignored=cpu~step                         /* JRST */
call eq cpu~pc,oct("772371"),"NXM loop repeats"
call eq cpu~accumulator(oct("10")),oct("000741"),"probe virtual page fixed"
call eq cpu~accumulator(oct("12")),oct("001001"),"candidate advances"
call eq cpu~apr~irqFlags,oct("002000"),"NXM remains pending"

ignored=cpu~step                         /* CONO APR,022000 */
call eq cpu~apr~irqFlags,0,"next loop clears NXM"

say "PASS test_mtboot_nxm_handoff"
exit 0
oct: procedure
 use arg t
 n=0; do i=1 to length(t); n=n*8+substr(t,i,1); end; return n
eq: procedure
 use arg a,e,l
 if a \= e then do; say "FAIL" l "expected="e "actual="a; exit 1; end
 return
::requires "../KL10IPL.cls"
