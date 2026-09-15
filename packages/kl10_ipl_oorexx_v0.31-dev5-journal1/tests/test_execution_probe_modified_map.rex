numeric digits 30
parse arg statePath
if statePath="" then do
 say "usage: rexx test_execution_probe_modified_map.rex probe-762000.state"
 exit 2
end
slow=.KL10State~new~load(statePath)
fast=.KL10State~new~load(statePath)
call eq slow~pc,oct("774542"),"slow PC"
call eq fast~pc,oct("774542"),"fast PC"
call eq slow~accumulator(oct("13"))//(2**18),oct("762000"),"slow candidate"
call eq fast~accumulator(oct("13"))//(2**18),oct("762000"),"fast candidate"
map=fast~memory~mapWord(oct("762000"))["word"]
call eq .LROct~fromDecimal(map)~string,"160000,,762000","modified MAP fixture"

do 32
 ignored=slow~step
end
r=.KL10ExecutionRunner~new(fast)
call eq r~tryMtbootMemoryProbeCycle,32,"modified-map cycle accelerated"
call eq fast~pc,slow~pc,"PC"
call eq fast~instructionCount,slow~instructionCount,"ICOUNT"
call eq fast~pag~tlbFlushCount,slow~pag~tlbFlushCount,"PAG generation"
do a=0 to 15
 call eq fast~accumulator(a),slow~accumulator(a),"AC" a
end
do addr over .array~of(oct("766741"),oct("772245"),oct("772274"),oct("772275"))
 call eq fast~memory~word(addr),slow~memory~word(addr),"memory" addr
end
say "PASS test_execution_probe_modified_map"
exit 0

eq: procedure
 use arg actual,expected,label
 if actual\=expected then do; say "FAIL" label "expected="expected "actual="actual; exit 1; end
 return
oct: procedure
 use arg text; text=changestr(",",text,""); n=0; do i=1 to length(text); n=n*8+substr(text,i,1); end; return n
::requires "../KL10Execution.cls"
