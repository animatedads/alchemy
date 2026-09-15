parse arg portFile stopFile resultFile packagePath
if portFile="" | stopFile="" | resultFile="" | packagePath="" then do; say "fixture paths/package required"; exit 2; end

manager=.ObjectQueueManager~new("FBMWIREBROWSER")
topics=.QueueTopicFabric~new(manager)
feed=.FBMerchantWireProjectionFeed~new
call put feed,row("ROOT-A","PORT-A","CLIENT-A","CLOSED",2,-2000000,"GBP","DIRECTIONAL_RESIDUAL","EXECUTION_DIVERGENCE","OPEN","OPEN","CONTROL_OPEN","URGENT"),detail("ROOT-A","PORT-A","CLIENT-A","DIRECTIONAL_RESIDUAL",-2000000,"HEDGE_IMPAIRED")
call put feed,row("ROOT-B","PORT-B","CLIENT-B","CLOSED",2,0,"GBP","NET_ZERO_WITH_IMPAIRED_CONTRACTS","COMPLETE","OPEN","COMPLETE","CONTROL_OPEN","ACTION_REQUIRED"),detail("ROOT-B","PORT-B","CLIENT-B","NET_ZERO",0,"HEDGE_IMPAIRED")
call put feed,row("ROOT-C","PORT-C","CLIENT-C","OPEN",1,500000,"GBP","DIRECTIONAL_RESIDUAL","NONE","NONE","NONE","NONE","MONITOR"),detail("ROOT-C","PORT-C","CLIENT-C","DIRECTIONAL_RESIDUAL",500000,"CLEAR")

pkg=.json~fromJsonFile(packagePath)
r=.FBMerchantWireRuntimeFactory~buildFromPackage("FBM-LIVE","S-LIVE","WEB",feed,pkg)
if \r~ok then do; say r~code r~detail; exit 3; end
app=r~value
service=.FBMerchantWireWebGatewayService~new(manager,topics,app,"WEB","merchant-browser-gateway","admin")
backend=.QueueFabricWebGatewayBackend~new(manager,service~inboundQueue,service~outboundQueue,"merchant-browser-gateway","bridge-secret")
listener=.QueueFabricWebGatewayBridgeListener~new(backend,"127.0.0.1",0)
if listener~serveAsync == .false then do; say "listener start failed"; exit 4; end
call lineout portFile,listener~port; call lineout portFile

written=.false
do while stream(stopFile,"C","QUERY EXISTS") = ""
  sr=service~processAvailable
  if \sr~ok then do; say "service failed" sr~code sr~detail; leave; end
  sel=app~workspaceSelection("FBM.BOOKS")~selectedIds
  if \written & sel~items=1 then do
    out=.directory~new; out["selectedRootTradeId"]=sel[1]; out["workspaceContext"]=app~workspaceContext("FBM.BOOKS"); out["viewRevision"]=app~view~revision
    call lineout resultFile,.json~toJSON(out); call lineout resultFile
    written=.true
  end
  call syssleep 0.01
end
ignore=listener~stop
exit 0

put: procedure
  use arg feed,r,d
  feed~putBook(r,d); return

row: procedure
  use arg root,portfolio,client,clientState,contracts,net,currency,risk,execution,remediation,settlement,accounting,attention
  d=.directory~new; d["schema"]="federationbank.merchant.wire-book-row/1"; d["rootTradeId"]=root; d["portfolioId"]=portfolio; d["clientEntity"]=client; d["clientState"]=clientState; d["contractCount"]=contracts; d["netBaseExposure"]=net; d["currency"]=currency; d["riskState"]=risk; d["executionState"]=execution; d["remediationState"]=remediation; d["settlementState"]=settlement; d["accountingState"]=accounting; d["attention"]=attention; return d

detail: procedure
  use arg root,portfolio,client,economic,net,market
  d=.directory~new; d["schema"]="federationbank.merchant.wire-book-detail/1"; d["rootTradeId"]=root; d["portfolioId"]=portfolio; d["clientEntity"]=client; d["clientState"]="CLOSED"; d["contractState"]="ACTIVE"; d["contractCount"]=2; d["economicState"]=economic; d["netBaseExposure"]=net; d["riskState"]="DIRECTIONAL_RESIDUAL"; d["remediationId"]="R-"||root; d["remediationState"]="OPEN"; d["planId"]="P-"||root; d["planState"]="DEVIATED"; d["verificationState"]="EXECUTION_DIVERGENCE"; d["settlementObligationId"]=""; d["settlementState"]="OPEN"; d["accountingState"]="CONTROL_OPEN"; d["accountingControlState"]="DERIVATIVE_CONTROL_OPEN"; d["marketStructureState"]=market; d["hedgeEquivalenceEvidenceRef"]="HE-"||root; d["bookAssessmentId"]="HBA-"||root; d["valuationRef"]="VAL-"||root; d["asOfRef"]="2026-09-01T11:00:00Z"; return d

::requires "json.cls"
::requires "QueueFabricWebGatewayBridge.cls"
::requires "FBMerchantWireWebGatewayService.cls"
::requires "FBMerchantWireUIApplication.cls"
::requires "ObjectQueueFabric.cls"
::requires "ObjectQueueTopics.cls"
