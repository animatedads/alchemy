storage=.IBM370JournaledStorage~new(65536,2048,"SESSION-RAM")
m=.IBM4361Machine~new(65536,storage)
m~powerOn
m~cpu~setGpr(1,10)
session=.IBM4361JournalSession~new(m)
base=session~controller~checkpoint("base","TEST")

cp=session~beginInstruction
m~cpu~setGpr(1,99)
m~cpu~noteInstruction
m~storage~storeHex(256,"DEADBEEF")
m~clock~setCpuTimer(123)
session~commitInstruction
call eq 99,m~cpu~gpr(1),"after cpu"
call eq "DEADBEEF",m~storage~fetchHex(256,4),"after memory"
call eq 123,m~clock~cpuTimer,"after clock"
future=session~controller~checkpoint("future","TEST")

session~restore(cp)
call eq 10,m~cpu~gpr(1),"rewind cpu"
call eq "00000000",m~storage~fetchHex(256,4),"rewind memory"
call eq 0,m~clock~cpuTimer,"rewind clock"

session~beginInstruction
m~cpu~setGpr(1,77)
m~cpu~noteInstruction
m~storage~storeHex(256,"CAFEBABE")
session~commitInstruction
patched=session~controller~checkpoint("patched","TEST")

session~restore(future)
call eq 99,m~cpu~gpr(1),"old future cpu"
call eq "DEADBEEF",m~storage~fetchHex(256,4),"old future memory"

session~restore(patched)
call eq 77,m~cpu~gpr(1),"patched cpu"
call eq "CAFEBABE",m~storage~fetchHex(256,4),"patched memory"

session~restore(base)
call eq 10,m~cpu~gpr(1),"base cpu"
call eq "00000000",m~storage~fetchHex(256,4),"base memory"
say "PASS test_journal_instruction_rewind"
exit 0

eq: procedure
  use arg expected,actual,label
  if expected \== actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
  return

::requires "IBM4361Journal.cls"
