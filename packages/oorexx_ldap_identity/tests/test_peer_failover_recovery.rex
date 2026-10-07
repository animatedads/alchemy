/* dev12 logical LDAP peer survives coordinator/runtime loss. */
base=value("LDAP_NOSQL_TEST_ROOT",,"ENVIRONMENT")
if base="" then raise syntax 88.900 array("LDAP_NOSQL_TEST_ROOT required")
dirRoot=base||"-failover-directory"
outRoot=base||"-failover-outbox"
address system "rm -rf "||dirRoot||" "||outRoot

epoch=.IdentityPeerEpochAuthority~new
ignore=.LdapIdentityTest~assert(epoch~activate("peer-a",1,1)~ok,"epoch1 active")
b=.IdentityDirectory~new("peer-b")
c=.IdentityDirectory~new("peer-c")
transport=.MemoryIdentityPeerTransport~new
transport~register("peer-b",.IdentityPeerReceiver~new("peer-b",b,epoch))
transport~register("peer-c",.IdentityPeerReceiver~new("peer-c",c,epoch))
transport~setAvailable("peer-c",.false)

aStore=.NoSQLDirectoryStore~new(dirRoot)
a=.IdentityDirectory~new("peer-a",aStore,.true)
out=.NoSQLIdentityPeerStateStore~new(outRoot)
coord=.IdentityPeerCoordinator~new(a,epoch,transport,out)
ignore=.LdapIdentityTest~assert(a~createPrincipal("principal:alice","uid=alice,dc=example,dc=org","PERSON","Alice","alice")~ok,"active A commit")
ch=a~changesSince(0)[1]
pending=coord~multicastChange(ch,1,.array~of("peer-b","peer-c"),.IdentityPeerCommitPolicy~ALL_TARGETS_COMMITTED)
ignore=.LdapIdentityTest~assert(\pending~ok,"all-target update pending while C unavailable")
ignore=.LdapIdentityTest~assert(b~entryById("principal:alice")<>.nil,"B committed before crash")
ignore=.LdapIdentityTest~assert(c~entryById("principal:alice")==.nil,"C missed before crash")

/* External RTO authority promotes the replacement runtime.  Epoch 1 is sealed
 * through sequence 1 so its already-committed request may still be recovered. */
ignore=.LdapIdentityTest~assert(epoch~promote("peer-a",2,1)~ok,"external promotion epoch2")
transport~setAvailable("peer-c",.true)
sendsBefore=transport~sends

/* Process-local A/coordinator state is intentionally discarded and rebuilt
 * exclusively from durable directory + delivery stores. */
a2=.IdentityDirectory~new("peer-a",.NoSQLDirectoryStore~new(dirRoot),.true)
out2=.NoSQLIdentityPeerStateStore~new(outRoot)
coord2=.IdentityPeerCoordinator~new(a2,epoch,transport,out2)
ignore=.LdapIdentityTest~equal(1,a2~revision,"replacement recovered committed revision")
ignore=.LdapIdentityTest~equal("Alice",a2~entryById("principal:alice")~displayName,"replacement recovered identity")
retry=coord2~retryOutstanding
ignore=.LdapIdentityTest~assert(retry~ok,"replacement resumes durable outstanding delivery")
ignore=.LdapIdentityTest~equal(sendsBefore+1,transport~sends,"replacement sends only missing C")
ignore=.LdapIdentityTest~assert(c~entryById("principal:alice")<>.nil,"C receives sealed epoch replay")

/* The replacement remains logical peer-a and continues origin sequence in the
 * promoted epoch rather than creating a new peer identity. */
ignore=.LdapIdentityTest~assert(a2~createPrincipal("principal:bob","uid=bob,dc=example,dc=org","PERSON","Bob","bob")~ok,"post-promotion commit")
ch2=a2~changesSince(1)[1]
ignore=.LdapIdentityTest~equal("peer-a",ch2~originPeerId,"logical peer identity survives failover")
ignore=.LdapIdentityTest~equal(2,ch2~originSequence,"origin sequence survives failover")
r2=coord2~multicastChange(ch2,2,.array~of("peer-b","peer-c"),.IdentityPeerCommitPolicy~ALL_TARGETS_COMMITTED)
ignore=.LdapIdentityTest~assert(r2~ok,"epoch2 update all targets")
ignore=.LdapIdentityTest~assert(b~entryById("principal:bob")<>.nil & c~entryById("principal:bob")<>.nil,"post-failover update replicated")
address system "rm -rf "||dirRoot||" "||outRoot
say "IDENTITY PEER FAILOVER RECOVERY: OK"
::requires "tests/TestSupport.cls"
::requires "src/NoSQLDirectoryStore.cls"
::requires "src/NoSQLIdentityPeerStateStore.cls"
