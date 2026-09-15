parse arg statePath
if statePath="" then do
  say "usage: rexx test_mtboot_no_ready_tape_state.rex no-ready.state"
  exit 2
end
state=.KL10State~new
cpu=state~load(statePath)
meta=state~metadata
call eq meta["checkpoint"],"mtboot.no-ready-tape.prompt","checkpoint"
call eq cpu~pc,oct("773466"),"PC"
call eq cpu~instructionCount,274468,"ICOUNT"
call eq cpu~dte~rxHex,"","RX empty"
call eq cpu~dte~txHex,-
 "0D0A424F4F54205631312E3028333135290D0A0D0A4D54424F4F543E0D0D0A0D0A20203F424F4F543A204E6F20726561647920746170652D647269766520617661696C61626C650D0A0D0A4D54424F4F543E",-
 "console transcript"
do code=oct("540") to oct("574") by 4
  call eq cpu~ioBus~hasDevice(code),1,"RH20 attached" code
  call eq cpu~rh20(code)~state["massbusEnabled"],1,"RH20 enabled" code
end
p=cpu~preview
call eq p["mnemonic"],"SKIPN","waiting"
call eq p["effectiveAddress"],oct("765456"),"DTMTI"
say "PASS test_mtboot_no_ready_tape_state"
exit 0

oct: procedure
 use arg t
 n=0
 do i=1 to length(t); n=n*8+substr(t,i,1); end
 return n
eq: procedure
 use arg a,e,l,x
 if a\=e then do; say "FAIL" l x "expected="e "actual="a; exit 1; end
 return
::requires "../KL10IPL.cls"
