/* Federation regulated intermediary operational Wire UI application v0.7. */
::class RIDWireApplicationBuild public
::constant VERSION "0.7"
::constant API_VERSION "regulated.intermediary.wire-ui/0.7"

::class RIDIntermediaryWireApplication subclass WireUIApplication public
::method init
  expose engine catalog workService feed signingRegistry signatureService firmId representativeId windowRevision timelineRevision securityContext
  use arg applicationId,sessionId,accessPointId,view,projection,engineArg,catalogArg,workServiceArg,feedArg,signingRegistryArg=.nil,signatureServiceArg=.nil,firmIdArg,representativeIdArg="*",securityContextArg=.nil
  self~init:super(applicationId,sessionId,accessPointId,view,projection)
  engine=engineArg; catalog=catalogArg; workService=workServiceArg; feed=feedArg; signingRegistry=signingRegistryArg; signatureService=signatureServiceArg; securityContext=securityContextArg
  firmId=.RIDCanonical~required("firmId",firmIdArg)~upper; representativeId=representativeIdArg~string~upper; if representativeId="" then representativeId="*"
  windowRevision=0; timelineRevision=0

::method installInitialView
  expose firmId representativeId securityContext
  v=self~view; p=self~projection
  shell=.table~new; shell["visible"]=.true; shell["firmId"]=firmId; shell["representativeId"]=representativeId
  if securityContext<>.nil then do; shell["principalId"]=securityContext~principalId; shell["roleName"]=securityContext~roleName; shell["accessDecisionRef"]=securityContext~accessDecisionRef; end
  else do; shell["principalId"]=""; shell["roleName"]=""; shell["accessDecisionRef"]=""; end
  call must v~createInstance("root","RID_APP_SHELL@1",shell)
  summary=.table~new; summary["total"]=0; summary["actionRequired"]=0; summary["overdue"]=0; summary["waitingProvider"]=0; summary["complete"]=0
  call must v~createInstance("summary","RID_SUMMARY@1",summary,"root")
  query=.table~new; query["attentionState"]="ALL"; query["productFamily"]="ALL"; query["providerStatus"]="ALL"; query["sortRef"]="PRIORITY"; query["sortDirection"]="DESC"; query["actions"]=.array~of("CASES.FILTER","CASES.SORT","CASES.SELECT","DASHBOARD.REFRESH")
  call must v~createInstance("case-query","RID_CASE_QUERY@1",query,"root")
  do a over query["actions"]
    v~setActionAvailable("case-query",a,self~canPresent(a,"RID.WORKSPACE:"||firmId,"RIDINTERMEDIARYWORKSPACE"))
  end
  table=.table~new; table["windowTotalCount"]=0; table["queryRevision"]=0; table["scopeRevision"]=0; table["orderRevision"]=0; table["selectionRevision"]=0; table["resultRevision"]=0; table["resultQueryRevision"]=0; table["resultScopeRevision"]=0; table["resultOrderRevision"]=0
  call must v~createInstance("case-table","RID_CASE_TABLE@1",table,"root")
  detail=.table~new; detail["visible"]=.false; detail["canAcknowledge"]=.false; detail["actions"]=.array~of("WORK.ACK"); detail["workspaceRef"]="RID.CASES"
  call must v~createInstance("case-detail","RID_CASE_DETAIL@1",detail,"root"); v~setActionAvailable("case-detail","WORK.ACK",.false)
  signing=.table~new; signing["visible"]=.false; signing["canPrepareSignature"]=.false; signing["canSubmitSignature"]=.false; signing["actions"]=.array~of("SIGNATURE.PREPARE","SIGNATURE.SUBMIT"); signing["workspaceRef"]="RID.CASES"
  call must v~createInstance("signing","RID_SIGNING_PANEL@1",signing,"root"); v~setActionAvailable("signing","SIGNATURE.PREPARE",.false); v~setActionAvailable("signing","SIGNATURE.SUBMIT",.false)
  timeline=.table~new; timeline["visible"]=.false; timeline["windowTotalCount"]=0; timeline["windowRevision"]=0
  call must v~createInstance("case-timeline","RID_CASE_TIMELINE@1",timeline,"root")
  call must self~registerWorkspace("RID.CASES")

  p~bindSlots("summary.group","summary")
  p~bindSlots("query.group","case-query")
  p~bindSlots("table.group","case-table")
  p~bindSlots("detail.group","case-detail")
  p~bindSlots("signing.group","signing")
  p~bindSlots("timeline.group","case-timeline")
  r=self~refreshDashboard
  if \r~ok then return r
  return .WireUIResult~success(self,"RID_WIRE_INITIAL_VIEW_INSTALLED")

