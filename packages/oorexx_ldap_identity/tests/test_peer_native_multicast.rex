/* dev13 semantic multicast carrier qualification. */
a=.IdentityDirectory~new("peer-a")
b=.IdentityDirectory~new("peer-b")
c=.IdentityDirectory~new("peer-c")
epoch=.IdentityPeerEpochAuthority~new
ignore=.LdapIdentityTest~assert(epoch~activate("peer-a",1,1)~ok,"activate peer-a epoch1")

rb=.IdentityPeerReceiver~new("peer-b",b,epoch)
rc=.IdentityPeerReceiver~new("peer-c",c,epoch)
channel=.MemoryIdentityPeerMulticastChannel~new
channel~register("peer-b",rb)~register("peer-c",rc)
channel~setAvailable("peer-c",.false)

/* Targeted unicast is retained for recovery of only the missing peer. */
fallback=.MemoryIdentityPeerTransport~new
fallback~register("peer-b",rb)~register("peer-c",rc)
transport=.IdentityPeerNativeMulticastTransport~new(channel,fallback)
ignore=.LdapIdentityTest~assert(transport~nativeMulticast,"native multicast advertised by this transport")
coord=.IdentityPeerCoordinator~new(a,epoch,transport,.MemoryIdentityPeerOutbox~new)
targets=.array~of("peer-b","peer-c")

ignore=.LdapIdentityTest~assert(a~createPrincipal("principal:alice","uid=alice,dc=example,dc=org","PERSON","Alice","alice")~ok,"local add")
ch=a~changesSince(0)[1]
r=coord~multicastChange(ch,1,targets,.IdentityPeerCommitPolicy~QUORUM_COMMITTED)
ignore=.LdapIdentityTest~assert(r~ok,"one multicast publication obtains quorum")
ignore=.LdapIdentityTest~equal(1,channel~publications,"one carrier publication for two peers")
ignore=.LdapIdentityTest~equal(0,fallback~sends,"initial full fanout does not use unicast")
ignore=.LdapIdentityTest~assert(b~entryById("principal:alice")<>.nil,"B receives multicast request")
ignore=.LdapIdentityTest~assert(c~entryById("principal:alice")==.nil,"unavailable C misses first publication")

/* Durable retry has only C pending.  Do not republish to the whole group. */
channel~setAvailable("peer-c",.true)
retry=coord~retryOutstanding
ignore=.LdapIdentityTest~assert(retry~ok,"outstanding retry succeeds")
ignore=.LdapIdentityTest~equal(1,channel~publications,"retry does not multicast duplicate to already ACKed B")
ignore=.LdapIdentityTest~equal(1,fallback~sends,"retry targets only missing C")
ignore=.LdapIdentityTest~assert(c~entryById("principal:alice")<>.nil,"C recovered by targeted retry")

/* ACKs are explicit portable application evidence, not inferred delivery. */
reqs=coord~outbox~loadRequests
req=reqs~value[1]
ack=rb~receive(req)
json=.IdentityPeerAckCodec~toJson(ack)
ack2=.IdentityPeerAckCodec~fromJson(json)
ignore=.LdapIdentityTest~equal(ack~requestId,ack2~requestId,"ACK request id round trip")
ignore=.LdapIdentityTest~equal(ack~peerId,ack2~peerId,"ACK peer id round trip")
ignore=.LdapIdentityTest~equal(ack~status,ack2~status,"ACK status round trip")
ignore=.LdapIdentityTest~equal(ack~durableRevision,ack2~durableRevision,"ACK revision round trip")

/* SocketProvider bridge publishes the same request body exactly once through
 * the selected multicast address and delegates ACK collection. */
fakeAddress=.PeerMulticastAddressFixture~new
fakeEndpoint=.PeerMulticastEndpointFixture~new
fakeProvider=.PeerMulticastProviderFixture~new(fakeEndpoint)
fakeCollector=.PeerAckCollectorFixture~new(.array~of(ack2))
socketChannel=.SocketProviderIdentityPeerMulticastChannel~new(fakeProvider,fakeAddress,fakeCollector)
published=socketChannel~publish(req,targets)
ignore=.LdapIdentityTest~assert(published~ok,"SocketProvider multicast publish")
ignore=.LdapIdentityTest~equal(1,fakeEndpoint~sends,"one SocketProvider send")
wireReq=.IdentityPeerUpdateCodec~fromJson(fakeEndpoint~payload)
ignore=.LdapIdentityTest~equal(req~semanticIdentity,wireReq~semanticIdentity,"wire request semantic identity preserved")
collected=socketChannel~collectAcks(req,targets)
ignore=.LdapIdentityTest~equal(1,collected~items,"ACK collector remains separate from publication")

say "IDENTITY PEER NATIVE MULTICAST: OK"

::class PeerMulticastAddressFixture
::method multicast
  return .true
::method canonical
  return "norm://239.192.0.36:43601"

::class PeerMulticastEndpointFixture
::method init
  expose sends payload closed
  sends=0; payload=""; closed=.false
::attribute sends get
::attribute payload get
::method send
  expose sends payload
  use strict arg bytes
  sends+=1; payload=bytes
  return length(bytes)
::method waitDrained
  use strict arg timeoutMilliseconds=5000
  return .true
::method close
  expose closed
  closed=.true
  return 0

::class PeerMulticastProviderFixture
::method init
  expose endpoint
  use strict arg endpointArg
  endpoint=endpointArg
::method senderAt
  expose endpoint
  use strict arg address
  return endpoint

::class PeerAckCollectorFixture
::method init
  expose acks
  use strict arg ackArray
  acks=ackArray
::method collect
  expose acks
  use strict arg request, targetIds
  return acks

::requires "tests/TestSupport.cls"
::requires "src/IdentityPeerFabric.cls"
