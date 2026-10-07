/* dev12 logical peer/request-multicast/epoch qualification. */
a=.IdentityDirectory~new("peer-a")
b=.IdentityDirectory~new("peer-b")
c=.IdentityDirectory~new("peer-c")
epoch=.IdentityPeerEpochAuthority~new
ignore=.LdapIdentityTest~assert(epoch~activate("peer-a",1,1)~ok,"activate peer-a epoch1")
transport=.MemoryIdentityPeerTransport~new
transport~register("peer-b",.IdentityPeerReceiver~new("peer-b",b,epoch))
transport~register("peer-c",.IdentityPeerReceiver~new("peer-c",c,epoch))
outbox=.MemoryIdentityPeerOutbox~new
coord=.IdentityPeerCoordinator~new(a,epoch,transport,outbox)
targets=.array~of("peer-b","peer-c")

/* One semantic request fans out. Quorum of A/B/C requires one remote ACK. */
ignore=.LdapIdentityTest~assert(a~createPrincipal("principal:alice","uid=alice,ou=people,dc=example,dc=org","PERSON","Alice","alice")~ok,"local add")
ch=a~changesSince(0)[1]
transport~setAvailable("peer-c",.false)
r=coord~multicastChange(ch,1,targets,.IdentityPeerCommitPolicy~QUORUM_COMMITTED)
ignore=.LdapIdentityTest~assert(r~ok,"quorum with one remote")
ignore=.LdapIdentityTest~equal("QUORUM_COMMITTED",r~detail,"quorum marker")
ignore=.LdapIdentityTest~equal(a~entryById("principal:alice")~semanticIdentity,b~entryById("principal:alice")~semanticIdentity,"B receives one semantic update")
ignore=.LdapIdentityTest~assert(c~entryById("principal:alice")==.nil,"C unavailable")
reqs=outbox~loadRequests
ignore=.LdapIdentityTest~equal(1,reqs~value~items,"one request in outbox")
req=reqs~value[1]
ignore=.LdapIdentityTest~equal("peer-a:epoch=1:change=peer-a:1",req~requestId,"stable request identity")
ignore=.LdapIdentityTest~equal(2,req~targets~items,"same request owns both targets")

/* Recovery retries only missing targets, not an already acknowledged peer. */
sendsBefore=transport~sends
transport~setAvailable("peer-c",.true)
retry=coord~retryOutstanding
ignore=.LdapIdentityTest~assert(retry~ok,"retry outstanding")
ignore=.LdapIdentityTest~equal(sendsBefore+1,transport~sends,"only missing C resent")
ignore=.LdapIdentityTest~equal(a~entryById("principal:alice")~semanticIdentity,c~entryById("principal:alice")~semanticIdentity,"C recovered")

/* Duplicate delivery is idempotent and does not create a new local revision. */
revB=b~revision
ack=.IdentityPeerReceiver~new("peer-b",b,epoch)~receive(req)
ignore=.LdapIdentityTest~assert(ack~ok,"duplicate ACK is successful")
ignore=.LdapIdentityTest~equal("ALREADY_APPLIED",ack~status,"duplicate status")
ignore=.LdapIdentityTest~equal(revB,b~revision,"duplicate does not advance revision")

/* Same change ID with different semantic content fails closed before mutation. */
tamperedAfter=.IdentityPrincipal~new("principal:alice","uid=alice,ou=people,dc=example,dc=org","PERSON","Mallory","alice")
tampered=.DirectoryChange~new(ch~changeId,ch~originPeerId,ch~originSequence,ch~localRevision,"ADD",ch~entityId,.nil,tamperedAfter,ch~createdAt)
tamperedReq=.IdentityPeerUpdateRequest~new(1,tampered,.array~of("peer-b"),"LOCAL_COMMITTED",req~requestId)
tack=.IdentityPeerReceiver~new("peer-b",b,epoch)~receive(tamperedReq)
ignore=.LdapIdentityTest~assert(\tack~ok,"divergent duplicate rejected")
ignore=.LdapIdentityTest~assert(tack~detail~pos("REPLICATION_CHANGE_ID_DIVERGED")>0,"divergence code retained")

/* Seal epoch 1 at sequence 1. Old committed replay remains legal, future stale writes do not. */
ignore=.LdapIdentityTest~assert(epoch~promote("peer-a",2,1)~ok,"promote epoch2")
oldAck=.IdentityPeerReceiver~new("peer-b",b,epoch)~receive(req)
ignore=.LdapIdentityTest~assert(oldAck~ok,"sealed committed replay allowed")
staleAfter=.IdentityPrincipal~new("principal:stale","uid=stale,ou=people,dc=example,dc=org","PERSON","Stale","stale")
stale=.DirectoryChange~new("peer-a:2","peer-a",2,2,"ADD","principal:stale",.nil,staleAfter)
staleReq=.IdentityPeerUpdateRequest~new(1,stale,.array~of("peer-b"))
staleAck=.IdentityPeerReceiver~new("peer-b",b,epoch)~receive(staleReq)
ignore=.LdapIdentityTest~assert(\staleAck~ok,"future write from sealed epoch rejected")
ignore=.LdapIdentityTest~assert(staleAck~detail~pos("STALE_EPOCH_SEQUENCE_OUTSIDE_SEAL")>0,"stale epoch reason")

/* New logical ACTIVE keeps peer-a identity, continuing sequence under epoch 2. */
ignore=.LdapIdentityTest~assert(a~createPrincipal("principal:bob","uid=bob,ou=people,dc=example,dc=org","PERSON","Bob","bob")~ok,"new epoch local change")
ch2=a~changesSince(1)[1]
ignore=.LdapIdentityTest~equal(2,ch2~originSequence,"origin sequence continuity")
r2=coord~multicastChange(ch2,2,targets,.IdentityPeerCommitPolicy~ALL_TARGETS_COMMITTED)
ignore=.LdapIdentityTest~assert(r2~ok,"all targets committed")
ignore=.LdapIdentityTest~equal("ALL_TARGETS_COMMITTED",r2~detail,"all marker")
ignore=.LdapIdentityTest~assert(b~entryById("principal:bob")<>.nil & c~entryById("principal:bob")<>.nil,"new epoch reaches both")

say "IDENTITY PEER FABRIC: OK"
::requires "tests/TestSupport.cls"
::requires "src/IdentityPeerFabric.cls"
