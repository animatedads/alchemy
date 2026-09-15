numeric digits 30
parse arg statePath
if statePath="" then do
 say "usage: rexx test_first_read_integrated_state.rex state.kl10state"
 exit 2
end
s=.KL10State~new
cpu=s~load(statePath)
call eq s~schemaSha256,"c86e8d86cc028409df01f57f9c9af0d57e36727e6549e0f025c5a184fbe1ea3f","schema"
call eq cpu~pc,oct("774445"),"PC"
call eq cpu~instructionCount,276997,"ICOUNT"
rh=cpu~rh20(oct("540"))
t=rh~unit(0)
call eq t~mediaSha256,"7248864ad885ee89f4c3e93b0dfa266bfa5e79c136f3cace300480df179780f7","media SHA"
call eq t~position,2568,"tape position"
call eq t~fileNumber,0,"file number"
call eq t~pendingRecord["kind"],"DATA","pending kind"
call eq t~pendingRecord["length"],2560,"pending length"
call eq t~pendingWord36(0),oct("001776000017"),"first tape word"
call eq cpu~memory~physicalWord(oct("771000")),t~pendingWord36(0),"channel word 0"
call eq cpu~memory~physicalWord(oct("771777")),t~pendingWord36(511),"channel word 511"

/* Round trip the complete moved-media state. */
out="/tmp/kl10-v030-first-read-roundtrip.state"
meta=.directory~new
meta["checkpoint"]="test.first-read-roundtrip"
.KL10State~new~save(cpu,out,meta)
vstate=.KL10State~new
v=vstate~load(out)
vt=v~rh20(oct("540"))~unit(0)
call eq v~pc,cpu~pc,"reload PC"
call eq v~instructionCount,cpu~instructionCount,"reload ICOUNT"
call eq vt~position,t~position,"reload tape position"
call eq vt~pendingWord36(0),t~pendingWord36(0),"reload pending record"
call eq vstate~memoryDigest,s~memoryDigest,"reload memory digest"
call sysFileDelete out
say "PASS test_first_read_integrated_state"
exit

eq: procedure
 use arg a,e,l
 if a\=e then do; say "FAIL" l "expected="e "actual="a; exit 1; end
 return
oct: procedure
 use arg t
 t=changestr(",",t,"")
 n=0
 do i=1 to length(t); n=n*8+substr(t,i,1); end
 return n
::requires "../KL10IPL.cls"
