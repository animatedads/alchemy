numeric digits 30

/* Synthetic exact-loop equivalence: ordinary CPU stepping vs runner collapse. */
slowMem=.KL10Memory~new
fastMem=.KL10Memory~new

do page=0 to oct("777")
  slowMem~mapZeroPage(page,page)
  fastMem~mapZeroPage(page,page)
end

/* Exact MTBOOT clear loop and fallthrough JRST-to-self sentinel. */
slowMem~put(oct("774670"),oct("402001000000"))
slowMem~put(oct("774671"),oct("305053000000"))
slowMem~put(oct("774672"),oct("344040774670"))
slowMem~put(oct("774673"),oct("254000774673"))
fastMem~put(oct("774670"),oct("402001000000"))
fastMem~put(oct("774671"),oct("305053000000"))
fastMem~put(oct("774672"),oct("344040774670"))
fastMem~put(oct("774673"),oct("254000774673"))

first=oct("1000")
last=oct("1017")
do a=first to last
  slowMem~put(a,oct("777777777777"))
  fastMem~put(a,oct("777777777777"))
end

slow=.KL10CPU~new~~loadImage(slowMem,oct("774670"))
fast=.KL10CPU~new~~loadImage(fastMem,oct("774670"))
slow~setAccumulator(1,first)
slow~setAccumulator(oct("13"),last)
fast~setAccumulator(1,first)
fast~setAccumulator(oct("13"),last)

n=last-first+1
do 3*n-1
  ignored=slow~step
end

runner=.KL10ExecutionRunner~new(fast)
r=runner~run(1)

call eq r~reason,"LIMIT","runner reason"
call eq r~accelerations,1,"one acceleration"
call eq r~architecturalInstructions,3*n-1,"architectural instruction count"
call eq fast~pc,slow~pc,"PC"
call eq fast~instructionCount,slow~instructionCount,"ICOUNT"
call eq fast~accumulator(1),slow~accumulator(1),"AC1"
call eq fast~accumulator(oct("13")),slow~accumulator(oct("13")),"AC13"
call eq fast~flags,slow~flags,"FLAGS"

do a=first to last
  call eq fast~memory~word(a),slow~memory~word(a),"word" a
end

say "PASS test_execution_clear_accelerator"
exit 0

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
