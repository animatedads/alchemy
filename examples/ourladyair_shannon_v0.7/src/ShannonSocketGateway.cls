/* Authenticated Queue Fabric TCP ingress for Shannon.
 *
 * This is intentionally a transport boundary, not a second chatbot protocol.
 * The payload is the same PASSENGER_TURN object used by local queue submission.
 * HMAC-authenticated transport can deliver it into SHANNON.INBOUND; the normal
 * queue trigger, Legal Effect and HardWorld path then owns processing.
 */

::class ShannonSocketIngressServer public
::attribute service get
::attribute channelFabric get
::attribute listener get
::attribute managerName get
::attribute receiverChannel get
::attribute sourceManager get
::attribute principal get

::method init
  expose service channelFabric listener managerName receiverChannel sourceManager principal
  use arg serviceArg, keyHex, keyId = 'shannon-k1', bindHost = '127.0.0.1', bindPort = 0, managerNameArg = 'SHANNON.WORKER', sourceManagerArg = 'SHANNON.CLIENT', receiverChannelArg = 'CLIENT.TO.SHANNON', principalArg = 'passenger'
  if serviceArg == .nil then raise syntax 88.900 array('Shannon socket ingress server requires a ShannonQueueService')
  service = serviceArg
  managerName = managerNameArg~string
  receiverChannel = receiverChannelArg~string
  sourceManager = sourceManagerArg~string
  principal = principalArg~string

  channelFabric = .QueueChannelFabric~new(managerName, service~manager, .QueueInProcessTransport~new, 'shannon-admin')
  defineResult = channelFabric~defineReceiverChannel(receiverChannel, sourceManager, principal, 'TEMPORARY', 'shannon-admin')
  if \defineResult~ok then raise syntax 88.900 array('define Shannon receiver channel failed:' defineResult~code || ' ' || defineResult~detail)
  startResult = channelFabric~startReceiverChannel(receiverChannel, 'shannon-admin')
  if \startResult~ok then raise syntax 88.900 array('start Shannon receiver channel failed:' startResult~code || ' ' || startResult~detail)

  listener = .QueueSocketListener~new(managerName, bindHost, bindPort, channelFabric)
  ignored = listener~trustPeer(sourceManager, principal, keyId, keyHex)
  if \listener~start then raise syntax 88.900 array('Shannon socket listener failed:' listener~lastError)

::method port
  expose listener
  return listener~port

::method serveOne
  expose listener
  return listener~serveOne

::method stop
  expose listener
  return listener~stop

::class ShannonSocketIngressClient public
::attribute queueManager get
::attribute transport get
::attribute channelFabric get
::attribute managerName get
::attribute remoteManager get
::attribute receiverChannel get
::attribute principal get

::method init
  expose queueManager transport channelFabric managerName remoteManager receiverChannel principal
  use arg host, port, keyHex, keyId = 'shannon-k1', managerNameArg = 'SHANNON.CLIENT', remoteManagerArg = 'SHANNON.WORKER', receiverChannelArg = 'CLIENT.TO.SHANNON', principalArg = 'passenger'
  managerName = managerNameArg~string
  remoteManager = remoteManagerArg~string
  receiverChannel = receiverChannelArg~string
  principal = principalArg~string

  queueManager = .ObjectQueueManager~new('', .QueueGraphPayloadCodec~new, 'client-admin')
  createResult = queueManager~createQueue('XMIT.SHANNON', 'TEMPORARY', 'OURLADYAIR.CHAT', 100, 'client-admin')
  if \createResult~ok then raise syntax 88.900 array('create Shannon XMIT queue failed:' createResult~code)

  transport = .QueueSocketClientTransport~new('client-admin')
  ignored = transport~registerEndpoint(remoteManager, host, port, principal, keyId, keyHex)
  channelFabric = .QueueChannelFabric~new(managerName, queueManager, transport, 'client-admin')

  senderResult = channelFabric~defineSenderChannel(receiverChannel, 'XMIT.SHANNON', remoteManager, receiverChannel, 'client-admin', principal, 3, 'TEMPORARY', 'client-admin')
  if \senderResult~ok then raise syntax 88.900 array('define Shannon sender channel failed:' senderResult~code || ' ' || senderResult~detail)
  startResult = channelFabric~startSenderChannel(receiverChannel, 'client-admin')
  if \startResult~ok then raise syntax 88.900 array('start Shannon sender channel failed:' startResult~code || ' ' || startResult~detail)

  remoteResult = channelFabric~defineRemoteQueue('REMOTE.SHANNON.INBOUND', 'SHANNON.INBOUND', remoteManager, 'XMIT.SHANNON', receiverChannel, 'OURLADYAIR.CHAT', 'TEMPORARY', 'client-admin', 'client-admin')
  if \remoteResult~ok then raise syntax 88.900 array('define Shannon remote queue failed:' remoteResult~code || ' ' || remoteResult~detail)
  grantResult = channelFabric~grantRemotePut('REMOTE.SHANNON.INBOUND', principal, 'client-admin')
  if \grantResult~ok then raise syntax 88.900 array('grant Shannon remote put failed:' grantResult~code || ' ' || grantResult~detail)

::method submit
  expose channelFabric principal receiverChannel
  use arg text
  payload = .directory~new
  payload['kind'] = 'PASSENGER_TURN'
  payload['text'] = text~string
  options = .table~new
  options['correlationId'] = .DateTime~new~string
  options['securityDomain'] = 'OURLADYAIR.CHAT'
  putResult = channelFabric~put('REMOTE.SHANNON.INBOUND', payload, options, principal)
  if \putResult~ok then return putResult
  return channelFabric~pump(receiverChannel, 1, 'client-admin')

::requires 'ShannonQueueService.cls'
::requires 'ObjectQueueSocketTransport.cls'
