dir = .IdentityDirectory~new("sync-peer-a")
ignore = .LdapIdentityTest~assert(dir~createPrincipal("principal:alice", "uid=alice,ou=people,dc=example,dc=org", "PERSON", "Alice", "alice")~ok, "create alice")
ignore = .LdapIdentityTest~assert(dir~createPrincipal("principal:bob", "uid=bob,ou=people,dc=example,dc=org", "PERSON", "Bob", "bob")~ok, "create bob")
sync = .LdapSyncProvider~new(dir, .NativeLdapPersonality~new)
attrs = .array~of("uid", "cn", "entryUUID", "oorexxEntityId")

r = sync~refreshOnly("dc=example,dc=org", "SUB", "(uid=alice)", attrs)
ignore = .LdapIdentityTest~assert(r~ok, "initial refresh")
b1 = r~value
ignore = .LdapIdentityTest~equal(1, b1~records~items, "initial one record")
ignore = .LdapIdentityTest~equal("ADD", b1~records[1]~state, "initial state")
ignore = .LdapIdentityTest~equal("principal:alice", b1~records[1]~entityId, "semantic id retained separately")
uuidBytes = b1~records[1]~entryUuidBytes
ignore = .LdapIdentityTest~equal(16, uuidBytes~length, "sync state UUID is 16 octets")
uuidText = b1~records[1]~entryUuid
ignore = .LdapIdentityTest~equal(uuidText, .LdapSyncCodec~uuidText(uuidBytes), "sync text/octet views agree")
ignore = .LdapIdentityTest~equal(dir~entryById("principal:alice")~entryUuid, uuidText, "sync UUID matches LDAP entryUUID")
c1 = b1~cookie
ignore = .LdapIdentityTest~assert(c1 <> "", "initial cookie")

ignore = .LdapIdentityTest~assert(dir~updatePrincipal("principal:alice", "Alice Updated")~ok, "modify alice")
r = sync~refreshOnly("dc=example,dc=org", "SUB", "(uid=alice)", attrs, c1)
ignore = .LdapIdentityTest~assert(r~ok, "incremental refresh")
b2 = r~value
ignore = .LdapIdentityTest~equal(1, b2~records~items, "one incremental record")
ignore = .LdapIdentityTest~equal("MODIFY", b2~records[1]~state, "modify state")
ignore = .LdapIdentityTest~equal(uuidText, b2~records[1]~entryUuid, "UUID stable across modify")
ignore = .LdapIdentityTest~assert(b2~cookie <> c1, "cookie advanced")

/* A cookie is bound to the exact query and provider peer; it is not a naked revision. */
r = sync~refreshOnly("dc=example,dc=org", "SUB", "(uid=bob)", attrs, c1)
ignore = .LdapIdentityTest~assert(\r~ok, "cookie query mismatch rejected")
ignore = .LdapIdentityTest~equal("SYNC_REFRESH_REQUIRED", r~code, "query mismatch refresh required")

c2 = b2~cookie
ignore = .LdapIdentityTest~assert(dir~deleteEntity("principal:alice")~ok, "delete alice")
r = sync~refreshOnly("dc=example,dc=org", "SUB", "(uid=alice)", attrs, c2)
ignore = .LdapIdentityTest~assert(r~ok, "delete incremental refresh")
b3 = r~value
ignore = .LdapIdentityTest~equal(1, b3~records~items, "one delete record")
ignore = .LdapIdentityTest~equal("DELETE", b3~records[1]~state, "delete state")
ignore = .LdapIdentityTest~equal(uuidText, b3~records[1]~entryUuid, "delete carries former UUID")
ignore = .LdapIdentityTest~equal(0, b3~records[1]~entry~attributes~names~items, "delete does not invent live attributes")

/* Malformed/foreign/future cookies fail closed to a full refresh requirement. */
r = sync~refreshOnly("dc=example,dc=org", "SUB", "(uid=alice)", attrs, "not-a-cookie")
ignore = .LdapIdentityTest~assert(\r~ok, "malformed cookie rejected")
ignore = .LdapIdentityTest~equal("SYNC_REFRESH_REQUIRED", r~code, "malformed refresh required")

/* RFC 4533 refreshAndPersist uses a Sync Info IntermediateResponse at the
 * refresh/persist boundary.  Keep the ASN.1 CHOICE codec independently
 * qualified from the TCP server. */
infoBytes = .LdapSyncCodec~infoRefresh(.false, "cookie-1", .true)
info = .LdapSyncCodec~decodeInfoValue(infoBytes)
ignore = .LdapIdentityTest~assert(info["ok"], "refresh info decodes")
ignore = .LdapIdentityTest~equal("REFRESH", info["kind"], "refresh info kind")
ignore = .LdapIdentityTest~equal("cookie-1", info["cookie"], "refresh info cookie")
ignore = .LdapIdentityTest~assert(info["refreshDone"], "refresh info completed")
newCookie = .LdapSyncCodec~decodeInfoValue(.LdapSyncCodec~infoNewCookie("cookie-2"))
ignore = .LdapIdentityTest~assert(newCookie["ok"], "newcookie info decodes")
ignore = .LdapIdentityTest~equal("NEW_COOKIE", newCookie["kind"], "newcookie info kind")
ignore = .LdapIdentityTest~equal("cookie-2", newCookie["cookie"], "newcookie info value")
say "LDAP SYNC: OK"
::requires "tests/TestSupport.cls"
::requires "src/LdapSync.cls"
