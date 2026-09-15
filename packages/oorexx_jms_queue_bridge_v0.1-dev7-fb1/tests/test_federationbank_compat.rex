msgBody = .directory~new
msgBody["protocolVersion"] = "IJCIB-CIR/0.1"
msgBody["requestId"] = "REQ-FB-1"
props = .directory~new
props["IJCIB_REQUEST_ID"] = "REQ-FB-1"
props["FB_ATM_SCHEMA"] = "federationbank.atm.response/0.1"
headers = .directory~new
headers["JMSCORRELATIONID"] = "REQ-FB-1"
msg = .JMSBridgeMessage~new("", "MAP", msgBody, headers, props, "FEDERATIONBANK", "fixture")
call assert msg~bodyType = "MAP", "MAP body type retained"
call assert msg~body["requestId"] = "REQ-FB-1", "MAP body retained"
call assert msg~properties["IJCIB_REQUEST_ID"] = "REQ-FB-1", "arbitrary property retained"
call assert msg~headers["JMSCORRELATIONID"] = "REQ-FB-1", "correlation metadata retained"
call assert .JMSQueueBridgeBuild~VERSION = "0.1-dev7-fb1", "candidate build identity"
say "PASS FederationBank MAP/property Java-neutral compatibility surface"
exit 0

assert: procedure
  use arg condition, label
  if \condition then do
    say "FAIL" label
    exit 1
  end
  return

::requires "JMSQueueBridge.cls"
