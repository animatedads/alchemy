/* Freeze MTBOOT at its first monitor-input wait.
 * Input: authenticated mtboot.pre-map state with DTE attached.
 */
parse arg inputState outputState
if inputState="" | outputState="" then do
 say "usage: rexx MTBootFreezePrompt.rex pre-map.state prompt.state"
 exit 2
end
reader=.KL10State~new
cpu=reader~load(inputState)
m=reader~metadata
call eq m["checkpoint"],"mtboot.pre-map","input checkpoint"

do 119
 ignored=cpu~step
end

call eq cpu~pc,oct("773466"),"prompt wait PC"
call eq cpu~instructionCount,273187,"prompt ICOUNT"
call eq cpu~dte~txHex,"0D0A424F4F54205631312E3028333135290D0A0D0A4D54424F4F543E","prompt bytes"
call eq cpu~dte~rxHex,"","RX queue empty"
call eq cpu~memory~physicalWord(cpu~pag~ebPtr+oct("0450")),0,"DTF11 empty"
call eq cpu~memory~physicalWord(cpu~pag~ebPtr+oct("0456")),0,"DTMTI clear"
p=cpu~preview
call eq p["mnemonic"],"SKIPN","input wait instruction"
call eq p["effectiveAddress"],oct("765456"),"input flag address"

meta=.directory~new
do key over m; meta[key]=m[key]; end
meta["checkpoint"]="mtboot.prompt"
meta["parent_checkpoint"]="mtboot.pre-map"
meta["parent_state_sha256"]=sha256File(inputState)
writer=.KL10State~new
ignored=writer~save(cpu,outputState,meta)

verifyState=.KL10State~new
verify=verifyState~load(outputState)
call eq verify~pc,cpu~pc,"reload PC"
call eq verify~instructionCount,cpu~instructionCount,"reload ICOUNT"
call eq verify~dte~txHex,cpu~dte~txHex,"reload TX"
call eq verify~dte~rxHex,"","reload RX"
vp=verify~preview
call eq vp["mnemonic"],"SKIPN","reload wait"

say "FROZEN" outputState
say " checkpoint=mtboot.prompt"
say " PC=" || .LROct~fromDecimal(verify~pc)~right "ICOUNT=" || verify~instructionCount
say " console_hex=" || verify~dte~txHex
say " waiting=DTMTI@" || .LROct~fromDecimal(verify~pag~ebPtr+oct("0456"))~right
exit 0

sha256File: procedure
 use arg path
 out=path||".parent.sha256.tmp"
 address system 'sha256sum "'||path||'" > "'||out||'"'
 if rc \= 0 then do; say "sha256sum failed"; exit 1; end
 st=.stream~new(out)~~open("READ")
 line=st~linein
 st~close
 call sysFileDelete out
 parse var line h .
 return h

oct: procedure
 use arg t
 n=0
 do i=1 to length(t); n=n*8+substr(t,i,1); end
 return n

eq: procedure
 use arg a,e,l
 if a\=e then do
  say "FAIL" l "expected="e "actual="a
  exit 1
 end
 return

::requires "../KL10IPL.cls"
