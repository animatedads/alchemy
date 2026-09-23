schema = .LdapSchemaRegistry~new
entry = schema~entry(.nil)
ignore = .LdapIdentityTest~equal('cn=subschema', entry~dn, 'subschema DN')
ignore = .LdapIdentityTest~assert(entry~attributes~get('attributeTypes')~items > 20, 'native attribute schema projected')
ignore = .LdapIdentityTest~assert(entry~attributes~get('objectClasses')~items >= 8, 'native object classes projected')
ignore = .LdapIdentityTest~assert(.LdapFilter~matches('(objectClass=subschema)', entry), 'subschema entry is searchable')
selected = schema~entry(.array~of('cn', 'objectClasses'))
ignore = .LdapIdentityTest~assert(selected~attributes~has('cn'), 'selected cn')
ignore = .LdapIdentityTest~assert(selected~attributes~has('objectClasses'), 'selected objectClasses')
ignore = .LdapIdentityTest~assert(\selected~attributes~has('attributeTypes'), 'selection does not leak omitted schema attributes')

dir = .IdentityDirectory~new('schema-capability')
service = .LdapConversationService~new(dir, .NativeLdapPersonality~new, .nil, .nil, 'resource:directory')
server = .LdapWireServer~new(service)
caps = server~compatibilitySnapshot
ignore = .LdapIdentityTest~assert(caps['rfc4514DnSyntax'], 'DN syntax advertised')
ignore = .LdapIdentityTest~assert(caps['rfc4515Filters'], 'filter syntax advertised')
ignore = .LdapIdentityTest~assert(caps['subschemaDiscovery'], 'subschema discovery advertised')
ignore = .LdapIdentityTest~assert(\caps['schemaEnforcement'], 'general schema enforcement not overclaimed')
ignore = .LdapIdentityTest~assert(\caps['filterExtensibleMatch'], 'extensibleMatch not overclaimed')

say 'LDAP SCHEMA DISCOVERY: OK'
::requires 'tests/TestSupport.cls'
::requires 'src/LdapWireServer.cls'
