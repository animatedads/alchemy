numeric digits 30
message="Subject: telemetry"||'0d0a'x||'0d0a'x||"body"||'0d0a'x
input='A0 LOGIN "alice" "wrong"'||'0d0a'x|| -
      'A1 LOGIN "alice" "secret"'||'0d0a'x|| -
      'A2 CREATE "Archive"'||'0d0a'x|| -
      'A3 APPEND "Archive" {'||message~length||'}'||'0d0a'x|| -
      message||'0d0a'x|| -
      'A4 SELECT "Archive"'||'0d0a'x|| -
      'A5 UID FETCH 1 BODY.PEEK[]'||'0d0a'x|| -
      'A6 LOGOUT'||'0d0a'x

identity=.InstrumentationCodec~identity("estate-test","imap","server-1","node-a","","IMAP")
instrumentation=.ImapInstrumentationSource~new(identity)
transport=.FixtureInstrumentationTransport~new(input)
auth=.ImapTestAuthenticationProvider~new~addUser("alice","secret","person:alice")
session=.ImapServerSession~new(auth,.ImapMemoryMailboxProvider~new,.ImapTestAllowAllMailboxAuthority~new,.true)
served=.ImapServerEndpoint~new(session,20,1048576,instrumentation)~serve(transport)
call assert served~ok,"instrumented endpoint serves flow"

snapshot=instrumentation~snapshot("2026-10-08T10:00:00Z")
call equal sampleValue(snapshot,"imap.sessions.accepted.total"),1,"accepted session counted"
call equal sampleValue(snapshot,"imap.sessions.closed.total"),1,"closed session counted"
call equal sampleValue(snapshot,"imap.sessions.active"),0,"active session gauge settled"
call equal sampleValue(snapshot,"imap.sessions.selected"),0,"selected gauge settled"
call equal sampleValue(snapshot,"imap.sessions.authenticated"),0,"authenticated gauge settled"
call equal sampleValue(snapshot,"imap.authentication.attempts.total"),2,"authentication attempts counted"
call equal sampleValue(snapshot,"imap.authentication.succeeded.total"),1,"authentication success counted"
call equal sampleValue(snapshot,"imap.authentication.failed.total"),1,"authentication failure counted"
call equal sampleValue(snapshot,"imap.command.append.ok.total"),1,"APPEND success counted"
call equal sampleValue(snapshot,"imap.command.uid_fetch.ok.total"),1,"UID FETCH success counted"
call equal sampleValue(snapshot,"request.accepted.total"),7,"mesh request accepted counter"
call equal sampleValue(snapshot,"request.completed.total"),7,"mesh request completed counter"
call equal sampleValue(snapshot,"request.inflight"),0,"mesh inflight settled"
call assert sampleValue(snapshot,"io.bytes.in.total")>message~length,"wire input bytes counted"
call assert sampleValue(snapshot,"io.bytes.out.total")>0,"wire output bytes counted"
call equal sampleValue(snapshot,"imap.literal.bytes.in.total"),message~length,"literal byte count exact"
call assert snapshot["semantic_ref"]="instrumentation://estate-test/imap/server-1@node-a","semantic ref preserved"
call assert \snapshotContains(snapshot,"alice"),"principal not leaked"
call assert \snapshotContains(snapshot,"secret"),"credential not leaked"
call assert \snapshotContains(snapshot,"wrong"),"failed credential not leaked"
call assert \snapshotContains(snapshot,"Archive"),"mailbox name not leaked"
call assert \snapshotContains(snapshot,"Subject: telemetry"),"message content not leaked"

say "PASS test_instrumentation_adapter"
exit 0

sampleValue: procedure
  use strict arg snapshot,name
  do sample over snapshot["samples"]
    if sample["name"] = name then return sample["value"]
  end
  return -999999

snapshotContains: procedure
  use strict arg value,wanted
  if value == .nil then return .false
  if value~isA(.Directory) then do
    do k over value
      if k~string~pos(wanted)>0 then return .true
      if snapshotContains(value[k],wanted) then return .true
    end
    return .false
  end
  if value~isA(.Array) then do
    do item over value
      if snapshotContains(item,wanted) then return .true
    end
    return .false
  end
  return value~string~pos(wanted)>0

assert: procedure
  use strict arg condition,message
  if \condition then do; say "FAIL:" message; exit 1; end
  return

equal: procedure
  use strict arg actual,expected,message
  if actual\=expected then do; say "FAIL:" message "expected="expected "actual="actual; exit 1; end
  return

::class FixtureInstrumentationTransport public
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

::requires "ImapInstrumentationAdapter.cls"
::requires "ImapServer.cls"
