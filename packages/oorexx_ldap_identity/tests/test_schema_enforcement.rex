dir = .IdentityDirectory~new('schema-enforcement-peer')
personality = .NativeLdapPersonality~new
policy = .NativeLdapSchemaPolicy~new

/* Existing owners/members for group, key and ACL Add qualification. */
ignore = .LdapIdentityTest~assert(dir~createPrincipal('principal:owner', 'uid=owner,ou=people,dc=example,dc=org', 'PERSON', 'Owner', 'owner')~ok, 'owner create')
ignore = .LdapIdentityTest~assert(dir~createResource('resource:directory', 'cn=directory,ou=resources,dc=example,dc=org', 'DIRECTORY', 'identity://example', 'Directory')~ok, 'resource create')

/* Add accepts schema numericoids/descriptors but normalizes them into the
 * native personality before semantic import.  oorexxEntryKind is derived from
 * the structural class if the caller omits the redundant field. */
a = .LdapAttributeSet~new
a~add('2.5.4.0', 'top')
a~add('2.5.4.0', '1.3.6.1.4.1.32473.999.2.1')
a~put('1.3.6.1.4.1.32473.999.1.1', 'principal:schema')
a~put('2.5.4.3', 'Schema User')
a~put('0.9.2342.19200300.100.1.1', 'schema-user')
a~put('1.3.6.1.4.1.32473.999.1.7', 'PERSON')
r = personality~importAdd(.LdapEntry~new('uid=schema-user,ou=people,dc=example,dc=org', a), dir)
ignore = .LdapIdentityTest~assert(r~ok, 'schema-normalized principal Add')
principal = dir~entryById('principal:schema')
ignore = .LdapIdentityTest~equal('Schema User', principal~displayName, 'cn numericoid normalized')
ignore = .LdapIdentityTest~equal('schema-user', principal~loginName, 'uid numericoid normalized')

/* Undefined attributes do not fall through into the semantic model. */
bad = .LdapAttributeSet~new
bad~add('objectClass', 'oorexxPrincipal')
bad~put('oorexxEntityId', 'principal:bad-unknown')
bad~put('madeUpAttribute', 'x')
r = personality~importAdd(.LdapEntry~new('uid=bad-unknown,ou=people,dc=example,dc=org', bad), dir)
ignore = .LdapIdentityTest~assert(\r~ok, 'undefined attribute rejected')
ignore = .LdapIdentityTest~equal('LDAP_UNDEFINED_ATTRIBUTE_TYPE', r~code, 'undefined attribute result')

/* Server-maintained operational values cannot be injected by Add. */
bad = .LdapAttributeSet~new
bad~add('objectClass', 'oorexxPrincipal')
bad~put('oorexxEntityId', 'principal:bad-uuid')
bad~put('entryUUID', '01234567-89ab-cdef-0123-456789abcdef')
r = personality~importAdd(.LdapEntry~new('uid=bad-uuid,ou=people,dc=example,dc=org', bad), dir)
ignore = .LdapIdentityTest~assert(\r~ok, 'user entryUUID rejected')
ignore = .LdapIdentityTest~equal('LDAP_CONSTRAINT_VIOLATION', r~code, 'entryUUID is server-maintained')

/* Native object classes and semantic entry kind must agree. */
bad = .LdapAttributeSet~new
bad~add('objectClass', 'oorexxPrincipal')
bad~put('oorexxEntityId', 'principal:bad-kind')
bad~put('oorexxEntryKind', 'RESOURCE')
r = personality~importAdd(.LdapEntry~new('uid=bad-kind,ou=people,dc=example,dc=org', bad), dir)
ignore = .LdapIdentityTest~assert(\r~ok, 'kind/class mismatch rejected')
ignore = .LdapIdentityTest~equal('LDAP_OBJECT_CLASS_VIOLATION', r~code, 'kind/class result')

/* Required object-class attributes are enforced before the core constructor. */
bad = .LdapAttributeSet~new
bad~add('objectClass', 'oorexxResource')
bad~put('oorexxEntityId', 'resource:bad')
bad~put('oorexxResourceType', 'QUEUE')
r = personality~importAdd(.LdapEntry~new('cn=bad-resource,ou=resources,dc=example,dc=org', bad), dir)
ignore = .LdapIdentityTest~assert(\r~ok, 'missing resourceRef rejected')
ignore = .LdapIdentityTest~equal('LDAP_OBJECT_CLASS_VIOLATION', r~code, 'missing MUST result')

/* Native groups have their own structural class. groupOfNames is accepted only
 * as an interoperability Add alias and normalized to oorexxGroup; it is never
 * mixed in as a second unrelated structural class. */
g = .LdapAttributeSet~new
g~add('objectClass', 'oorexxGroup')
g~put('oorexxEntityId', 'group:empty')
g~put('cn', 'Empty Group')
r = personality~importAdd(.LdapEntry~new('cn=empty,ou=groups,dc=example,dc=org', g), dir)
ignore = .LdapIdentityTest~assert(r~ok, 'empty native group Add')
ge = personality~project(dir~entryById('group:empty'), dir)
ignore = .LdapIdentityTest~assert(.LdapFilter~matches('(objectClass=oorexxGroup)', ge), 'native group class projected')
ignore = .LdapIdentityTest~assert(\.LdapFilter~matches('(objectClass=groupOfNames)', ge), 'empty group does not falsely claim groupOfNames')

