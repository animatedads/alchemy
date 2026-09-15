/*
 * All Japan Insurance authoritative development Wire UI application.
 *
 * This process owns the WireUIApplication, semantic view and Queue Fabric
 * queues.  It projects a development fixture through the same authoritative
 * Wire UI Server v0.17 path used by a production AJI adapter.  Browser code
 * cannot mutate or manufacture this state.
 */
parse source . . script
compiledFile=value("AJI_WUI_COMPILED_RELEASE",,"ENVIRONMENT")
if compiledFile="" then compiledFile=filespec("P",script)"aji-compiled-release.json"
bridgeToken=value("AJI_WUI_BRIDGE_TOKEN",,"ENVIRONMENT")
pathToken=value("AJI_WUI_PATH_TOKEN",,"ENVIRONMENT")
if bridgeToken="" | pathToken="" then do
  say "AJI_WUI_ERROR missing launcher tokens"
  exit 2
end

applicationId="ALL-JAPAN-INSURANCE-OPERATIONS"
sessionId=value("AJI_WUI_SESSION_ID",,"ENVIRONMENT")
if sessionId="" then sessionId="AJI-DEV-SESSION"
accessPointId="AJI-WEB"
gatewayPrincipal="aji-wire-ui-gateway"
moduleUrl="/wire-ui-js/src/index.js"
siteId="ALL_JAPAN_INSURANCE"

line=linein(compiledFile); call lineout compiledFile
if line="" then do; say "AJI_WUI_ERROR compiled release empty"; exit 3; end
wire=.JSON~fromJSON(line)
catalogue=.WireUICompiledCatalogue~new(wire)

view=.WireUIView~new("AJI.Operations","portfolio")
projection=.WireUIProjection~new
app=.AJIWireUIApplication~new(applicationId,sessionId,accessPointId,view,projection)
r=app~bindCompiledRelease(catalogue,.WireUIProtocol~PROFILE_HUMAN_VISUAL)
if \r~ok then do; say "AJI_WUI_ERROR release-bind" r~code r~detail; exit 4; end
r=app~seedInitialView
if \r~ok then do; say "AJI_WUI_ERROR initial-view" r~code r~detail; exit 5; end

manager=.ObjectQueueManager~new("",.QueueGraphPayloadCodec~new,"admin")
topics=.QueueTopicFabric~new(manager)
server=.WireUIServer~new(manager,topics,"admin")
server~registerApplication(app)
binding=.WireUIWebAccessPointBinding~new(manager,server,app,gatewayPrincipal,bridgeToken,pathToken,moduleUrl,siteId,"127.0.0.1",0,"/wire-ui")
if \binding~startBridge then do; say "AJI_WUI_ERROR bridge-start-failed"; exit 6; end

/* Material is server-owned release material. Queue it before the browser hello. */
r=server~enqueueMaterialsToAccessPoint(applicationId)
if \r~ok then do; say "AJI_WUI_ERROR material-enqueue" r~code r~detail; exit 7; end

ready=.directory~new
ready["event"]="aji-wire-ui-backend-ready"
ready["bridgePort"]=binding~bridgeListener~port
ready["inQueue"]=binding~inQueue
ready["outQueue"]=binding~outQueue
ready["applicationId"]=app~applicationId
ready["sessionId"]=app~sessionId
ready["accessPointId"]=app~accessPointId
ready["moduleUrl"]=moduleUrl
ready["siteId"]=siteId
ready["releaseId"]=app~siteReleaseBinding~releaseId
ready["releaseVersion"]=app~siteReleaseBinding~version
ready["releaseContentAddress"]=app~siteReleaseBinding~contentAddress
ready["viewRef"]=view~viewRef
ready["projectionMode"]="AUTHORITATIVE_DEVELOPMENT_FIXTURE"
say .JSON~toJSON(ready)

call rxfuncadd "SysLoadFuncs","rxunixsys","SysLoadFuncs"
call SysLoadFuncs
signal on halt name shutdown

