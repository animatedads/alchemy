parse arg root
if root="" then do; say "usage: test_nosql_index.rex DBROOT"; exit 2; end
call SysMkDir root
idx=.ImapNoSQLIndex~new(root)
r1=.ImapIndexRecord~new("gmail:test","INBOX",13,1,323,"Security alert from Google","Google <no-reply@accounts.google.com>","2026-09-16T14:30:00","","<g1@example>")
r2=.ImapIndexRecord~new("gmail:test","INBOX",13,2,401,"Facebook notification","social@example.net","2026-09-16T14:31:00","","<g2@example>")
r3=.ImapIndexRecord~new("gmail:test","INBOX",13,3,800,"Customer invoice","billing@example.net","2026-09-16T14:32:00","","<g3@example>")
ignore=idx~indexMessage(r1)
ignore=idx~indexMessage(r2)
ignore=idx~indexMessage(r3,"The customer mentioned Facebook in the body and requested a refund")
built=idx~buildSearchIndexes
call assert built~items>=3, "NoSQL derived indexes built"
res=idx~searchFrom("no-reply@accounts.google.com",10,"gmail:test","INBOX")
call assert res~count=1, "From search returns one"
call assert res~hits[1]~uid=1, "From search returns Google message"
res=idx~searchText("Facebook",10,"gmail:test","INBOX")
call assert res~count=2, "metadata plus body full-text token search"
call assert containsUid(res~hits,2), "subject token indexed"
call assert containsUid(res~hits,3), "body token indexed"
res=idx~searchText("customer refund",10,"gmail:test","INBOX")
call assert res~count=1 & res~hits[1]~uid=3, "AND-term search"
/* Re-indexing replaces stale terms and stays query-correct even with a behind
 * NoSQL derived index: NoSQL reconciles its journal delta. */
r2b=.ImapIndexRecord~new("gmail:test","INBOX",13,2,401,"Ordinary notification","social@example.net","2026-09-16T14:31:00","","<g2@example>")
ignore=idx~indexMessage(r2b)
res=idx~searchText("Facebook",10,"gmail:test","INBOX")
call assert res~count=1 & res~hits[1]~uid=3, "re-index removes stale term"
ignore=idx~checkpointMailbox("gmail:test","INBOX",13,4,"88",.true,3,3,"2026-09-16T14:40:00")
cp=idx~mailboxCheckpoint("gmail:test","INBOX")
call assert cp<>.nil & cp["uidvalidity"]=13, "mailbox checkpoint stored"
call assert cp["last_seen_uid"]=3, "mailbox progress stored"
say "PASS test_nosql_index"
exit 0
containsUid: procedure
  use strict arg hits,wanted
  do h over hits; if h~uid=wanted then return .true; end
  return .false
assert: procedure
  use strict arg condition,message
  if \condition then do; say "FAIL:" message; exit 1; end
  return
::requires "ImapNoSQLIndex.cls"
