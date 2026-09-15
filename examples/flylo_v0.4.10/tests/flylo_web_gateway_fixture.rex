/* Real FlyLo Wire UI application hosted behind the same-manager Queue Fabric Web Gateway. */
parse arg portFile stopFile resultFile
if portFile="" | stopFile="" | resultFile="" then do; say "fixture paths required"; exit 2; end

manager=.ObjectQueueManager~new("FLYLOWEBE2E")
topics=.QueueTopicFabric~new(manager)
server=.WireUIServer~new(manager,topics,"admin")
provider=.CapturingProvider~new
assistant=.FlyLoGrokAssistant~new(provider,"fixture-model",256)
r=.FlyLoWireRuntimeFactory~buildDemo("FLYLO-APP","S1","WEB",assistant); call must r,"build FlyLo app"
app=r~value
server~registerApplication(app)
principal="browser-gateway"
call must server~provisionAccessPoint("WEB",principal),"provision access point"

host=.FlyLoGatewayHost~new(server,app,"WEB",principal)
inq=server~directQueueName("WEB","IN")
outq=server~directQueueName("WEB","OUT")
backend=.HostedQueueFabricWebGatewayBackend~new(manager,inq,outq,principal,"bridge-secret",host)
listener=.QueueFabricWebGatewayBridgeListener~new(backend,"127.0.0.1",0)
if listener~serveAsync == .false then do; say "listener start failed"; exit 3; end
call lineout portFile,listener~port; call lineout portFile

do while stream(stopFile,"C","QUERY EXISTS") = ""
  call syssleep 0.01
end

/* Export only test evidence; the web gateway itself never sees this material. */
evidenceOut=.directory~new
if provider~request \== .nil then evidenceOut["assistantPrompt"]=provider~request~prompt
else evidenceOut["assistantPrompt"]=""
review=app~view~instance("review")
if review \== .nil then evidenceOut["authoritativeTotalMinor"]=review["slots"]["totalMinor"]
confirmation=app~view~instance("confirmation")
if confirmation \== .nil then do
  evidenceOut["bookingStatus"]=confirmation["slots"]["status"]
  evidenceOut["bookingRef"]=confirmation["slots"]["bookingRef"]
end
call lineout resultFile,.JSON~toJSON(evidenceOut); call lineout resultFile
ignore=listener~stop
exit 0

::class FlyLoGatewayHost
::method init
  expose server app accessPoint principal
  use strict arg server,app,accessPoint,principal
::method serviceIncoming unguarded
  expose server app accessPoint principal
  r=server~receiveFromAccessPoint(accessPoint,principal)
  if \r~ok then return r
  out=app~drainOutbound
  do m over out
    q=server~enqueueToAccessPoint(accessPoint,m)
    if \q~ok then return q
  end
  return r

::class HostedQueueFabricWebGatewayBackend subclass QueueFabricWebGatewayBackend
::method init
  expose host
  use strict arg manager,inQueue,outQueue,principal,bridgeToken,host
  self~init:super(manager,inQueue,outQueue,principal,bridgeToken)
::method handle unguarded
  expose host
  use strict arg request
  response=self~handle:super(request)
  if response["ok"] & request~hasIndex("op") & request["op"]~string~translate="PUT" then do
    serviced=host~serviceIncoming
    /* Queue insertion acceptance remains distinct from application acceptance.
       Valid test traffic produces outbound application messages synchronously. */
  end
  return response

::class CapturingProvider
::attribute request get
::method complete
  expose request
  use arg requestArg
  request=requestArg
  return .AIProviderReply~success("fixture sales explanation; nothing has been added",request~model,"stop",.AIProviderUsage~new(5,7))

::routine must
  use arg r,label="operation"
  if \r~ok then do; say "FAIL" label r~code r~detail; exit 10; end
  return r

::requires "json.cls"
::requires "FlyLoWireApplication.cls"
::requires "WireUIServer.cls"
::requires "QueueFabricWebGatewayBridge.cls"
::requires "ObjectQueueFabric.cls"
::requires "ObjectQueueTopics.cls"
