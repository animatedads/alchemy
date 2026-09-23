dir = .IdentityDirectory~new("peer-a")
ignore = .LdapIdentityTest~assert(dir~createPrincipal("principal:alice", "uid=alice,ou=people,dc=example,dc=org", "PERSON", "Alice", "alice")~ok, "alice")
ignore = .LdapIdentityTest~assert(dir~createResource("resource:directory", "cn=directory,ou=resources,dc=example,dc=org", "DIRECTORY", "identity://example")~ok, "resource")
authn = .TestLdapAuthenticator~new
security = .DirectoryAclLdapAuthority~new(dir)
service = .LdapConversationService~new(dir, .NativeLdapPersonality~new, authn, security, "resource:directory")
bind = service~bind("uid=alice,ou=people,dc=example,dc=org", "correct")
ignore = .LdapIdentityTest~assert(bind~ok, "bind authenticates")
session = bind~value
/* Bind is attribution only: no ACL means search is still denied. */
r = service~search(session, "dc=example,dc=org", "SUB", "(uid=alice)")
ignore = .LdapIdentityTest~assert(\r~ok, "bind confers no search authority")
ignore = .LdapIdentityTest~equal("ACL_DEFAULT_DENY", r~code, "default deny after bind")
ignore = .LdapIdentityTest~assert(dir~createAclGrant("acl:alice-search", "cn=alice-search,ou=acl,dc=example,dc=org", "principal:alice", "resource:directory", "LDAP_SEARCH", "ALLOW")~ok, "grant search")
r = service~search(session, "dc=example,dc=org", "SUB", "(uid=alice)")
ignore = .LdapIdentityTest~assert(r~ok, "search after grant")
ignore = .LdapIdentityTest~equal(1, r~value~items, "one alice")
/* Delete remains separately denied. */
r = service~delete(session, "uid=alice,ou=people,dc=example,dc=org")
ignore = .LdapIdentityTest~assert(\r~ok, "delete denied")
say "CONVERSATION AUTHORITY: OK"

::class TestLdapAuthenticator subclass LdapAuthenticator
::method bind
  use strict arg bindName, credential
  if bindName~caselessEquals("uid=alice,ou=people,dc=example,dc=org") & credential = "correct" then return .LdapBindResult~new(.true, "OK", "principal:alice")
  return .LdapBindResult~new(.false, "INVALID_CREDENTIALS")

::requires "tests/TestSupport.cls"
::requires "src/LdapConversation.cls"
