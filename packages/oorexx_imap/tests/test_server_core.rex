numeric digits 30
call testParser
call testSession
call testAuthoritySeparation
call testHonestCapabilities
say "PASS test_server_core"
exit 0

testParser:
  p = .ImapServerParser~parseLine('A1 STATUS "My Box" (MESSAGES UIDNEXT)')
  call assert p~ok, "parser accepts quoted mailbox"
  call assert p~tag = "A1", "parser tag"
  call assert p~command = "STATUS", "parser command"
  a = p~args
  call assert a~items = 2, "parser grouped STATUS items"
  call assert a[1] = "My Box", "quoted string decoded"
  call assert a[2] = "(MESSAGES UIDNEXT)", "parenthesized group retained"
  p = .ImapServerParser~parseLine('A2 LIST "" "*"')
  call assert p~ok & p~args[1] = "", "empty quoted argument preserved"
  bad = .ImapServerParser~parseLine("A1 STATUS (BROKEN")
  call assert \bad~ok, "unbalanced group rejected"
  return

testSession:
  auth = .ImapTestAuthenticationProvider~new~addUser("alice", "secret", "person:alice")
  store = .ImapMemoryMailboxProvider~new
  authority = .ImapTestAllowAllMailboxAuthority~new
  session = .ImapServerSession~new(auth, store, authority, .false)

  r = session~processLine("A1 CAPABILITY")
  call assert r~wire~pos("LOGINDISABLED") > 0, "cleartext capability disables LOGIN"
  call assert r~wire~pos("X-OOREXX-SERVER-CORE") > 0, "partial server capability is explicit"
  call assert r~wire~pos("IMAP4rev1") = 0, "partial server does not overclaim IMAP4rev1"
  r = session~processLine('A2 LOGIN "alice" "secret"')
  call assert r~wire~pos("PRIVACYREQUIRED") > 0, "cleartext LOGIN rejected"

  ignore = session~setTlsActive(.true)
  r = session~processLine('A3 LOGIN "alice" "secret"')
  call assert r~wire~pos("A3 OK") > 0, "encrypted LOGIN succeeds"
  call assert session~identity~principalId = "person:alice", "identity attributed"

  r = session~processLine("A3N NAMESPACE")
  call assert r~wire~pos("* NAMESPACE") > 0, "NAMESPACE implemented when advertised"

  r = session~processLine('A4 LIST "" "*"')
  call assert r~wire~pos('"INBOX"') > 0, "LIST exposes verified inbox"
  call assert r~wire~pos('"INBOX-UNSIGNED"') > 0, "LIST exposes unsigned inbox"

  r = session~processLine('A5 STATUS "INBOX" (MESSAGES UNSEEN UIDVALIDITY UIDNEXT)')
  call assert r~wire~pos("* STATUS") > 0, "STATUS emits mailbox data"
  r = session~processLine('A5B STATUS "INBOX" (BOGUS)')
  call assert r~wire~pos("A5B BAD") > 0, "unknown STATUS item fails closed"

  r = session~processLine('A6 EXAMINE "INBOX"')
  call assert r~wire~pos("[READ-ONLY]") > 0, "EXAMINE is read-only"
  call assert session~state = "SELECTED", "selected state entered"
  r = session~processLine("A7 CLOSE")
  call assert r~wire~pos("A7 OK") > 0, "read-only CLOSE succeeds without expunge"
  call assert session~state = "AUTHENTICATED", "CLOSE leaves authenticated state"

  r = session~processLine('A8 CREATE "INBOX-UNSIGNED"')
  call assert r~wire~pos("delivery-managed") > 0, "classified inbox cannot be client-created"
  call assert \.ImapClassifiedInboxPolicy~clientMayCreateMembership("INBOX"), "client cannot manufacture verified membership"
  call assert \.ImapClassifiedInboxPolicy~clientMayCreateMembership("INBOX-UNSIGNED"), "client cannot manufacture unsigned classification membership"

  r = session~processLine('A9 CREATE "Archive"')
  call assert r~wire~pos("A9 OK") > 0, "ordinary mailbox create"
  r = session~processLine('A10 SUBSCRIBE "Archive"')
  call assert r~wire~pos("A10 OK") > 0, "subscribe"
  r = session~processLine('A11 LSUB "" "*"')
  call assert r~wire~pos('"Archive"') > 0, "LSUB sees subscribed mailbox"
  r = session~processLine('A12 RENAME "Archive" "Archive2"')
  call assert r~wire~pos("A12 OK") > 0, "rename"
  r = session~processLine('A13 DELETE "Archive2"')
  call assert r~wire~pos("A13 OK") > 0, "delete"

  r = session~processLine("A14 FETCH 1 FLAGS")
  call assert r~wire~pos("NOTIMPLEMENTED") > 0, "unimplemented data commands are explicit"
  r = session~processLine("A15 LOGOUT")
  call assert r~closeConnection, "logout closes endpoint"
  return

testAuthoritySeparation:
  auth = .ImapTestAuthenticationProvider~new~addUser("alice", "secret", "person:alice")
  store = .ImapMemoryMailboxProvider~new
  authority = .DenySelectAuthority~new
  session = .ImapServerSession~new(auth, store, authority, .true)
  r = session~processLine('B1 LOGIN "alice" "secret"')
  call assert r~wire~pos("B1 OK") > 0, "authentication succeeds independently"
  r = session~processLine('B2 SELECT "INBOX"')
  call assert r~wire~pos("NOPERM") > 0, "mailbox authority can deny authenticated principal"
  return

testHonestCapabilities:
  auth = .ImapTestAuthenticationProvider~new~addUser("a", "b")
  session = .ImapServerSession~new(auth, .ImapMemoryMailboxProvider~new, .ImapTestAllowAllMailboxAuthority~new, .true)
  caps = session~capabilityArray
  call assert has(caps, "NAMESPACE"), "implemented extension advertised"
  call assert \has(caps, "AUTH=PLAIN"), "unimplemented SASL mechanism not advertised"
  call assert \has(caps, "IMAP4rev1"), "mandatory surface not overclaimed"
  return

has: procedure
  use strict arg a, wanted
  do item over a; if item = wanted then return .true; end
  return .false
assert: procedure
  use strict arg condition, message
  if \condition then call fail message
  return
fail: procedure
  use strict arg message
  say "FAIL:" message
  exit 1

::class DenySelectAuthority subclass ImapMailboxAuthority
::method authorize
  use strict arg identity, action, mailbox = "", context = .nil
  if action = "IMAP_SELECT" then return .ImapServerResult~failure("DENY_TEST")
  return .ImapServerResult~success(.true)

::requires "ImapServer.cls"
