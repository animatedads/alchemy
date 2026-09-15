/* KL10_STATE/1 must reject omissions and unauthenticated memory changes. */
numeric digits 30
base = "/tmp/kl10_state_fail_closed.state"
badSchema = "/tmp/kl10_state_missing_pag_field.state"
badMemory = "/tmp/kl10_state_bad_memory.state"

mem=.KL10Memory~new
ignored=mem~mapZeroPage(0,0)
mem~put(100,octToDec("123456654321"))
cpu=.KL10CPU~new~~loadImage(mem,100)
cpu~pag~ioReset
meta=.directory~new
meta["machine"]="KL10"
ignored=.KL10State~new~save(cpu,base,meta)

/* Remove exactly one mandatory PAG field. */
inp=.stream~new(base)~~open("READ")
out=.stream~new(badSchema)~~open("WRITE REPLACE")
do while inp~lines > 0
  line=inp~linein
  if left(line,4)="PAG " then
    line=changestr(" previousContextSection=0","",line)
  out~lineout(line)
end
inp~close; out~close
call assertEq mustReject(badSchema),1,"missing PAG field rejected"

/* Change one physical word but preserve the original MEMSHA256 record. */
inp=.stream~new(base)~~open("READ")
out=.stream~new(badMemory)~~open("WRITE REPLACE")
changed=0
do while inp~lines > 0
  line=inp~linein
  if \changed & left(line,9)="WORD 100 " then do
    parse var line tag address value
    line="WORD 100" (value+1)
    changed=1
  end
  out~lineout(line)
end
inp~close; out~close
call assertEq changed,1,"memory mutation located"
call assertEq mustReject(badMemory),1,"memory digest mismatch rejected"

/* v0.25 snapshots without the mandatory schema identity are intentionally
 * no longer authentic under the hardened contract. */
inp=.stream~new(base)~~open("READ")
oldish="/tmp/kl10_state_no_schema.state"
out=.stream~new(oldish)~~open("WRITE REPLACE")
do while inp~lines > 0
  line=inp~linein
  if left(line,7) \= "SCHEMA " then out~lineout(line)
end
inp~close; out~close
call assertEq mustReject(oldish),1,"state without schema identity rejected"

call sysFileDelete base
call sysFileDelete badSchema
call sysFileDelete badMemory
call sysFileDelete oldish
say "PASS test_state_fail_closed"
exit 0

mustReject: procedure
  use arg path
  signal on syntax name rejected
  ignored=.KL10State~new~load(path)
  signal off syntax
  return 0
rejected:
  signal off syntax
  return 1

octToDec: procedure
  use arg t
  numeric digits 30
  n=0
  do i=1 to t~length
    n=n*8+t~substr(i,1)
  end
  return n

assertEq: procedure
  use arg actual, expected, label
  if actual \= expected then do
    say "FAIL" label "expected=" expected "actual=" actual
    exit 1
  end
  return

::requires "../KL10IPL.cls"
