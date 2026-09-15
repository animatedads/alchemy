/* Freeze the authenticated mapped MTBOOT machine immediately before MAP.
 * Input must already carry the explicit DTE attachment.
 */
parse arg inputState outputState
if inputState="" | outputState="" then do
 say "usage: rexx MTBootFreezePreMap.rex pre-dte-attached.kl10state pre-map.kl10state"
 exit 2
end
reader=.KL10State~new
cpu=reader~load(inputState)
if \cpu~ioBus~hasDevice(128) then do; say "DTE not attached"; exit 1; end
p=cpu~preview
if p["xctDeviceName"] \= "DTE" then do; say "input not at DTE proposal"; exit 1; end

do i=1 to 430
 ignored=cpu~step
end
call eq cpu~pc,oct("772512"),"pre-MAP PC"
call eq cpu~instructionCount,273068,"pre-MAP ICOUNT"
p=cpu~preview
call eq p["mnemonic"],"MAP","next mnemonic"
call eq p["instruction"],oct("257040762000"),"next MAP word"
call eq cpu~dte~txHex,"0D0A424F4F54205631312E3028333135290D0A","console output"
call eq cpu~dte~monitorMode,1,"DTE monitor mode"
call eq cpu~dte~servicePending,0,"DTE service drained"

meta=.directory~new
old=reader~metadata
do key over old; meta[key]=old[key]; end
meta["checkpoint"]="mtboot.pre-map"
meta["parent_checkpoint"]="mtboot.pre-dte-probe.attached"
meta["parent_state_sha256"]=sha256File(inputState)
meta["console_hex"]=cpu~dte~txHex

writer=.KL10State~new
ignored=writer~save(cpu,outputState,meta)
verifyState=.KL10State~new
verify=verifyState~load(outputState)
call eq verify~pc,cpu~pc,"reload PC"
call eq verify~instructionCount,cpu~instructionCount,"reload ICOUNT"
call eq verify~dte~txHex,cpu~dte~txHex,"reload console"
vp=verify~preview
call eq vp["mnemonic"],"MAP","reload proposal"

say "FROZEN" outputState
say " checkpoint=mtboot.pre-map"
say " PC=" || .LROct~fromDecimal(verify~pc)~right "ICOUNT=" || verify~instructionCount
say " console_hex=" || verify~dte~txHex
say " next=" || .LROct~fromDecimal(vp["instruction"])~string vp["mnemonic"]
exit 0

sha256File: procedure
 use arg path
 out=path||".parent.sha256.tmp"
 address system 'sha256sum "'||path||'" > "'||out||'"'
 if rc \= 0 then do; say "sha256sum failed"; exit 1; end
 s=.stream~new(out)~~open("READ"); line=s~linein; s~close
 call sysFileDelete out
 parse var line h .
 return h
oct: procedure
 use arg t
 t=changestr(",",t,"")
 n=0; do i=1 to length(t); n=n*8+substr(t,i,1); end; return n
eq: procedure
 use arg a,e,l
 if a \= e then do; say "FAIL" l "expected="e "actual="a; exit 1; end
 return
::requires "../KL10IPL.cls"
