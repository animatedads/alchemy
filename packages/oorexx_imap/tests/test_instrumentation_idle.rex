numeric digits 30

identity=.InstrumentationCodec~identity("estate-test","imap","idle-server","node-a","","IMAP")
instrumentation=.ImapInstrumentationSource~new(identity)
auth=.ImapTestAuthenticationProvider~new~addUser("alice","secret","person:alice")
store=.ImapMemoryMailboxProvider~new
authority=.ImapTestAllowAllMailboxAuthority~new
session=.ImapServerSession~new(auth,store,authority,.true,1048576,"instrumented-idle")
input='A1 LOGIN "alice" "secret"'||'0d0a'x|| -
      'A2 CREATE "Archive"'||'0d0a'x|| -
      'A3 SELECT "Archive"'||'0d0a'x|| -
      'A4 IDLE'||'0d0a'x|| -
      'DONE'||'0d0a'x|| -
      'A5 LOGOUT'||'0d0a'x
transport=.FixtureInstrumentedIdleTransport~new(input,store,"Archive")
served=.ImapServerEndpoint~new(session,20,1048576,instrumentation,1,10)~serve(transport)
call assert served~ok,'instrumented IDLE endpoint serves flow'
call assert transport~written~pos('* 1 EXISTS')>0,'IDLE update reached client'

snapshot=instrumentation~snapshot("2026-10-09T20:00:00Z")
call equal sampleValue(snapshot,"imap.idle.started.total"),1,'IDLE start counted'
call equal sampleValue(snapshot,"imap.idle.stopped.total"),1,'IDLE stop counted'
call equal sampleValue(snapshot,"imap.idle.active"),0,'IDLE active gauge settled'
call equal sampleValue(snapshot,"imap.idle.updates.total"),1,'IDLE update batch counted'
call equal sampleValue(snapshot,"imap.idle.events.total"),1,'IDLE event count exact'
call equal sampleValue(snapshot,"imap.command.idle.accepted.total"),1,'IDLE command admission counted'
call equal sampleValue(snapshot,"imap.command.idle.ok.total"),1,'IDLE command completion counted'
call equal sampleValue(snapshot,"request.accepted.total"),5,'mesh accepted count includes IDLE as one command'
call equal sampleValue(snapshot,"request.completed.total"),5,'mesh completed count includes IDLE after DONE'
call equal sampleValue(snapshot,"request.inflight"),0,'mesh inflight settles after IDLE termination'
call equal sampleValue(snapshot,"imap.sessions.active"),0,'session gauge settles on logout'
call equal sampleValue(snapshot,"imap.sessions.selected"),0,'selected gauge settles on logout'
call equal sampleValue(snapshot,"imap.sessions.authenticated"),0,'authenticated gauge settles on logout'
call assert \snapshotContains(snapshot,"alice"),'principal not leaked'
call assert \snapshotContains(snapshot,"secret"),'credential not leaked'
call assert \snapshotContains(snapshot,"Archive"),'mailbox name not leaked'
call assert \snapshotContains(snapshot,"Subject: idle secret"),'message content not leaked'

say 'PASS test_instrumentation_idle'
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
  if \condition then do; say 'FAIL:' message; exit 1; end
  return

equal: procedure
  use strict arg actual,expected,message
  if actual\=expected then do; say 'FAIL:' message 'expected='expected 'actual='actual; exit 1; end
  return

::class FixtureInstrumentedIdleTransport public
::method init
  expose incoming written waitCount store mailbox
  use strict arg input,storeArg,mailboxArg
  incoming=input; written=""; waitCount=0; store=storeArg; mailbox=mailboxArg
::attribute written get
::method supportsReadiness
  return .true
::method readLine
  expose incoming
  numeric digits 30
  use strict arg maximumBytes
  p=incoming~pos('0d0a'x)
  if p=0 then return .nil
  if p-1>maximumBytes then raise syntax 88.900 array('fixture line too large')
  line=incoming~left(p-1)
  incoming=incoming~substr(p+2)
  return line
::method writeAll
  expose written
  use strict arg bytes
  written=written||bytes
  return .true
::method waitReadable
  expose waitCount store mailbox
  use strict arg timeoutSeconds
  waitCount+=1
  if waitCount=1 then do
    bytes="Subject: idle secret"||'0d0a'x||'0d0a'x||"private body"||'0d0a'x
    appended=store~appendMessage(mailbox,bytes,.nil,"","smtp-delivery")
    if \appended~ok then return -1
    return 0
  end
  return 1

::requires "ImapInstrumentationAdapter.cls"
::requires "ImapServer.cls"
