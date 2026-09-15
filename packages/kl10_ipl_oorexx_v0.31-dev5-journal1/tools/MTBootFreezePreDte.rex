/* Derive an authenticated MTBOOT state immediately before its first DTE20
 * status probe, starting from the authenticated pre-paging checkpoint.
 *
 * Usage:
 *   rexx MTBootFreezePreDte.rex pre-paging.kl10state pre-dte.kl10state
 */
numeric digits 30
parse arg inputState outputState
if inputState="" | outputState="" then do
 say "usage: rexx MTBootFreezePreDte.rex pre-paging.kl10state pre-dte.kl10state"
 exit 2
end

reader=.KL10State~new
cpu=reader~load(inputState)
meta=reader~metadata
if \meta~hasIndex("checkpoint") | meta["checkpoint"] \= "mtboot.pre-paging-enable" then do
 say "input is not mtboot.pre-paging-enable"
 exit 1
end
call eq cpu~pc,1,"input PC"

/* Enter the real pager and execute the exact first sizing candidate. */
ignored=cpu~step
call eq cpu~pag~pageEnabled,1,"pager enabled"
ignored=cpu~step
call eq cpu~pc,oct("772350"),"mapped entry"

do 30
 ignored=cpu~step
end
call eq cpu~pc,oct("772407"),"candidate-zero prefix"
call eq cpu~accumulator(oct("10")),0,"candidate-zero AC10"
call eq cpu~accumulator(oct("12")),0,"candidate-zero AC12"

/* This authenticated checkpoint contains 512 contiguous physical 512-word
 * pages: 000..777 octal. Verify that premise before applying the loop
 * equivalence; otherwise refuse rather than manufacture a different machine.
 */
backing=cpu~memory~backingMemory
call eq backing~mappedPages,512,"expected physical page count"
call eq backing~isMapped(oct("777")),1,"highest physical page resident"
call eq backing~isMapped(oct("1000")),0,"first NXM page absent"

/* Complete candidate zero tail and mathematically equivalent remaining sizing
 * loop. Exact unit/historical regressions separately prove both the resident
 * and first-NXM branches. The final architectural effects are:
 *   page map 000..740 -> corresponding physical page
 *   probe slot 741 -> final failed candidate 17777
 *   saved highest successful physical page -> 777
 *   AC10=741, AC12=20000, APR NXM pending, PC=772415.
 */
do pg=1 to oct("740")
 cpu~memory~physicalPut(oct("766000")+pg,oct("120000")*(2**18)+pg)
end
cpu~memory~physicalPut(oct("766741"),oct("120000")*(2**18)+oct("17777"))
cpu~memory~physicalPut(oct("772146"),oct("777"))

cpu~setAccumulator(oct("1"),oct("741000"))
cpu~setAccumulator(oct("10"),oct("741"))
cpu~setAccumulator(oct("12"),oct("20000"))
ignored=cpu~apr~signalFlag(oct("2000"))

pagState=cpu~pag~state
pagState["tlbFlushCount"]=8196
ignored=cpu~pag~restoreState(pagState)

/* 147442 exact instructions remain after the 30-step prefix. */
ignored=cpu~restoreCoreState(oct("772415"),cpu~flags,cpu~halted,cpu~instructionCount+147442,cpu~processorMode)
call eq cpu~instructionCount,272626,"sizing handoff ICOUNT"

/* Execute the real post-sizing setup to the ordinary XCT. */
do 12
 ignored=cpu~step
end
call eq cpu~pc,oct("772431"),"pre-DTE XCT PC"
call eq cpu~instructionCount,272638,"pre-DTE ICOUNT"

proposal=cpu~preview
call eq proposal["mnemonic"],"XCT","outer proposal"
call eq proposal["xctInstruction"],oct("720340000017"),"nested DTE word"
call eq proposal["xctMnemonic"],"CONSO","nested DTE operation"
call eq proposal["xctDeviceName"],"DTE","nested device"
call eq proposal["xctIoFunction"],7,"nested CONSO function"

/* Preserve existing provenance and add the explicit parent relationship. */
newMeta=.directory~new
do key over meta
 newMeta[key]=meta[key]
end
newMeta["checkpoint"]="mtboot.pre-dte-probe"
newMeta["parent_checkpoint"]="mtboot.pre-paging-enable"
newMeta["parent_state_sha256"]=sha256File(inputState)
newMeta["derivation"]="pager+sizing-handoff"

writer=.KL10State~new
ignored=writer~save(cpu,outputState,newMeta)

/* Reload from bytes alone. Preview must still expose the nested DTE proposal
 * without mutating the state. */
verifyState=.KL10State~new
verify=verifyState~load(outputState)
call eq verify~pc,oct("772431"),"reloaded PC"
call eq verify~instructionCount,272638,"reloaded ICOUNT"
call eq verify~pag~pageEnabled,1,"reloaded pager"
call eq verify~apr~irqFlags,oct("2000"),"reloaded final NXM"
vp=verify~preview
call eq vp["xctDeviceName"],"DTE","reloaded nested DTE"

say "FROZEN" outputState
say " checkpoint=mtboot.pre-dte-probe"
say " PC=" || .LROct~fromDecimal(verify~pc)~right "ICOUNT=" || verify~instructionCount
say " next=" || .LROct~fromDecimal(vp["instruction"])~string vp["mnemonic"]
say " xct=" || .LROct~fromDecimal(vp["xctInstruction"])~string vp["xctMnemonic"] vp["xctDeviceName"]
exit 0

sha256File: procedure
 use arg path
 out=path||".sha256-parent.tmp"
 address system 'sha256sum "' || path || '" > "' || out || '"'
 if rc \= 0 then do; say "sha256sum failed"; exit 1; end
 s=.stream~new(out)~~open("READ")
 line=s~linein
 s~close
 call sysFileDelete out
 parse var line digest .
 return digest

oct: procedure
 use arg t
 t=changestr(",",t,"")
 n=0
 do i=1 to length(t); n=n*8+substr(t,i,1); end
 return n

eq: procedure
 use arg a,e,l
 if a \= e then do
  say "FAIL" l "expected="e "actual="a
  exit 1
 end
 return

::requires "../KL10IPL.cls"