do forever
  depth=manager~depth(binding~inQueue,"admin")
  if depth~ok & depth~value["ready"]>0 then do
    result=server~receiveFromAccessPoint(accessPointId,gatewayPrincipal)
    if \result~ok then say "AJI_WUI_ERROR receive" result~code result~detail
    else if result~code="RESYNC_SNAPSHOT" then do
      q=server~enqueueToAccessPoint(accessPointId,result~value)
      if \q~ok then say "AJI_WUI_ERROR resync-enqueue" q~code q~detail
    end
    outbound=app~drainOutbound
    do message over outbound
      q=server~enqueueToAccessPoint(accessPointId,message)
      if \q~ok then do
        say "AJI_WUI_ERROR outbound" q~code q~detail
        signal shutdown
      end
    end
  end
  else call SysSleep 0.01
end

shutdown:
  signal off halt
  if symbol("binding")="VAR" then ignore=binding~stopBridge
  exit 0

::class AJIWireUIApplication subclass WireUIApplication
::method init
  expose policies selectedPolicy detailsCreated
  use arg applicationId,sessionId,accessPointId,view,projection
  self~init:super(applicationId,sessionId,accessPointId,view,projection)
  policies=self~fixturePolicies
  selectedPolicy=""
  detailsCreated=.false

::method seedInitialView
  expose policies
  portfolio=.directory~new
  portfolio["asOfRef"]="AJI-WUI-DEV-20260828T203000+0100"
  portfolio["currency"]="JPY"
  portfolio["policyCount"]=policies~items
  portfolio["openReceivableMinor"]=442800
  portfolio["claimsOutstandingMinor"]=1260000
  portfolio["projectionMode"]="AUTHORITATIVE_DEVELOPMENT_FIXTURE"
  r=self~view~createInstance("portfolio","AJI_WUI_PORTFOLIO@2",portfolio)
  if \r~ok then return r
  items=.array~new
  ids=policies~allIndexes; ids~sort
  do id over ids
    row=policies[id]
    item=.directory~new
    item["id"]=id
    item["productCode"]=row["policy"]["productCode"]
    item["status"]=row["policy"]["status"]
    item["premiumJPY"]=row["policy"]["premiumMinor"]
    item["billing"]=row["billingStatus"]
    item["claim"]=row["claimStatus"]
    items~append(item)
  end
  slots=.directory~new; slots["items"]=items; slots["visible"]=.true; slots["ariaLabel"]="All Japan Insurance policies"; slots["action"]="AJI.POLICY.OPEN"
  r=self~view~createInstance("policy-list","AJI_WUI_POLICY_LIST@1",slots,"portfolio")
  if \r~ok then return r
  v=self~view
  ignore=v~setActionAvailable("policy-list","AJI.POLICY.OPEN",.true)
  return .WireUIResult~success("portfolio","AJI_INITIAL_VIEW_READY")

::method dispatchSemanticAction
  use arg action,message
  if action="AJI.POLICY.OPEN" then return self~openPolicy(message)
  return .WireUIResult~failure("ACTION_NOT_IMPLEMENTED",action)

::method openPolicy private
  expose policies selectedPolicy detailsCreated outbound
  use arg message
  detail=self~field(message,"detail",.nil)
  if detail==.nil | \detail~hasMethod("HASINDEX") then return .WireUIResult~failure("AJI_POLICY_SELECTION_REQUIRED")
  policyId=self~field(detail,"id",self~field(detail,"policyId",self~field(detail,"ref","")))
  if policyId="" | \policies~hasIndex(policyId) then return .WireUIResult~failure("AJI_POLICY_NOT_FOUND",policyId)
  row=policies[policyId]

  if \detailsCreated then do
    evidence=.directory~new; evidence["policyId"]=policyId; evidence["source"]="server-issued-policy-list"
    ar=self~advanceJourney("POLICY","AJI.POLICY.OPEN",evidence,self~field(message,"messageId",""))
    if \ar~ok then return ar
    r=self~createViewInstance("policy-detail","AJI_WUI_POLICY@2",row["policy"],"portfolio"); if \r~ok then return r
    r=self~createViewInstance("billing-detail","AJI_WUI_BILLING@2",row["billing"],"portfolio"); if \r~ok then return r
    r=self~createViewInstance("claim-detail","AJI_WUI_CLAIM@2",row["claim"],"portfolio"); if \r~ok then return r
    r=self~createViewInstance("accounting-detail","AJI_WUI_ACCOUNTING@2",row["accounting"],"portfolio"); if \r~ok then return r
    detailsCreated=.true
  end
  else do
    updates=.table~new
    updates["policy-detail"]=row["policy"]
    updates["billing-detail"]=row["billing"]
    updates["claim-detail"]=row["claim"]
    updates["accounting-detail"]=row["accounting"]
    r=self~view~setSlotsAcross(updates)
    if \r~ok then return r
    if r~value \== .nil then outbound~append(r~value)
  end
  selectedPolicy=policyId
  return .WireUIResult~success(policyId,"AJI_POLICY_SELECTED")

