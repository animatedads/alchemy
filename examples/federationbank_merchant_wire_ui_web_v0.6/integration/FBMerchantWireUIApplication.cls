/* FederationBank Merchant Banking read/navigation Wire UI application v0.6. */
::class FBMerchantWireApplicationBuild public
::constant VERSION "0.6"
::constant API_VERSION "federationbank.merchant.wire-ui/0.6"

::class FBMerchantWireApplication subclass WireUIApplication public
::method init
  expose feed merchantEntity windowRevision authorityAdapter windowOffset windowLimit publishedFeedRevision
  use arg applicationId,sessionId,accessPointId,view,projection,feedArg,merchantEntityArg="FEDERATIONBANK_MERCHANT_BANK",authorityAdapterArg=.nil
  self~init:super(applicationId,sessionId,accessPointId,view,projection)
  if feedArg==.nil | \feedArg~isA(.FBMerchantWireProjectionFeed) then raise syntax 88.900 array("FBMerchantWireProjectionFeed required")
  if authorityAdapterArg<>.nil & \authorityAdapterArg~hasMethod("REFRESHFEED") then raise syntax 88.900 array("authority projection adapter with refreshFeed required")
  feed=feedArg; merchantEntity=merchantEntityArg~string~upper; windowRevision=0; authorityAdapter=authorityAdapterArg; windowOffset=0; windowLimit=25; publishedFeedRevision=-1

::method installInitialView
  expose merchantEntity authorityAdapter feed
  v=self~view; p=self~projection
  shell=.table~new; shell["visible"]=.true; shell["merchantEntity"]=merchantEntity; shell["perimeter"]="MERCHANT_BANKING"; shell["asOfRef"]=""
  call must v~createInstance("root","FBM_APP_SHELL@1",shell)
  summary=.table~new; summary["totalBooks"]=0; summary["riskAttention"]=0; summary["executionDivergence"]=0; summary["settlementOpen"]=0; summary["accountingOpen"]=0; summary["clientClosed"]=0
  call must v~createInstance("summary","FBM_TRUTH_SUMMARY@1",summary,"root")
  query=.table~new; query["workspaceRef"]="FBM.BOOKS"; query["riskState"]="ALL"; query["settlementState"]="ALL"; query["accountingState"]="ALL"; query["clientState"]="ALL"; query["attention"]="ALL"; query["sortRef"]="ATTENTION"; query["sortDirection"]="DESC"; query["actions"]=.array~of("BOOKS.FILTER","BOOKS.SORT","BOOKS.WINDOW","BOOKS.SELECT","WORKSPACE.REFRESH")
  call must v~createInstance("book-query","FBM_BOOK_QUERY@1",query,"root")
  do a over .array~of("BOOKS.FILTER","BOOKS.SORT","BOOKS.WINDOW","BOOKS.SELECT","WORKSPACE.REFRESH"); v~setActionAvailable("book-query",a,.true); end
  table=.table~new; table["collectionRef"]="book-table"; table["windowOffset"]=0; table["windowLimit"]=25; table["windowTotalCount"]=0; table["visibleRowCount"]=0; table["windowRevision"]=0; table["sortRef"]="ATTENTION:DESC"; table["filterRef"]=""; table["anchorRef"]=""; table["queryRevision"]=0; table["scopeRevision"]=0; table["orderRevision"]=0; table["selectionRevision"]=0; table["resultRevision"]=0
  call must v~createInstance("book-table","FBM_BOOK_TABLE@1",table,"root")
  wc=.table~new; wc["visible"]=.false; wc["workspaceRef"]="FBM.BOOKS"; wc["selectedIdsJson"]="[]"; wc["queryRevision"]=0; wc["scopeRevision"]=0; wc["orderRevision"]=0; wc["selectionRevision"]=0; wc["resultRevision"]=0; wc["resultQueryRevision"]=0; wc["resultScopeRevision"]=0; wc["resultOrderRevision"]=0
  call must v~createInstance("workspace-context","FBM_WORKSPACE_CONTEXT@1",wc,"root")
  detail=.table~new; detail["visible"]=.false; call must v~createInstance("book-detail","FBM_BOOK_DETAIL@1",detail,"root")
  cp=.table~new; cp["visible"]=.false; call must v~createInstance("execution-checkpoint","FBM_EXECUTION_CHECKPOINT@1",cp,"root")
  st=.table~new; st["visible"]=.false; call must v~createInstance("settlement-detail","FBM_SETTLEMENT_DETAIL@1",st,"root")
  ac=.table~new; ac["visible"]=.false; call must v~createInstance("accounting-detail","FBM_ACCOUNTING_DETAIL@1",ac,"root")
  mk=.table~new; mk["visible"]=.false; call must v~createInstance("market-detail","FBM_MARKET_STRUCTURE_DETAIL@1",mk,"root")
  call must self~registerWorkspace("FBM.BOOKS")
  p~bindSlots("summary.group","summary"); p~bindSlots("table.group","book-table"); p~bindSlots("workspace.context","workspace-context"); p~bindSlots("detail.group","book-detail"); p~bindSlots("checkpoint.group","execution-checkpoint"); p~bindSlots("settlement.group","settlement-detail"); p~bindSlots("accounting.group","accounting-detail"); p~bindSlots("market.group","market-detail")
  if authorityAdapter<>.nil then ignore=authorityAdapter~refreshFeed(feed)
  return self~refreshWorkspace

