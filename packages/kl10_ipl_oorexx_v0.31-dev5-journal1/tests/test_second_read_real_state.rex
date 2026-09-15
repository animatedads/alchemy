numeric digits 30
parse arg statePath
if statePath="" then do
  say "usage: rexx test_second_read_real_state.rex second-read.state"
  exit 2
end

cpu=.KL10State~new~load(statePath)
rh=cpu~rh20(oct("540"))
t=rh~unit(0)
m=cpu~memory
logout=cpu~pag~ebPtr
clp=oct("762000")

call eq cpu~pc,oct("774445"),"PC"
call eq cpu~instructionCount,852340,"ICOUNT"
call eq t~position,5136,"tape position"
call eq t~pendingRecord["kind"],"DATA","pending kind"
call eq t~pendingRecord["length"],2560,"pending length"

call eq m~physicalWord(0),t~pendingWord36(0),"physical word 0"
call eq m~physicalWord(oct("17")),t~pendingWord36(15),"physical word 17"
call eq m~physicalWord(oct("20")),t~pendingWord36(16),"physical word 20"
call eq m~physicalWord(oct("777")),t~pendingWord36(511),"physical word 777"

call eq m~physicalWord(clp),oct("400400000000"),"CCW 1"
call eq m~physicalWord(clp+1),oct("617400000020"),"CCW 2 LAST"
call eq m~physicalWord(logout+1)//(2**22),clp+2,"logout command pointer"
call eq m~physicalWord(logout+2)//(2**22),oct("777"),"logout final address"
call eq bitSet(rh~statusWord,oct("20")),0,"PCR FULL clear"
call eq bitSet(rh~statusWord,oct("10")),1,"CMD DONE"

say "PASS test_second_read_real_state"
say "  word0=" .LROct~fromDecimal(t~pendingWord36(0))~string
say "  word15=" .LROct~fromDecimal(t~pendingWord36(15))~string
say "  word16=" .LROct~fromDecimal(t~pendingWord36(16))~string
say "  word511=" .LROct~fromDecimal(t~pendingWord36(511))~string
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
  do i=1 to length(text); n=n*8+substr(text,i,1); end
  return n

::requires "../KL10IPL.cls"
