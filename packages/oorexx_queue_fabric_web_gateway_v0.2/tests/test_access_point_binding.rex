manager=.ObjectQueueManager~new("", .QueueGraphPayloadCodec~new, "admin")
server=.WireUIServer~new(manager)
app=.BindingTestApplication~new("FLYLO-APP","SESSION-42","AP-42")
binding=.WireUIWebAccessPointBinding~new(manager,server,app,"browser-gateway","bridge-secret","path-secret","/alchemy-wire-ui-v0.4-dev3/src/index.js","FLYLO")
if \binding~provision then call fail "provision failed"
if binding~inQueue<>"WIREUI.IN.AP-42" then call fail "wrong IN queue" binding~inQueue
if binding~outQueue<>"WIREUI.OUT.AP-42" then call fail "wrong OUT queue" binding~outQueue
if manager~queue(binding~inQueue)==.nil | manager~queue(binding~outQueue)==.nil then call fail "server queues absent"
if \binding~startBridge then call fail "bridge start failed"
if binding~bridgeListener~port<1 then call fail "bridge has no port"
env=binding~privateEdgeEnvironment("wss://flylo.example/wire-ui?token=path-secret","127.0.0.1",8443)
if env==.nil then call fail "private environment absent"
call eq env["WIRE_UI_INBOUND_QUEUE"],"WIREUI.IN.AP-42","private IN queue"
call eq env["WIRE_UI_APPLICATION_ID"],"FLYLO-APP","private application"
call eq env["WIRE_UI_SESSION_ID"],"SESSION-42","private session"
call eq env["WIRE_UI_ACCESS_POINT_ID"],"AP-42","private access point"
call eq env["QF_BRIDGE_TOKEN"],"bridge-secret","private bridge token"
if env~hasIndex("WIRE_UI_OUTBOUND_QUEUE") then call fail "private edge should not need Queue Fabric OUT queue selection"
browser=binding~browserBootstrap("wss://flylo.example/wire-ui?token=path-secret")
call eq browser["moduleUrl"],"/alchemy-wire-ui-v0.4-dev3/src/index.js","browser module"
call eq browser["gatewayUrl"],"wss://flylo.example/wire-ui?token=path-secret","browser gateway"
call eq browser["outboundQueue"],"WIREUI.IN.AP-42","browser fixed PUT queue"
call eq browser["ownership"]["applicationId"],"FLYLO-APP","browser application"
call eq browser["ownership"]["sessionId"],"SESSION-42","browser session"
call eq browser["ownership"]["accessPointId"],"AP-42","browser access point"
text=.JSON~toJSON(browser)
if text~pos("bridge-secret")>0 then call fail "browser leaked bridge token"
if text~pos("browser-gateway")>0 then call fail "browser leaked Queue Fabric principal"
if text~pos("WIREUI.OUT.AP-42")>0 then call fail "browser leaked Queue Fabric OUT queue"
ignore=binding~stopBridge
call syssleep 0.20
if binding~bridgeListener~running then call fail "bridge did not stop"
say "WIRE UI WEB ACCESS POINT BINDING: OK"
exit 0

::class BindingTestApplication public
::attribute applicationId get
::attribute sessionId get
::attribute accessPointId get
::method init
  expose applicationId sessionId accessPointId
  use strict arg applicationId, sessionId, accessPointId

::routine eq
  use arg actual, expected, label
  if actual<>expected then call fail label "expected="expected "actual="actual
  return .true
::routine fail
  use arg text
  say "FAIL:" text
  exit 1
::requires "WireUIWebAccessPointBinding.cls"
::requires "WireUIServer.cls"