::method refreshWorkspace
  expose feed windowRevision windowOffset windowLimit publishedFeedRevision
  q=self~workspaceQuery("FBM.BOOKS"); filters=q~filters; wire=q~asWire; sortRef="ATTENTION"; direction="DESC"
  if wire~hasIndex("sort") then do; sortRef=wire["sort"]["sortRef"]; direction=wire["sort"]["direction"]; end
  page=feed~window(filters,sortRef,direction,windowOffset,windowLimit)
  total=page["totalCount"]
  if total=0 then windowOffset=0
  else if windowOffset>=total then do
    windowOffset=0
    page=feed~window(filters,sortRef,direction,windowOffset,windowLimit)
  end
  rows=page["rows"]
  wireRows=.array~new
  do r over rows
    row=.directory~new; row["instanceId"]=r["rootTradeId"]; row["definitionKey"]="FBM_BOOK_ROW@1"; row["slots"]=self~rowSlots(r); wireRows~append(row)
  end
  windowRevision+=1
  window=.WireUICollectionWindow~new("book-table",windowOffset,windowLimit,total,sortRef||":"||direction,self~filterRef(filters),windowRevision,"feed:"||feed~revision)
  rr=self~reconcileCollectionWindow("book-table",wireRows,window); if \rr~ok then return rr
  do r over rows
    rootId=r["rootTradeId"]
    actionId=rootId||"::OPEN"
    if self~view~instance(actionId)==.nil then do
      openSlots=.table~new; openSlots["workspaceRef"]="FBM.BOOKS"; openSlots["semanticRowId"]=rootId; openSlots["label"]="Open book"; openSlots["action"]="BOOK.OPEN"
      cr=self~createViewInstance(actionId,"FBM_BOOK_OPEN@1",openSlots,rootId); if \cr~ok then return cr
    end
    self~view~setActionAvailable(actionId,"BOOK.OPEN",.true)
  end
  sums=feed~summary(filters)
  mr=self~mutateState("summary.group",sums); if \mr~ok then return mr
  resultState=self~workspaceResult("FBM.BOOKS")
  if \resultState~published | \resultState~currentFor(q) | publishedFeedRevision<>feed~revision then do
    pub=self~publishWorkspaceResult("FBM.BOOKS",total,sums,"feed:"||feed~revision,"feed:"||feed~revision); if \pub~ok then return pub
    publishedFeedRevision=feed~revision
  end
  ctx=self~workspaceContext("FBM.BOOKS")
  table=.table~new; table["visibleRowCount"]=rows~items; table["queryRevision"]=ctx["queryRevision"]; table["scopeRevision"]=ctx["scopeRevision"]; table["orderRevision"]=ctx["orderRevision"]; table["selectionRevision"]=ctx["selectionRevision"]; table["resultRevision"]=ctx["resultRevision"]
  mr=self~mutateState("table.group",table); if \mr~ok then return mr
  wc=.table~new; wc["workspaceRef"]="FBM.BOOKS"; wc["selectedIdsJson"]=self~jsonStringArray(ctx["selectedIds"]); wc["queryRevision"]=ctx["queryRevision"]; wc["scopeRevision"]=ctx["scopeRevision"]; wc["orderRevision"]=ctx["orderRevision"]; wc["selectionRevision"]=ctx["selectionRevision"]; wc["resultRevision"]=ctx["resultRevision"]; wc["resultQueryRevision"]=ctx["resultQueryRevision"]; wc["resultScopeRevision"]=ctx["resultScopeRevision"]; wc["resultOrderRevision"]=ctx["resultOrderRevision"]
  mr=self~mutateState("workspace.context",wc); if \mr~ok then return mr
  sel=self~workspaceSelection("FBM.BOOKS")
  if sel~selectedIds~items=1 then do
    root=sel~selectedIds[1]
    if feed~containsRootInScope(root,filters) then return self~projectBook(root)
  end
  return self~hideDetail

