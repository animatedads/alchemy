/* dev15 split-brain fencing: epoch authority is bound to the active runtime holder. */
epoch=.IdentityPeerEpochAuthority~new
ignore=.LdapIdentityTest~assert(epoch~activate("peer-a",1,1,"node-a")~ok,"node-a epoch1")
ignore=.LdapIdentityTest~equal("node-a",epoch~currentHolder("peer-a"),"current holder node-a")

active=.IdentityDirectory~new("peer-a")
peer=.IdentityDirectory~new("peer-b")
transport=.MemoryIdentityPeerTransport~new
transport~register("peer-b",.IdentityPeerReceiver~new("peer-b",peer,epoch))
oldCoord=.IdentityPeerCoordinator~new(active,epoch,transport,.MemoryIdentityPeerOutbox~new,"node-a")
ignore=.LdapIdentityTest~assert(active~createPrincipal("principal:alice","uid=alice,dc=example,dc=org","PERSON","Alice","alice")~ok,"epoch1 change")
ch1=active~changesSince(0)[1]
r1=oldCoord~multicastChange(ch1,1,.array~of("peer-b"),.IdentityPeerCommitPolicy~ALL_TARGETS_COMMITTED)
ignore=.LdapIdentityTest~assert(r1~ok,"node-a epoch1 accepted")

ignore=.LdapIdentityTest~assert(epoch~promote("peer-a",2,1,"node-b")~ok,"node-b promoted epoch2")
ignore=.LdapIdentityTest~equal("node-b",epoch~currentHolder("peer-a"),"holder transferred")

/* A stale runtime cannot simply claim the new epoch. */
ignore=.LdapIdentityTest~assert(active~createPrincipal("principal:stale","uid=stale,dc=example,dc=org","PERSON","Stale","stale")~ok,"local stale process can mutate its private copy")
ch2=active~changesSince(1)[1]
stale=oldCoord~multicastChange(ch2,2,.array~of("peer-b"),.IdentityPeerCommitPolicy~ALL_TARGETS_COMMITTED)
ignore=.LdapIdentityTest~assert(\stale~ok,"old node fenced")
ignore=.LdapIdentityTest~equal("PEER_AUTHORITY_HOLDER_FENCED",stale~code,"fence reason explicit")
ignore=.LdapIdentityTest~assert(peer~entryById("principal:stale")==.nil,"stale update never reaches receiver")

/* Replacement holder may continue the logical peer at the promoted epoch. */
replacement=.IdentityPeerCoordinator~new(active,epoch,transport,.MemoryIdentityPeerOutbox~new,"node-b")
r2=replacement~multicastChange(ch2,2,.array~of("peer-b"),.IdentityPeerCommitPolicy~ALL_TARGETS_COMMITTED)
ignore=.LdapIdentityTest~assert(r2~ok,"new holder accepted")
ignore=.LdapIdentityTest~assert(peer~entryById("principal:stale")<>.nil,"promoted holder replicated change")

/* A sealed old-epoch request remains recoverable only by its original holder. */
legacyReq=.IdentityPeerUpdateRequest~new(1,ch1,.array~of("peer-b"),.IdentityPeerCommitPolicy~ALL_TARGETS_COMMITTED,"legacy-replay",.DateTime~new,"node-a")
ack=.IdentityPeerReceiver~new("peer-b",peer,epoch)~receive(legacyReq)
ignore=.LdapIdentityTest~assert(ack~ok,"sealed replay from original holder remains valid")
wrong=.IdentityPeerUpdateRequest~new(1,ch1,.array~of("peer-b"),.IdentityPeerCommitPolicy~ALL_TARGETS_COMMITTED,"wrong-holder",.DateTime~new,"node-x")
ack2=.IdentityPeerReceiver~new("peer-b",peer,epoch)~receive(wrong)
ignore=.LdapIdentityTest~equal("REJECTED",ack2~status,"sealed replay wrong holder rejected")

say "IDENTITY PEER AUTHORITY FENCING: OK"
::requires "tests/TestSupport.cls"
::requires "src/IdentityPeerFabric.cls"
