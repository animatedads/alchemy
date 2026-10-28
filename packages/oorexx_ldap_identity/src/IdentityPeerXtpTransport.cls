/* IdentityPeerXtpTransport.cls - XTP dev18 multicast carrier adapter.
 *
 * LDAP/Identity owns request identity, authority epochs, fencing, durable
 * outbox state and application ACK quorum. XTP owns reliable multicast wire
 * delivery, replay suppression, ALLOC and RATE/BURST pacing. A successful XTP
 * send is transport evidence only; it is never promoted into an LDAP ACK.
 */

::class IdentityPeerXtpBuild public
::constant API_VERSION "identity.peer.xtp-multicast/0.1"
::constant REQUIRED_XTP "xtp/0.1-dev18"

::class IdentityPeerXtpMulticastChannel subclass IdentityPeerMulticastChannel public
::method init
  expose backend address ackCollector reliable segmentBytes timeoutMs retries allocationPacing ratePacing
  use strict arg backendArg, addressArg, ackCollectorArg, reliableArg=.true, segmentArg=1200, timeoutArg=250, retryArg=12, allocationPacingArg=.true, ratePacingArg=.true
  if backendArg == .nil | addressArg == .nil | ackCollectorArg == .nil then raise syntax 88.900 array("XTP multicast channel requires backend, address and ACK collector")
  if \addressArg~multicast then raise syntax 88.900 array("XTP identity peer address must be multicast")
  backend=backendArg; address=addressArg; ackCollector=ackCollectorArg
  reliable=reliableArg; segmentBytes=segmentArg; timeoutMs=timeoutArg; retries=retryArg
  allocationPacing=allocationPacingArg; ratePacing=ratePacingArg
::attribute address get
::method publish
  expose backend address reliable segmentBytes timeoutMs retries allocationPacing ratePacing
  use strict arg request, targetIds
  expected=targetIds~items
  if expected=0 then return .DirectoryResult~success(0,"PEER_XTP_MULTICAST_NOT_REQUIRED")
  if \backend~hasMethod("MULTICASTSENDER") then return .DirectoryResult~failure("PEER_XTP_MULTICAST_UNSUPPORTED")
  sender=backend~multicastSender(address,expected,reliable,segmentBytes,timeoutMs,retries,allocationPacing,ratePacing)
  if sender == .nil then return .DirectoryResult~failure("PEER_XTP_MULTICAST_NO_SENDER")
  payload=.IdentityPeerUpdateCodec~toJson(request)
  sent=sender~send(payload)
  ignore=sender~close
  if sent == .nil then return .DirectoryResult~failure("PEER_XTP_MULTICAST_SEND_FAILED")
  if datatype(sent,"W") then if sent < length(payload) then return .DirectoryResult~failure("PEER_XTP_MULTICAST_SHORT_SEND",sent || "/" || length(payload))
  return .DirectoryResult~success(expected,"PEER_XTP_MULTICAST_PUBLISHED")
::method collectAcks
  expose ackCollector
  use strict arg request, targetIds
  return ackCollector~collect(request,targetIds)

::requires "src/IdentityPeerFabric.cls"
