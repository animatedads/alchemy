/* Opt-in real BSF4ooRexx + ActiveMQ edge test.
 * Requires a live broker URL supplied as argv and javax.jms/ActiveMQ on CLASSPATH.
 * It never depends on Queue Fabric: this test isolates the Java/JMS adapter seam. */
signal on syntax name failed
parse arg brokerUrl
if brokerUrl = "" then do
  say "FAIL missing broker URL"
  exit 2
end

inQueue = "fb.dev7.edge.in"
outQueue = "fb.dev7.edge.out"
config = .JMSBridgeConfig~new("fb-live-edge", "GENERIC", brokerUrl, "ConnectionFactory", -
  "dynamicQueues/" || inQueue, "dynamicQueues/" || outQueue, "", "", "", "", "", "bridge", -
  .false, 2000, "REJECT", "org.apache.activemq.jndi.ActiveMQInitialContextFactory", "CLIENT_ACKNOWLEDGE", "ADMINISTERED")
provider = .JMSBSFProvider~new(config, .nil)
r = provider~connect
call assert r~ok, "bridge provider connect: " || r~code || " " || r~detail

/* Independent JMS peer using the real ActiveMQ client. */
Factory = bsf.importClass("org.apache.activemq.ActiveMQConnectionFactory")
cf = Factory~new(brokerUrl)
peerConnection = cf~createConnection
peerSession = peerConnection~createSession(.false, 1)
inDest = peerSession~createQueue(inQueue)
outDest = peerSession~createQueue(outQueue)
inProducer = peerSession~createProducer(inDest)
outConsumer = peerSession~createConsumer(outDest)
peerConnection~bsf.invoke("start")

/* Real Java MapMessage -> bridge -> Java-free durable shape. */
inbound = peerSession~createMapMessage
inbound~setString("protocolVersion", "IJCIB-CIP/0.1")
inbound~setString("bureauReference", "LIVE-BSF-REF-1")
inbound~setStringProperty("IJCIB_OVERALL_DISPOSITION", "INTELLIGENCE_PRODUCT_RELEASED_WITH_QUALIFICATIONS")
inbound~setStringProperty("IJCIB_REASON_CODE_TREE", "IJCIB.OPAQUE.7|IJCIB.OPAQUE.11")
inbound~setJMSCorrelationID("LIVE-CORR-IN-1")
inbound~setJMSType("IJCIB_REPLY")
inProducer~bsf.invoke("send", inbound)

received = provider~receive(3000)
call assert received~ok, "bridge receive: " || received~code || " " || received~detail
call assert received~value \== .nil, "bridge received message"
delivery = received~value
bm = delivery~message
call assert bm~bodyType = "MAP", "inbound body type MAP"
call assert bm~body["protocolVersion"] = "IJCIB-CIP/0.1", "inbound map protocol"
call assert bm~body["bureauReference"] = "LIVE-BSF-REF-1", "inbound map bureau ref"
call assert bm~properties["IJCIB_REASON_CODE_TREE"] = "IJCIB.OPAQUE.7|IJCIB.OPAQUE.11", "inbound property forwarding"
call assert bm~headers["JMSCORRELATIONID"] = "LIVE-CORR-IN-1", "inbound correlation"
call assert bm~headers["JMSTYPE"] = "IJCIB_REPLY", "inbound JMS type"
call assert provider~acceptInbound(delivery)~ok, "CLIENT_ACKNOWLEDGE settlement"

/* Java-free MAP -> bridge -> real broker MapMessage. */
body = .directory~new
body["requestId"] = "LIVE-REQ-1"
body["requestedProductCode"] = "FB-IJCIB-FIXTURE-GBP"
props = .directory~new
props["IJCIB_PROTOCOL_VERSION"] = "IJCIB-CIR/0.1"
props["IJCIB_REQUEST_ID"] = "LIVE-REQ-1"
props["AlchemyTransferId"] = "SPOOF-MUST-NOT-WIN"
props["AlchemyQueue"] = "SPOOF-QUEUE-MUST-NOT-WIN"
headers = .directory~new
headers["JMSCORRELATIONID"] = "LIVE-CORR-OUT-1"
headers["JMSTYPE"] = "IJCIB_REQUEST"
bridgeMessage = .JMSBridgeMessage~new("", "MAP", body, headers, props, "FEDERATIONBANK", outQueue)
package = .LiveBridgePackage~new("PKG-LIVE-1", "FB.OUT", "", bridgeMessage)
sent = provider~send(package)
call assert sent~ok, "bridge send: " || sent~code || " " || sent~detail
call assert sent~code = "JMS_SEND_RETURNED", "non-transacted send return code"

jmsg = outConsumer~receive(3000)
call assert jmsg \== .nil, "peer received outbound message"
call assert jmsg~bsf.isA("javax.jms.MapMessage"), "outbound real MapMessage"
call assert jmsg~getString("requestId")~string = "LIVE-REQ-1", "outbound map request id"
call assert jmsg~getString("requestedProductCode")~string = "FB-IJCIB-FIXTURE-GBP", "outbound map product"
call assert jmsg~getStringProperty("IJCIB_PROTOCOL_VERSION")~string = "IJCIB-CIR/0.1", "outbound application property"
call assert jmsg~getStringProperty("AlchemyTransferId")~string = "PKG-LIVE-1", "reserved transfer id protected"
call assert jmsg~getStringProperty("AlchemyQueue")~string = "FB.OUT", "reserved queue protected"
call assert jmsg~getJMSCorrelationID~string = "LIVE-CORR-OUT-1", "outbound envelope correlation fallback"
call assert jmsg~getJMSType~string = "IJCIB_REQUEST", "outbound JMS type"

/* Existing candidate semantics: Queue Fabric package correlation wins when present. */
textHeaders = .directory~new
textHeaders["JMSCORRELATIONID"] = "HEADER-LOSES"
textMessage = .JMSBridgeMessage~new("", "TEXT", "hello-live", textHeaders, .directory~new, "TEST", outQueue)
textPackage = .LiveBridgePackage~new("PKG-LIVE-2", "FB.OUT", "PACKAGE-CORR-WINS", textMessage)
call assert provider~send(textPackage)~ok, "TEXT send"
tmsg = outConsumer~receive(3000)
call assert tmsg \== .nil, "peer received TEXT"
call assert tmsg~bsf.isA("javax.jms.TextMessage"), "outbound real TextMessage"
call assert tmsg~getText~string = "hello-live", "TEXT body retained"
call assert tmsg~getJMSCorrelationID~string = "PACKAGE-CORR-WINS", "package correlation precedence retained"

call assert provider~close~ok, "provider close"
inProducer~close
outConsumer~close
peerSession~close
peerConnection~close
say "JMS BRIDGE FEDERATIONBANK REAL BSF/ACTIVEMQ EDGE PASS 24"
exit 0

failed:
  say "FAIL syntax:" condition("D")
  if .BSF_ERROR_MESSAGE \== .nil then say .BSF_ERROR_MESSAGE
  exit 1

assert: procedure
  use arg ok, label
  if \ok then do
    say "FAIL:" label
    exit 1
  end
return

::class LiveBridgePackage public
::attribute packageId get
::attribute currentQueue get
::attribute correlationId get
::attribute payload get
::method init
  expose packageId currentQueue correlationId payload
  use arg packageId, currentQueue, correlationId, payload
  packageId = packageId~string
  currentQueue = currentQueue~string
  correlationId = correlationId~string
  payload = payload

::requires "JMSQueueBridgeBSF.cls"
