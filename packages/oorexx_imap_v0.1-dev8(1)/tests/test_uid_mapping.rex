s=.ImapUidSet~parse("1:3,10,20:18")
call assert s~ordinalOf(1)=1,"ordinal first"
call assert s~ordinalOf(3)=3,"ordinal range end"
call assert s~ordinalOf(10)=4,"ordinal singleton"
call assert s~ordinalOf(19)=6,"ordinal descending range"
call assert s~uidAtOrdinal(1)=1,"uid at first"
call assert s~uidAtOrdinal(4)=10,"uid at singleton"
call assert s~uidAtOrdinal(7)=18,"uid at descending end"

r=.ImapCommandResult~new("A1","OK","[COPYUID 88 1:3,10 101:104] done")
c=.ImapTransferOps~parseCopyUid(r)
call assert c~hasCopyUid,"COPYUID detected"
call assert c~mappingCountMatches,"mapping count"
call assert c~destinationUidFor(1)=101,"map first"
call assert c~destinationUidFor(3)=103,"map range"
call assert c~destinationUidFor(10)=104,"map tail"
call assert c~destinationUidFor(99)=0,"unknown source uid"

say "PASS test_uid_mapping"
exit 0
assert: procedure
  use strict arg condition,message
  if \condition then do; say "FAIL:" message; exit 1; end
  return
::requires "ImapTransfer.cls"
