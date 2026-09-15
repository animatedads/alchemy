numeric digits 30
parse arg inputState outputState
if inputState="" | outputState="" then do
  say "usage: rexx RunOneAndFreezeNXM.rex input.state output.state"
  exit 2
end
state=.KL10State~new
cpu=state~load(inputState)
before=cpu~instructionCount
ignored=cpu~step
meta=.directory~new
meta["checkpoint"]="resident.post-nxm"
meta["architectural_instructions"]=cpu~instructionCount-before
state~save(cpu,outputState,meta)
say "PC="||.LROct~fromDecimal(cpu~pc)~right "ICOUNT="||cpu~instructionCount
say cpu~apr
say "FROZEN" outputState
::requires "../KL10IPL.cls"
