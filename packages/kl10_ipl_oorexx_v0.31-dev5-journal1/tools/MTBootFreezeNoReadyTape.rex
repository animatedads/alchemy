/* Derive the completed ENTER/no-ready-tape prompt state.
 *
 * Input: v0.28 post-ENTER checkpoint at IDPB boundary.
 * Output: state after MTBOOT probes all RH20 slots, reports no ready tape,
 *         and returns to its monitor input wait.
 */
parse arg inputState outputState
if inputState="" | outputState="" then do
  say "usage: rexx MTBootFreezeNoReadyTape.rex after-enter.state no-ready.state"
  exit 2
end

reader=.KL10State~new
cpu=reader~load(inputState)
meta0=reader~metadata

call eq cpu~pc,oct("773446"),"input IDPB PC"
call eq cpu~instructionCount,273207,"input ICOUNT"
p=cpu~preview
call eq p["mnemonic"],"IDPB","input boundary"

/* The historical path itself asks for all documented RH20 slots. Attaching
 * them here is an explicit configuration transition, not an implicit load. */
do code=oct("540") to oct("574") by 4
  ignored=cpu~attachRh20(code)
end

steps=0
do forever
  ignored=cpu~step
  steps=steps+1
  if steps>1 & cpu~pc=oct("773466") then leave
  if steps>5000 then do
    say "FAIL prompt did not return"
    exit 1
  end
end

call eq steps,1261,"historical steps to returned prompt"
call eq cpu~instructionCount,274468,"returned-prompt ICOUNT"
call eq cpu~dte~rxHex,"","returned-prompt RX empty"
call eq cpu~dte~txHex,-
  "0D0A424F4F54205631312E3028333135290D0A0D0A4D54424F4F543E0D0D0A0D0A20203F424F4F543A204E6F20726561647920746170652D647269766520617661696C61626C650D0A0D0A4D54424F4F543E",-
  "guest console transcript"

p=cpu~preview
call eq p["mnemonic"],"SKIPN","returned wait instruction"
call eq p["effectiveAddress"],oct("765456"),"returned DTMTI wait"

/* Every RH20 was reset twice by MTBOOT and left Massbus-enabled. */
do code=oct("540") to oct("574") by 4
  rh=cpu~rh20(code)
  call eq rh~resetCount,2,"RH20 reset count" code
  rs=rh~state
  call eq rs["massbusEnabled"],1,"RH20 massbus enabled" code
end

meta=.directory~new
do key over meta0
  meta[key]=meta0[key]
end
meta["checkpoint"]="mtboot.no-ready-tape.prompt"
meta["parent_checkpoint"]="console.keyboard"
meta["parent_state_sha256"]=sha256File(inputState)
meta["transition"]="attach-RH20-slots-and-run"
meta["console_pump_reason"]="WAIT"
meta["console_steps"]=steps

writer=.KL10State~new
ignored=writer~save(cpu,outputState,meta)

/* The checkpoint is only named after a full byte-level reconstruction. */
verifyState=.KL10State~new
verify=verifyState~load(outputState)
call eq verify~pc,cpu~pc,"reload PC"
call eq verify~instructionCount,cpu~instructionCount,"reload ICOUNT"
call eq verify~dte~txHex,cpu~dte~txHex,"reload TX"
call eq verify~dte~rxHex,cpu~dte~rxHex,"reload RX"
do code=oct("540") to oct("574") by 4
  call eq verify~ioBus~hasDevice(code),1,"reload RH20 attachment" code
  call directoryEq verify~rh20(code)~state,cpu~rh20(code)~state,"reload RH20" code
end
vp=verify~preview
call eq vp["mnemonic"],"SKIPN","reload wait"

say "FROZEN" outputState
say " checkpoint=mtboot.no-ready-tape.prompt"
say " PC=" || .LROct~fromDecimal(verify~pc)~right "ICOUNT=" || verify~instructionCount
say " steps=" || steps
say " RH20=540,544,550,554,560,564,570,574"
say " next=" || .LROct~fromDecimal(vp["instruction"])~string vp["mnemonic"]
exit 0

directoryEq: procedure
  use arg actual,expected,label,code
  if actual~items \= expected~items then do
    say "FAIL" label code "item count"
    exit 1
  end
  do key over expected
    if \actual~hasIndex(key) | actual[key] \= expected[key] then do
      say "FAIL" label code key "expected="expected[key] "actual="actual[key]
      exit 1
    end
  end
  return

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
  t=changestr(",",t,"")
  n=0
  do i=1 to length(t)
    n=n*8+substr(t,i,1)
  end
  return n

eq: procedure
  use arg actual,expected,label,extra
  if actual \= expected then do
    say "FAIL" label extra "expected="expected "actual="actual
    exit 1
  end
  return

::requires "../KL10IPL.cls"
