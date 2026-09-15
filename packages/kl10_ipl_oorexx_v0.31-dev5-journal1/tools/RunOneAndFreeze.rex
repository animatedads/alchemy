numeric digits 30
parse arg inputState outputState
cpu=.KL10State~new~load(inputState)
r=.KL10ExecutionRunner~new(cpu)~run(1,.false)
m=.directory~new
m["checkpoint"]="one-work-unit"
m["architectural_instructions"]=r~architecturalInstructions
m["accelerations"]=r~accelerations
.KL10State~new~save(cpu,outputState,m)
say "RUN" r~reason "arch="r~architecturalInstructions "accel="r~accelerations
say "FROZEN" outputState
::requires "../KL10Execution.cls"
