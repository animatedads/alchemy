/* Queue Fabric XTP interactive session wire, candidate1, 2026-10-29.
 * The session provides a protected wire exchange, NOT a durable Queue Fabric
 * application acknowledgement. QueueXtpReceiptGate owns the latter.
 *
 * Inject authoritative service descriptor (peer, service), actual XtpSession
 * class, queue.transport/2 encoder and QueueOperationResult class.
 */
::class QueueXtpSessionArtifact public
::attribute payload get
::attribute service get
::attribute peer get
::attribute protection get
::attribute keyId get
::method init
  expose payload service peer protection keyId
  use strict arg replyBytes, serviceName, peerName, mode, keyIdentity
  payload=replyBytes;service=serviceName;peer=peerName;protection=mode;keyId=keyIdentity

::class QueueXtpSessionWire public
::method init
  expose sessionFactory requestCodec resultClass routePeer serviceName openTimeout ioTimeout maxResponse
  use strict arg factory, codec, resultType, peer, service, openMs=3000, ioMs=5000, maxReply=8388608
  if factory==.nil | \factory~hasMethod('OPEN') then raise syntax 88.900 array('XTP factory missing OPEN')
  if codec==.nil | \codec~hasMethod('ENCODEDELIVERY') then raise syntax 88.900 array('Queue codec missing ENCODEDELIVERY')
  if resultType==.nil | \resultType~hasMethod('SUCCESS') | \resultType~hasMethod('FAILURE') then raise syntax 88.900 array('Queue result class required')
  if peer~string~strip='' | service~string~strip='' then raise syntax 88.900 array('Service peer and name required')
  if \datatype(openMs,'W') | openMs<1 | \datatype(ioMs,'W') | ioMs<1 then raise syntax 88.900 array('Bounded timeouts required')
  if \datatype(maxReply,'W') | maxReply<1 | maxReply>8388608 then raise syntax 88.900 array('Invalid response bound')
  sessionFactory=factory;requestCodec=codec;resultClass=resultType
  routePeer=peer~string~strip;serviceName=service~string~strip
  openTimeout=openMs;ioTimeout=ioMs;maxResponse=maxReply
::method deliver
  expose sessionFactory requestCodec resultClass routePeer serviceName openTimeout ioTimeout maxResponse
  use strict arg remoteManager, remoteChannel, envelope, principal
  if envelope==.nil then return resultClass~failure('INVALID_TRANSMISSION_ENVELOPE')
  if remoteManager~string~strip='' | remoteChannel~string~strip='' | principal~string~strip='' then return resultClass~failure('INVALID_CHANNEL_IDENTITY')
  signal on syntax name failed
  encoded=requestCodec~encodeDelivery(remoteManager,remoteChannel,envelope,principal)
  if encoded==.nil then return resultClass~failure('INVALID_QUEUE_REQUEST')
  encoded=encoded~string
  if encoded~length=0 | encoded~length>8388608 then return resultClass~failure('INVALID_QUEUE_REQUEST_SIZE')
  session=sessionFactory~open(routePeer,serviceName,openTimeout,'encrypt')
  if session==.nil then return resultClass~failure('XTP_SESSION_UNAVAILABLE')
  meta=session~info
  if meta==.nil then do
    ignore=session~abort
    return resultClass~failure('XTP_SESSION_UNVERIFIED','metadata absent')
  end
  protect=meta['PROTECTION'];actualService=meta['SERVICE'];actualPeer=meta['PEER'];keyId=meta['KEYID']
  if protect==.nil | actualService==.nil | actualPeer==.nil | keyId==.nil then do
    ignore=session~abort
    return resultClass~failure('XTP_SESSION_UNVERIFIED','incomplete metadata')
  end
  if protect~string~lower<>'encrypt' | actualService~string<>serviceName | actualPeer~string<>routePeer | keyId~string~strip='' then do
    ignore=session~abort
    return resultClass~failure('XTP_SESSION_IDENTITY_MISMATCH')
  end
  written=session~write(encoded,.true,ioTimeout)
  if \datatype(written,'W') | written<>encoded~length then do
    ignore=session~abort
    return resultClass~failure('XTP_WRITE_UNCERTAIN')
  end
  reply=''
  do forever
    remaining=maxResponse-reply~length
    if remaining<0 then do
      ignore=session~abort
      return resultClass~failure('XTP_RESPONSE_TOO_LARGE')
    end
    requested=65536
    if remaining<requested then requested=remaining+1
    part=session~read(requested,ioTimeout)
    if part==.nil then do
      ignore=session~abort
      return resultClass~failure('XTP_RESPONSE_UNCERTAIN','missing part')
    end
    reply=reply||part~string
    marker=session~lastFlag
    if reply~length>maxResponse then do
      ignore=session~abort
      return resultClass~failure('XTP_RESPONSE_TOO_LARGE')
    end
    if marker='TIMEOUT' | marker='END' then do
      ignore=session~abort
      return resultClass~failure('XTP_RESPONSE_UNCERTAIN',marker)
    end
    if marker='EOM' then leave
    if marker<>'' | part~length=0 then do
      ignore=session~abort
      return resultClass~failure('XTP_RESPONSE_UNCERTAIN','no progress')
    end
  end
  ignore=session~close(1000)
  if reply~length=0 then return resultClass~failure('XTP_RESPONSE_UNCERTAIN','empty reply')
  return resultClass~success(.QueueXtpSessionArtifact~new(reply,serviceName,routePeer,protect,keyId),'application reply not yet verified')
failed:
  signal off syntax
  if var('session') then do
    if session<>.nil then do
      signal on syntax name abortFailed
      ignore=session~abort
      signal off syntax
    end
  end
  return resultClass~failure('XTP_RESPONSE_UNCERTAIN','session or codec exception')
abortFailed:
  signal off syntax
  return resultClass~failure('XTP_RESPONSE_UNCERTAIN','abort failure')