::method refreshDashboard
  expose feed windowRevision firmId
  pr=feed~pump; if \pr~ok then return .WireUIResult~failure(pr~code,pr~detail)
  q=self~workspaceQuery("RID.CASES"); filters=q~filters; qw=q~asWire; sortRef="PRIORITY"; direction="DESC"
  if qw~hasIndex("sort") then do; sortRef=qw["sort"]["sortRef"]; direction=qw["sort"]["direction"]; end
  rows=feed~rows(filters,sortRef,direction)
  wireRows=.array~new
  do a over rows
    slots=self~rowSlots(a)
    row=.directory~new; row["instanceId"]=a["case_id"]; row["definitionKey"]="RID_CASE_ROW@1"; row["slots"]=slots; wireRows~append(row)
  end
  windowRevision+=1
  fref=self~filterRef(filters)
  window=.WireUICollectionWindow~new("case-table",0,100,rows~items,sortRef||":"||direction,fref,windowRevision,"")
  rr=self~reconcileCollectionWindow("case-table",wireRows,window); if \rr~ok then return rr
  do a over rows; self~view~setActionAvailable(a["case_id"],"CASE.OPEN",self~canPresent("CASE.OPEN","RID.CASE:"||a["case_id"],"RIDDISTRIBUTIONCASE")); end
  s=feed~summary(filters)
  sumSlots=.table~new; sumSlots["total"]=s["TOTAL"]; sumSlots["actionRequired"]=s["ACTION_REQUIRED"]; sumSlots["overdue"]=s["OVERDUE"]; sumSlots["waitingProvider"]=s["WAITING_PROVIDER"]; sumSlots["complete"]=s["COMPLETE"]
  mr=self~mutateState("summary.group",sumSlots); if \mr~ok then return mr
  querySlots=.table~new; querySlots["attentionState"]=self~fieldOf(filters,"attention_state","ALL"); querySlots["productFamily"]=self~fieldOf(filters,"product_family","ALL"); querySlots["providerStatus"]=self~fieldOf(filters,"provider_status","ALL"); querySlots["sortRef"]=sortRef; querySlots["sortDirection"]=direction
  mr=self~mutateState("query.group",querySlots); if \mr~ok then return mr
  aggregates=.table~new; aggregates["ACTION_REQUIRED"]=s["ACTION_REQUIRED"]; aggregates["OVERDUE"]=s["OVERDUE"]; aggregates["WAITING_PROVIDER"]=s["WAITING_PROVIDER"]; aggregates["COMPLETE"]=s["COMPLETE"]
  pub=self~publishWorkspaceResult("RID.CASES",rows~items,aggregates,"RID.CASE.ATTENTION:"||firmId,.DateTime~new~string); if \pub~ok then return pub
  sel=self~workspaceSelection("RID.CASES"); wresult=self~workspaceResult("RID.CASES")
  tableSlots=.table~new; tableSlots["queryRevision"]=q~queryRevision; tableSlots["scopeRevision"]=q~scopeRevision; tableSlots["orderRevision"]=q~orderRevision; tableSlots["selectionRevision"]=sel~selectionRevision; tableSlots["resultRevision"]=wresult~resultRevision; tableSlots["resultQueryRevision"]=wresult~queryRevision; tableSlots["resultScopeRevision"]=wresult~scopeRevision; tableSlots["resultOrderRevision"]=wresult~orderRevision
  mr=self~mutateState("table.group",tableSlots); if \mr~ok then return mr
  if sel~selectedIds~items=1 then do
    selected=sel~selectedIds[1]
    if feed~containsCaseInScope(selected,filters) then return self~projectCase(selected)
  end
  return .WireUIResult~success(rows~items,"RID_DASHBOARD_REFRESHED")

