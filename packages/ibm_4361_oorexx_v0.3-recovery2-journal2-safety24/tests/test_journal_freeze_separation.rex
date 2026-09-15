normal=.IBM4361Machine~new(65536)
normal~powerOn
normal~cpu~setGpr(3,123456)
normal~cpu~noteInstruction
normal~storage~storeHex(1024,"0102030405060708")
normal~storage~setStorageKeyRaw(0,10)
normal~clock~setCpuTimer(-99)

js=.IBM370JournaledStorage~new(65536,2048,"FREEZE-RAM")
journalled=.IBM4361Machine~new(65536,js)
journalled~powerOn
session=.IBM4361JournalSession~new(journalled)
session~beginInstruction
journalled~cpu~setGpr(3,123456)
journalled~cpu~noteInstruction
journalled~storage~storeHex(1024,"0102030405060708")
journalled~storage~setStorageKeyRaw(0,10)
journalled~clock~setCpuTimer(-99)
session~commitInstruction

codec=.IBM4361State~new
a=codec~freeze(normal)~encoded
b=codec~freeze(journalled)~encoded
if a \== b then raise syntax 88.900 array("journal history altered durable freeze representation")
if b~caselessPos("JOURNAL")>0 then raise syntax 88.900 array("durable freeze leaked journal metadata")
if js~retainedJournalNodeCount<1 then raise syntax 88.900 array("test failed to create journal history")
say "PASS test_journal_freeze_separation"
exit 0

::requires "IBM4361Journal.cls"
::requires "IBM4361State.cls"