::method dispatchSemanticAction
  expose feed authorityAdapter windowOffset windowLimit
  use arg action,message
  d=self~detailOf(message)
  select
    when action="WORKSPACE.REFRESH" then do
      if authorityAdapter<>.nil then ignore=authorityAdapter~refreshFeed(feed)
      return self~refreshWorkspace
    end
    when action="BOOKS.FILTER" then do
      ref=self~fieldOf(d,"filterRef","")~string~lower; value=self~fieldOf(d,"value","ALL")~string~upper
      if ref<>"risk_state" & ref<>"settlement_state" & ref<>"accounting_state" & ref<>"client_state" & ref<>"attention" then return .WireUIResult~failure("FBM_FILTER_NOT_ALLOWED",ref)
      if value="" | value="ALL" | value="*" then r=self~removeWorkspaceFilter("FBM.BOOKS",ref); else r=self~setWorkspaceFilter("FBM.BOOKS",ref,value)
      if \r~ok then return r
      windowOffset=0
      return self~refreshWorkspace
    end
    when action="BOOKS.SORT" then do
      ref=self~fieldOf(d,"sortRef","")~string~upper; direction=self~fieldOf(d,"direction","DESC")~string~upper
      if ref<>"ATTENTION" & ref<>"ROOT_TRADE_ID" & ref<>"PORTFOLIO_ID" & ref<>"RISK_STATE" & ref<>"NET_EXPOSURE" then return .WireUIResult~failure("FBM_SORT_NOT_ALLOWED",ref)
      r=self~setWorkspaceSort("FBM.BOOKS",ref,direction); if \r~ok then return r
      return self~refreshWorkspace
    end
    when action="BOOKS.WINDOW" then do
      offset=self~fieldOf(d,"offset",-1); limit=self~fieldOf(d,"limit",-1)
      if \datatype(offset,"W") | offset<0 then return .WireUIResult~failure("FBM_WINDOW_OFFSET_INVALID",offset)
      if \datatype(limit,"W") | limit<1 | limit>100 then return .WireUIResult~failure("FBM_WINDOW_LIMIT_INVALID",limit)
      total=self~workspaceResult("FBM.BOOKS")~totalCount
      if total=0 then do
        if offset<>0 then return .WireUIResult~failure("FBM_WINDOW_OFFSET_OUT_OF_RANGE",offset,total)
      end
      else if offset>=total then return .WireUIResult~failure("FBM_WINDOW_OFFSET_OUT_OF_RANGE",offset,total)
      windowOffset=offset; windowLimit=limit
      return self~refreshWorkspace
    end
    when action="BOOKS.SELECT" then do
      ids=self~fieldOf(d,"selectedIds",.nil); scope=self~fieldOf(d,"scopeRevision",-1)
      if ids==.nil | \ids~isA(.Array) then return .WireUIResult~failure("FBM_SELECTION_REQUIRED")
      q=self~workspaceQuery("FBM.BOOKS"); if scope<>q~scopeRevision then return .WireUIResult~failure("FBM_SELECTION_SCOPE_STALE")
      do id over ids; if \feed~containsRootInScope(id,q~filters) then return .WireUIResult~failure("FBM_SELECTION_OUT_OF_SCOPE",id); end
      r=self~setWorkspaceSelection("FBM.BOOKS",scope,ids); if \r~ok then return r
      return self~refreshWorkspace
    end
    when action="BOOK.OPEN" then do
      instanceId=self~fieldOf(message,"elementInstance","")~string
      actionInstance=self~view~instance(instanceId)
      if actionInstance==.nil then return .WireUIResult~failure("FBM_BOOK_OPEN_INSTANCE_NOT_FOUND",instanceId)
      root=self~fieldOf(actionInstance["slots"],"semanticRowId","")~string~upper
      if root="" then return .WireUIResult~failure("FBM_BOOK_OPEN_IDENTITY_MISSING",instanceId)
      q=self~workspaceQuery("FBM.BOOKS")
      if \feed~containsRootInScope(root,q~filters) then return .WireUIResult~failure("FBM_SELECTION_OUT_OF_SCOPE",root)
      ids=.array~of(root)
      r=self~setWorkspaceSelection("FBM.BOOKS",q~scopeRevision,ids); if \r~ok then return r
      return self~refreshWorkspace
    end
    otherwise return .WireUIResult~failure("FBM_WIRE_ACTION_UNSUPPORTED",action)
  end

