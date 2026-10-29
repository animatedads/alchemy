/* dev15 XTP dev18 carrier contract without confusing XTP delivery with LDAP ACK. */
a=.IdentityDirectory~new("peer-a")
b=.IdentityDirectory~new("peer-b")
c=.IdentityDirectory~new("peer-c")
epoch=.IdentityPeerEpochAuthority~new
ignore=.LdapIdentityTest~assert(epoch~activate("peer-a",1,1,"node-a")~ok,"node-a owns epoch1")
rb=.IdentityPeerReceiver~new("peer-b",b,epoch)
rc=.IdentityPeerReceiver~new("peer-c",c,epoch)
acks=.PeerXtpAckCollector~new(.array~of(rb,rc))
backend=.PeerXtpBackendFixture~new
address=.PeerXtpAddressFixture~new
channel=.IdentityPeerXtpMulticastChannel~new(backend,address,acks)
fallback=.MemoryIdentityPeerTransport~new
fallback~register("peer-b",rb)~register("peer-c",rc)
transport=.IdentityPeerNativeMulticastTransport~new(channel,fallback)
coord=.IdentityPeerCoordinator~new(a,epoch,transport,.MemoryIdentityPeerOutbox~new,"node-a")

ignore=.LdapIdentityTest~assert(a~createPrincipal("principal:alice","uid=alice,dc=example,dc=org","PERSON","Alice","alice")~ok,"local change")
ch=a~changesSince(0)[1]
r=coord~multicastChange(ch,1,.array~of("peer-b","peer-c"),.IdentityPeerCommitPolicy~ALL_TARGETS_COMMITTED)
ignore=.LdapIdentityTest~assert(r~ok,"application ACKs satisfy all-target commit")
ignore=.LdapIdentityTest~equal(1,backend~senderRequests,"single XTP multicast sender allocation")
ignore=.LdapIdentityTest~equal(2,backend~expectedReceivers,"target population passed to XTP")
ignore=.LdapIdentityTest~equal(1,backend~sends,"single XTP carrier send")
ignore=.LdapIdentityTest~assert(backend~allocationPacing,"XTP allocation pacing retained")
ignore=.LdapIdentityTest~assert(backend~ratePacing,"XTP RATE/BURST pacing retained")
wire=.IdentityPeerUpdateCodec~fromJson(backend~payload)
ignore=.LdapIdentityTest~equal("node-a",wire~authorityHolderId,"authority holder crosses XTP wire")
ignore=.LdapIdentityTest~equal(ch~semanticIdentity,wire~change~semanticIdentity,"change identity preserved")
ignore=.LdapIdentityTest~assert(b~entryById("principal:alice")<>.nil & c~entryById("principal:alice")<>.nil,"ACK collector applies at receivers")

say "IDENTITY PEER XTP MULTICAST: OK"

::class PeerXtpAddressFixture
::method multicast
  return .true
::method canonical
  return "xtp-multicast://identity-cluster"
::method xtpAddress
  return "IDENTITY-CLUSTER"

::class PeerXtpBackendFixture
::method init
  expose senderRequests expectedReceivers sends payload allocationPacing ratePacing
  senderRequests=0; expectedReceivers=0; sends=0; payload=""; allocationPacing=.false; ratePacing=.false
::attribute senderRequests get
::attribute expectedReceivers get
::attribute sends get
::attribute payload get
::attribute allocationPacing get
::attribute ratePacing get
::method multicastSender
  expose senderRequests expectedReceivers allocationPacing ratePacing
  use strict arg address, expected, reliable=.true, segment=1200, timeout=250, retries=12, allocation=.true, rate=.true
  senderRequests+=1; expectedReceivers=expected; allocationPacing=allocation; ratePacing=rate
  return .PeerXtpSenderFixture~new(self)
::method recordSend
  expose sends payload
  use strict arg bytes
  sends+=1; payload=bytes
  return length(bytes)

::class PeerXtpSenderFixture
::method init
  expose owner
  use strict arg ownerArg
  owner=ownerArg
::method send
  expose owner
  use strict arg bytes
  return owner~recordSend(bytes)
::method close
  return 0

::class PeerXtpAckCollector
::method init
  expose receivers
  use strict arg receiverArray
  receivers=receiverArray
::method collect
  expose receivers
  use strict arg request, targetIds
  wanted=.directory~new
  do p over targetIds; wanted[p~string]=.true; end
  out=.array~new
  do receiver over receivers
    ack=receiver~receive(request)
    if wanted~hasIndex(ack~peerId) then out~append(ack)
  end
  return out

::requires "tests/TestSupport.cls"
::requires "src/IdentityPeerXtpTransport.cls"