::method dispatchSemanticAction
  expose feed workService signingRegistry signatureService
  use arg action,message
  detail=self~detailOf(message)
  auth=self~authorizeAction(action,detail)
  if \auth~ok then return auth
  select
    when action="DASHBOARD.REFRESH" then return self~refreshDashboard
    when action="CASES.FILTER" then do
      ref=self~fieldOf(detail,"filterRef","")~string~lower; value=self~fieldOf(detail,"value","ALL")~string~upper
      if ref<>"attention_state" & ref<>"product_family" & ref<>"provider_status" & ref<>"waiting_on" then return .WireUIResult~failure("RID_FILTER_NOT_ALLOWED",ref)
      if value="" | value="ALL" | value="*" then r=self~removeWorkspaceFilter("RID.CASES",ref)
      else r=self~setWorkspaceFilter("RID.CASES",ref,value)
      if \r~ok then return r
      return self~refreshDashboard
    end
    when action="CASES.SORT" then do
      ref=self~fieldOf(detail,"sortRef","")~string~upper; direction=self~fieldOf(detail,"direction","DESC")~string~upper
      if ref<>"PRIORITY" & ref<>"CASE_ID" & ref<>"PROVIDER_STATUS" & ref<>"PRODUCT_FAMILY" & ref<>"ATTENTION" then return .WireUIResult~failure("RID_SORT_NOT_ALLOWED",ref)
      r=self~setWorkspaceSort("RID.CASES",ref,direction); if \r~ok then return r
      return self~refreshDashboard
    end
    when action="CASES.SELECT" then do
      ids=self~fieldOf(detail,"selectedIds",.nil); scope=self~fieldOf(detail,"scopeRevision",-1)
      if ids==.nil | \ids~isA(.Array) then return .WireUIResult~failure("RID_SELECTION_REQUIRED")
      q=self~workspaceQuery("RID.CASES"); if scope<>q~scopeRevision then return .WireUIResult~failure("RID_SELECTION_SCOPE_STALE")
      filters=q~filters
      do id over ids
        if \feed~containsCaseInScope(id,filters) then return .WireUIResult~failure("RID_SELECTION_OUT_OF_SCOPE",id)
      end
      r=self~setWorkspaceSelection("RID.CASES",scope,ids); if \r~ok then return r
      return self~refreshDashboard
    end
    when action="CASE.OPEN" then do
      caseId=self~fieldOf(detail,"caseId","")
      sr=self~selectedCase(caseId); if \sr~ok then return sr
      return self~projectCase(caseId)
    end
    when action="WORK.ACK" then do
      caseId=self~fieldOf(detail,"caseId",""); sr=self~selectedCase(caseId); if \sr~ok then return sr
      w=feed~activeWorkForCase(caseId); if w==.nil then return .WireUIResult~failure("RID_ACTIVE_WORK_NOT_FOUND")
      if w["completion_mode"]<>"ACK" then return .WireUIResult~failure("RID_WORK_REQUIRES_SIGNATURE")
      r=workService~completeWork(w["work_item_id"],"WIRE_ACK:"||self~sessionId||":"||.DateTime~new~string)
      if \r~ok then return .WireUIResult~failure(r~code,r~detail)
      return self~refreshDashboard
    end
    when action="SIGNATURE.PREPARE" then do
      if signingRegistry==.nil then return .WireUIResult~failure("RID_SIGNING_NOT_CONFIGURED")
      caseId=self~fieldOf(detail,"caseId",""); sr=self~selectedCase(caseId); if \sr~ok then return sr
      w=feed~activeWorkForCase(caseId); if w==.nil then return .WireUIResult~failure("RID_ACTIVE_WORK_NOT_FOUND")
      if w["completion_mode"]<>"SIGNATURE" then return .WireUIResult~failure("RID_WORK_NOT_SIGNATURE_MODE")
      r=signingRegistry~prepare(w["work_item_id"],self~fieldOf(detail,"requirementId",""),self~fieldOf(detail,"authenticationRef",""),self~fieldOf(detail,"consentRef",""))
      if \r~ok then return .WireUIResult~failure(r~code,r~detail)
      return self~projectChallenge(r~value)
    end
    when action="SIGNATURE.SUBMIT" then do
      if signingRegistry==.nil | signatureService==.nil then return .WireUIResult~failure("RID_SIGNING_NOT_CONFIGURED")
      caseId=self~fieldOf(detail,"caseId",""); sr=self~selectedCase(caseId); if \sr~ok then return sr
      challenge=signingRegistry~challenge(self~fieldOf(detail,"challengeId","")); if challenge==.nil then return .WireUIResult~failure("SIGNING_CHALLENGE_NOT_FOUND")
      if challenge~caseId<>caseId then return .WireUIResult~failure("SIGNING_CHALLENGE_CASE_MISMATCH")
      r=signingRegistry~submit(challenge~challengeId,self~fieldOf(detail,"keyId",""),self~fieldOf(detail,"signatureHex",""),self~fieldOf(detail,"evidenceRef",""),signatureService)
      if \r~ok then return .WireUIResult~failure(r~code,r~detail)
      return self~refreshDashboard
    end
    otherwise return .WireUIResult~failure("RID_WIRE_ACTION_UNSUPPORTED",action)
  end

