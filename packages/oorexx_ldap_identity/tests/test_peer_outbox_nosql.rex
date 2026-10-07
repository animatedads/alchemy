root=value("LDAP_NOSQL_TEST_ROOT",,"ENVIRONMENT")
if root="" then raise syntax 88.900 array("LDAP_NOSQL_TEST_ROOT required")
root=root||"-peer-outbox"
/* Use shell only for test workspace cleanup, never product state semantics. */
address system "rm -rf " || root

a=.IdentityDirectory~new("peer-a")
ignore=.LdapIdentityTest~assert(a~createPrincipal("principal:alice","uid=alice,dc=example,dc=org","PERSON","Alice","alice")~ok,"source change")
ch=a~changesSince(0)[1]
req=.IdentityPeerUpdateRequest~new(7,ch,.array~of("peer-b","peer-c"),"QUORUM_COMMITTED")
store=.NoSQLIdentityPeerStateStore~new(root)
ignore=.LdapIdentityTest~assert(store~recordRequest(req)~ok,"persist request")
ack=.IdentityPeerAck~new(req~requestId,"peer-b","APPLIED","",11)
ignore=.LdapIdentityTest~assert(store~recordAck(ack)~ok,"persist ack")

store2=.NoSQLIdentityPeerStateStore~new(root)
loaded=store2~loadRequests
ignore=.LdapIdentityTest~assert(loaded~ok,"reload requests")
ignore=.LdapIdentityTest~equal(1,loaded~value~items,"one request")
copy=loaded~value[1]
ignore=.LdapIdentityTest~equal(req~semanticIdentity,copy~semanticIdentity,"request semantic identity roundtrip")
ignore=.LdapIdentityTest~equal(7,copy~originEpoch,"epoch roundtrip")
ignore=.LdapIdentityTest~assert(copy~createdAt~isA(.DateTime),"createdAt restored DateTime")
acks=store2~loadAcks(req~requestId)
ignore=.LdapIdentityTest~equal(1,acks~value~items,"one ack")
ignore=.LdapIdentityTest~assert(acks~value[1]~ackedAt~isA(.DateTime),"ack time restored DateTime")
ignore=.LdapIdentityTest~equal(11,acks~value[1]~durableRevision,"durable revision roundtrip")

/* Same request ID cannot be rebound to different semantic content. */
otherAfter=.IdentityPrincipal~new("principal:alice","uid=alice,dc=example,dc=org","PERSON","Different","alice")
other=.DirectoryChange~new(ch~changeId,ch~originPeerId,ch~originSequence,ch~localRevision,"ADD",ch~entityId,.nil,otherAfter,ch~createdAt)
bad=.IdentityPeerUpdateRequest~new(7,other,.array~of("peer-b","peer-c"),"QUORUM_COMMITTED",req~requestId)
div=store2~recordRequest(bad)
ignore=.LdapIdentityTest~assert(\div~ok,"divergent request ID rejected")
ignore=.LdapIdentityTest~equal("PEER_REQUEST_DIVERGED",div~code,"divergence code")

caps=store2~capabilities
ignore=.LdapIdentityTest~assert(caps["durable"],"durable capability")
ignore=.LdapIdentityTest~assert(caps["semanticCommitSeparateFromDeliveryState"],"delivery state separated")
address system "rm -rf " || root
say "NOSQL IDENTITY PEER OUTBOX: OK"
::requires "tests/TestSupport.cls"
::requires "src/NoSQLIdentityPeerStateStore.cls"
