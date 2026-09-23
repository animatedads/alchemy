parse arg port
if port = "" then port = 1389
client = .LdapWireClient~new("127.0.0.1", port)
say "WIRE STEP connect"
r = client~connect
ignore = .LdapIdentityTest~assert(r~ok, "connect")
/* Root DSE is protocol discovery, not directory authority. */
say "WIRE STEP root-dse"
r = client~search("", "BASE", "(objectClass=*)", .array~of("namingContexts", "supportedLDAPVersion", "vendorName", "supportedControl", "supportedExtension", "supportedSASLMechanisms", "subschemaSubentry"))
ignore = .LdapIdentityTest~assert(r~ok, "root DSE search")
ignore = .LdapIdentityTest~equal(1, r~value~items, "one root DSE")
root = r~value[1]
ignore = .LdapIdentityTest~equal("3", root~attributes~first("supportedLDAPVersion"), "LDAPv3")
ignore = .LdapIdentityTest~equal(.LdapSyncBuild~REQUEST_OID, root~attributes~first("supportedControl"), "RFC4533 Sync advertised")
hasPaging = .false
do oid over root~attributes~get("supportedControl"); if oid = .LdapPagingBuild~CONTROL_OID then hasPaging = .true; end
ignore = .LdapIdentityTest~assert(hasPaging, "RFC2696 paging advertised")
ignore = .LdapIdentityTest~equal(.LdapCancelBuild~CANCEL_OID, root~attributes~first("supportedExtension"), "RFC3909 Cancel advertised")
ignore = .LdapIdentityTest~equal("PLAIN", root~attributes~first("supportedSASLMechanisms"), "SASL personality advertised")
ignore = .LdapIdentityTest~equal("cn=subschema", root~attributes~first("subschemaSubentry"), "subschema advertised")
say "WIRE STEP subschema"
r = client~search("cn=subschema", "BASE", "(objectClass=subschema)", .array~of("cn", "objectClasses", "attributeTypes"))
ignore = .LdapIdentityTest~assert(r~ok, "subschema search")
ignore = .LdapIdentityTest~equal(1, r~value~items, "one subschema entry")
ignore = .LdapIdentityTest~assert(r~value[1]~attributes~get("objectClasses")~items >= 8, "subschema object classes")
/* Bind authenticates only; fixture ACLs separately authorize operations. */
say "WIRE STEP alice-bind"
r = client~bind("uid=alice,ou=people,dc=example,dc=org", "wire-secret")
ignore = .LdapIdentityTest~assert(r~ok, "bind")
say "WIRE STEP paging"
p1 = client~searchPage("dc=example,dc=org","SUB","(objectClass=*)",.array~of("oorexxEntityId"),2)
ignore = .LdapIdentityTest~assert(p1~ok,"paged first page")
ignore = .LdapIdentityTest~equal(2,p1~value~entries~items,"paged first count")
ignore = .LdapIdentityTest~assert(p1~value~cookie <> "","paged first cookie")
pc1 = p1~value~cookie
p2 = client~searchPage("dc=example,dc=org","SUB","(objectClass=*)",.array~of("oorexxEntityId"),3,pc1)
ignore = .LdapIdentityTest~assert(p2~ok,"paged second page")
ignore = .LdapIdentityTest~equal(3,p2~value~entries~items,"paged changed page size")
ignore = .LdapIdentityTest~assert(p2~value~cookie <> "" & p2~value~cookie <> pc1,"paged cookie rotation")
pc2 = p2~value~cookie
stale = client~searchPage("dc=example,dc=org","SUB","(objectClass=*)",.array~of("oorexxEntityId"),2,pc1)
ignore = .LdapIdentityTest~assert(\stale~ok,"old paged cookie refused")
ignore = .LdapIdentityTest~equal("LDAP_RESULT_53",stale~code,"old paged cookie unwillingToPerform")
abandoned = client~abandonPagedSearch("dc=example,dc=org","SUB","(objectClass=*)",.array~of("oorexxEntityId"),pc2)
ignore = .LdapIdentityTest~assert(abandoned~ok,"paged search abandoned")
ignore = .LdapIdentityTest~assert(abandoned~value~abandoned,"paged abandon response")
say "WIRE STEP sync-initial"
sync = client~syncRefreshOnly("dc=example,dc=org", "SUB", "(uid=alice)", .array~of("uid", "entryUUID", "oorexxEntityId"))
ignore = .LdapIdentityTest~assert(sync~ok, "initial Sync refreshOnly")
ignore = .LdapIdentityTest~equal(1, sync~value~records~items, "initial Sync count")
ignore = .LdapIdentityTest~equal("ADD", sync~value~records[1]~state, "initial Sync state")
syncCookie = sync~value~cookie
syncUuid = sync~value~records[1]~entryUuid
ignore = .LdapIdentityTest~equal(36, syncUuid~length, "Sync state UUID text")
mods = .array~of(.LdapModification~new("REPLACE", "cn", .array~of("Alice Synced")))
r = client~modify("uid=alice,ou=people,dc=example,dc=org", mods)
ignore = .LdapIdentityTest~assert(r~ok, "modify between Sync refreshes")
say "WIRE STEP sync-incremental"
sync2 = client~syncRefreshOnly("dc=example,dc=org", "SUB", "(uid=alice)", .array~of("uid", "entryUUID", "oorexxEntityId"), syncCookie)
ignore = .LdapIdentityTest~assert(sync2~ok, "incremental Sync refreshOnly")
ignore = .LdapIdentityTest~equal(1, sync2~value~records~items, "incremental Sync count")
ignore = .LdapIdentityTest~equal("MODIFY", sync2~value~records[1]~state, "incremental Sync state")
ignore = .LdapIdentityTest~equal(syncUuid, sync2~value~records[1]~entryUuid, "Sync UUID stable across modification")
ignore = .LdapIdentityTest~assert(sync2~value~cookie <> syncCookie, "Sync cookie advanced")
say "WIRE STEP alice-search"
r = client~search("dc=example,dc=org", "SUB", "(uid=alice)", .array~of("uid", "cn", "entryUUID"))
ignore = .LdapIdentityTest~assert(r~ok, "search")
ignore = .LdapIdentityTest~equal(1, r~value~items, "alice count")
ignore = .LdapIdentityTest~equal("alice", r~value[1]~attributes~first("uid"), "alice uid")
say "WIRE STEP complex-filter"
r = client~search("dc=example,dc=org", "SUB", "(&(objectClass=oorexxPrincipal)(|(uid=alice)(uid=nobody))(!(cn=Nobody))(cn=Alice*))", .array~of("uid", "cn"))
ignore = .LdapIdentityTest~assert(r~ok, "complex RFC4515-style filter over wire")
ignore = .LdapIdentityTest~equal(1, r~value~items, "complex filter count")
say "WIRE STEP alice-compare"
r = client~compare("uid=alice,ou=people,dc=example,dc=org", "uid", "alice")
ignore = .LdapIdentityTest~assert(r~ok, "compare operation")
ignore = .LdapIdentityTest~assert(r~value, "compare true")
/* Exercise mutation via the wire personality without vendor semantics in core. */
a = .LdapAttributeSet~new
a~add("objectClass", "top")
a~add("objectClass", "oorexxPrincipal")
a~put("oorexxEntityId", "principal:temp")
a~put("oorexxEntryKind", "PRINCIPAL")
a~put("oorexxPrincipalType", "SERVICE")
a~put("cn", "Temporary Service")
a~put("uid", "temp")
say "WIRE STEP add"
r = client~add(.LdapEntry~new("uid=temp,ou=people,dc=example,dc=org", a))
if \r~ok then say "WIRE ADD FAILURE code=" || r~code || " detail=" || r~detail
ignore = .LdapIdentityTest~assert(r~ok, "wire add")
mods = .array~new
mods~append(.LdapModification~new("REPLACE", "uid", .array~of("temp-updated")))
say "WIRE STEP modify"
r = client~modify("uid=temp,ou=people,dc=example,dc=org", mods)
if \r~ok then say "WIRE MODIFY FAILURE code=" || r~code || " detail=" || r~detail
ignore = .LdapIdentityTest~assert(r~ok, "wire modify")
say "WIRE STEP modify-dn"
r = client~modifyDn("uid=temp,ou=people,dc=example,dc=org", "uid=temp2")
if \r~ok then say "WIRE MODIFYDN FAILURE code=" || r~code || " detail=" || r~detail
ignore = .LdapIdentityTest~assert(r~ok, "wire modifyDN")
say "WIRE STEP renamed-search"
r = client~search("dc=example,dc=org", "SUB", "(uid=temp-updated)", .array~of("uid", "entryUUID", "oorexxEntityId"))
ignore = .LdapIdentityTest~assert(r~ok, "search renamed stable entity")
ignore = .LdapIdentityTest~equal(1, r~value~items, "renamed entity exists")
ignore = .LdapIdentityTest~equal("uid=temp2,ou=people,dc=example,dc=org", r~value[1]~dn, "DN changed")
ignore = .LdapIdentityTest~equal("principal:temp", r~value[1]~attributes~first("oorexxEntityId"), "semantic identity survives rename")
entryUuid = r~value[1]~attributes~first("entryUUID")
ignore = .LdapIdentityTest~equal(36, entryUuid~length, "LDAP entryUUID syntax")
say "WIRE STEP delete"
r = client~delete("uid=temp2,ou=people,dc=example,dc=org")
if \r~ok then say "WIRE DELETE FAILURE code=" || r~code || " detail=" || r~detail
ignore = .LdapIdentityTest~assert(r~ok, "wire delete")
client~unbind
/* A second authenticated principal has no ACL. Real-wire Bind still does not
 * imply search authority. */
say "WIRE STEP bob"
bob = .LdapWireClient~new("127.0.0.1", port)
ignore = .LdapIdentityTest~assert(bob~connect~ok, "bob connect")
ignore = .LdapIdentityTest~assert(bob~bind("uid=bob,ou=people,dc=example,dc=org", "bob-secret")~ok, "bob bind")
r = bob~search("dc=example,dc=org", "SUB", "(uid=bob)", .array~of("uid"))
ignore = .LdapIdentityTest~assert(\r~ok, "authenticated bob still denied search")
ignore = .LdapIdentityTest~equal("LDAP_RESULT_50", r~code, "wire insufficient access")
bob~unbind
say "LDAP WIRE OOREXX CLIENT: OK"
::requires "tests/TestSupport.cls"
::requires "src/LdapWireClient.cls"