::method projectBook private
  expose feed
  use arg root
  d=feed~detail(root); if d==.nil then return .WireUIResult~failure("FBM_BOOK_DETAIL_NOT_FOUND",root)
  main=.table~new
  do k over .array~of("rootTradeId","portfolioId","clientEntity","clientState","contractState","contractCount","economicState","netBaseExposure","riskState","remediationId","remediationState","planId","planState","verificationState","settlementObligationId","settlementState","accountingState","accountingControlState","marketStructureState","hedgeEquivalenceEvidenceRef","bookAssessmentId","valuationRef","asOfRef"); if d~hasIndex(k) then main[k]=d[k]; end
  main["visible"]=.true; r=self~mutateState("detail.group",main); if \r~ok then return r
  r=self~projectSection("checkpoint.group",d,"checkpoint",.array~of("checkpointId","resultState","divergenceReason","executionState","evidenceId","bookAssessmentId","assessedAt","actualNetBaseExposure","expectedPlanPeakAbsBaseExposure","transientExposureBreach")); if \r~ok then return r
  r=self~projectSection("settlement.group",d,"settlement",.array~of("obligationId","obligationAmount","currency","instructionId","instructionState","instructionAmount","observationId","observationState","observedAmount","cumulativeObservedAmount","externalSettlementRef","sourceAuthority","settlementState")); if \r~ok then return r
  r=self~projectSection("accounting.group",d,"accounting",.array~of("journalId","journalStatus","policyRef","policyIdentity","settlementReceivablePayable","cashAtSettlementAgent","derivativeSettlementControl","accountingState","controlState","settlementDeterminationState","determinedSettlementAmount","roundingDifferenceMinor","settlementRulesetRef")); if \r~ok then return r
  return self~projectSection("market.group",d,"marketStructure",.array~of("marketStructureEventId","eventType","effectiveAt","instrumentEvidenceRef","hedgeClassification","hedgeEquivalenceEvidenceRef","riskState"))

::method projectSection private
  use arg group,d,prefix,names
  slots=.table~new; present=.false
  do k over names
    key=prefix||"."||k
    if d~hasIndex(key) then do; slots[k]=d[key]; present=.true; end
  end
  slots["visible"]=present
  return self~mutateState(group,slots)

::method hideDetail private
  do g over .array~of("detail.group","checkpoint.group","settlement.group","accounting.group","market.group")
    x=.table~new; x["visible"]=.false; r=self~mutateState(g,x); if \r~ok then return r
  end
  return .WireUIResult~success(self,"FBM_WORKSPACE_REFRESHED")

::method rowSlots private
  use arg r
  d=.table~new
  d["workspaceRef"]="FBM.BOOKS"
  d["semanticRowId"]=r["rootTradeId"]
  do k over .array~of("rootTradeId","portfolioId","clientEntity","clientState","contractCount","netBaseExposure","currency","riskState","executionState","remediationState","settlementState","accountingState","attention"); d[k]=r[k]; end
  return d

::method jsonStringArray private
  use arg values
  text="["; first=.true
  do v over values
    if \first then text||=","
    text||='"'||v~string||'"'
    first=.false
  end
  return text||"]"

::method filterRef private
  use arg filters
  keys=filters~allIndexes; keys~sort; text=""
  do k over keys; if text<>"" then text||=";"; text||=k||"="||filters[k]; end
  return text
::method detailOf private
  use arg message
  if message==.nil then return .directory~new
  if message~hasIndex("detail") & message["detail"]<>.nil then return message["detail"]
  return .directory~new
::method fieldOf private
  use arg object,key,default=.nil
  if object==.nil then return default
  if object~hasIndex(key) then return object[key]
  return default

::class FBMerchantWireRuntimeFactory public
::method buildFromPackage class
  use arg applicationId,sessionId,accessPointId,feed,wirePackage,merchantEntity="FEDERATIONBANK_MERCHANT_BANK",authorityAdapter=.nil
  if wirePackage==.nil | \wirePackage~hasMethod("HASINDEX") then return .WireUIResult~failure("FBM_COMPILED_PACKAGE_REQUIRED")
  catalogue=.WireUICompiledCatalogue~new(wirePackage)
  view=.WireUIView~new("FederationBank.Merchant.Operations","root"); projection=.WireUIProjection~new
  app=.FBMerchantWireApplication~new(applicationId,sessionId,accessPointId,view,projection,feed,merchantEntity,authorityAdapter)
  bound=app~bindCompiledRelease(catalogue,.WireUIProtocol~PROFILE_HUMAN_VISUAL,"OPERATIONS"); if \bound~ok then return bound
  installed=app~installInitialView; if \installed~ok then return installed
  return .WireUIResult~success(app,"FBM_WIRE_APPLICATION_READY")

::routine must
  use arg r
  if \r~ok then raise syntax 88.900 array(r~code,r~detail)
  return r

::requires "WireUIAll.cls"
::requires "WireUICompiledCatalogue.cls"
::requires "WireUICollectionWindow.cls"
::requires "FBMerchantWireProjectionFeed.cls"