::method selectedCase private
  use arg requested
  requested=.RIDCanonical~token(requested); sel=self~workspaceSelection("RID.CASES")~selectedIds
  if sel~items<>1 then return .WireUIResult~failure("RID_SINGLE_CASE_SELECTION_REQUIRED")
  if sel[1]<>requested then return .WireUIResult~failure("RID_SELECTED_CASE_MISMATCH",requested)
  return .WireUIResult~success(requested)

::method rowSlots private
  expose feed
  use arg a
  w=feed~activeWorkForCase(a["case_id"])
  d=.table~new
  d["caseId"]=a["case_id"]; d["productFamily"]=a["product_family"]; d["workflowState"]=a["workflow_state"]; d["providerStatus"]=a["provider_status"]; d["attentionState"]=a["attention_state"]; d["nextAction"]=a["next_action"]; d["waitingOn"]=a["waiting_on"]; d["priority"]=a["priority"]+0; d["dueTick"]=a["due_tick"]
  if w==.nil then do; d["workItemId"]=""; d["workStatus"]=""; end
  else do; d["workItemId"]=w["work_item_id"]; d["workStatus"]=w["status"]; end
  d["action"]="CASE.OPEN"; d["workspaceRef"]="RID.CASES"
  return d

::method projectCase private
  expose engine catalog feed signingRegistry
  use arg caseId
  a=feed~attention(caseId); if a==.nil then return .WireUIResult~failure("RID_CASE_NOT_IN_WIRE_SCOPE",caseId)
  c=engine~case(caseId); if c==.nil then return .WireUIResult~failure("UNKNOWN_CASE")
  p=catalog~product(c~productRefId); if p==.nil then return .WireUIResult~failure("UNKNOWN_PRODUCT")
  w=feed~activeWorkForCase(caseId)
  if w==.nil then w=feed~latestWorkForCase(caseId)
  u=.table~new
  u["caseId"]=c~caseId; u["subjectRef"]=c~subjectRef; u["productRefId"]=c~productRefId; u["productFamily"]=p~productFamily; u["workflowState"]=a["workflow_state"]; u["providerStatus"]=a["provider_status"]; u["providerSequence"]=a["provider_sequence"]+0; u["providerEventId"]=a["provider_event_id"]; u["nextAction"]=a["next_action"]; u["priority"]=a["priority"]+0; u["visible"]=.true
  if w==.nil then do; u["workItemId"]=""; u["workStatus"]=""; u["completionMode"]=""; u["completionEvidenceRef"]=""; end
  else do; u["workItemId"]=w["work_item_id"]; u["workStatus"]=w["status"]; u["completionMode"]=w["completion_mode"]; u["completionEvidenceRef"]=w["completion_evidence_ref"]; end
  r=self~mutateState("detail.group",u); if \r~ok then return r
  canAck=.false; canPrepare=.false; canSubmit=.false
  if w<>.nil then do
    canAck=w["completion_mode"]="ACK" & self~canPresent("WORK.ACK","RID.WORK:"||w["work_item_id"],"RIDINTERMEDIARYWORK")
    canPrepare=w["completion_mode"]="SIGNATURE" & self~canPresent("SIGNATURE.PREPARE","RID.WORK:"||w["work_item_id"],"RIDSIGNINGCEREMONY")
    canSubmit=w["completion_mode"]="SIGNATURE" & self~canPresent("SIGNATURE.SUBMIT","RID.WORK:"||w["work_item_id"],"RIDSIGNINGCEREMONY")
  end
  self~view~setActionAvailable("case-detail","WORK.ACK",canAck); self~view~setActionAvailable("signing","SIGNATURE.PREPARE",canPrepare); self~view~setActionAvailable("signing","SIGNATURE.SUBMIT",canSubmit)
  permSlots=.table~new; permSlots["canAcknowledge"]=canAck; mr=self~mutateState("detail.group",permSlots); if \mr~ok then return mr
  signPerm=.table~new; signPerm["canPrepareSignature"]=canPrepare; signPerm["canSubmitSignature"]=canSubmit; mr=self~mutateState("signing.group",signPerm); if \mr~ok then return mr
  tr=self~projectTimeline(caseId); if \tr~ok then return tr
  if w<>.nil then do
    if w["completion_mode"]="SIGNATURE" & signingRegistry<>.nil then do
      env=signingRegistry~envelopeForWork(w["work_item_id"])
      if env<>.nil then return self~projectEnvelope(w["work_item_id"],env)
    end
  end
  hide=.table~new; hide["visible"]=.false; return self~mutateState("signing.group",hide)

