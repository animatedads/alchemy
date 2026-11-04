numeric digits 30

/* Multi-session selected-mailbox coherence. */
auth=.ImapTestAuthenticationProvider~new~addUser("alice","secret","person:alice")
store=.ImapMemoryMailboxProvider~new
authority=.ImapTestAllowAllMailboxAuthority~new
s1=.ImapServerSession~new(auth,store,authority,.true,1048576,"session-one")
s2=.ImapServerSession~new(auth,store,authority,.true,1048576,"session-two")

call ok s1~processLine('A1 LOGIN "alice" "secret"'),'A1','session one login'
call ok s2~processLine('B1 LOGIN "alice" "secret"'),'B1','session two login'
call ok s2~processLine('B2 CREATE "Archive"'),'B2','create archive'
call ok s1~processLine('A2 SELECT "Archive"'),'A2','session one selects archive'

/* IDLE is only advertised when the endpoint has an actual readiness primitive. */
call assert \containsCapability(s1~capabilityArray,"IDLE"),'direct session does not advertise IDLE before transport readiness'

message="Subject: other session"||'0d0a'x||'0d0a'x||"hello"||'0d0a'x
r=s2~processLineWithLiteral('B3 APPEND "Archive" {'||message~length||'}',message)
call ok r,'B3','external append succeeds'
changes=s1~pollSelectedChanges
call assert changes~ok,'selected-session append feed succeeds'
call assert linesContain(changes~value,'* 1 EXISTS'),'selected session receives EXISTS from other session'

call ok s2~processLine('B4 SELECT "Archive"'),'B4','session two selects archive'
r=s2~processLine('B5 UID STORE 1 +FLAGS.SILENT (\Seen)')
call ok r,'B5','external flag mutation succeeds'
changes=s1~pollSelectedChanges
call assert changes~ok,'selected-session flag feed succeeds'
call assert linesContain(changes~value,'FETCH (FLAGS (\Seen) UID 1)'),'selected session receives FLAGS update from other session'

r=s2~processLine('B6 UID STORE 1 +FLAGS.SILENT (\Deleted)')
call ok r,'B6','mark deleted succeeds'
changes=s1~pollSelectedChanges
call assert changes~ok,'deleted flag feed succeeds'
call assert linesContain(changes~value,'\Deleted'),'selected session receives deleted flag update'

r=s2~processLine('B7 UID EXPUNGE 1')
call ok r,'B7','exact expunge succeeds'
changes=s1~pollSelectedChanges
call assert changes~ok,'selected-session expunge feed succeeds'
call assert linesContain(changes~value,'* 1 EXPUNGE'),'selected session receives EXPUNGE from other session'

/* Endpoint IDLE: first wait interval injects an external mailbox change; second
 * readiness indication provides DONE.  The session remains SELECTED throughout. */
idleStore=.ImapMemoryMailboxProvider~new
ignore=idleStore~createMailbox("Archive")
idleSession=.ImapServerSession~new(auth,idleStore,authority,.true,1048576,"idle-session")
call ok idleSession~processLine('C1 LOGIN "alice" "secret"'),'C1','idle session login'
call ok idleSession~processLine('C2 SELECT "Archive"'),'C2','idle session select'
transport=.FixtureIdleTransport~new('C3 IDLE'||'0d0a'x||'DONE'||'0d0a'x,idleStore,"Archive")
served=.ImapServerEndpoint~new(idleSession,20,1048576,.nil,1,10)~serve(transport)
call assert served~ok,'endpoint IDLE flow succeeds'
wire=transport~written
call assert wire~pos('CAPABILITY')>0,'greeting includes capability response'
call assert wire~pos(' IDLE')>0,'endpoint-capable greeting advertises IDLE'
call assert wire~pos('+ idling')>0,'IDLE continuation emitted'
call assert wire~pos('* 1 EXISTS')>0,'IDLE emits unsolicited EXISTS'
call assert wire~pos('C3 OK IDLE terminated')>0,'DONE terminates IDLE with tagged OK'
call assert idleSession~state='SELECTED','IDLE does not change selected authentication state'
call assert \idleSession~idleActive,'IDLE active flag clears after DONE'

/* IDLE has its own mailbox-authority action; authentication/readiness alone is not permission. */
denyStore=.ImapMemoryMailboxProvider~new
ignore=denyStore~createMailbox("Archive")
denySession=.ImapServerSession~new(auth,denyStore,.DenyIdleAuthority~new,.true,1048576,"deny-idle")
call ok denySession~processLine('D1 LOGIN "alice" "secret"'),'D1','deny-idle login'
call ok denySession~processLine('D2 SELECT "Archive"'),'D2','deny-idle select'
ignore=denySession~setIdleTransportCapable(.true)
parsed=.ImapServerParser~parseLine('D3 IDLE')
denied=denySession~processIdleStart(parsed)
call assert denied~wire~pos('D3 NO [NOPERM] IDLE denied')>0,'IDLE requires independent mailbox authority'
call assert \denySession~idleActive,'denied IDLE never enters IDLE mode'

say 'PASS test_server_idle'
exit 0

containsCapability: procedure
  use strict arg caps,wanted
  do c over caps
    if c~string~upper=wanted~string~upper then return .true
  end
  return .false

linesContain: procedure
  use strict arg lines,wanted
  do line over lines
    if line~string~pos(wanted)>0 then return .true
  end
  return .false

ok: procedure
  use strict arg response,tag,label
  call assert response~wire~pos(tag||' OK')>0,label
  return

assert: procedure
  use strict arg condition,message
  if \condition then do; say 'FAIL:' message; exit 1; end
  return

::class DenyIdleAuthority subclass ImapMailboxAuthority public
::method authorize
  use strict arg identity,action,mailbox="",context=.nil
  if identity==.nil then return .ImapServerResult~failure("IMAP_AUTHENTICATION_REQUIRED")
  if action~string~upper="IMAP_IDLE" then return .ImapServerResult~failure("TEST_IDLE_DENIED")
  return .ImapServerResult~success(.true,"TEST_ALLOW_NON_IDLE")

::class FixtureIdleTransport public
::method init
  expose incoming written waitCount store mailbox
  use strict arg input,storeArg,mailboxArg
  incoming=input
  written=""
  waitCount=0
  store=storeArg
  mailbox=mailboxArg
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
    bytes="Subject: during idle"||'0d0a'x||'0d0a'x||"wake"||'0d0a'x
    appended=store~appendMessage(mailbox,bytes,.nil,"","external-delivery")
    if \appended~ok then return -1
    return 0
  end
  return 1

::requires "ImapServer.cls"
