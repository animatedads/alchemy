numeric digits 30
message="Subject: endpoint"||'0d0a'x||'0d0a'x||"literal body"||'0d0a'x
input='A1 LOGIN "alice" "secret"'||'0d0a'x|| -
      'A2 CREATE "Archive"'||'0d0a'x|| -
      'A3 APPEND "Archive" {'||message~length||'}'||'0d0a'x|| -
      message||'0d0a'x|| -
      'A4 SELECT "Archive"'||'0d0a'x|| -
      'A5 UID FETCH 1 BODY.PEEK[]'||'0d0a'x|| -
      'A6 LOGOUT'||'0d0a'x
transport=.FixtureLiteralTransport~new(input)
auth=.ImapTestAuthenticationProvider~new~addUser("alice","secret","person:alice")
session=.ImapServerSession~new(auth,.ImapMemoryMailboxProvider~new,.ImapTestAllowAllMailboxAuthority~new,.true)
served=.ImapServerEndpoint~new(session,20)~serve(transport)
call assert served~ok,"endpoint serves literal flow"
wire=transport~written
call assert wire~pos("+ Ready for literal")>0,"synchronizing APPEND continuation emitted"
call assert wire~pos("APPENDUID")>0,"APPENDUID emitted through endpoint"
call assert wire~pos(message)>0,"FETCH literal bytes round-trip through endpoint"
call assert wire~pos("A6 OK LOGOUT completed")>0,"session cleanly logs out"
say "PASS test_server_literal_endpoint"
exit 0

assert: procedure
  use strict arg condition,message
  if \condition then do; say "FAIL:" message; exit 1; end
  return

::class FixtureLiteralTransport public
::method init
  expose incoming written
  use strict arg input
  incoming=input; written=""
::attribute written get
::method readLine
  expose incoming
  numeric digits 30
  use strict arg maximumBytes
  p=incoming~pos('0d0a'x)
  if p=0 then return .nil
  if p-1>maximumBytes then raise syntax 88.900 array("fixture line too large")
  line=incoming~left(p-1)
  incoming=incoming~substr(p+2)
  return line
::method readExact
  expose incoming
  numeric digits 30
  use strict arg byteCount
  if incoming~length<byteCount then return .nil
  bytes=incoming~left(byteCount)
  incoming=incoming~substr(byteCount+1)
  return bytes
::method writeAll
  expose written
  use strict arg bytes
  written=written||bytes
  return .true

::requires "ImapServer.cls"
