/* Run a frozen KL10 using only proven-equivalent accelerators.
 *
 * Usage:
 *   rexx KL10Run.rex input.state output.state [work-units]
 *
 * Stops on bounded refusal, media motion, or work-unit limit.  The resulting
 * complete machine state is always frozen when an output path is supplied.
 */
numeric digits 30
parse arg inputState outputState maxWorkUnits
if inputState="" | outputState="" then do
  say "usage: rexx KL10Run.rex input.state output.state [work-units]"
  exit 2
end
if maxWorkUnits="" then maxWorkUnits=100000

state=.KL10State~new
cpu=state~load(inputState)
runner=.KL10ExecutionRunner~new(cpu)
startCount=cpu~instructionCount
r=runner~run(maxWorkUnits,.true)

meta=.directory~new
meta["checkpoint"]="kl10.execution-run"
meta["parent_state"]=inputState
meta["run_reason"]=r~reason
meta["work_units"]=r~workUnits
meta["architectural_instructions"]=r~architecturalInstructions
meta["accelerations"]=r~accelerations
.KL10State~new~save(cpu,outputState,meta)

say "RUN" r~reason
say " work_units=" || r~workUnits
say " architectural_instructions=" || r~architecturalInstructions
say " accelerations=" || r~accelerations
say " PC=" || .LROct~fromDecimal(cpu~pc)~right "ICOUNT=" || cpu~instructionCount
if r~refused then say " refusal=" || r~conditionMessage
if r~mediaMotion then do
  say " media motion:"
  do key over r~mediaAfter
    before="-"
    if r~mediaBefore~hasIndex(key) then before=r~mediaBefore[key]
    say "  " key before "->" r~mediaAfter[key]
  end
end
say "FROZEN" outputState
exit 0

::requires "../KL10Execution.cls"
