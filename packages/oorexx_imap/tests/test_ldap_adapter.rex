call testDirectBind
call testConversationBind
say "PASS test_ldap_adapter"
exit 0

testDirectBind:
  provider = .ImapLdapAuthenticationProvider~new(.FakeLdapAuthenticator~new)
  r = provider~authenticateLogin("alice", "secret")
  call assert r~ok, "direct LDAP bind maps"
  call assert r~value~principalId = "ldap:alice", "direct LDAP principal preserved"
  bad = provider~authenticateLogin("alice", "wrong")
  call assert \bad~ok, "failed LDAP bind rejected"
  return

testConversationBind:
  provider = .ImapLdapAuthenticationProvider~new(.FakeLdapConversation~new)
  r = provider~authenticateLogin("bob", "secret")
  call assert r~ok, "conversation LDAP bind maps"
  call assert r~value~principalId = "ldap:bob", "conversation session principal preserved"
  return

assert: procedure
  use strict arg condition, message
  if \condition then call fail message
  return
fail: procedure
  use strict arg message
  say "FAIL:" message
  exit 1

::class FakeBindResult
::attribute ok get
::attribute code get
::attribute principalId get
::method init
  expose ok code principalId
  use strict arg okArg, principalArg = "", codeArg = "OK"
  ok = okArg; principalId = principalArg; code = codeArg

::class FakeSession
::attribute principalId get
::method init
  expose principalId
  use strict arg principalArg
  principalId = principalArg

::class FakeDirectoryResult
::attribute ok get
::attribute code get
::attribute value get
::method init
  expose ok code value
  use strict arg okArg, valueArg = .nil, codeArg = "OK"
  ok = okArg; value = valueArg; code = codeArg

::class FakeLdapAuthenticator
::method bind
  use strict arg user, credential
  if credential <> "secret" then return .FakeBindResult~new(.false, "", "INVALID_CREDENTIALS")
  return .FakeBindResult~new(.true, "ldap:" || user)

::class FakeLdapConversation
::method bind
  use strict arg user, credential
  if credential <> "secret" then return .FakeDirectoryResult~new(.false, .nil, "INVALID_CREDENTIALS")
  return .FakeDirectoryResult~new(.true, .FakeSession~new("ldap:" || user))

::requires "ImapLdapAdapter.cls"