::method field private
  use arg table,key,default=.nil
  if table==.nil then return default
  if table~hasIndex(key) then return table[key]
  return default

::method fixturePolicies private
  rows=.table~new
  rows["AJI-CAR-2026-006712"]=self~policyRow("AJI-CAR-2026-006712","CAR",164200,"AJI-CAR-CONTRACT/2026A","AJI-CAR-PROGRAM/2026A",0,0,0,"","CURRENT","NONE","BILL-CAR-6712","JRN-AJI-002381")
  rows["AJI-HOME-2026-018441"]=self~policyRow("AJI-HOME-2026-018441","HOME",128600,"AJI-HOME-CONTRACT/2026A","AJI-HOME-PROGRAM/2026A",780000,300000,480000,"AJI-CLM-2026-00418","CURRENT","OPEN","BILL-HOME-18441","JRN-AJI-002419")
  rows["AJI-PI-2026-001904"]=self~policyRow("AJI-PI-2026-001904","PI",315400,"AJI-PI-CONTRACT/2026A","AJI-PI-PROGRAM/2026A",900000,120000,780000,"AJI-CLM-2026-00502","ARREARS","OPEN","BILL-PI-1904","JRN-AJI-002447")
  return rows

::method policyRow private
  use arg policyId,productCode,premiumMinor,contractRef,programRef,assessed,paid,outstanding,claimId,billingStatus,claimStatus,sourceEventRef,journalRef
  row=.directory~new
  p=.directory~new
  p["policyId"]=policyId; p["productCode"]=productCode; p["status"]="ACTIVE"; p["currency"]="JPY"; p["premiumMinor"]=premiumMinor
  p["contractRef"]=contractRef; p["productProgramRef"]=programRef; p["ratingFunctionRef"]="AJI.PRODUCT.RATING.COMPOSITE/1"
  b=.directory~new
  b["policyId"]=policyId; b["openDebitMinor"]=0; if billingStatus="ARREARS" then b["openDebitMinor"]=150000; b["unappliedCreditMinor"]=0; b["unappliedCashMinor"]=0; if productCode="HOME" then b["unappliedCashMinor"]=3200; b["allocationFunctionRef"]="AJI.BILLING.ALLOCATE.OLDEST_DUE/1"
  c=.directory~new
  c["claimId"]=claimId; c["policyId"]=policyId; c["assessmentId"]=""; if claimId<>"" then c["assessmentId"]=claimId||"-ASSESS-01"
  c["assessedPayableMinor"]=assessed; c["paidMinor"]=paid; c["outstandingMinor"]=outstanding; c["payoutFunctionRef"]=""; if claimId<>"" then c["payoutFunctionRef"]="AJI.PAYOUT.DEDUCT_RATE_CAP/1"
  a=.directory~new
  a["bookRef"]="AJI-STAT"; a["currency"]="JPY"; a["sourceEventRef"]=sourceEventRef; a["journalRef"]=journalRef; a["accountingPolicyRef"]="all.japan.insurance.accounting/0.5"
  row["policy"]=p; row["billing"]=b; row["claim"]=c; row["accounting"]=a; row["billingStatus"]=billingStatus; row["claimStatus"]=claimStatus
  return row

::requires "json.cls"
::requires "WireUIAll.cls"
::requires "WireUIServer.cls"
::requires "WireUIWebAccessPointBinding.cls"
::requires "ObjectQueueFabric.cls"
::requires "ObjectQueueTopics.cls"
