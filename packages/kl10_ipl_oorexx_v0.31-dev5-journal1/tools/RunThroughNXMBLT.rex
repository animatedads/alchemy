numeric digits 30
parse arg statePath outputState
cpu=.KL10State~new~load(statePath)
start=cpu~instructionCount
do i=1 to 4
  w=cpu~fetch; d=cpu~decode(w)
  say i "PC="||.LROct~fromDecimal(cpu~pc)~right d["mnemonic"] -
      "AC1="||.LROct~fromDecimal(cpu~accumulator(1))~string -
      "AC2="||.LROct~fromDecimal(cpu~accumulator(2))~string
  ignored=cpu~step
end
say "END PC="||.LROct~fromDecimal(cpu~pc)~right "ICOUNT="||cpu~instructionCount
say cpu~apr
m=.directory~new
m["checkpoint"]="resident.post-nxm-blt"
m["architectural_instructions"]=cpu~instructionCount-start
.KL10State~new~save(cpu,outputState,m)
say "FROZEN" outputState
::requires "../KL10IPL.cls"
