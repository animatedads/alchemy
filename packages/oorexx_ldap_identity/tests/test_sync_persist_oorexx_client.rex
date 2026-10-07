parse arg port
if port = "" then raise syntax 88.900 array("port required")

client = .LdapWireClient~new("127.0.0.1", port)
ignore = .LdapIdentityTest~assert(client~connect~ok, "client connect")
ignore = .LdapIdentityTest~assert(client~bind("uid=alice,ou=people,dc=example,dc=org", "wire-secret")~ok, "client bind")
r = client~syncRefreshAndPersist("dc=example,dc=org", "SUB", "(uid=alice)", .array~of("uid","cn","entryUUID","oorexxEntityId"))
ignore = .LdapIdentityTest~assert(r~ok, "refreshAndPersist starts")
sub = r~value
ignore = .LdapIdentityTest~equal(1, sub~refreshRecords~items, "one initial refresh entry")
ignore = .LdapIdentityTest~equal("ADD", sub~refreshRecords[1]~state, "initial refresh state")
ignore = .LdapIdentityTest~assert(sub~cookie <> "", "refresh stage cookie")

/* dev9 keeps the persistent search outstanding on this same LDAP association.
 * A point operation may complete while Sync notifications with another message
 * id are interleaved; the DUA demultiplexer retains those frames for sub~next. */
mods = .array~of(.LdapModification~new("REPLACE", "cn", .array~of("Alice Persistent Update")))
ignore = .LdapIdentityTest~assert(client~modify("uid=alice,ou=people,dc=example,dc=org", mods)~ok, "same-association modifier update")
ev = sub~next
ignore = .LdapIdentityTest~assert(ev~ok, "persistent event arrives")
ignore = .LdapIdentityTest~equal("ENTRY", ev~value["kind"], "persistent event kind")
rec = ev~value["record"]
ignore = .LdapIdentityTest~equal("MODIFY", rec~state, "persistent modify state")
ignore = .LdapIdentityTest~equal("Alice Persistent Update", rec~entry~attributes~first("cn"), "persistent current content")
ignore = .LdapIdentityTest~assert(sub~cookie <> "", "persistent cookie retained")

/* RFC 3909 Cancel terminates only the outstanding search.  The LDAP
 * association remains alive and can immediately service a normal search. */
closed = sub~close
ignore = .LdapIdentityTest~assert(closed~ok, "persistent search canceled")
late = client~cancelOperation(sub~messageId)
ignore = .LdapIdentityTest~assert(\late~ok, "repeat cancel refused")
ignore = .LdapIdentityTest~equal("LDAP_CANCEL_TOO_LATE", late~code, "completed search reports tooLate")
post = client~search("dc=example,dc=org", "SUB", "(uid=alice)", .array~of("uid","cn"))
ignore = .LdapIdentityTest~assert(post~ok, "association remains usable after Cancel")
ignore = .LdapIdentityTest~equal(1, post~value~items, "post-cancel search result")
ignore = .LdapIdentityTest~equal("Alice Persistent Update", post~value[1]~attributes~first("cn"), "post-cancel state")
client~unbind
say "LDAP SYNC PERSIST + CANCEL OOREXX CLIENT: OK"

::requires "tests/TestSupport.cls"
::requires "src/LdapWireClient.cls"
