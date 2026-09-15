parse source . . here
root = filespec("L", here)
call directory root

config = .JMSBridgeConfig~new("fb-bsf", "GENERIC", "fake://broker", "CF", "IN", "OUT", "", "", "", "", "", "bridge", .false, 1000, "REJECT", "fake.InitialContext", "AUTO_ACKNOWLEDGE", "ADMINISTERED")
provider = .JMSBSFProvider~new(config, .nil)
connected = provider~connect
call assert connected~ok, "fake BSF/JMS connect"
call assert .environment["FAKE_JMS_CONNECTION"]~started, "connection started"

/* FederationBank/IJCIB outbound MAP + arbitrary properties + explicit message correlation. */
body = .directory~new
body["protocolVersion"] = "IJCIB-CIR/0.1"
body["requestId"] = "IJCIB-REQ-EDGE-1"
body["requestedProductCode"] = "FB-IJCIB-FIXTURE-GBP"
props = .directory~new
props["IJCIB_PROTOCOL_VERSION"] = "IJCIB-CIR/0.1"
props["IJCIB_REQUEST_ID"] = "IJCIB-REQ-EDGE-1"
props["IJCIB_REQUEST_DIGEST"] = "deadbeef"
props["AlchemyTransferId"] = "PAYLOAD-MUST-NOT-WIN"
headers = .directory~new
headers["JMSCORRELATIONID"] = "FB-CORR-EDGE-1"
headers["JMSTYPE"] = "IJCIB_REQUEST"
bridge = .JMSBridgeMessage~new("", "MAP", body, headers, props, "FEDERATIONBANK", "")
package = .FakeBridgePackage~new("PKG-EDGE-1", "FB.OUT", "QUEUE-CORR-FALLBACK", bridge)
sent = provider~send(package)
call assert sent~ok, "MAP send"
jm = .environment["FAKE_JMS_PRODUCER"]~lastMessage
call assert jm~bsf.isA("javax.jms.MapMessage"), "created JMS MapMessage"
call assert jm~mapValue("requestId") = "IJCIB-REQ-EDGE-1", "MAP request id forwarded"
call assert jm~mapValue("requestedProductCode") = "FB-IJCIB-FIXTURE-GBP", "MAP product forwarded"
call assert jm~property("IJCIB_PROTOCOL_VERSION") = "IJCIB-CIR/0.1", "application property forwarded"
call assert jm~property("IJCIB_REQUEST_DIGEST") = "deadbeef", "arbitrary property forwarded"
call assert jm~property("AlchemyTransferId") = "PKG-EDGE-1", "bridge transfer id protected"
call assert jm~property("AlchemyQueue") = "FB.OUT", "bridge queue metadata"
call assert jm~getJMSCorrelationID = "QUEUE-CORR-FALLBACK", "Queue Fabric package correlation wins when present"

/* If Queue Fabric did not supply a package correlation, preserve the explicit
 * JMS correlation carried by the durable bridge envelope. */
headerOnlyHeaders = .directory~new
headerOnlyHeaders["JMSCORRELATIONID"] = "FB-CORR-HEADER-ONLY"
headerOnly = .JMSBridgeMessage~new("", "TEXT", "corr", headerOnlyHeaders, .directory~new, "TEST", "")
headerOnlyPackage = .FakeBridgePackage~new("PKG-CORR-2", "FB.OUT", "", headerOnly)
call assert provider~send(headerOnlyPackage)~ok, "header-only correlation send"
hm = .environment["FAKE_JMS_PRODUCER"]~lastMessage
call assert hm~getJMSCorrelationID = "FB-CORR-HEADER-ONLY", "bridge-message correlation used when package correlation absent"
call assert jm~getJMSType = "IJCIB_REQUEST", "JMS type forwarded"

/* dev6 TEXT behavior remains and Queue Fabric correlation is the fallback. */
textBridge = .JMSBridgeMessage~new("", "TEXT", "hello", .directory~new, .directory~new, "TEST", "")
textPackage = .FakeBridgePackage~new("PKG-TEXT-1", "FB.OUT", "QUEUE-CORR-1", textBridge)
textSent = provider~send(textPackage)
call assert textSent~ok, "TEXT send remains"
tm = .environment["FAKE_JMS_PRODUCER"]~lastMessage
call assert tm~bsf.isA("javax.jms.TextMessage"), "created JMS TextMessage"
call assert tm~getText = "hello", "TEXT body unchanged"
call assert tm~getJMSCorrelationID = "QUEUE-CORR-1", "package correlation fallback"

/* Inbound IJCIB MapMessage becomes the existing Java-free JMSBridgeMessage. */
inbound = .FakeMapMessage~new
ignore = inbound~setJMSMessageID("ID:IJCIB-REPLY-1")
ignore = inbound~setJMSCorrelationID("FB-CORR-EDGE-1")
ignore = inbound~setString("protocolVersion", "IJCIB-CIP/0.1")
ignore = inbound~setString("bureauReference", "OPAQUE-REF-1")
ignore = inbound~setStringProperty("IJCIB_OVERALL_DISPOSITION", "INTELLIGENCE_PRODUCT_RELEASED_WITH_QUALIFICATIONS")
ignore = inbound~setStringProperty("IJCIB_REASON_CODE_TREE", "IJCIB.QUAL.X.7|IJCIB.OPAQUE.Y.3")
.environment["FAKE_JMS_INBOUND"] = inbound
received = provider~receive(1)
if \received~ok then say "MAP receive failure:" received~code received~detail
call assert received~ok, "MAP receive"
delivery = received~value
out = delivery~message
call assert out~isA(.JMSBridgeMessage), "decoded bridge message"
call assert out~bodyType = "MAP", "decoded MAP type"
call assert out~body["protocolVersion"] = "IJCIB-CIP/0.1", "decoded MAP protocol"
call assert out~body["bureauReference"] = "OPAQUE-REF-1", "decoded MAP bureau reference"
call assert out~properties["IJCIB_OVERALL_DISPOSITION"] = "INTELLIGENCE_PRODUCT_RELEASED_WITH_QUALIFICATIONS", "decoded property"
call assert out~properties["IJCIB_REASON_CODE_TREE"] = "IJCIB.QUAL.X.7|IJCIB.OPAQUE.Y.3", "opaque reason property retained"
call assert out~headers["JMSCORRELATIONID"] = "FB-CORR-EDGE-1", "decoded correlation"
call assert delivery~transferId = "jms:fb-bsf:ID:IJCIB-REPLY-1", "transfer identity"

call assert provider~close~ok, "close"
say "JMS BRIDGE FEDERATIONBANK FAKE-BSF EDGE PASS 28"
exit 0

assert: procedure
  use arg ok, label
  if \ok then do
    say "FAIL:" label
    exit 1
  end
return

::class FakeBridgePackage public
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
