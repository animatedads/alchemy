s=.JournalPointedState~new
call assertTrue s~journalId~length>5,"default journal id"
p=s~put("x",1)
call assertTrue p~string~pos("@N1")>0,"point string"
say "PASS test_default_identity"
exit 0
::routine assertTrue
  use strict arg actual,label
  if \actual then raise syntax 88.900 array("ASSERT_TRUE",label)
::requires "src/JournalPointedState.cls"