g2 = .LdapAttributeSet~new
g2~add('objectClass', 'groupOfNames')
g2~put('oorexxEntityId', 'group:staff')
g2~put('cn', 'Staff')
g2~add('member', 'uid=owner,ou=people,dc=example,dc=org')
r = personality~importAdd(.LdapEntry~new('cn=staff,ou=groups,dc=example,dc=org', g2), dir)
ignore = .LdapIdentityTest~assert(r~ok, 'groupOfNames Add with member')
ignore = .LdapIdentityTest~assert(dir~entryById('group:staff')~hasMember('principal:owner'), 'group Add member resolved before atomic create')
ge = personality~project(dir~entryById('group:staff'), dir)
ignore = .LdapIdentityTest~assert(.LdapFilter~matches('(objectClass=oorexxGroup)', ge), 'group gets native structural class')
ignore = .LdapIdentityTest~assert(\.LdapFilter~matches('(objectClass=groupOfNames)', ge), 'native group keeps one structural class')

/* KeySet and staged KeyGeneration are now complete native Add paths. */
ks = .LdapAttributeSet~new
ks~add('objectClass', 'oorexxKeySet')
ks~put('oorexxEntityId', 'keyset:owner-sign')
ks~put('oorexxOwnerId', 'principal:owner')
ks~put('oorexxKeyUsage', 'SIGN')
r = personality~importAdd(.LdapEntry~new('cn=signing,ou=keys,dc=example,dc=org', ks), dir)
ignore = .LdapIdentityTest~assert(r~ok, 'keyset Add')
kg = .LdapAttributeSet~new
kg~add('objectClass', 'oorexxKeyGeneration')
kg~put('oorexxEntityId', 'keygen:owner-sign:1')
kg~put('oorexxKeySetId', 'keyset:owner-sign')
kg~put('oorexxKeyGeneration', '001')
kg~put('oorexxKeyAlgorithm', 'ED25519')
kg~put('oorexxSecretRef', 'secret://owner/sign/1')
kg~put('oorexxNotBefore', '2026-09-24T00:00:00.000000Z')
kg~put('oorexxNotAfter', '2027-09-24T00:00:00.000000Z')
r = personality~importAdd(.LdapEntry~new('cn=signing-1,ou=keys,dc=example,dc=org', kg), dir)
ignore = .LdapIdentityTest~assert(r~ok, 'key generation Add')
ignore = .LdapIdentityTest~equal('STAGED', dir~entryById('keygen:owner-sign:1')~state, 'LDAP Add cannot bypass key activation lifecycle')
ignore = .LdapIdentityTest~assert(dir~entryById('keygen:owner-sign:1')~notBefore~isA(.DateTime), 'key generation notBefore stays DateTime')

/* Modify is schema-normalized too: OID form works, structural class changes do
 * not, and deleting a MUST value is refused before semantic mutation. */
mods = .array~of(.LdapModification~new('REPLACE', '2.5.4.3', .array~of('Schema User Renamed')))
r = personality~importModify('uid=schema-user,ou=people,dc=example,dc=org', mods, dir)
ignore = .LdapIdentityTest~assert(r~ok, 'cn OID Modify')
ignore = .LdapIdentityTest~equal('Schema User Renamed', dir~entryById('principal:schema')~displayName, 'OID Modify reached semantic field')
mods = .array~of(.LdapModification~new('REPLACE', 'objectClass', .array~of('oorexxResource')))
r = personality~importModify('uid=schema-user,ou=people,dc=example,dc=org', mods, dir)
ignore = .LdapIdentityTest~assert(\r~ok, 'objectClass mutation rejected')
ignore = .LdapIdentityTest~equal('LDAP_OBJECT_CLASS_MODS_PROHIBITED', r~code, 'objectClass mods result')
mods = .array~of(.LdapModification~new('DELETE', 'oorexxResourceRef'))
r = personality~importModify('cn=directory,ou=resources,dc=example,dc=org', mods, dir)
ignore = .LdapIdentityTest~assert(\r~ok, 'deleting required resourceRef rejected')
ignore = .LdapIdentityTest~equal('LDAP_OBJECT_CLASS_VIOLATION', r~code, 'required attribute delete result')

/* Projected native entities themselves conform to the enforcement profile. */
do entity over dir~allEntries
  projected = personality~project(entity, dir)
  normalized = policy~validateProjected(projected)
  ignore = .LdapIdentityTest~assert(normalized~ok, 'projected entry conforms to native schema: ' || entity~entityId)
end

say 'LDAP SCHEMA ENFORCEMENT: OK'
::requires 'tests/TestSupport.cls'
::requires 'src/LdapWireServer.cls'
