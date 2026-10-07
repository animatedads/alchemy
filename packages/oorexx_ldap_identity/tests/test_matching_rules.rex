registry = .LdapMatchingRuleRegistry~new

ignore = .LdapIdentityTest~equal('oorexx-ldap-schema-matching/0.1', .LdapMatchingBuild~DN_COMPARISON_PROFILE, 'schema matching comparison profile')
ignore = .LdapIdentityTest~assert(registry~supportedRule('caseIgnoreMatch'), 'caseIgnoreMatch registered')
ignore = .LdapIdentityTest~assert(registry~supportedRule('2.5.13.2'), 'caseIgnoreMatch OID registered')
ignore = .LdapIdentityTest~assert(registry~equality('caseIgnoreMatch', '  Alice   Smith ', 'alice smith'), 'case-ignore normalization')
ignore = .LdapIdentityTest~assert(registry~equality('integerMatch', '0012', '12'), 'integer normalization')
ignore = .LdapIdentityTest~equal(-1, registry~orderingCompare('integerOrderingMatch', '9', '10'), 'integer ordering is numeric')
ignore = .LdapIdentityTest~assert(registry~distinguishedNameEquivalent('CN=Alice+UID=A1,OU=People,DC=Example,DC=Org', 'uid=a1+2.5.4.3=alice,2.5.4.11=people,0.9.2342.19200300.100.1.25=example,dc=org'), 'schema-aware DN structural equality including attribute OID aliases')

attrs = .LdapAttributeSet~new
attrs~put('cn', 'Alice Smith')
attrs~add('objectClass', 'top')
attrs~add('objectClass', 'oorexxPrincipal')
attrs~put('uid', 'alice')
attrs~put('oorexxRevision', '12')
attrs~put('entryUUID', '01234567-89ab-cdef-0123-456789abcdef')
attrs~add('member', 'uid=Alice,ou=People,dc=example,dc=org')
entry = .LdapEntry~new('uid=Alice,ou=People,dc=example,dc=org', attrs, 'principal:alice')

ignore = .LdapIdentityTest~assert(.LdapFilter~matches('(member=UID=alice,OU=people,DC=example,DC=org)', entry, registry), 'normal equality uses distinguishedNameMatch for member')
ignore = .LdapIdentityTest~assert(.LdapFilter~matches('(oorexxRevision>=10)', entry, registry), 'ordering uses integerOrderingMatch')
ignore = .LdapIdentityTest~assert(\.LdapFilter~matches('(oorexxRevision<=9)', entry, registry), 'integer ordering rejects lexical false positive')
ignore = .LdapIdentityTest~assert(.LdapFilter~matches('(entryUUID=01234567-89AB-CDEF-0123-456789ABCDEF)', entry, registry), 'UUID equality follows uuidMatch')
ignore = .LdapIdentityTest~assert(.LdapFilter~matches('(2.5.4.3=alice smith)', entry, registry), 'attribute OID resolves to native cn profile/value')
ignore = .LdapIdentityTest~assert(.LdapFilter~matches('(objectClass=1.3.6.1.4.1.32473.999.2.1)', entry, registry), 'objectIdentifierMatch resolves native objectClass descriptor to numericoid')

extensible = .array~of('(cn:caseIgnoreMatch:= alice   smith )', '(cn:2.5.13.2:=ALICE SMITH)', '(:caseIgnoreMatch:=alice smith)', '(cn:caseExactMatch:=Alice Smith)', '(uid:dn:caseIgnoreMatch:=ALICE)', '(member:distinguishedNameMatch:=UID=alice,OU=people,DC=example,DC=org)')
do f over extensible
  parsed = .LdapFilter~parse(f)
  ignore = .LdapIdentityTest~assert(parsed~ok, 'extensible filter parses: ' || f)
  valid = .LdapFilter~validate(parsed~value, registry)
  ignore = .LdapIdentityTest~assert(valid~ok, 'extensible filter validates: ' || f)
  ignore = .LdapIdentityTest~assert(.LdapFilter~matches(f, entry, registry), 'extensible filter matches: ' || f)
  encoded = .LdapWireCodec~encodeFilter(f)
  element = .LdapBer~readElement(encoded, 1)
  decoded = .LdapWireCodec~decodeFilter(element)
  ignore = .LdapIdentityTest~assert(decoded <> '', 'extensible BER decodes: ' || f)
  ignore = .LdapIdentityTest~assert(.LdapFilter~matches(decoded, entry, registry), 'extensible BER round-trip matches: ' || f)
end

