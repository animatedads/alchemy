numeric digits 30
parse arg statePath
if statePath="" then do
  say "usage: rexx test_nxm_historical_refusal.rex current_refusal.kl10state"
  exit 2
end

cpu=.KL10State~new~load(statePath)
m=cpu~memory

call eq cpu~pc,oct("071724"),"PC before"
call eq cpu~instructionCount,1242342,"ICOUNT before"
call eq cpu~accumulator(2),oct("000000645000"),"AC2"

tr=m~translate(oct("645000"),1,1)
call eq tr["physical"] % 512,oct("1235"),"physical page"
call eq m~physicalExists(tr["physical"]),0,"NXM physical page absent"

mappedBefore=m~backingMemory~mappedPages
aprBefore=cpu~apr~state
call eq aprBefore["irqFlags"],0,"APR flags before"
call eq aprBefore["irqEnable"],0,"APR enables before"

ignored=cpu~step

call eq cpu~pc,oct("071725"),"PC after"
call eq cpu~instructionCount,1242343,"ICOUNT after"
aprAfter=cpu~apr~state
call eq bitSet(aprAfter["irqFlags"],oct("002000")),1,"APR NXM flag"
call eq aprAfter["irqEnable"],0,"APR enables unchanged"
call eq m~backingMemory~mappedPages,mappedBefore,"no physical page allocated"
call eq m~physicalExists(tr["physical"]),0,"NXM page remains absent"

say "PASS test_nxm_historical_refusal"
say "  virtual=645000 physical_page=1235"
say "  write discarded; APR NXM=002000 latched; PC advanced"
exit

bitSet: procedure
  use arg value,mask
  return (value % mask) // 2

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
  do i=1 to length(text)
    n=n*8+substr(text,i,1)
  end
  return n

::requires "../KL10IPL.cls"
