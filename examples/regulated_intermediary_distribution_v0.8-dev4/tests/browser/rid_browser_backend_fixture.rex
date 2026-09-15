parse arg portFile stopFile resultFile
if portFile="" | stopFile="" | resultFile="" then do; say "fixture paths required"; exit 2; end
clock=.RIDManualTimeSource~new(1000000)
fx=.RIDWireUITestFixtures~setup("OFFERED","MORTGAGE",clock)
item=fx["SERVICE"]~workItemsForCase("CASE-W")[1]
if item~completionMode<>"SIGNATURE" then do; say "signature work expected"; call cleanup fx; exit 3; end
env=.RIDSignatureEnvelope~new("ENV-BROWSER-1","CASE-W","MORTGAGE_OFFER","OFFER|BROWSER|1","1","SHA-256","deadbeef","STORE:OFFER:BROWSER","DURABLE:OFFER:BROWSER")
call mustRid env~addRequirement(.RIDSignatureRequirement~new("CUSTOMER-SIGN","CUSTOMER:W","CUSTOMER","ACCEPT_MORTGAGE_OFFER",.true)); call mustRid env~seal
registry=.RIDWireSigningRegistry~new(fx["SERVICE"],clock,300); call mustRid registry~bindEnvelope(item~workItemId,env)
keys=.RIDSigningKeyRegistry~new; before=fx["ENV"]["NOW"]-.TimeSpan~new(0,0,0,0,60)
call mustRid keys~register(.RIDSigningKey~new("CUSTOMER-W-KEY","CUSTOMER:W","ED25519","dummy","DOCUMENT_SIGNATURE",before,.nil,"KEY:BROWSER"))
sigsvc=.RIDDigitalSignatureService~new(keys,.RIDAlwaysValidSignatureVerifier~new)
securityContext=.RIDWireSecurityPolicyFixtures~context("ADVISER","RID:ADVISER:REP-1")
r=.RIDWireRuntimeFactory~build("RID-APP","RID-SESSION","WEB",fx["ENGINE"],fx["ENV"]["CATALOG"],fx["SERVICE"],fx["FEED"],registry,sigsvc,"FIRM-1","REP-1",securityContext)
if \r~ok then do; say "app build failed" r~code r~detail; call cleanup fx; exit 4; end
app=r~value; ignore=app~drainOutbound
server=.WireUIServer~new(fx["MANAGER"],fx["BRIDGE"]~topicFabric,"RID_ADMIN"); ignore=server~registerApplication(app)
call mustWire server~provisionAccessPoint("WEB","browser-gateway")
backend=.RIDBrowserGatewayBackend~new(fx["MANAGER"],"WIREUI.IN.WEB","WIREUI.OUT.WEB","browser-gateway","bridge-secret",server,app)
listener=.QueueFabricWebGatewayBridgeListener~new(backend,"127.0.0.1",0)
if listener~serveAsync == .false then do; say "listener start failed"; call cleanup fx; exit 5; end
call lineout portFile,listener~port; call lineout portFile
written=.false
do while stream(stopFile,"C","QUERY EXISTS") = ""
  if item~status="COMPLETE" & \written then do
    d=.directory~new; d["caseId"]="CASE-W"; d["providerStatus"]=fx["ENGINE"]~case("CASE-W")~providerStatus; d["workItemId"]=item~workItemId; d["workStatus"]=item~status; d["completionEvidenceRef"]=item~completionEvidenceRef; d["envelopeId"]=env~envelopeId; d["envelopeState"]=env~state; d["signatures"]=env~signatures~items
    call lineout resultFile,.JSON~toJSON(d); call lineout resultFile; written=.true
  end
  call syssleep 0.02
end
ignore=listener~stop; call cleanup fx; exit 0
::routine mustRid
  use arg r
  if \r~ok then do; say "RID operation failed" r~code r~detail; exit 8; end
  return r
::routine mustWire
  use arg r
  if \r~ok then do; say "Wire operation failed" r~code r~detail; exit 9; end
  return r
::routine cleanup
  use arg fx
  .RIDWorkIntegrationFixtures~cleanup(fx); return .true
::class RIDBrowserGatewayBackend subclass QueueFabricWebGatewayBackend
::method init
  expose ridServer ridApp ridPrincipal
  use strict arg manager,inQueue,outQueue,principal,bridgeToken,server,app
  self~init:super(manager,inQueue,outQueue,principal,bridgeToken); ridServer=server; ridApp=app; ridPrincipal=principal
::method handle
  expose ridServer ridApp ridPrincipal
  use strict arg request
  r=self~handle:super(request)
  if \r["ok"] then return r
  if request~hasIndex("op") then if request["op"]~string~translate="PUT" then do
    sr=ridServer~receiveFromAccessPoint(ridApp~accessPointId,ridPrincipal); if \sr~ok then return self~ridFailure(sr~code,sr~detail)
    do message over ridApp~drainOutbound
      q=ridServer~enqueueToAccessPoint(ridApp~accessPointId,message,ridApp~applicationId||"/browser"); if \q~ok then return self~ridFailure(q~code,q~detail)
    end
  end
  return r
::method ridFailure private
  use arg code,detail=""
  d=.directory~new; d["ok"]=.false; d["code"]=code~string; if detail<>"" then d["detail"]=detail~string; return d
::requires "json.cls"
::requires "QueueFabricWebGatewayBridge.cls"
::requires "WireUIServer.cls"
::requires "WireUITestSupport.cls"

::requires "RIDWireSecurityPolicyFixtures.cls"
