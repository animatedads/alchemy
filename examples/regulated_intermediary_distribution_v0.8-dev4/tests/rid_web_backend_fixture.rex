parse arg portFile stopFile resultFile
if portFile="" | stopFile="" | resultFile="" then do; say "fixture paths required"; exit 2; end
clock=.RIDManualTimeSource~new(1000000)
fx=.RIDWireUITestFixtures~setup("OFFERED","MORTGAGE",clock)
item=fx["SERVICE"]~workItemsForCase("CASE-W")[1]
env=.RIDSignatureEnvelope~new("ENV-WEB-1","CASE-W","MORTGAGE_OFFER","OFFER|WEB|1","1","SHA-256","deadbeef","STORE:OFFER:WEB","DURABLE:OFFER:WEB")
req=.RIDSignatureRequirement~new("CUSTOMER-SIGN","CUSTOMER:W","CUSTOMER","ACCEPT_MORTGAGE_OFFER",.true)
call must env~addRequirement(req); call must env~seal
registry=.RIDWireSigningRegistry~new(fx["SERVICE"],clock,300); call must registry~bindEnvelope(item~workItemId,env)
keys=.RIDSigningKeyRegistry~new
before=fx["ENV"]["NOW"]-.TimeSpan~new(0,0,0,0,60)
call must keys~register(.RIDSigningKey~new("CUSTOMER-W-KEY","CUSTOMER:W","ED25519","dummy","DOCUMENT_SIGNATURE",before,.nil,"KEY:EVIDENCE"))
sigsvc=.RIDDigitalSignatureService~new(keys,.RIDAlwaysValidSignatureVerifier~new)
app=.RIDWireUITestFixtures~app(fx,registry,sigsvc)
service=.RIDWireWebGatewayService~new(fx["MANAGER"],fx["BRIDGE"]~topicFabric,app,"WEB","rid-browser-gateway","RID_ADMIN")
backend=.QueueFabricWebGatewayBackend~new(fx["MANAGER"],service~inboundQueue,service~outboundQueue,"rid-browser-gateway","bridge-secret")
listener=.QueueFabricWebGatewayBridgeListener~new(backend,"127.0.0.1",0)
if listener~serveAsync == .false then do; say "listener start failed"; exit 3; end
call lineout portFile,listener~port; call lineout portFile

do while stream(stopFile,"C","QUERY EXISTS") = ""
  r=service~processAvailable
  if \r~ok then do; say "gateway process failed" r~code r~detail; exit 4; end
  call sysSleep 0.01
end
out=.directory~new; out["workStatus"]=item~status; out["envelopeState"]=env~state
challenge=registry~challenge("RID-SIGN-CHALLENGE-000001")
if challenge==.nil then out["challengeUsed"]="MISSING"; else if challenge~used then out["challengeUsed"]="1"; else out["challengeUsed"]="0"
out["viewRevision"]=app~view~revision
call lineout resultFile,.JSON~toJSON(out); call lineout resultFile
ignore=listener~stop
.RIDWorkIntegrationFixtures~cleanup(fx)
exit 0

::routine must
  use arg r
  if \r~ok then do; say "fixture operation failed" r~code r~detail; exit 5; end
  return r
::requires "WireUITestSupport.cls"
::requires "RIDWireWebGatewayService.cls"
::requires "QueueFabricWebGatewayBridge.cls"
::requires "json.cls"

::requires "RIDWireSecurityPolicyFixtures.cls"