badRule = .LdapFilter~parse('(cn:192.0.2.1.5:=Alice)')
ignore = .LdapIdentityTest~assert(badRule~ok, 'syntactically valid unknown rule parses')
badValidation = .LdapFilter~validate(badRule~value, registry)
ignore = .LdapIdentityTest~assert(\badValidation~ok, 'unknown matching rule rejected by registry')
ignore = .LdapIdentityTest~equal('LDAP_INAPPROPRIATE_MATCHING', badValidation~code, 'unknown rule result code')
incompatible = .LdapFilter~parse('(entryUUID:caseIgnoreMatch:=01234567-89ab-cdef-0123-456789abcdef)')
ignore = .LdapIdentityTest~assert(incompatible~ok, 'incompatible rule syntax parses')
incompatibleValidation = .LdapFilter~validate(incompatible~value, registry)
ignore = .LdapIdentityTest~assert(\incompatibleValidation~ok, 'incompatible rule fails closed')
caseExactMismatch = .LdapFilter~parse('(cn:caseExactMatch:=alice smith)')
ignore = .LdapIdentityTest~assert(caseExactMismatch~ok, 'caseExact extensible syntax parses')
ignore = .LdapIdentityTest~assert(.LdapFilter~validate(caseExactMismatch~value, registry)~ok, 'caseExact applies to Directory String syntax')
ignore = .LdapIdentityTest~assert(\.LdapFilter~matches('(cn:caseExactMatch:=alice smith)', entry, registry), 'caseExact preserves case')
orderingExtensible = .LdapFilter~parse('(cn:caseIgnoreOrderingMatch:=Alice Smith)')
ignore = .LdapIdentityTest~assert(orderingExtensible~ok, 'ordering rule extensible syntax parses')
ignore = .LdapIdentityTest~assert(\.LdapFilter~validate(orderingExtensible~value, registry)~ok, 'ordering rule refused as extensible boolean match')

/* Compare must use the attribute's equality rule rather than raw caseless text. */
dir = .IdentityDirectory~new('matching-peer')
ignore = .LdapIdentityTest~assert(dir~createPrincipal('principal:alice', 'uid=Alice,ou=People,dc=example,dc=org', 'PERSON', 'Alice Smith', 'alice')~ok, 'principal create')
ignore = .LdapIdentityTest~assert(dir~createGroup('group:ops', 'cn=Ops,ou=Groups,dc=example,dc=org', 'Ops')~ok, 'group create')
ignore = .LdapIdentityTest~assert(dir~createPrincipal('principal:bobspace', 'cn=Bob  Smith,ou=People,dc=example,dc=org', 'PERSON', 'Bob Smith', 'bobspace')~ok, 'spaced-DN principal create')
ignore = .LdapIdentityTest~assert(dir~updateGroup('group:ops', .nil, .array~of('principal:alice'), .nil)~ok, 'group member update')
ignore = .LdapIdentityTest~assert(dir~createResource('resource:directory', 'cn=directory,ou=resources,dc=example,dc=org', 'DIRECTORY', 'identity://example')~ok, 'resource create')
ignore = .LdapIdentityTest~assert(dir~createAclGrant('acl:compare', 'cn=compare,ou=acl,dc=example,dc=org', 'principal:alice', 'resource:directory', 'LDAP_COMPARE', 'ALLOW')~ok, 'compare grant')
ignore = .LdapIdentityTest~assert(dir~createAclGrant('acl:modify-matching', 'cn=modify-matching,ou=acl,dc=example,dc=org', 'principal:alice', 'resource:directory', 'LDAP_MODIFY', 'ALLOW')~ok, 'modify grant')
authn = .MatchingAuthenticator~new
service = .LdapConversationService~new(dir, .NativeLdapPersonality~new, authn, .DirectoryAclLdapAuthority~new(dir), 'resource:directory', .nil, registry)
bound = service~bind('uid=alice,ou=people,dc=example,dc=org', 'ok')
ignore = .LdapIdentityTest~assert(bound~ok, 'matching test bind')
compared = service~compare(bound~value, 'cn=ops,ou=groups,dc=example,dc=org', '2.5.4.31', 'UID=alice,OU=people,DC=example,DC=org')
ignore = .LdapIdentityTest~assert(compared~ok, 'compare operation succeeds')
ignore = .LdapIdentityTest~assert(compared~value, 'Compare resolves attribute OID and uses distinguishedNameMatch')

/* Mutation resolution and group-member import use the same schema matching
 * registry as Search/Compare rather than the legacy DN syntax helper. */
mods = .array~of(.LdapModification~new('ADD', 'member', .array~of('cn=bob smith,ou=people,dc=example,dc=org')))
modified = service~modify(bound~value, 'cn=ops,ou=groups,dc=example,dc=org', mods)
ignore = .LdapIdentityTest~assert(modified~ok, 'Modify resolves member DN through matching registry')
ignore = .LdapIdentityTest~assert(dir~entryById('group:ops')~hasMember('principal:bobspace'), 'schema-equivalent member became semantic member id')
ignore = .LdapIdentityTest~assert(registry~findEntity(dir, 'cn=bob smith,ou=people,dc=example,dc=org')~entityId = 'principal:bobspace', 'registry resolves schema-equivalent DN')

say 'LDAP MATCHING RULES: OK'

::class MatchingAuthenticator subclass LdapAuthenticator
::method bind
  use strict arg bindName, credential
  if bindName~caselessEquals('uid=alice,ou=people,dc=example,dc=org') & credential = 'ok' then return .LdapBindResult~new(.true, 'OK', 'principal:alice')
  return .LdapBindResult~new(.false, 'INVALID_CREDENTIALS')

::requires 'tests/TestSupport.cls'
::requires 'src/LdapWireServer.cls'
