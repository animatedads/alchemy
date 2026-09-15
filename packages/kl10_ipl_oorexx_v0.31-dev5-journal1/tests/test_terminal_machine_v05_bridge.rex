numeric digits 30
parse arg statePath
if statePath="" then do
  say "usage: rexx test_terminal_machine_v05_bridge.rex mtboot-prompt.state"
  exit 2
end

cpu=.KL10State~new~load(statePath)
console=.KL10Console~new(cpu)
model=.KL10TerminalModelV05~new(console)
session=.TerminalSession~new("KL10-TEST",model)
watch=.TerminalWatchAlong~new
session~addWatcher(watch)

s=session~commit
call eq s~terminalType,"KL10-DTE20","terminal type"
call eq s~capabilities~has("CHARACTER_STREAM"),1,"stream capability"
call eq s~capabilities~has("KL10_DTE20"),1,"KL10 capability"
call contains s~visibleText,"MTBOOT>","historical prompt"
call eq watch~current~generation,s~generation,"watch snapshot"

token=s~metadata["stateToken"]
bad=model~press("ENTER","stale")
call eq bad~ok,0,"stale action rejected"
call eq bad~code,"STALE_ACTION_TOKEN","generic stale code"

good=model~press("ENTER",token)
call eq good~ok,1,"ENTER accepted"
after=good~value
call eq after~metadata["queuedInputBytes"],1,"one queued byte"

/* Terminal Machine trace records the action as terminal evidence without
 * acquiring the KL10 model internals. */
session~noteAction(.TerminalAction~new(s~generation,"KEY","ENTER","","operator-test"))
committed=session~commit
call eq session~trace~snapshotCount,2,"two committed snapshots"
call eq session~trace~events~items,3,"snapshot/action/snapshot"

say "PASS test_terminal_machine_v05_bridge"
exit 0

contains: procedure
 use arg haystack,needle,label
 if pos(needle,haystack)=0 then do
   say "FAIL" label "missing="needle
   exit 1
 end
 return

eq: procedure
 use arg actual,expected,label
 if actual\=expected then do
   say "FAIL" label "expected="expected "actual="actual
   exit 1
 end
 return

::requires "../KL10TerminalMachineV05.cls"