::method projectTimeline private
  expose engine workService timelineRevision
  use arg caseId
  c=engine~case(caseId); if c==.nil then return .WireUIResult~failure("UNKNOWN_CASE")
  entries=.array~new
  do ev over c~events
    if ev~eventType="PROVIDER_STATUS_RECORDED" | ev~eventType="EVIDENCE_ATTACHED" then iterate
    d=.table~new; d["timelineId"]="RID-TL-EVENT-"||ev~eventId; d["kind"]="CASE"; d["occurredAt"]=ev~occurredAt~string; d["label"]=ev~eventType
    if ev~fromState<>"" | ev~toState<>"" then d["status"]=ev~fromState||"->"||ev~toState; else d["status"]=""
    d["actorRef"]=ev~actorRole||":"||ev~actorId; d["evidenceRef"]=ev~evidenceRef; d["sourceRef"]=""
    entries~append(d)
  end
  do pe over c~providerStatusHistory
    d=.table~new; d["timelineId"]="RID-TL-PROVIDER-"||pe~eventId; d["kind"]="PROVIDER"; d["occurredAt"]=pe~occurredAt~string; d["label"]="Provider status"; d["status"]=pe~status
    d["actorRef"]=pe~providerEntityId||"|"||pe~providerSystem; d["evidenceRef"]=pe~eventId; d["sourceRef"]=pe~sourceRef
    entries~append(d)
  end
  do evd over c~evidences
    d=.table~new; d["timelineId"]="RID-TL-EVIDENCE-"||evd~evidenceId; d["kind"]="EVIDENCE"; d["occurredAt"]=evd~recordedAt~string; d["label"]=evd~evidenceType; d["status"]=evd~semanticKind
    d["actorRef"]=evd~authorityClass; d["evidenceRef"]=evd~evidenceId; d["sourceRef"]=evd~sourceSystem||":"||evd~sourceRef
    entries~append(d)
  end
  do wi over workService~workItemsForCase(caseId)
    d=.table~new; d["timelineId"]="RID-TL-WORK-"||wi~workItemId; d["kind"]="WORK"; d["occurredAt"]=wi~updatedAt~string; d["label"]=wi~workType; d["status"]=wi~status
    d["actorRef"]=wi~audience; d["evidenceRef"]=wi~completionEvidenceRef; d["sourceRef"]=wi~sourceEventId
    entries~append(d)
  end
  if entries~items>1 then do i=2 to entries~items
    moving=entries[i]; j=i-1
    do while j>=1
      if \self~timelineBefore(moving,entries[j]) then leave
      entries[j+1]=entries[j]; j-=1
    end
    entries[j+1]=moving
  end
  total=entries~items; visible=.array~new; max=total; if max>100 then max=100
  if max>0 then do i=1 to max
    e=entries[i]; row=.directory~new; row["instanceId"]=e["timelineId"]; row["definitionKey"]="RID_TIMELINE_ROW@1"; row["slots"]=e; visible~append(row)
  end
  timelineRevision+=1
  window=.WireUICollectionWindow~new("case-timeline",0,100,total,"OCCURRED_AT:DESC",caseId,timelineRevision,"")
  rr=self~reconcileCollectionWindow("case-timeline",visible,window); if \rr~ok then return rr
  state=.table~new; state["visible"]=.true; state["windowTotalCount"]=total; state["windowRevision"]=timelineRevision
  mr=self~mutateState("timeline.group",state); if \mr~ok then return mr
  return .WireUIResult~success(total,"RID_CASE_TIMELINE_PROJECTED")

