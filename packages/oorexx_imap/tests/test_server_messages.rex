numeric digits 30
auth=.ImapTestAuthenticationProvider~new~addUser("alice","secret","person:alice")
store=.ImapMemoryMailboxProvider~new
authority=.ImapTestAllowAllMailboxAuthority~new
session=.ImapServerSession~new(auth,store,authority,.true)
call ok session~processLine('A1 LOGIN "alice" "secret"'),'A1','login'
call ok session~processLine('A2 CREATE "Archive"'),'A2','create Archive'
call ok session~processLine('A3 CREATE "Dest"'),'A3','create Dest'

message="From: alice@example.test"||'0d0a'x||"Subject: dev11 message"||'0d0a'x||'0d0a'x||"hello"||'0d0a'x
appendLine='A4 APPEND "Archive" (\Flagged) {'||message~length||'}'
r=session~processLineWithLiteral(appendLine,message)
call assert r~wire~pos('APPENDUID')>0,'APPEND returns APPENDUID'
call assert r~wire~pos('A4 OK')>0,'APPEND succeeds'

r=session~processLine('A5 SELECT "Archive"')
call assert r~wire~pos('* 1 EXISTS')>0,'SELECT sees one message'
call assert r~wire~pos('[UIDNEXT 2]')>0,'UIDNEXT advanced'

r=session~processLine('A6 FETCH 1 (UID FLAGS RFC822.SIZE BODY.PEEK[])')
call assert r~wire~pos('UID 1')>0,'FETCH includes UID'
call assert r~wire~pos('\Flagged')>0,'FETCH includes flags'
call assert r~wire~pos('RFC822.SIZE '||message~length)>0,'FETCH includes size'
call assert r~wire~pos(message)>0,'FETCH BODY.PEEK returns exact bytes'

r=session~processLine('A7 SEARCH UNSEEN')
call assert r~wire~pos('* SEARCH 1')>0,'SEARCH UNSEEN finds sequence'
r=session~processLine('A8 UID SEARCH UNSEEN')
call assert r~wire~pos('* SEARCH 1')>0,'UID SEARCH returns UID'

r=session~processLine('A9 UID STORE 1 +FLAGS.SILENT (\Seen)')
call assert r~wire~pos('A9 OK')>0,'UID STORE silent succeeds'
r=session~processLine('A10 SEARCH UNSEEN')
call assert r~wire~pos('* SEARCH 1')=0,'stored Seen clears unseen search'

r=session~processLine('A11 UID COPY 1 "Dest"')
call assert r~wire~pos('COPYUID')>0,'UID COPY returns COPYUID'

r=session~processLine('A12 UID STORE 1 +FLAGS.SILENT (\Deleted)')
call ok r,'A12','mark deleted'
r=session~processLine('A13 UID EXPUNGE 1')
call assert r~wire~pos('* 1 EXPUNGE')>0,'UID EXPUNGE exact UID emits expunge'
r=session~processLine('A14 SEARCH ALL')
call assert r~wire~pos('* SEARCH 1')=0,'source empty after exact expunge'

call ok session~processLine('A15 CLOSE'),'A15','close source'
r=session~processLine('A16 SELECT "Dest"')
call assert r~wire~pos('* 1 EXISTS')>0,'copy destination contains message'
r=session~processLine('A17 UID FETCH 1 BODY.PEEK[]')
call assert r~wire~pos(message)>0,'copied bytes exact'
call ok session~processLine('A18 CLOSE'),'A18','close destination'

call ok session~processLine('A19 CREATE "MoveSrc"'),'A19','create move source'
moveMessage="Subject: move"||'0d0a'x||'0d0a'x||"move me"||'0d0a'x
line='A20 APPEND "MoveSrc" {'||moveMessage~length||'}'
call ok session~processLineWithLiteral(line,moveMessage),'A20','append move source'
call ok session~processLine('A21 SELECT "MoveSrc"'),'A21','select move source'
r=session~processLine('A22 UID MOVE 1 "Dest"')
call assert r~wire~pos('COPYUID')>0,'MOVE returns UID mapping'
call assert r~wire~pos('EXPUNGE')>0,'MOVE removes source message'
r=session~processLine('A23 SEARCH ALL')
call assert r~wire~pos('* SEARCH 1')=0,'MOVE source empty'

r=session~processLineWithLiteral('A24 APPEND "INBOX" {1}',"x")
call assert r~wire~pos('NOPERM')>0,'client cannot manufacture verified inbox membership'
r=session~processLineWithLiteral('A25 APPEND "INBOX-UNSIGNED" {1}',"x")
call assert r~wire~pos('NOPERM')>0,'client cannot manufacture unsigned classification membership'

say 'PASS test_server_messages'
exit 0

ok: procedure
  use strict arg response,tag,label
  call assert response~wire~pos(tag||' OK')>0,label
  return
assert: procedure
  use strict arg condition,message
  if \condition then do; say 'FAIL:' message; exit 1; end
  return
::requires "ImapServer.cls"
