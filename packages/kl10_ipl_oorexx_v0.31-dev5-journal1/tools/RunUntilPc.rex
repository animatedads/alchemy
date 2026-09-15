numeric digits 30
parse arg inputState outputState targetOct maxWork
if inputState="" | outputState="" | targetOct="" then do
  say "usage: rexx RunUntilPc.rex input.state output.state target-octal [max-work]"
  exit 2
end
if maxWork="" then maxWork=5000
target=oct(targetOct)
state=.KL10State~new
cpu=state~load(inputState)
runner=.KL10ExecutionRunner~new(cpu)
work=0
start=cpu~instructionCount
do while work<maxWork
  if cpu~pc=target then leave
  r=runner~run(1,.false)
  work=work+1
  if r~refused then do
    say "REFUSED" r~conditionMessage
    leave
  end
end
meta=.directory~new
meta["checkpoint"]="run-until-pc"
meta["target"]=targetOct
meta["work_units"]=work
meta["architectural_instructions"]=cpu~instructionCount-start
state~save(cpu,outputState,meta)
say "STOP PC=" || .LROct~fromDecimal(cpu~pc)~right,
    "ICOUNT=" || cpu~instructionCount,
    "work=" || work,
    "arch=" || (cpu~instructionCount-start)
say "FROZEN" outputState
exit
oct: procedure
  use arg text
  text=changestr(",",text,"")
  n=0
  do i=1 to length(text); n=n*8+substr(text,i,1); end
  return n
::requires "../KL10Execution.cls"
