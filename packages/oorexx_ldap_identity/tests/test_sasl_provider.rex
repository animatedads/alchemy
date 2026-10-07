authn = .SaslTestAuthenticator~new("uid=alice,ou=people,dc=example,dc=org", "secret", "principal:alice")
sasl = .PlainLdapSaslProvider~new(authn)
ignore = .LdapIdentityTest~equal("ldap.sasl/0.1", .LdapSaslBuild~API_VERSION, "SASL API identity")
ignore = .LdapIdentityTest~equal("PLAIN", sasl~mechanisms[1], "PLAIN mechanism")
creds = '00'x || "uid=alice,ou=people,dc=example,dc=org" || '00'x || "secret"
r = sasl~authenticate("PLAIN", creds, .false)
ignore = .LdapIdentityTest~assert(\r~ok, "PLAIN refused without TLS")
ignore = .LdapIdentityTest~equal("SASL_CONFIDENTIALITY_REQUIRED", r~code, "confidentiality failure")
r = sasl~authenticate("PLAIN", creds, .true)
ignore = .LdapIdentityTest~assert(r~ok, "PLAIN over TLS accepted")
ignore = .LdapIdentityTest~equal("principal:alice", r~principalId, "SASL principal attribution")
bad = "uid=bob,ou=people,dc=example,dc=org" || '00'x || "uid=alice,ou=people,dc=example,dc=org" || '00'x || "secret"
r = sasl~authenticate("PLAIN", bad, .true)
ignore = .LdapIdentityTest~assert(\r~ok, "unsupported authzid delegation refused")
ignore = .LdapIdentityTest~equal("SASL_AUTHZID_UNSUPPORTED", r~code, "authzid refusal")

/* SASL establishes attribution only; operation authority remains separate. */
dir = .IdentityDirectory~new("sasl-test")
ignore = dir~createResource("resource:directory", "cn=directory,dc=example,dc=org", "DIRECTORY", "identity://example", "Directory")
authority = .DirectoryAclLdapAuthority~new(dir)
service = .LdapConversationService~new(dir, .NativeLdapPersonality~new, authn, authority, "resource:directory", sasl)
r = service~bindSasl("PLAIN", creds, .true)
ignore = .LdapIdentityTest~assert(r~ok, "service SASL bind")
session = r~value
ignore = .LdapIdentityTest~equal("principal:alice", session~principalId, "session principal")
a = service~authorizeOperation(session, "LDAP_SEARCH", "dc=example,dc=org")
ignore = .LdapIdentityTest~assert(\a~ok, "SASL bind does not manufacture ACL authority")
ignore = .LdapIdentityTest~equal("ACL_DEFAULT_DENY", a~code, "authority still separate")
say "LDAP SASL PROVIDER: OK"

::class SaslTestAuthenticator subclass LdapAuthenticator
::method init
  expose expectedName expectedSecret principalId
  use strict arg expectedNameArg, expectedSecretArg, principalIdArg
  expectedName=expectedNameArg; expectedSecret=expectedSecretArg; principalId=principalIdArg
::method bind
  expose expectedName expectedSecret principalId
  use strict arg bindName, credential
  if bindName=expectedName & credential=expectedSecret then return .LdapBindResult~new(.true,"OK",principalId)
  return .LdapBindResult~new(.false,"INVALID_CREDENTIALS")

::requires "tests/TestSupport.cls"
::requires "src/LdapConversation.cls"
