a = .LdapAttributeSet~new
a~add('objectClass', 'top')
a~add('objectClass', 'oorexxPrincipal')
a~put('uid', 'jsmith')
a~put('cn', 'Smith, John')
a~put('oorexxRevision', '12')
a~put('description', 'literal*star')
entry = .LdapEntry~new('uid=jsmith,dc=example,dc=org', a, 'principal:jsmith')

good = .array~of('(&(objectClass=oorexxPrincipal)(uid=jsmith))', '(|(uid=nobody)(uid=JSMITH))', '(!(uid=nobody))', '(cn=Smith*)', '(cn=*John)', '(cn=*ith*Jo*)', '(uid>=aaaa)', '(uid<=zzzz)', '(cn~=  smith,   john  )', '(description=literal\2astar)', '(objectClass=*)')
do f over good
  parsed = .LdapFilter~parse(f)
  ignore = .LdapIdentityTest~assert(parsed~ok, 'filter parses: ' || f)
  ignore = .LdapIdentityTest~assert(.LdapFilter~matchesNode(parsed~value, a), 'filter matches: ' || f)
  encoded = .LdapWireCodec~encodeFilter(f)
  element = .LdapBer~readElement(encoded, 1)
  decoded = .LdapWireCodec~decodeFilter(element)
  ignore = .LdapIdentityTest~assert(decoded <> '', 'BER filter decodes: ' || f)
  ignore = .LdapIdentityTest~assert(.LdapFilter~matches(decoded, entry), 'BER round-trip preserves match: ' || f)
end
ignore = .LdapIdentityTest~assert(\.LdapFilter~matches('(uid=nobody)', entry), 'negative equality')
ignore = .LdapIdentityTest~assert(\.LdapFilter~parse('(uid=bad\zz)')~ok, 'non-hex assertion escape rejected')
ignore = .LdapIdentityTest~assert(\.LdapFilter~parse('(uid:caseExactMatch:=jsmith)')~ok, 'extensibleMatch truthfully unsupported')

say 'LDAP FILTER SEMANTICS: OK'
::requires 'tests/TestSupport.cls'
::requires 'src/LdapBer.cls'
