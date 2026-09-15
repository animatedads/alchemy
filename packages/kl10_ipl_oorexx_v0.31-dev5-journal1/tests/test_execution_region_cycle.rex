numeric digits 30
parse arg entryState expectedState
if entryState="" | expectedState="" then do
  say "usage: rexx test_execution_region_cycle.rex entry.state expected.state"
  exit 2
end

actual=.KL10State~new~load(entryState)
expected=.KL10State~new~load(expectedState)
runner=.KL10ExecutionRunner~new(actual)
r=runner~run(1,.false)

call eq r~accelerations,1,"one acceleration"
call eq r~architecturalInstructions,2542,"historical instruction delta"
call eq actual~pc,expected~pc,"PC"
call eq actual~flags,expected~flags,"FLAGS"
call eq actual~halted,expected~halted,"HALTED"
call eq actual~instructionCount,expected~instructionCount,"ICOUNT"
call eq actual~processorMode,expected~processorMode,"MODE"

do block=0 to 7
  do ac=0 to 15
    call eq actual~accumulatorInBlock(block,ac),expected~accumulatorInBlock(block,ac), -
        "AC block" block "ac" ac
  end
end

ap=actual~pag~state
ep=expected~pag~state
do key over ep
  call eq ap[key],ep[key],"PAG" key
end
aa=actual~apr~state
ea=expected~apr~state
do key over ea
  call eq aa[key],ea[key],"APR" key
end

/* Freeze computes the canonical full-memory digest for both machines. */
af=.KL10State~new~freeze(actual)
ef=.KL10State~new~freeze(expected)
call eq af~memoryDigest,ef~memoryDigest,"memory digest"

do code=oct("540") to oct("574") by 4
  if expected~ioBus~hasDevice(code) then do
    call eq actual~ioBus~hasDevice(code),1,"RH20 attachment" code
    ar=actual~rh20(code)~state
    er=expected~rh20(code)~state
    do key over er
      call eq ar[key],er[key],"RH20" code key
    end
    do unit over expected~rh20(code)~unitNumbers
      at=actual~rh20(code)~unit(unit)~state
      et=expected~rh20(code)~unit(unit)~state
      do key over et
        call eq at[key],et[key],"TAPE" code unit key
      end
    end
  end
end

say "PASS test_execution_region_cycle"
exit

eq: procedure
  use arg actual,expected,label
  if actual\=expected then do
    say "FAIL" label "expected="expected "actual="actual
    exit 1
  end
  return

oct: procedure
  use arg text
  text=changestr(",",text,"")
  n=0
  do i=1 to length(text); n=n*8+substr(text,i,1); end
  return n

::requires "../KL10Execution.cls"
