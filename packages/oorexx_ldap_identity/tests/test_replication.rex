a = .IdentityDirectory~new("peer-a")
b = .IdentityDirectory~new("peer-b")
ignore = .LdapIdentityTest~assert(a~createPrincipal("principal:alice", "uid=alice,ou=people,dc=example,dc=org", "PERSON", "Alice", "alice")~ok, "create on a")
changes = a~changesSince(0)
ignore = .LdapIdentityTest~equal(1, changes~items, "one change")
r = b~applyReplicatedChange(changes[1])
ignore = .LdapIdentityTest~assert(r~ok, "apply on b")
ignore = .LdapIdentityTest~equal(a~entryById("principal:alice")~semanticIdentity, b~entryById("principal:alice")~semanticIdentity, "same semantic identity")
r = b~applyReplicatedChange(changes[1])
ignore = .LdapIdentityTest~assert(r~ok, "idempotent replay")
ignore = .LdapIdentityTest~equal("ALREADY_APPLIED", r~detail, "idempotent marker")
ignore = .LdapIdentityTest~assert(a~renameEntity("principal:alice", "uid=alice,ou=staff,dc=example,dc=org")~ok, "rename a")
changes2 = a~changesSince(1)
ignore = .LdapIdentityTest~equal(1, changes2~items, "rename change")
ignore = .LdapIdentityTest~assert(b~applyReplicatedChange(changes2[1])~ok, "rename b")
ignore = .LdapIdentityTest~equal("uid=alice,ou=staff,dc=example,dc=org", b~entryById("principal:alice")~dn, "stable id across dn move")
/* Divergence is fail-closed, not last-writer-wins. */
c = .IdentityDirectory~new("peer-c")
ignore = .LdapIdentityTest~assert(c~createPrincipal("principal:alice", "uid=other,ou=people,dc=example,dc=org", "PERSON", "Other", "alice")~ok, "divergent c")
r = c~applyReplicatedChange(changes2[1])
ignore = .LdapIdentityTest~assert(\r~ok, "divergence refused")
say "REPLICATION: OK"
::requires "tests/TestSupport.cls"
::requires "src/IdentityDirectory.cls"
