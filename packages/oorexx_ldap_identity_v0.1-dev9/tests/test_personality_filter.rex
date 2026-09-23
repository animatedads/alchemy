dir = .IdentityDirectory~new("personality-filter-test")
ignore = dir~createResource("resource:directory", "cn=directory,ou=resources,dc=example,dc=org", "DIRECTORY", "identity://example", "Directory")
ignore = dir~createPrincipal("principal:operator", "uid=operator,ou=people,dc=example,dc=org", "PERSON", "Operator", "operator")
ignore = dir~createAclGrant("acl:operator:add", "cn=add,ou=acl,dc=example,dc=org", "principal:operator", "resource:directory", "LDAP_ADD", "ALLOW")
ignore = dir~createAclGrant("acl:operator:search", "cn=search,ou=acl,dc=example,dc=org", "principal:operator", "resource:directory", "LDAP_SEARCH", "ALLOW")

filter = .AttributeAliasConversationFilter~new("fictional-directory-vocabulary/0.1")
filter~addAlias("objectGuid", "entryUUID")
filter~addAlias("platformObjectId", "oorexxEntityId")
filter~addAlias("entryKind", "oorexxEntryKind")
filter~addAlias("principalKind", "oorexxPrincipalType")
filter~addAlias("accountName", "uid")
filter~addAlias("displayLabel", "cn")
personality = .FilteredDirectoryPersonality~new("fictional-directory/0.1", .NativeLdapPersonality~new, filter)

authn = .FixedTestAuthenticator~new("cn=operator", "secret", "principal:operator")
authority = .DirectoryAclLdapAuthority~new(dir)
service = .LdapConversationService~new(dir, personality, authn, authority, "resource:directory")
sessionResult = service~bind("cn=operator", "secret")
ignore = .LdapIdentityTest~assert(sessionResult~ok, "bind test principal")
session = sessionResult~value

external = .LdapAttributeSet~new
external~add("objectClass", "top")
external~add("objectClass", "fictionalPerson")
external~put("platformObjectId", "principal:edge")
external~put("entryKind", "PRINCIPAL")
external~put("principalKind", "SERVICE")
external~put("accountName", "edge-service")
external~put("displayLabel", "Edge Service")
r = service~add(session, .LdapEntry~new("uid=edge-service,ou=people,dc=example,dc=org", external))
ignore = .LdapIdentityTest~assert(r~ok, "filtered add")

core = dir~entryById("principal:edge")
ignore = .LdapIdentityTest~assert(core \== .nil, "core stable identity")
ignore = .LdapIdentityTest~equal("edge-service", core~loginName, "external account name translated")
ignore = .LdapIdentityTest~equal("SERVICE", core~principalType, "external principal kind translated")

r = service~search(session, "dc=example,dc=org", "SUB", "(accountName=edge-service)", .array~of("accountName", "objectGuid", "platformObjectId", "displayLabel"))
ignore = .LdapIdentityTest~assert(r~ok, "filtered search")
ignore = .LdapIdentityTest~equal(1, r~value~items, "one filtered search result")
entry = r~value[1]
ignore = .LdapIdentityTest~equal("edge-service", entry~attributes~first("accountName"), "external vocabulary returned")
ignore = .LdapIdentityTest~assert(entry~attributes~first("objectGuid") <> "", "external UUID vocabulary returned")
ignore = .LdapIdentityTest~equal(36, entry~attributes~first("objectGuid")~length, "external UUID syntax length")
ignore = .LdapIdentityTest~equal("principal:edge", entry~attributes~first("platformObjectId"), "platform identity alias returned")
ignore = .LdapIdentityTest~equal("", entry~attributes~first("uid"), "native vocabulary not leaked when not requested")
ignore = .LdapIdentityTest~assert(\core~hasMethod("accountName"), "vendor alias did not enter semantic object")

caps = personality~capabilities
ignore = .LdapIdentityTest~equal("identity.directory/0.1", caps["semanticAuthority"], "semantic authority stays native")
ignore = .LdapIdentityTest~assert(\caps["vendorPolicyInCore"], "vendor policy remains outside core")
say "PERSONALITY FILTER: OK"

::class FixedTestAuthenticator subclass LdapAuthenticator
::method init
  expose expectedName expectedCredential principalId
  use strict arg expectedNameArg, expectedCredentialArg, principalIdArg
  expectedName = expectedNameArg; expectedCredential = expectedCredentialArg; principalId = principalIdArg
::method bind
  expose expectedName expectedCredential principalId
  use strict arg bindName, credential
  if bindName = expectedName & credential = expectedCredential then return .LdapBindResult~new(.true, "OK", principalId)
  return .LdapBindResult~new(.false, "INVALID_CREDENTIALS")

::requires "tests/TestSupport.cls"
::requires "src/LdapConversation.cls"