::method timelineBefore private
  use arg a,b
  if a["occurredAt"]~string=b["occurredAt"]~string then return a["timelineId"]~string > b["timelineId"]~string
  return a["occurredAt"]~string > b["occurredAt"]~string

::method projectEnvelope private
  use arg workId,env
  u=.table~new; u["workItemId"]=workId; u["envelopeId"]=env~envelopeId; u["documentType"]=env~documentType; u["documentSemanticIdentity"]=env~documentSemanticIdentity; u["documentVersion"]=env~documentVersion; u["digestAlgorithm"]=env~digestAlgorithm; u["contentDigest"]=env~contentDigest; u["storageRef"]=env~storageRef; u["durableMediumRef"]=env~durableMediumRef; u["envelopeState"]=env~state; u["challengeId"]=""; u["requirementId"]=""; u["signerRef"]=""; u["signerRole"]=""; u["purpose"]=""; u["canonicalMessage"]=""; u["expiresTick"]=""; u["visible"]=.true
  return self~mutateState("signing.group",u)

::method projectChallenge private
  use arg c
  u=.table~new; u["challengeId"]=c~challengeId; u["requirementId"]=c~requirementId; u["signerRef"]=c~signerRef; u["signerRole"]=c~signerRole; u["purpose"]=c~purpose; u["canonicalMessage"]=c~canonicalMessage; u["expiresTick"]=c~expiresTick~string; u["visible"]=.true
  r=self~mutateState("signing.group",u); if \r~ok then return r
  return .WireUIResult~success(c~asWire,"RID_SIGNING_CHALLENGE_READY")

