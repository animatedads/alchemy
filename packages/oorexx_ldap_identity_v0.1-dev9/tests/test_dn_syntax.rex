parsed = .LdapDn~parse('cn=Smith\, John+uid=jsmith,ou=People,dc=Example,dc=ORG')
ignore = .LdapIdentityTest~assert(parsed~ok, 'escaped/multi-valued DN parses')
dn = parsed~value
ignore = .LdapIdentityTest~equal('cn=Smith\, John+uid=jsmith,ou=People,dc=Example,dc=ORG', dn~canonicalText, 'deterministic DN rendering')
ignore = .LdapIdentityTest~assert(.LdapDn~equivalent('cn=Smith\, John+uid=jsmith,ou=People,dc=Example,dc=ORG', 'UID=JSMITH+CN=Smith\2c John,OU=people,DC=example,DC=org'), 'escaped hex and AVA set ordering compare equal')
ignore = .LdapIdentityTest~equal(1, dn~relativeDepth('ou=people,dc=example,dc=org'), 'ONE-level depth uses parsed RDNs')
ignore = .LdapIdentityTest~assert(dn~isDescendantOf('dc=example,dc=org', .true), 'parsed subtree relation')
ignore = .LdapIdentityTest~equal('ou=People,dc=Example,dc=ORG', dn~parentText, 'parent DN preserves parsed hierarchy')
composed = .LdapDn~compose('cn=Doe\, Jane', 'ou=People,dc=example,dc=org')
ignore = .LdapIdentityTest~assert(composed~ok, 'escaped new RDN composes')
ignore = .LdapIdentityTest~equal('cn=Doe\, Jane,ou=People,dc=example,dc=org', composed~value, 'composed DN')
ignore = .LdapIdentityTest~assert(\.LdapDn~parse('cn= leading,dc=example,dc=org')~ok, 'unescaped leading space rejected')
ignore = .LdapIdentityTest~assert(\.LdapDn~parse('cn=trailing ,dc=example,dc=org')~ok, 'unescaped trailing space rejected')

/* Conversation lookup must use LDAP DN equivalence rather than string commas. */
dir = .IdentityDirectory~new('dn-peer')
ignore = .LdapIdentityTest~assert(dir~createPrincipal('principal:smith', 'cn=Smith\, John+uid=jsmith,ou=People,dc=Example,dc=ORG', 'PERSON', 'Smith, John', 'jsmith')~ok, 'principal')
ignore = .LdapIdentityTest~assert(dir~createResource('resource:directory', 'cn=directory,ou=resources,dc=example,dc=org', 'DIRECTORY', 'identity://dn')~ok, 'resource')
ignore = .LdapIdentityTest~assert(dir~createAclGrant('acl:search', 'cn=search,ou=acl,dc=example,dc=org', 'principal:smith', 'resource:directory', 'LDAP_SEARCH', 'ALLOW')~ok, 'search grant')
session = .LdapSession~new('dn-session', 'principal:smith', .true)
service = .LdapConversationService~new(dir, .NativeLdapPersonality~new, .nil, .DirectoryAclLdapAuthority~new(dir), 'resource:directory')
found = service~search(session, 'uid=JSMITH+cn=Smith\2C John,ou=people,dc=example,dc=org', 'BASE', '(uid=jsmith)')
ignore = .LdapIdentityTest~assert(found~ok, 'BASE search accepts equivalent RFC4514 form')
ignore = .LdapIdentityTest~equal(1, found~value~items, 'equivalent BASE identifies one entry')

say 'LDAP DN SYNTAX: OK'
::requires 'tests/TestSupport.cls'
::requires 'src/LdapConversation.cls'
