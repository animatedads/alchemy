/* Deterministic JMS-shaped provider used by FederationBank integration tests.
 * It deliberately models only the provider contract of JMSQueueBridgeService;
 * no Java or broker is involved.  This allows the Queue Fabric and bank
 * boundaries to be tested while BSF4ooRexx/provider jars remain optional. */
::class CaptureJMSProvider public
::attribute connected get
::attribute accepts get
::attribute rejects get
::attribute sends get
::attribute completes get
::attribute aborts get
::attribute lastSentPackage get
::attribute sessionMode get

::method init
  expose inbound connected accepts rejects sends completes aborts lastSentPackage sessionMode
  use arg sessionMode = "CLIENT_ACKNOWLEDGE"
  inbound=.queue~new
  connected=.false
  accepts=0; rejects=0; sends=0; completes=0; aborts=0
  lastSentPackage=.nil
  sessionMode=sessionMode~string~translate

::method enqueue
  expose inbound
  use arg delivery
  inbound~queue(delivery)
  return delivery

::method connect
  expose connected
  connected=.true
  return .JMSBridgeResult~success(.nil,"CONNECTED")

::method close
  expose connected
  connected=.false
  return .JMSBridgeResult~success(.nil,"CLOSED")

::method receive
  expose inbound connected
  use arg timeoutMs=0
  if \connected then return .JMSBridgeResult~failure("JMS_NOT_CONNECTED")
  if inbound~items=0 then return .JMSBridgeResult~success(.nil,"NO_MESSAGE")
  return .JMSBridgeResult~success(inbound~pull,"RECEIVED")

::method acceptInbound
  expose accepts
  use arg delivery
  accepts+=1
  return .JMSBridgeResult~success(delivery,"JMS_CLIENT_ACKNOWLEDGED")

::method rejectInbound
  expose rejects
  use arg delivery
  rejects+=1
  return .JMSBridgeResult~success(delivery,"JMS_CLIENT_RECOVER_REQUESTED")

::method send
  expose sends lastSentPackage connected
  use arg package
  if \connected then return .JMSBridgeResult~failure("JMS_NOT_CONNECTED")
  sends+=1
  lastSentPackage=package
  return .JMSBridgeResult~success(package,"JMS_SEND_RETURNED")

::method completeOutbound
  expose completes
  use arg package
  completes+=1
  return .JMSBridgeResult~success(package,"JMS_NONTRANSACTED_SEND_COMPLETE")

::method abortOutbound
  expose aborts
  use arg package
  aborts+=1
  return .JMSBridgeResult~success(package,"JMS_NONTRANSACTED_NO_ROLLBACK")

::requires "JMSQueueBridge.cls"
