numeric digits 30
parse arg tapePath
if tapePath="" then do
  say "usage: rexx test_tape_operator_panel.rex tape.tap"
  exit 2
end

tape=.KL10MassbusTape~new~~mount(tapePath)
collector=.OperatorCollector~new
panel=.KL10TapeOperatorPanel~new(tape,collector)

s0=panel~snapshot
call eq s0~mounted,1,"mounted"
call eq s0~online,1,"online"
call eq s0~ready,1,"ready"
call eq s0~bot,1,"BOT"
call eq s0~lamps["ONLINE"],1,"online lamp"
call eq s0~lamps["BOT"],1,"BOT lamp"
call eq s0~buttons["OFFLINE"],1,"offline button enabled"

/* Stale token is refused but is still instrumented. */
r=panel~press("OFFLINE","stale","operator-A","evt-1")
call eq r~ok,0,"stale rejected"
call eq r~code,"STALE_ACTION_TOKEN","stale code"
call eq collector~events~items,1,"stale event emitted"

/* Real OFFLINE action. */
r=panel~press("OFFLINE",s0~stateToken,"operator-A","evt-2")
call eq r~ok,1,"offline accepted"
call eq r~snapshot~online,0,"offline state"
call eq r~snapshot~lamps["ONLINE"],0,"offline lamp"
call eq r~event~actor,"operator-A","event actor"
call eq r~event~correlationId,"evt-2","event correlation"
call eq r~event~button,"OFFLINE","event button"
call eq r~event~beforeToken,s0~stateToken,"event before token"
call ne r~event~afterToken,s0~stateToken,"event after token"

/* Old token is now stale. */
r2=panel~press("ONLINE",s0~stateToken,"operator-B","evt-3")
call eq r2~code,"STALE_ACTION_TOKEN","old token stale"

/* Bring transport back online using the fresh token. */
s1=panel~snapshot
r3=panel~press("ONLINE",s1~stateToken,"operator-B","evt-4")
call eq r3~ok,1,"online accepted"
call eq r3~snapshot~ready,1,"ready restored"

/* Rewind is an observable operator action. */
s2=panel~snapshot
r4=panel~press("REWIND",s2~stateToken,"operator-B","evt-5")
call eq r4~ok,1,"rewind accepted"
call eq r4~snapshot~bot,1,"rewound BOT"

/* Unload removes reel and therefore READY. */
s3=panel~snapshot
r5=panel~press("UNLOAD",s3~stateToken,"operator-C","evt-6")
call eq r5~ok,1,"unload accepted"
call eq r5~snapshot~mounted,0,"unloaded"
call eq r5~snapshot~ready,0,"not ready"
call eq r5~snapshot~lamps["READY"],0,"ready lamp off"

call eq collector~events~items,6,"all actions instrumented"
say "PASS test_tape_operator_panel"
exit 0

eq: procedure
  use arg actual,expected,label
  if actual \= expected then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end
  return

ne: procedure
  use arg actual,unexpected,label
  if actual = unexpected then do
    say "FAIL" label "unexpected="unexpected
    exit 1
  end
  return


::class OperatorCollector
::attribute events get
::method init
  expose events
  events=.array~new
::method emit
  expose events
  use strict arg event
  events~append(event)
  return .true

::requires "../KL10TapeOperator.cls"
