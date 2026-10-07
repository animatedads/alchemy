/* Date/time values are semantic objects in the core, strings only at protocol edges. */
dir = .IdentityDirectory~new("peer-time")
ignore = .LdapIdentityTest~assert(dir~createPrincipal("service:clock", "uid=clock,ou=services,dc=example,dc=org", "SERVICE", "Clock", "clock")~ok, "principal")

nb = .DateTime~fromUtcIsoDate("2026-09-22T12:00:00.000000Z")
na = .DateTime~fromUtcIsoDate("2026-12-31T23:59:59.000000Z")
rotate = .DateTime~fromUtcIsoDate("2026-12-01T00:00:00.000000Z")

r = dir~createCredential("credential:clock", "cn=credential,uid=clock,ou=services,dc=example,dc=org", "service:clock", "PASSWORD_VERIFIER", "secret://identity/clock", nb, na, "ACTIVE")
ignore = .LdapIdentityTest~assert(r~ok, "credential")
cred = dir~entryById("credential:clock")
ignore = .LdapIdentityTest~equal("DateTime", cred~notBefore~class~id, "notBefore object")
ignore = .LdapIdentityTest~equal("DateTime", cred~notAfter~class~id, "notAfter object")
ignore = .LdapIdentityTest~equal(0, cred~notBefore~compareTo(nb), "notBefore preserved")
ignore = .LdapIdentityTest~assert(cred~validAt(.DateTime~fromUtcIsoDate("2026-10-01T00:00:00.000000Z")), "credential valid in window")
ignore = .LdapIdentityTest~assert(\cred~validAt(.DateTime~fromUtcIsoDate("2027-01-01T00:00:00.000000Z")), "credential invalid after window")

ignore = .LdapIdentityTest~assert(dir~createKeySet("keyset:clock", "cn=clock,ou=keysets,dc=example,dc=org", "service:clock", "SIGNING")~ok, "key set")
r = dir~stageKeyGeneration("key:clock:1", "cn=1,cn=clock,ou=keysets,dc=example,dc=org", "keyset:clock", 1, "ED25519", "pub", "secret://keys/clock/1", nb, na, rotate)
ignore = .LdapIdentityTest~assert(r~ok, "key generation")
kg = dir~entryById("key:clock:1")
ignore = .LdapIdentityTest~equal("DateTime", kg~rotateAt~class~id, "rotateAt object")
tooEarly = dir~activateKeyGeneration("keyset:clock", "key:clock:1", .DateTime~fromUtcIsoDate("2026-09-22T11:59:59.000000Z"))
ignore = .LdapIdentityTest~assert(\tooEarly~ok, "key cannot activate before notBefore")
ignore = .LdapIdentityTest~equal("KEY_GENERATION_NOT_EFFECTIVE", tooEarly~code, "activation validity code")
ignore = .LdapIdentityTest~assert(dir~activateKeyGeneration("keyset:clock", "key:clock:1", nb)~ok, "key activates at notBefore")
ignore = .LdapIdentityTest~assert(\kg~rotationDue(.DateTime~fromUtcIsoDate("2026-11-30T23:59:59.000000Z")), "rotation not due")
ignore = .LdapIdentityTest~assert(kg~rotationDue(.DateTime~fromUtcIsoDate("2026-12-01T00:00:00.000000Z")), "rotation due")

/* Equivalent instants with different offsets canonicalize identically. */
a = .DateTime~fromUtcIsoDate("2026-09-22T12:00:00.000000Z")
b = .DateTime~fromUtcIsoDate("2026-09-22T13:00:00.000000+01:00")
ignore = .LdapIdentityTest~equal(.DirectoryCanonical~dateTimeText(a), .DirectoryCanonical~dateTimeText(b), "UTC canonical instant")

/* Entity/change timestamps are DateTime too, and reading a copy does not mutate them. */
e1 = dir~entryById("service:clock")
e2 = dir~entryById("service:clock")
ignore = .LdapIdentityTest~equal("DateTime", e1~createdAt~class~id, "createdAt object")
ignore = .LdapIdentityTest~equal("DateTime", e1~updatedAt~class~id, "updatedAt object")
ignore = .LdapIdentityTest~equal(0, e1~createdAt~compareTo(e2~createdAt), "copy preserves createdAt")
ignore = .LdapIdentityTest~equal(0, e1~updatedAt~compareTo(e2~updatedAt), "copy preserves updatedAt")
changes = dir~changesSince(0)
ignore = .LdapIdentityTest~equal("DateTime", changes[1]~createdAt~class~id, "change createdAt object")

/* LDAP projection is a string edge, not the in-memory representation. */
p = .NativeLdapPersonality~new
entry = p~project(cred, dir)
ignore = .LdapIdentityTest~equal("2026-09-22T12:00:00.000000Z", entry~attributes~first("oorexxNotBefore"), "wire time projection")

say "DATETIME LIFECYCLE: OK"
::requires "tests/TestSupport.cls"
::requires "src/LdapDirectoryPersonality.cls"
