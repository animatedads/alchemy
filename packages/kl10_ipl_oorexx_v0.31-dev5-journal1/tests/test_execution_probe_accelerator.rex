numeric digits 30
parse arg statePath
if statePath="" then do
  say "usage: rexx test_execution_probe_accelerator.rex first-read.state"
  exit 2
end

/* Build the exact second steady probe-cycle entry twice. */
slow=.KL10State~new~load(statePath)
fast=.KL10State~new~load(statePath)
call reachSecondEntry slow
call reachSecondEntry fast

slowPagBefore=slow~pag~tlbFlushCount
fastPagBefore=fast~pag~tlbFlushCount
slowCount=slow~instructionCount
fastCount=fast~instructionCount

do 32
  ignored=slow~step
end

runner=.KL10ExecutionRunner~new(fast)
delta=runner~tryMtbootMemoryProbeCycle
call eq delta,32,"accelerated instruction count"
call eq fast~pc,slow~pc,"PC"
call eq fast~instructionCount,slow~instructionCount,"ICOUNT"
call eq fast~instructionCount-fastCount,32,"fast delta"
call eq slow~instructionCount-slowCount,32,"slow delta"
call eq fast~flags,slow~flags,"FLAGS"
call eq fast~pag~tlbFlushCount,slow~pag~tlbFlushCount,"PAG generation"
call eq fast~pag~tlbFlushCount-fastPagBefore,2,"two fast CLRPTs"
call eq slow~pag~tlbFlushCount-slowPagBefore,2,"two slow CLRPTs"

do a=0 to 15
  call eq fast~accumulator(a),slow~accumulator(a),"AC" a
end

do addr over .array~of(oct("766741"),oct("772245"),oct("772274"),oct("772275"))
  call eq fast~memory~word(addr),slow~memory~word(addr),"memory" addr
end

say "PASS test_execution_probe_accelerator"
exit 0

reachSecondEntry: procedure
 use arg cpu
 seen=0
 do 300
   if cpu~pc=oct("774542") then do
     seen=seen+1
     if seen=2 then return
   end
   ignored=cpu~step
 end
 say "FAIL did not reach second probe entry"
 exit 1

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
