numeric digits 30
parse arg statePath tapePath
if statePath="" | tapePath="" then do
  say "usage: rexx test_rh20_multiccw_read.rex first-read.state tape.tap"
  exit 2
end

cpu=.KL10State~new~load(statePath)
rh=cpu~rh20(oct("540"))
t=rh~unit(0)

/* Rebind to the caller-supplied authenticated reel so this test is portable. */
ignored=t~operatorUnload
t=.KL10MassbusTape~new~~mount(tapePath)
/* Fetch record one and then record two through the real TM03 READ FORWARD path. */
ignored=t~writeRegister(0,oct("71"))
ignored=t~writeRegister(0,oct("71"))
rh2=.KL10Rh20~new(oct("540"))
/* Replace the existing RH20 attachment is not supported; use the bus-attached
 * RH20 but attach a fresh unit is likewise prohibited.  Therefore restore the
 * existing unit's second-record state through its state contract. */
ts=t~state
existing=rh~unit(0)
existing~restoreState(ts,tapePath)
t=existing

call eq t~position,5136,"second record tape position"
call eq t~pendingRecord["kind"],"DATA","second record kind"
call eq t~pendingRecord["length"],2560,"second record bytes"

m=cpu~memory
ept=cpu~pag~ebPtr
logout=ept
clp=oct("762000")
m~physicalPut(logout,ccw(2,0,clp))
m~physicalPut(clp,ccw(4,16,0))
m~physicalPut(clp+1,ccw(6,496,oct("20")))

ac0Before=cpu~accumulator(0)
t0=t~pendingWord36(0)
t15=t~pendingWord36(15)
t16=t~pendingWord36(16)
t511=t~pendingWord36(511)

/* DATAO internal STCR (RS 071, LR set), drive 0, function 071 READ FORWARD.
 * The pending record is already materialized above, so calling STCR would read
 * a third record.  Instead rewind the reader position to before the second
 * read, then allow the actual STCR command to acquire record two. */
ignored=t~operatorRewind
ignored=t~writeRegister(0,oct("71"))       /* consume first record */
call eq t~position,2568,"before STCR second read"

/* 714000,,000071 = RS 071 + LR + TM03 READ FORWARD function 071. */
value=oct("714000000071")
ignored=rh~datao(value,cpu~ioBus)

call eq t~position,5136,"STCR moved second record"
call eq m~physicalWord(0),t0,"segment1 word0"
call eq m~physicalWord(oct("17")),t15,"segment1 word15"
call eq m~physicalWord(oct("20")),t16,"segment2 word16"
call eq m~physicalWord(oct("777")),t511,"segment2 word511"
call eq cpu~accumulator(0),ac0Before,"physical DMA does not alter AC0"
call eq m~physicalWord(logout+1)//(2**22),clp+2,"logout command pointer"
call eq m~physicalWord(logout+2)//(2**22),oct("777"),"logout final address"
call eq bitSet(rh~statusWord,oct("20")),0,"PCR FULL clear"
call eq bitSet(rh~statusWord,oct("10")),1,"CMD DONE"

say "PASS test_rh20_multiccw_read"
say "  tape_position=" t~position
say "  segment1=000000..000017"
say "  segment2=000020..000777"
say "  word0=" .LROct~fromDecimal(t0)~string
say "  word511=" .LROct~fromDecimal(t511)~string
exit

ccw: procedure
  use arg op,wc,address
  return op*(2**33)+wc*(2**22)+address

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
