numeric digits 30
parse arg inputState outputState maxWorkUnits
if inputState="" | outputState="" then do
 say "usage: rexx KL10RunContinuous.rex input.state output.state [work-units]"
 exit 2
end
if maxWorkUnits="" then maxWorkUnits=5000
state=.KL10State~new
cpu=state~load(inputState)
runner=.KL10ExecutionRunner~new(cpu)
start=cpu~instructionCount
before=.directory~new
do code=oct("540") to oct("574") by 4
 if cpu~ioBus~hasDevice(code) then do
   rh=cpu~rh20(code)
   do unit over rh~unitNumbers
     before[code||":"||unit]=rh~unit(unit)~position
   end
 end
end
r=runner~run(maxWorkUnits,.false)
meta=.directory~new
meta["checkpoint"]="kl10.continuous-run"
meta["run_reason"]=r~reason
meta["work_units"]=r~workUnits
meta["architectural_instructions"]=r~architecturalInstructions
meta["accelerations"]=r~accelerations
state~save(cpu,outputState,meta)
say "RUN" r~reason
say " work_units="r~workUnits
say " architectural_instructions="r~architecturalInstructions
say " accelerations="r~accelerations
say " PC="||.LROct~fromDecimal(cpu~pc)~right "ICOUNT="||cpu~instructionCount
if r~refused then say " refusal="||r~conditionMessage
do code=oct("540") to oct("574") by 4
 if cpu~ioBus~hasDevice(code) then do
   rh=cpu~rh20(code)
   do unit over rh~unitNumbers
     key=code||":"||unit
     old="-"; if before~hasIndex(key) then old=before[key]
     say " media" key old "->" rh~unit(unit)~position
   end
 end
end
say "FROZEN" outputState
exit
oct: procedure
 use arg text
 text=changestr(",",text,"")
 n=0
 do i=1 to length(text); n=n*8+substr(text,i,1); end
 return n
::requires "../KL10Execution.cls"