::method filterRef private
  use arg filters
  keys=filters~allIndexes; keys~sort; text=""
  do k over keys; if text<>"" then text||=";"; text||=k||"="||filters[k]; end
  return text

::method authorizeAction private
  expose securityContext firmId feed signingRegistry
  use arg action,detail
  if securityContext==.nil then return .WireUIResult~failure("RID_WIRE_SECURITY_CONTEXT_REQUIRED")
  objectId="RID.WORKSPACE:"||firmId; objectClass="RIDINTERMEDIARYWORKSPACE"
  if action="CASE.OPEN" then do; objectId="RID.CASE:"||self~fieldOf(detail,"caseId",""); objectClass="RIDDISTRIBUTIONCASE"; end
  else if action="WORK.ACK" | action="SIGNATURE.PREPARE" then do
    caseId=self~fieldOf(detail,"caseId",""); w=feed~activeWorkForCase(caseId); if w==.nil then return .WireUIResult~failure("RID_ACTIVE_WORK_NOT_FOUND")
    objectId="RID.WORK:"||w["work_item_id"]; if action="WORK.ACK" then objectClass="RIDINTERMEDIARYWORK"; else objectClass="RIDSIGNINGCEREMONY"
  end
  else if action="SIGNATURE.SUBMIT" then do
    if signingRegistry==.nil then return .WireUIResult~failure("RID_SIGNING_NOT_CONFIGURED")
    c=signingRegistry~challenge(self~fieldOf(detail,"challengeId","")); if c==.nil then return .WireUIResult~failure("SIGNING_CHALLENGE_NOT_FOUND")
    objectId="RID.WORK:"||c~workItemId; objectClass="RIDSIGNINGCEREMONY"
  end
  r=securityContext~permit(objectId,objectClass,action)
  if \r~ok then return .WireUIResult~failure(r~code,r~detail)
  return .WireUIResult~success(r~value,"RID_WIRE_ACTION_AUTHORISED")

::method canPresent private
  expose securityContext
  use arg action,objectId,objectClass
  if securityContext==.nil then return .false
  r=securityContext~preview(objectId,objectClass,action)
  return r~ok

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

::class RIDWireRuntimeFactory public
::method build class
  use arg applicationId,sessionId,accessPointId,engine,catalog,workService,feed,signingRegistry=.nil,signatureService=.nil,firmId,representativeId="*",securityContext=.nil
  if securityContext==.nil then return .WireUIResult~failure("RID_WIRE_SECURITY_CONTEXT_REQUIRED")
  access=securityContext~enter(accessPointId); if \access~ok then return .WireUIResult~failure(access~code,access~detail)
  design=.RIDWireUIDesignFixture~build
  compiled=.WireUICompiler~new~compile(design["workspace"],design["release"]); if \compiled~ok then return compiled
  catalogueUI=.WireUICompiledCatalogue~new(compiled~value)
  view=.WireUIView~new("Federation.RID.Intermediary","root"); projection=.WireUIProjection~new
  app=.RIDIntermediaryWireApplication~new(applicationId,sessionId,accessPointId,view,projection,engine,catalog,workService,feed,signingRegistry,signatureService,firmId,representativeId,securityContext)
  bound=app~bindCompiledRelease(catalogueUI,.WireUIProtocol~PROFILE_HUMAN_VISUAL,"DASHBOARD"); if \bound~ok then return bound
  installed=app~installInitialView; if \installed~ok then return installed
  return .WireUIResult~success(app,"RID_WIRE_APPLICATION_READY")

::routine must
  use arg r
  if \r~ok then raise syntax 88.900 array(r~code,r~detail)
  return r

::requires "WireUIAll.cls"
::requires "WireUICompiledCatalogue.cls"
::requires "WireUICollectionWindow.cls"
::requires "RIDWireUIDesignFixture.cls"
::requires "RIDWireReadModel.cls"
::requires "RIDWireSigning.cls"
::requires "RIDWireAuthority.cls"
