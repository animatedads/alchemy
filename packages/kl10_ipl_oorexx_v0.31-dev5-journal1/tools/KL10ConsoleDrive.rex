/* Drive one host keyboard action into a frozen KL10 state and optionally
 * advance the real bounded CPU.  The output state is written even when the
 * post-key execution reaches an explicit CPU boundary, because that stopped
 * state is valuable evidence.
 *
 * Usage:
 *   rexx KL10ConsoleDrive.rex in.state out.state KEY ENTER [200] [WAIT]
 *   rexx KL10ConsoleDrive.rex in.state out.state TYPE "N" [4] [STEPS]
 *   rexx KL10ConsoleDrive.rex in.state out.state LINE "HELP" [2000] [WAIT]
 *   rexx KL10ConsoleDrive.rex in.state out.state CTRL C [20] [OUTPUT]
 *   rexx KL10ConsoleDrive.rex in.state out.state CODE 13 [20] [OUTPUT]
 */
numeric digits 30
parse arg inputState outputState action value maxSteps stopMode
if inputState = "" | outputState = "" | action = "" then do
  say "usage: rexx KL10ConsoleDrive.rex in.state out.state KEY|TYPE|LINE|CTRL|CODE value [steps] [WAIT|STEPS|OUTPUT|INPUT_DELIVERED]"
  exit 2
end
if maxSteps = "" then maxSteps = 200
if stopMode = "" then stopMode = "WAIT"
if \datatype(maxSteps,"W") | maxSteps < 0 then do; say "steps must be non-negative"; exit 2; end

action = action~upper
reader=.KL10State~new
cpu=reader~load(inputState)
metaIn=reader~metadata
console=.KL10Console~new(cpu)
before=console~snapshot
token=before~stateToken

select
  when action = "KEY" then keyResult=console~keyboard~press(value,token)
  when action = "TYPE" then keyResult=console~keyboard~type(value,token)
  when action = "LINE" then keyResult=console~keyboard~typeLine(value,token)
  when action = "CTRL" then keyResult=console~keyboard~control(value,token)
  when action = "CODE" then keyResult=console~keyboard~sendCode(value,token)
  otherwise do; say "unknown action:" action; exit 2; end
end

if \keyResult~ok then do
  say "KEYBOARD REFUSED" keyResult~code keyResult~detail
  say "state_token=" || keyResult~stateToken
  exit 3
end

if maxSteps > 0 then pump=console~pump(maxSteps,stopMode)
else pump=.KL10ConsolePumpResult~new(.true,"NOT_RUN",0,"","","","",console~stateToken,console~snapshot)
after=pump~snapshot

meta=.directory~new
do key over metaIn; meta[key]=metaIn[key]; end
if meta~hasIndex("checkpoint") then meta["parent_checkpoint"]=meta["checkpoint"]
meta["checkpoint"]="console.keyboard"
meta["transition"]="console-" || action~lower
meta["parent_state_sha256"]=sha256File(inputState)
meta["console_pump_reason"]=pump~reason
meta["console_steps"]=pump~steps

writer=.KL10State~new
ignored=writer~save(cpu,outputState,meta)

say "SAVED" outputState
say " action=" || action "value=" || value
say " pump=" || pump~reason "steps=" || pump~steps "ok=" || pump~ok
say " state_token=" || after~stateToken
say " PC=" || .LROct~fromDecimal(after~pc)~right "ICOUNT=" || after~instructionCount
say " new_output_hex=" || pump~outputDeltaHex
if pump~outputDeltaText \= "" then do
  say "--- new console output ---"
  say pump~outputDeltaText
  say "--------------------------"
end
if \pump~ok then do
  say " execution_condition=" || pump~conditionCode pump~conditionMessage
  exit 4
end
exit 0

sha256File: procedure
 use arg path
 out=path||".console-parent.sha256.tmp"
 address system 'sha256sum "'||path||'" > "'||out||'"'
 if rc \= 0 then do; say "sha256sum failed"; exit 1; end
 st=.stream~new(out)~~open("READ")
 line=st~linein
 st~close
 call sysFileDelete out
 parse var line h .
 return h

::requires "../KL10Console.cls"
