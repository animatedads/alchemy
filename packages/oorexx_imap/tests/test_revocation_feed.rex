numeric digits 30

/* A revocation occurring after SELECT must cut off unsolicited updates. */
auth = .ImapTestAuthenticationProvider~new~addUser("alice", "secret", "ldap:alice")
mail = .ImapMemoryMailboxProvider~new
ignore = mail~createMailbox("Archive")
authority = .RevocableMailboxAuthority~new
session = .ImapServerSession~new(auth, mail, authority, .true, 1048576, "revocation-session")
call expectOk session~processLine('A1 LOGIN "alice" "secret"'), "A1", "LOGIN"
call expectOk session~processLine('A2 SELECT "Archive"'), "A2", "SELECT"

/* Another session adds mail while the selected principal is revoked. */
bytes = "Subject: private" || '0d0a0d0a'x || "sensitive payload" || '0d0a'x
ignore = mail~appendMessage("Archive", bytes, .nil, "", "external-delivery")
call ensure ignore~ok, "external APPEND"
authority~revoke
poll = session~pollSelectedChanges
call ensure \poll~ok, "revoked session poll must fail"
call ensure poll~code = "IMAP_AUTHORIZATION_REVOKED", "exact revocation diagnostic"
response = session~processLine("A3 NOOP")
call ensure response~wire~pos("A3 NO") > 0, "revoked NOOP cannot consume updates"
call ensure response~wire~pos("* 1 EXISTS") = 0, "revoked NOOP must not leak EXISTS"

/* Actual endpoint IDLE continuation must not leak queued events after revoke. */
authority2 = .RevocableMailboxAuthority~new
mail2 = .ImapMemoryMailboxProvider~new
ignore = mail2~createMailbox("Archive")
session2 = .ImapServerSession~new(auth, mail2, authority2, .true, 1048576, "revocation-idle")
call expectOk session2~processLine('B1 LOGIN "alice" "secret"'), "B1", "LOGIN for IDLE"
call expectOk session2~processLine('B2 SELECT "Archive"'), "B2", "SELECT for IDLE"
transport = .RevokeDuringIdleTransport~new('B3 IDLE'||'0d0a'x, authority2, mail2)
result = .ImapServerEndpoint~new(session2, 20, 1048576, .nil, 1, 4)~serve(transport)
call ensure \result~ok, "revoked IDLE must terminate the endpoint"
call ensure transport~written~pos("+ idling") > 0, "entered IDLE before revocation"
call ensure transport~written~pos("* BYE [ALERT] selected mailbox access revoked") > 0, "revoked IDLE sends BYE"
call ensure transport~written~pos("* 1 EXISTS") = 0, "no unsolicited EXISTS after revocation"
call ensure transport~written~pos("sensitive payload") = 0, "no bytes exposed after revocation"
say "PASS test_revocation_feed"
exit 0

expectOk: procedure
  use strict arg response, tag, detail
  call ensure response~wire~pos(tag || " OK") > 0, detail
  return
ensure: procedure
  use strict arg value, detail
  if \value then do
    say "FAIL test_revocation_feed:" detail
    exit 1
  end
  return

::class RevocableMailboxAuthority subclass ImapMailboxAuthority public
::attribute allowed get
::method init
  expose allowed
  allowed = .true
::method revoke
  expose allowed
  allowed = .false
::method authorize
  expose allowed
  use strict arg identity, action, mailbox = "", context = .nil
  if \allowed then return .ImapServerResult~failure("LDAP_REVOKED")
  return .ImapServerResult~success(.true)

::class RevokeDuringIdleTransport public
::attribute written get
::method init
  expose incoming written authority store waitCount
  use strict arg incomingArg, authorityArg, storeArg
  incoming = incomingArg
  written = ""
  authority = authorityArg
  store = storeArg
  waitCount = 0
::method supportsReadiness
  return .true
::method readLine
  expose incoming
  use strict arg maxBytes
  p = incoming~pos('0d0a'x)
  if p = 0 then return .nil
  line = incoming~left(p - 1)
  incoming = incoming~substr(p + 2)
  return line
::method writeAll
  expose written
  use strict arg bytes
  written ||= bytes
  return .true
::method waitReadable
  expose authority store waitCount
  use strict arg timeoutSeconds
  waitCount += 1
  if waitCount = 1 then do
    authority~revoke
    bytes = "Subject: private" || '0d0a0d0a'x || "sensitive payload" || '0d0a'x
    ignore = store~appendMessage("Archive", bytes, .nil, "", "external-delivery")
    if \ignore~ok then return -1
    return 0
  end
  return 0

::requires "ImapServer.cls"
