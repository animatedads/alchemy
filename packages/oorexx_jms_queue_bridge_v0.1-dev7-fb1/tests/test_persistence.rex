parse source . . here
root = filespec("L", here)
call directory root
store = "tmp_persistence_store"
"rm -rf" store

qm = .ObjectQueueManager~new(store)
call assert qm~createQueue("IN", "PERMANENT", "DEFAULT", 0, "bridge")~ok, "queue create"
provider = .FakeJMSProvider~new
config = .JMSBridgeConfig~new("persist", "SOLACE", "", "", "remote", "", "", "", "", "IN", "", "bridge", .true)
service = .JMSQueueBridgeService~new(qm, provider, config)
call assert service~start~ok, "start"
h = .directory~new
h["JMSMESSAGEID"] = "ID:persist"
p = .directory~new
p["source"] = "AIM_FNS"
msg = .JMSBridgeMessage~new("ID:persist", "TEXT", "<xml>safe</xml>", h, p, "SOLACE", "remote")
provider~enqueue(.JMSBridgeInboundDelivery~new("jms:persist:ID:persist", msg))
call assert service~pumpInbound(0)~ok, "bridge receive"

/* Recovery requires the bridge payload factory before manager initialization. */
codec = .JMSBridgeQueueCodecFactory~newCodec
qm3 = .ObjectQueueManager~new(store, codec)
read = qm3~browse("IN", "bridge")
call assert read~ok, "recovered browse"
restored = read~value~payload
call assert restored~isA(.JMSBridgeMessage), "restored bridge class"
call assert restored~body = "<xml>safe</xml>", "restored body"
call assert restored~properties["source"] = "AIM_FNS", "restored property"
call assert qm3~transferReceiptCount = 1, "transfer receipt recovered"
say "JMS BRIDGE PERSISTENCE PASS 8"
"rm -rf" store
exit 0

assert: procedure
  use arg ok, label
  if \ok then do
    say "FAIL:" label
    exit 1
  end
return

::requires "JMSQueueBridge.cls"
::requires "FakeJMSProvider.cls"
