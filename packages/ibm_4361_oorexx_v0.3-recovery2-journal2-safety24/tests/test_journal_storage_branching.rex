s=.IBM370JournaledStorage~new(65536,2048,"RAMTEST")
s~storeHex(100,"1122334455667788")
s~setStorageKeyRaw(0,2)
c=.StateOfNationController~new
c~register("storage",s)
root=c~checkpoint("base","TEST")

s~beginJournalEvent("I1")
s~storeHex(102,"AAAABBBB")
s~setStorageKeyRaw(0,6)
p1=s~commitJournalEvent
cp1=c~checkpoint("after-I1","TEST")
call eq "1122AAAABBBB7788",s~fetchHex(100,8),"I1 bytes"
call eq 6,s~storageKeyRaw(0),"I1 key"

s~beginJournalEvent("I2")
s~storeHex(101,"CCCCCCCCCC")
p2=s~commitJournalEvent
future=s~journalPoint
call eq "11CCCCCCCCCC7788",s~fetchHex(100,8),"I2 bytes"

c~restore(cp1)
call eq "1122AAAABBBB7788",s~fetchHex(100,8),"rewind bytes"
call eq 6,s~storageKeyRaw(0),"rewind key"

s~beginJournalEvent("I2-patched")
s~storeHex(101,"DDDDDDDDDD")
s~commitJournalEvent
patched=s~journalPoint
call eq "11DDDDDDDDDD7788",s~fetchHex(100,8),"patched branch"

s~journalMoveTo(future)
call eq "11CCCCCCCCCC7788",s~fetchHex(100,8),"old future retained"
s~journalMoveTo(patched)
call eq "11DDDDDDDDDD7788",s~fetchHex(100,8),"patched future retained"

c~restore(root)
call eq "1122334455667788",s~fetchHex(100,8),"root bytes"
call eq 2,s~storageKeyRaw(0),"root key"
say "PASS test_journal_storage_branching"
exit 0

eq: procedure
  use arg expected,actual,label
  if expected \== actual then raise syntax 88.900 array("ASSERT_EQ",label,"expected",expected,"actual",actual)
  return

::requires "IBM4361Journal.cls"
