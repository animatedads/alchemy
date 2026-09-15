iplPsw="0008000000001000"
ccw1="0200020040000020"
ccw2="0200022000000010"
r1=iplPsw||ccw1||ccw2
r2=copies("AA",32)
r3=copies("BB",16)
records=.array~of(r1,r2,r3)

ram=.IBM370JournaledStorage~new(1048576,2048,"IPL-JOURNAL-RAM")
m=.IBM4361Machine~new(1048576,ram)
m~powerOn
d=.IBM370IPLMemoryDevice~new(x2d("148"),records,"JOURNAL-IPL","fixture")
m~attachDevice(d)
s=.IBM4361JournalSession~new(m)

s~beginInstruction
m~beginInitialProgramLoad(x2d("148"))
s~commitInstruction
beforeStep=s~controller~checkpoint("before-ccw1","TEST")
call eq 8,m~channels~activeProgram(x2d("148"))~currentCCWAddress,"initial CCW address"
call eq 1,d~recordIndex,"record after implied Read IPL"

s~beginInstruction
m~stepInitialProgramLoad
s~commitInstruction
future=s~controller~checkpoint("after-ccw1","TEST")
call eq 16,m~channels~activeProgram(x2d("148"))~currentCCWAddress,"after CCW1 address"
call eq 2,d~recordIndex,"after CCW1 media position"
call eq r2,m~storage~fetchHex(512,32),"after CCW1 data"

s~restore(beforeStep)
call eq 8,m~channels~activeProgram(x2d("148"))~currentCCWAddress,"rewound CCW address"
call eq 1,d~recordIndex,"rewound media position"
call eq copies("00",32),m~storage~fetchHex(512,32),"rewound data"

s~beginInstruction
m~stepInitialProgramLoad
s~commitInstruction
retry=s~controller~checkpoint("retry-ccw1","TEST")
call eq 16,m~channels~activeProgram(x2d("148"))~currentCCWAddress,"retry CCW address"
call eq 2,d~recordIndex,"retry media position"
call eq r2,m~storage~fetchHex(512,32),"retry data"

s~restore(future)
call eq 16,m~channels~activeProgram(x2d("148"))~currentCCWAddress,"old future retained"
call eq 2,d~recordIndex,"old future device retained"
s~restore(retry)
call eq r2,m~storage~fetchHex(512,32),"retry branch retained"
say "PASS test_journal_ipl_rewind"
exit 0

eq: procedure
  parse arg expected,actual,label
  if expected \== actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
  return

::requires "IBM4361Journal.cls"
::requires "IBM370IO.cls"
