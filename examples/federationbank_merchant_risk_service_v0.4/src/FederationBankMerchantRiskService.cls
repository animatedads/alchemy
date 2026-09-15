/* FederationBankMerchantRiskService v0.4
 * Operational surveillance around FederationBank Merchant Bank v0.13.
 * The service discovers/coordinates; Merchant Bank remains risk authority.
 */
::class MBRiskServiceBuild public
::constant VERSION "0.4"
::constant API_VERSION "federationbank.merchant.risk.service/0.4"
::constant STATE_FORMAT "federationbank.merchant.risk.service.state/2"
::constant LEGACY_STATE_FORMAT "federationbank.merchant.risk.service.state/1"
::constant SERVICE_ID "FEDERATIONBANK_MERCHANT_RISK_SERVICE"

::class MBRiskServiceResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg okArg,codeArg,detailArg="",valueArg=.nil
  ok=okArg; code=codeArg~string; detail=detailArg~string; value=valueArg
::method success class
  use arg value=.nil,detail=""
  return self~new(.true,"OK",detail,value)
::method failure class
  use arg code,detail="",value=.nil
  return self~new(.false,code,detail,value)

::class MBRiskMarketStructureNotice public
::method init
  expose eventId eventType effectiveAt jurisdiction sourceAuthority sourceRef legalEffectRef affectedInstrumentEvidenceRef conversionAvailable settlementAvailable custodyTransferAvailable legalTransferPermitted marketLiquidityAvailable reasonCode
  use strict arg eventId,eventType,effectiveAt,jurisdiction,sourceAuthority,sourceRef,legalEffectRef,affectedInstrumentEvidenceRef,conversionAvailable=.true,settlementAvailable=.true,custodyTransferAvailable=.true,legalTransferPermitted=.true,marketLiquidityAvailable=.true,reasonCode=""
  if eventId="" | eventType="" | effectiveAt="" | jurisdiction="" | sourceAuthority="" | sourceRef="" | legalEffectRef="" | affectedInstrumentEvidenceRef="" then raise syntax 88.900 array("invalid Merchant Risk market-structure notice")
::method eventId; expose eventId; return eventId
::method eventType; expose eventType; return eventType
::method effectiveAt; expose effectiveAt; return effectiveAt
::method jurisdiction; expose jurisdiction; return jurisdiction
::method sourceAuthority; expose sourceAuthority; return sourceAuthority
::method sourceRef; expose sourceRef; return sourceRef
::method legalEffectRef; expose legalEffectRef; return legalEffectRef
::method affectedInstrumentEvidenceRef; expose affectedInstrumentEvidenceRef; return affectedInstrumentEvidenceRef
::method conversionAvailable; expose conversionAvailable; return conversionAvailable
::method settlementAvailable; expose settlementAvailable; return settlementAvailable
::method custodyTransferAvailable; expose custodyTransferAvailable; return custodyTransferAvailable
::method legalTransferPermitted; expose legalTransferPermitted; return legalTransferPermitted
::method marketLiquidityAvailable; expose marketLiquidityAvailable; return marketLiquidityAvailable
::method reasonCode; expose reasonCode; return reasonCode
::method toDomainEvent
  expose eventId eventType effectiveAt jurisdiction sourceAuthority sourceRef legalEffectRef affectedInstrumentEvidenceRef conversionAvailable settlementAvailable custodyTransferAvailable legalTransferPermitted marketLiquidityAvailable reasonCode
  return .MBMarketStructureEvent~new(eventId,eventType,effectiveAt,jurisdiction,sourceAuthority,sourceRef,legalEffectRef,affectedInstrumentEvidenceRef,conversionAvailable,settlementAvailable,custodyTransferAvailable,legalTransferPermitted,marketLiquidityAvailable,reasonCode)
::method queuePersistentType; return "federationbank.merchant.risk.market-structure-notice/1"
::method queuePersistentState
  expose eventId eventType effectiveAt jurisdiction sourceAuthority sourceRef legalEffectRef affectedInstrumentEvidenceRef conversionAvailable settlementAvailable custodyTransferAvailable legalTransferPermitted marketLiquidityAvailable reasonCode
  s=.table~new; s["eventId"]=eventId; s["eventType"]=eventType; s["effectiveAt"]=effectiveAt; s["jurisdiction"]=jurisdiction; s["sourceAuthority"]=sourceAuthority; s["sourceRef"]=sourceRef; s["legalEffectRef"]=legalEffectRef; s["affectedInstrumentEvidenceRef"]=affectedInstrumentEvidenceRef
  if conversionAvailable then s["conversionAvailable"]="1"; else s["conversionAvailable"]="0"
  if settlementAvailable then s["settlementAvailable"]="1"; else s["settlementAvailable"]="0"
  if custodyTransferAvailable then s["custodyTransferAvailable"]="1"; else s["custodyTransferAvailable"]="0"
  if legalTransferPermitted then s["legalTransferPermitted"]="1"; else s["legalTransferPermitted"]="0"
  if marketLiquidityAvailable then s["marketLiquidityAvailable"]="1"; else s["marketLiquidityAvailable"]="0"
  s["reasonCode"]=reasonCode; return s
::method queueRestoreState
  expose eventId eventType effectiveAt jurisdiction sourceAuthority sourceRef legalEffectRef affectedInstrumentEvidenceRef conversionAvailable settlementAvailable custodyTransferAvailable legalTransferPermitted marketLiquidityAvailable reasonCode
  use arg s
  eventId=s["eventId"]~string; eventType=s["eventType"]~string; effectiveAt=s["effectiveAt"]~string; jurisdiction=s["jurisdiction"]~string; sourceAuthority=s["sourceAuthority"]~string; sourceRef=s["sourceRef"]~string; legalEffectRef=s["legalEffectRef"]~string; affectedInstrumentEvidenceRef=s["affectedInstrumentEvidenceRef"]~string
  conversionAvailable=(s["conversionAvailable"]~string="1"); settlementAvailable=(s["settlementAvailable"]~string="1"); custodyTransferAvailable=(s["custodyTransferAvailable"]~string="1"); legalTransferPermitted=(s["legalTransferPermitted"]~string="1"); marketLiquidityAvailable=(s["marketLiquidityAvailable"]~string="1"); reasonCode=s["reasonCode"]~string; return self

::class MBRiskServiceEnvelope public
::method init
  expose commandId commandType actorId actorRole requestedAt correlationId replyTo payload
  use arg commandIdArg,commandTypeArg,actorIdArg,actorRoleArg,payloadArg=.nil,requestedAtArg="",correlationIdArg="",replyToArg=""
  commandId=commandIdArg~string; commandType=commandTypeArg~string~strip~upper; actorId=actorIdArg~string; actorRole=actorRoleArg~string~strip~upper
  if commandId="" | commandType="" | actorId="" | actorRole="" then raise syntax 88.900 array("invalid Merchant Risk service command")
  if requestedAtArg="" then requestedAt=.DateTime~new~string; else requestedAt=requestedAtArg~string
  if correlationIdArg="" then correlationId=commandId; else correlationId=correlationIdArg~string
  replyTo=replyToArg~string
  if payloadArg==.nil then payload=.directory~new; else payload=payloadArg
::method commandId; expose commandId; return commandId
::method commandType; expose commandType; return commandType
::method actorId; expose actorId; return actorId
::method actorRole; expose actorRole; return actorRole
::method requestedAt; expose requestedAt; return requestedAt
::method correlationId; expose correlationId; return correlationId
::method replyTo; expose replyTo; return replyTo
::method payload; expose payload; return payload
::method fingerprint
  expose commandType actorId actorRole payload
  marker=""
  if payload~hasIndex("notice") then marker=payload["notice"]~eventId
  else if commandType="RISK.REMEDIATION.PLAN.PROPOSE" & payload~hasIndex("planId") then do
    marker=payload["planId"]~string||"|"||payload["remediationId"]~string||"|"||payload["rootTradeId"]~string||"|"||payload["baselineBookAssessmentId"]~string||"|"||payload["policyRef"]~string
    if payload~hasIndex("steps") then do
      steps=payload["steps"]
      do i=1 to steps~items
        st=steps[i]
        marker=marker||"|"||st["stepId"]~string||":"||st["sequence"]~string||":"||st["actionType"]~string
        if st~hasIndex("targetRef") then marker=marker||":"||st["targetRef"]~string; else marker=marker||":"
        if st~hasIndex("signedBaseExposureDelta") then marker=marker||":"||st["signedBaseExposureDelta"]~string; else marker=marker||":0"
        if st~hasIndex("instrumentEvidenceRef") then marker=marker||":"||st["instrumentEvidenceRef"]~string; else marker=marker||":"
      end
    end
  end
  else if commandType="RISK.REMEDIATION.PLAN.APPROVE" & payload~hasIndex("approvalId") then marker=payload["approvalId"]~string||"|"||payload["planId"]~string||"|"||payload["approvalAuthorityRef"]~string||"|"||payload["policyRef"]~string
  else if commandType="RISK.REMEDIATION.PLAN.EXECUTION.INGEST" & payload~hasIndex("evidenceId") then do
    marker=payload["evidenceId"]~string||"|"||payload["planId"]~string||"|"||payload["stepId"]~string||"|"||payload["executionSequence"]~string||"|"||payload["executionState"]~string||"|"||payload["sourceRef"]~string||"|"||payload["authorityRef"]~string
    if payload~hasIndex("actualObjectRef") then marker=marker||"|"||payload["actualObjectRef"]~string; else marker=marker||"|"
    if payload~hasIndex("observedSignedBaseExposureDelta") then marker=marker||"|"||payload["observedSignedBaseExposureDelta"]~string; else marker=marker||"|0"
    marker=marker||"|"||payload["policyRef"]~string
  end
  else if commandType="RISK.REMEDIATION.PLAN.EXECUTION.LIST" & payload~hasIndex("planId") then marker=payload["planId"]~string
  else if payload~hasIndex("hedgeId") then marker=payload["hedgeId"]~string
  else if payload~hasIndex("rootTradeId") then marker=payload["rootTradeId"]~string
  else if payload~hasIndex("policyRef") then marker=payload["policyRef"]~string
  return commandType||"|"||actorId||"|"||actorRole||"|"||marker
::method queuePersistentType; return "federationbank.merchant.risk.command/1"
::method queuePersistentState
  expose commandId commandType actorId actorRole requestedAt correlationId replyTo payload
  s=.table~new; s["commandId"]=commandId; s["commandType"]=commandType; s["actorId"]=actorId; s["actorRole"]=actorRole; s["requestedAt"]=requestedAt; s["correlationId"]=correlationId; s["replyTo"]=replyTo; s["payload"]=payload; return s
::method queueRestoreState
  expose commandId commandType actorId actorRole requestedAt correlationId replyTo payload
  use arg s
  commandId=s["commandId"]~string; commandType=s["commandType"]~string; actorId=s["actorId"]~string; actorRole=s["actorRole"]~string; requestedAt=s["requestedAt"]~string; correlationId=s["correlationId"]~string; replyTo=s["replyTo"]~string; payload=s["payload"]; return self

::class MBRiskServiceReply public
::method init
  expose commandId correlationId ok code detail value
  use arg commandIdArg,correlationIdArg,okArg,codeArg,detailArg="",valueArg=.nil
  commandId=commandIdArg~string; correlationId=correlationIdArg~string; ok=okArg; code=codeArg~string; detail=detailArg~string; value=valueArg
::method commandId; expose commandId; return commandId
::method correlationId; expose correlationId; return correlationId
::method ok; expose ok; return ok
::method code; expose code; return code
::method detail; expose detail; return detail
::method value; expose value; return value
::method queuePersistentType; return "federationbank.merchant.risk.reply/1"
::method queuePersistentState
  expose commandId correlationId ok code detail value
  s=.table~new; s["commandId"]=commandId; s["correlationId"]=correlationId; if ok then s["ok"]="1"; else s["ok"]="0"; s["code"]=code; s["detail"]=detail; s["value"]=value; return s
::method queueRestoreState
  expose commandId correlationId ok code detail value
  use arg s
  commandId=s["commandId"]~string; correlationId=s["correlationId"]~string; ok=(s["ok"]~string="1"); code=s["code"]~string; detail=s["detail"]~string; value=s["value"]; return self

::class MBRiskWatch public
::method init
  expose hedgeId policyRef registeredAt registeredBy
  use strict arg hedgeId,policyRef,registeredAt,registeredBy
  if hedgeId="" | policyRef="" | registeredAt="" | registeredBy="" then raise syntax 88.900 array("invalid hedge surveillance watch")
::method hedgeId; expose hedgeId; return hedgeId
::method policyRef; expose policyRef; return policyRef
::method registeredAt; expose registeredAt; return registeredAt
::method registeredBy; expose registeredBy; return registeredBy
::method queuePersistentType; return "federationbank.merchant.risk.watch/1"
::method queuePersistentState
  expose hedgeId policyRef registeredAt registeredBy
  s=.table~new; s["hedgeId"]=hedgeId; s["policyRef"]=policyRef; s["registeredAt"]=registeredAt; s["registeredBy"]=registeredBy; return s
::method queueRestoreState
  expose hedgeId policyRef registeredAt registeredBy
  use arg s
  hedgeId=s["hedgeId"]~string; policyRef=s["policyRef"]~string; registeredAt=s["registeredAt"]~string; registeredBy=s["registeredBy"]~string; return self

::class MBRiskWorkItem public
::method init
  expose workId workType hedgeId remediationId sourceEventId createdAt policyRef state rootTradeId bookAssessmentId bookState netBaseExposure
  use strict arg workId,workType,hedgeId,remediationId,sourceEventId,createdAt,policyRef,rootTradeId="",bookAssessmentId="",bookState="",netBaseExposure=0
  if workId="" | workType="" | hedgeId="" | sourceEventId="" | createdAt="" | policyRef="" then raise syntax 88.900 array("invalid Merchant Risk work item")
  state="OPEN"
::method workId; expose workId; return workId
::method workType; expose workType; return workType
::method hedgeId; expose hedgeId; return hedgeId
::method remediationId; expose remediationId; return remediationId
::method sourceEventId; expose sourceEventId; return sourceEventId
::method createdAt; expose createdAt; return createdAt
::method policyRef; expose policyRef; return policyRef
::method state; expose state; return state
::method rootTradeId; expose rootTradeId; return rootTradeId
::method bookAssessmentId; expose bookAssessmentId; return bookAssessmentId
::method bookState; expose bookState; return bookState
::method netBaseExposure; expose netBaseExposure; return netBaseExposure
::method queuePersistentType; return "federationbank.merchant.risk.work/2"
::method queuePersistentState
  expose workId workType hedgeId remediationId sourceEventId createdAt policyRef state rootTradeId bookAssessmentId bookState netBaseExposure
  s=.table~new; s["workId"]=workId; s["workType"]=workType; s["hedgeId"]=hedgeId; s["remediationId"]=remediationId; s["sourceEventId"]=sourceEventId; s["createdAt"]=createdAt; s["policyRef"]=policyRef; s["state"]=state
  s["rootTradeId"]=rootTradeId; s["bookAssessmentId"]=bookAssessmentId; s["bookState"]=bookState; s["netBaseExposure"]=netBaseExposure; return s
::method queueRestoreState
  expose workId workType hedgeId remediationId sourceEventId createdAt policyRef state rootTradeId bookAssessmentId bookState netBaseExposure
  use arg s
  workId=s["workId"]~string; workType=s["workType"]~string; hedgeId=s["hedgeId"]~string; remediationId=s["remediationId"]~string; sourceEventId=s["sourceEventId"]~string; createdAt=s["createdAt"]~string; policyRef=s["policyRef"]~string; state=s["state"]~string
  rootTradeId=""; bookAssessmentId=""; bookState=""; netBaseExposure=0
  if s~hasIndex("rootTradeId") then rootTradeId=s["rootTradeId"]~string
  if s~hasIndex("bookAssessmentId") then bookAssessmentId=s["bookAssessmentId"]~string
  if s~hasIndex("bookState") then bookState=s["bookState"]~string
  if s~hasIndex("netBaseExposure") then netBaseExposure=s["netBaseExposure"]
  return self

::class MBRiskOperationalEvent public
::method init
  expose eventId eventType hedgeId sourceEventId objectRef occurredAt detail
  use strict arg eventId,eventType,hedgeId,sourceEventId,objectRef,occurredAt,detail=""
::method eventId; expose eventId; return eventId
::method eventType; expose eventType; return eventType
::method hedgeId; expose hedgeId; return hedgeId
::method sourceEventId; expose sourceEventId; return sourceEventId
::method objectRef; expose objectRef; return objectRef
::method occurredAt; expose occurredAt; return occurredAt
::method detail; expose detail; return detail
::method queuePersistentType; return "federationbank.merchant.risk.event/1"
::method queuePersistentState
  expose eventId eventType hedgeId sourceEventId objectRef occurredAt detail
  s=.table~new; s["eventId"]=eventId; s["eventType"]=eventType; s["hedgeId"]=hedgeId; s["sourceEventId"]=sourceEventId; s["objectRef"]=objectRef; s["occurredAt"]=occurredAt; s["detail"]=detail; return s
::method queueRestoreState
  expose eventId eventType hedgeId sourceEventId objectRef occurredAt detail
  use arg s
  eventId=s["eventId"]~string; eventType=s["eventType"]~string; hedgeId=s["hedgeId"]~string; sourceEventId=s["sourceEventId"]~string; objectRef=s["objectRef"]~string; occurredAt=s["occurredAt"]~string; detail=s["detail"]~string; return self

::class MBRiskCommandReceipt public
::method init
  expose commandId fingerprint code detail
  use strict arg commandId,fingerprint,code,detail=""
::method commandId; expose commandId; return commandId
::method fingerprint; expose fingerprint; return fingerprint
::method code; expose code; return code
::method detail; expose detail; return detail
::method queuePersistentType; return "federationbank.merchant.risk.receipt/1"
::method queuePersistentState
  expose commandId fingerprint code detail
  s=.table~new; s["commandId"]=commandId; s["fingerprint"]=fingerprint; s["code"]=code; s["detail"]=detail; return s
::method queueRestoreState
  expose commandId fingerprint code detail
  use arg s
  commandId=s["commandId"]~string; fingerprint=s["fingerprint"]~string; code=s["code"]~string; detail=s["detail"]~string; return self

::class MBRiskServiceState public
::method init
  expose watches workItems events receipts sequence
  watches=.directory~new; workItems=.directory~new; events=.array~new; receipts=.directory~new; sequence=0
::method watches; expose watches; return watches
::method workItems; expose workItems; return workItems
::method events; expose events; return events
::method receipts; expose receipts; return receipts
::method nextSequence
  expose sequence; sequence+=1; return sequence
::method sequence; expose sequence; return sequence
::method queuePersistentType; return .MBRiskServiceBuild~STATE_FORMAT
::method queuePersistentState
  expose watches workItems events receipts sequence
  s=.table~new; s["watches"]=watches; s["workItems"]=workItems; s["events"]=events; s["receipts"]=receipts; s["sequence"]=sequence; return s
::method queueRestoreState
  expose watches workItems events receipts sequence
  use arg s
  watches=s["watches"]; workItems=s["workItems"]; events=s["events"]; receipts=s["receipts"]; sequence=s["sequence"]; return self

::class MBRiskServiceRoleAuthorizer public
::method permitted
  use strict arg env
  t=env~commandType; role=env~actorRole
  if t="RISK.WATCH.REGISTER" then return role="MERCHANT_RISK_ADMIN"
  if t="RISK.MARKET_STRUCTURE.INGEST" then return role="MARKET_STRUCTURE_FEED" | role="MERCHANT_RISK"
  if t="RISK.HEDGE.REASSESS" then return role="MERCHANT_RISK"
  if t="RISK.BOOK.REASSESS" then return role="MERCHANT_RISK"
  if t="RISK.REMEDIATION.PLAN.PROPOSE" then return role="MERCHANT_RISK"
  if t="RISK.REMEDIATION.PLAN.APPROVE" then return role="MERCHANT_RISK_APPROVER"
  if t="RISK.REMEDIATION.PLAN.EXECUTION.INGEST" then return role="MERCHANT_EXECUTION_EVIDENCE"
  if t="RISK.REMEDIATION.PLAN.EXECUTION.LIST" then return role="MERCHANT_RISK" | role="MERCHANT_RISK_APPROVER" | role="MERCHANT_RISK_ADMIN" | role="MERCHANT_RISK_READ" | role="MERCHANT_EXECUTION_EVIDENCE"
  if t="RISK.REMEDIATION.PLAN.LIST" then return role="MERCHANT_RISK" | role="MERCHANT_RISK_APPROVER" | role="MERCHANT_RISK_ADMIN" | role="MERCHANT_RISK_READ"
  if t="RISK.WORK.LIST" then return role="MERCHANT_RISK" | role="MERCHANT_RISK_ADMIN" | role="MERCHANT_RISK_READ"
  return .false

::class FederationBankMerchantRiskService public
::method init
  expose book state authorizer
  use arg bookArg,stateArg=.nil,authorizerArg=.nil
  if bookArg==.nil | \bookArg~isA(.FederationBankMerchantBank) then raise syntax 88.900 array("FederationBankMerchantBank required")
  book=bookArg
  if stateArg==.nil then state=.MBRiskServiceState~new; else state=stateArg
  if authorizerArg==.nil then authorizer=.MBRiskServiceRoleAuthorizer~new; else authorizer=authorizerArg
::method state; expose state; return state
::method book; expose book; return book
::method handle
  expose book state authorizer
  use strict arg env
  if \env~isA(.MBRiskServiceEnvelope) then return .MBRiskServiceReply~new("","",.false,"INVALID_COMMAND","MBRiskServiceEnvelope required")
  prior=state~receipts[env~commandId]
  if prior<>.nil then do
    if prior~fingerprint<>env~fingerprint then return .MBRiskServiceReply~new(env~commandId,env~correlationId,.false,"IDEMPOTENCY_CONFLICT","command id reused with different semantics")
    return .MBRiskServiceReply~new(env~commandId,env~correlationId,.true,"REPLAY",prior~detail)
  end
  if \authorizer~permitted(env) then return .MBRiskServiceReply~new(env~commandId,env~correlationId,.false,"NOT_AUTHORISED",env~commandType)
  signal on syntax name commandFailed
  select
    when env~commandType="RISK.WATCH.REGISTER" then reply=self~registerWatch(env)
    when env~commandType="RISK.MARKET_STRUCTURE.INGEST" then reply=self~ingestMarketStructure(env)
    when env~commandType="RISK.HEDGE.REASSESS" then reply=self~reassessHedge(env)
    when env~commandType="RISK.BOOK.REASSESS" then reply=self~reassessBook(env)
    when env~commandType="RISK.REMEDIATION.PLAN.PROPOSE" then reply=self~proposeRemediationPlan(env)
    when env~commandType="RISK.REMEDIATION.PLAN.APPROVE" then reply=self~approveRemediationPlan(env)
    when env~commandType="RISK.REMEDIATION.PLAN.EXECUTION.INGEST" then reply=self~ingestRemediationPlanExecutionEvidence(env)
    when env~commandType="RISK.REMEDIATION.PLAN.EXECUTION.LIST" then reply=self~listRemediationPlanExecution(env)
    when env~commandType="RISK.REMEDIATION.PLAN.LIST" then reply=self~listRemediationPlans(env)
    when env~commandType="RISK.WORK.LIST" then reply=.MBRiskServiceReply~new(env~commandId,env~correlationId,.true,"OK","",self~openWork)
    otherwise reply=.MBRiskServiceReply~new(env~commandId,env~correlationId,.false,"COMMAND_UNSUPPORTED",env~commandType)
  end
  signal off syntax
  if reply~ok then state~receipts[env~commandId]=.MBRiskCommandReceipt~new(env~commandId,env~fingerprint,reply~code,reply~detail)
  return reply
commandFailed:
  signal off syntax
  return .MBRiskServiceReply~new(env~commandId,env~correlationId,.false,"DOMAIN_REJECTED","C="||condition("C")||" D="||condition("D")||" E="||condition("E"))
::method registerWatch private
  expose book state
  use strict arg env
  p=env~payload; hedgeId=self~field(p,"hedgeId"); policyRef=self~field(p,"policyRef")
  if book~hedgeRelationship(hedgeId)==.nil then return .MBRiskServiceReply~new(env~commandId,env~correlationId,.false,"UNKNOWN_HEDGE",hedgeId)
  existing=state~watches[hedgeId]
  if existing<>.nil then do
    if existing~policyRef<>policyRef then return .MBRiskServiceReply~new(env~commandId,env~correlationId,.false,"WATCH_CONFLICT",hedgeId)
    return .MBRiskServiceReply~new(env~commandId,env~correlationId,.true,"OK","watch already present",existing)
  end
  w=.MBRiskWatch~new(hedgeId,policyRef,env~requestedAt,env~actorId); state~watches[hedgeId]=w
  self~emit("HEDGE_WATCH_REGISTERED",hedgeId,"",hedgeId,env~requestedAt,policyRef)
  return .MBRiskServiceReply~new(env~commandId,env~correlationId,.true,"OK","",w)
::method ingestMarketStructure private
  expose book state
  use strict arg env
  notice=env~payload["notice"]
  if notice==.nil | \notice~isA(.MBRiskMarketStructureNotice) then return .MBRiskServiceReply~new(env~commandId,env~correlationId,.false,"NOTICE_REQUIRED")
  existing=book~marketStructureEvent(notice~eventId)
  if existing==.nil then book~recordMarketStructureEvent(notice~toDomainEvent)
  else if \self~sameMarketStructureNotice(existing,notice) then return .MBRiskServiceReply~new(env~commandId,env~correlationId,.false,"EVENT_ID_CONFLICT","market-structure event id reused with different evidence")
  impacted=book~hedgesAffectedByInstrumentEvidence(notice~affectedInstrumentEvidenceRef)
  applied=.array~new
  rowsByHedge=.directory~new
  roots=.directory~new
  rootPolicy=.directory~new
  rootTriggerHedge=.directory~new
  do hedgeId over impacted
    watch=state~watches[hedgeId]
    if watch==.nil then iterate
    eqId="EQE-RISK-"||notice~eventId||"-"||hedgeId
    appliedEqRef=book~marketStructureApplicationEvidenceRef(notice~eventId,hedgeId)
    if appliedEqRef==.nil | appliedEqRef="" then eq=book~applyMarketStructureEventToHedge(notice~eventId,hedgeId,eqId)
    else eq=book~hedgeEquivalenceEvidence(appliedEqRef)
    assessmentId="HRA-RISK-"||notice~eventId||"-"||hedgeId
    a=book~hedgeRiskAssessment(assessmentId)
    if a==.nil then a=book~reassessHedgeRiskFromLatestKnown(assessmentId,hedgeId,eq~evidenceId,notice~effectiveAt)
    remediationId=""
    if a~riskState="HEDGE_IMPAIRED" | a~riskState="EQUIVALENCE_UNPROVED" then do
      r=book~currentHedgeRemediation(hedgeId)
      needOpen=.false
      if r==.nil then needOpen=.true
      else if r~state="RESOLVED" then needOpen=.true
      if needOpen then do
        remediationId="REM-RISK-"||notice~eventId||"-"||hedgeId
        r=book~openHedgeRemediation(remediationId,hedgeId,assessmentId,watch~policyRef,notice~effectiveAt,"")
      end
      else remediationId=r~remediationId
      workId="WORK-RISK-"||notice~eventId||"-"||hedgeId
      if \state~workItems~hasIndex(workId) then state~workItems[workId]=.MBRiskWorkItem~new(workId,"HEDGE_REMEDIATION",hedgeId,remediationId,notice~eventId,notice~effectiveAt,watch~policyRef)
      self~emit("HEDGE_REMEDIATION_WORK_REQUIRED",hedgeId,notice~eventId,remediationId,notice~effectiveAt,a~riskState)
    end
    else self~emit("HEDGE_REASSESSED",hedgeId,notice~eventId,assessmentId,notice~effectiveAt,a~riskState)
    rootId=book~rootCFDTradeIdForHedge(hedgeId)
    roots[rootId]=.true
    if rootPolicy[rootId]==.nil then do
      rootPolicy[rootId]=watch~policyRef
      rootTriggerHedge[rootId]=hedgeId
    end
    row=.directory~new; row["hedgeId"]=hedgeId; row["equivalenceEvidenceRef"]=eq~evidenceId; row["assessmentId"]=assessmentId; row["riskState"]=a~riskState; row["remediationId"]=remediationId; row["rootTradeId"]=rootId
    rowsByHedge[hedgeId]=row; applied~append(row)
  end
  do rootId over roots~allIndexes
    bookAssessmentId="HBA-RISK-"||notice~eventId||"-"||rootId
    ba=book~hedgeBookAssessment(bookAssessmentId)
    if ba==.nil then ba=book~assessCFDHedgeBook(bookAssessmentId,rootId,notice~effectiveAt)
    triggerHedge=rootTriggerHedge[rootId]
    policyRef=rootPolicy[rootId]
    if ba~state<>"NET_ZERO_WITH_MONITORING" then do
      workType=self~bookWorkType(ba~state)
      workId="WORK-BOOK-"||notice~eventId||"-"||rootId
      remediationId=""
      tr=book~currentHedgeRemediation(triggerHedge); if tr<>.nil then remediationId=tr~remediationId
      if \state~workItems~hasIndex(workId) then state~workItems[workId]=.MBRiskWorkItem~new(workId,workType,triggerHedge,remediationId,notice~eventId,notice~effectiveAt,policyRef,rootId,bookAssessmentId,ba~state,ba~netBaseExposure)
      self~emit("CFD_HEDGE_BOOK_WORK_REQUIRED",triggerHedge,notice~eventId,bookAssessmentId,notice~effectiveAt,ba~state||" net="||ba~netBaseExposure)
    end
    else self~emit("CFD_HEDGE_BOOK_REASSESSED",triggerHedge,notice~eventId,bookAssessmentId,notice~effectiveAt,ba~state)
    do hedgeId over rowsByHedge~allIndexes
      row=rowsByHedge[hedgeId]
      if row["rootTradeId"]~string=rootId then do
        row["bookAssessmentId"]=bookAssessmentId
        row["bookState"]=ba~state
        row["netBaseExposure"]=ba~netBaseExposure
      end
    end
  end
  detail="affected="||impacted~items||",watchedApplied="||applied~items||",books="||roots~items
  return .MBRiskServiceReply~new(env~commandId,env~correlationId,.true,"OK",detail,applied)

::method reassessHedge private
  expose book state
  use strict arg env
  hedgeId=self~field(env~payload,"hedgeId")
  if state~watches[hedgeId]==.nil then return .MBRiskServiceReply~new(env~commandId,env~correlationId,.false,"HEDGE_NOT_WATCHED",hedgeId)
  if book~hedgeRelationship(hedgeId)==.nil then return .MBRiskServiceReply~new(env~commandId,env~correlationId,.false,"UNKNOWN_HEDGE",hedgeId)
  eq=book~latestHedgeEquivalenceEvidence(hedgeId); eqRef=""; if eq<>.nil then eqRef=eq~evidenceId
  assessmentId="HRA-MANUAL-"||env~commandId||"-"||hedgeId
  a=book~reassessHedgeRiskFromLatestKnown(assessmentId,hedgeId,eqRef,env~requestedAt)
  self~emit("HEDGE_REASSESSED",hedgeId,"",assessmentId,env~requestedAt,a~riskState)
  return .MBRiskServiceReply~new(env~commandId,env~correlationId,.true,"OK",a~riskState,a)
::method reassessBook private
  expose book
  use strict arg env
  rootTradeId=self~field(env~payload,"rootTradeId")
  assessmentId="HBA-MANUAL-"||env~commandId||"-"||rootTradeId
  a=book~assessCFDHedgeBook(assessmentId,rootTradeId,env~requestedAt)
  self~emit("CFD_HEDGE_BOOK_REASSESSED","","",assessmentId,env~requestedAt,a~state||" net="||a~netBaseExposure)
  return .MBRiskServiceReply~new(env~commandId,env~correlationId,.true,"OK",a~state,a)
::method proposeRemediationPlan private
  expose book
  use strict arg env
  payload=env~payload
  planId=self~field(payload,"planId"); remediationId=self~field(payload,"remediationId"); rootTradeId=self~field(payload,"rootTradeId"); baselineId=self~field(payload,"baselineBookAssessmentId"); policyRef=self~field(payload,"policyRef")
  if \payload~hasIndex("steps") then return .MBRiskServiceReply~new(env~commandId,env~correlationId,.false,"PLAN_STEPS_REQUIRED")
  rawSteps=payload["steps"]
  if \rawSteps~isA(.array) | rawSteps~items=0 then return .MBRiskServiceReply~new(env~commandId,env~correlationId,.false,"PLAN_STEPS_REQUIRED")
  steps=.array~new
  do i=1 to rawSteps~items
    st=rawSteps[i]
    if st==.nil | (\st~isA(.directory) & \st~isA(.table)) then return .MBRiskServiceReply~new(env~commandId,env~correlationId,.false,"PLAN_STEP_INVALID",i)
    stepId=self~field(st,"stepId"); sequence=st["sequence"]; actionType=self~field(st,"actionType")
    targetRef=""; if st~hasIndex("targetRef") then targetRef=st["targetRef"]~string
    delta=0; if st~hasIndex("signedBaseExposureDelta") then delta=st["signedBaseExposureDelta"]
    instrumentRef=""; if st~hasIndex("instrumentEvidenceRef") then instrumentRef=st["instrumentEvidenceRef"]~string
    detail=""; if st~hasIndex("detail") then detail=st["detail"]~string
    steps~append(.MBHedgeRemediationPlanStep~new(stepId,sequence,actionType,targetRef,delta,instrumentRef,detail))
  end
  plan=.MBHedgeRemediationPlan~new(planId,remediationId,rootTradeId,baselineId,env~actorId,policyRef,env~requestedAt,steps)
  p=book~proposeHedgeRemediationPlan(plan)
  self~emit("HEDGE_REMEDIATION_PLAN_PROPOSED",book~hedgeRemediation(p~remediationId)~hedgeId,"",p~planId,env~requestedAt,"projectedNet="||p~projectedNetBaseExposure||" peakAbs="||p~peakAbsBaseExposure)
  return .MBRiskServiceReply~new(env~commandId,env~correlationId,.true,"OK","",self~planProjection(p))
::method approveRemediationPlan private
  expose book
  use strict arg env
  payload=env~payload
  approvalId=self~field(payload,"approvalId"); planId=self~field(payload,"planId"); authorityRef=self~field(payload,"approvalAuthorityRef"); policyRef=self~field(payload,"policyRef")
  approval=.MBHedgeRemediationPlanApproval~new(approvalId,planId,env~actorId,authorityRef,policyRef,env~requestedAt)
  p=book~approveHedgeRemediationPlan(approval)
  self~emit("HEDGE_REMEDIATION_PLAN_APPROVED",book~hedgeRemediation(p~remediationId)~hedgeId,"",p~planId,env~requestedAt,"approval="||approval~approvalId)
  return .MBRiskServiceReply~new(env~commandId,env~correlationId,.true,"OK","",self~planProjection(p))
::method ingestRemediationPlanExecutionEvidence private
  expose book state
  use strict arg env
  payload=env~payload
  evidenceId=self~field(payload,"evidenceId"); planId=self~field(payload,"planId"); stepId=self~field(payload,"stepId"); executionState=self~field(payload,"executionState"); sourceRef=self~field(payload,"sourceRef"); authorityRef=self~field(payload,"authorityRef"); policyRef=self~field(payload,"policyRef")
  if \payload~hasIndex("executionSequence") then return .MBRiskServiceReply~new(env~commandId,env~correlationId,.false,"EXECUTION_SEQUENCE_REQUIRED")
  executionSequence=payload["executionSequence"]
  actualObjectRef=""; if payload~hasIndex("actualObjectRef") then actualObjectRef=payload["actualObjectRef"]~string
  delta=0; if payload~hasIndex("observedSignedBaseExposureDelta") then delta=payload["observedSignedBaseExposureDelta"]
  detail=""; if payload~hasIndex("detail") then detail=payload["detail"]~string
  existing=book~hedgeRemediationPlanStepExecutionEvidence(evidenceId)
  if existing<>.nil then do
    if \self~sameExecutionEvidence(existing,planId,stepId,executionSequence,executionState,env~actorId,sourceRef,authorityRef,actualObjectRef,delta,env~requestedAt,policyRef,detail) then return .MBRiskServiceReply~new(env~commandId,env~correlationId,.false,"EVIDENCE_ID_CONFLICT","execution evidence id reused with different semantics")
    return .MBRiskServiceReply~new(env~commandId,env~correlationId,.true,"OK","execution evidence already present",self~executionEvidenceProjection(existing))
  end
  evidence=.MBHedgeRemediationPlanStepExecutionEvidence~new(evidenceId,planId,stepId,executionSequence,executionState,env~actorId,sourceRef,authorityRef,actualObjectRef,delta,env~requestedAt,policyRef,detail)
  book~recordHedgeRemediationPlanStepExecutionEvidence(evidence)
  p=book~hedgeRemediationPlan(planId)
  rem=book~hedgeRemediation(p~remediationId)
  self~emit("HEDGE_REMEDIATION_PLAN_EXECUTION_EVIDENCE",rem~hedgeId,evidenceId,evidenceId,env~requestedAt,stepId||" "||executionState||" delta="||delta)
  out=.directory~new; out["evidence"]=self~executionEvidenceProjection(evidence); out["plan"]=self~planProjection(p)
  if p~state="EVIDENCE_COMPLETE" then do
    assessmentId="HBA-PLAN-EXEC-"||planId
    a=book~hedgeBookAssessment(assessmentId)
    if a==.nil then a=book~assessCFDHedgeBook(assessmentId,p~rootTradeId,env~requestedAt)
    verificationId="VER-PLAN-EXEC-"||planId
    v=book~hedgeRemediationPlanExecutionVerification(verificationId)
    if v==.nil then v=book~verifyHedgeRemediationPlanExecution(verificationId,planId,assessmentId,env~requestedAt)
    out["verification"]=self~executionVerificationProjection(v)
    if v~resultState="MATCHED_PROJECTED_BOOK" then self~emit("HEDGE_REMEDIATION_PLAN_EXECUTION_VERIFIED",rem~hedgeId,evidenceId,verificationId,env~requestedAt,"actualNet="||v~actualNetBaseExposure)
    else do
      workId="WORK-PLAN-EXEC-"||planId
      if \state~workItems~hasIndex(workId) then state~workItems[workId]=.MBRiskWorkItem~new(workId,"REMEDIATION_PLAN_EXECUTION_DEVIATION",rem~hedgeId,rem~remediationId,evidenceId,env~requestedAt,p~policyRef,p~rootTradeId,assessmentId,v~resultState,v~actualNetBaseExposure)
      self~emit("HEDGE_REMEDIATION_PLAN_EXECUTION_DEVIATED",rem~hedgeId,evidenceId,verificationId,env~requestedAt,v~resultState||" actualNet="||v~actualNetBaseExposure||" projected="||v~expectedNetBaseExposure)
    end
  end
  return .MBRiskServiceReply~new(env~commandId,env~correlationId,.true,"OK","",out)

::method listRemediationPlanExecution private
  expose book
  use strict arg env
  planId=self~field(env~payload,"planId")
  p=book~hedgeRemediationPlan(planId)
  if p==.nil then return .MBRiskServiceReply~new(env~commandId,env~correlationId,.false,"UNKNOWN_PLAN",planId)
  out=.directory~new; out["plan"]=self~planProjection(p)
  rows=.array~new
  do e over book~hedgeRemediationPlanExecutionEvidenceFor(planId); rows~append(self~executionEvidenceProjection(e)); end
  out["evidence"]=rows
  v=book~latestHedgeRemediationPlanExecutionVerification(planId)
  if v<>.nil then out["verification"]=self~executionVerificationProjection(v)
  return .MBRiskServiceReply~new(env~commandId,env~correlationId,.true,"OK","",out)

::method executionEvidenceProjection private
  use strict arg e
  r=.directory~new; r["evidenceId"]=e~evidenceId; r["planId"]=e~planId; r["stepId"]=e~stepId; r["executionSequence"]=e~executionSequence; r["executionState"]=e~executionState; r["sourceAuthority"]=e~sourceAuthority; r["sourceRef"]=e~sourceRef; r["authorityRef"]=e~authorityRef; r["actualObjectRef"]=e~actualObjectRef; r["observedSignedBaseExposureDelta"]=e~observedSignedBaseExposureDelta; r["effectiveAt"]=e~effectiveAt; r["policyRef"]=e~policyRef; r["detail"]=e~detail; return r

::method executionVerificationProjection private
  use strict arg v
  r=.directory~new; r["verificationId"]=v~verificationId; r["planId"]=v~planId; r["bookAssessmentId"]=v~bookAssessmentId; r["verifiedAt"]=v~verifiedAt; r["resultState"]=v~resultState; r["expectedNetBaseExposure"]=v~expectedNetBaseExposure; r["actualNetBaseExposure"]=v~actualNetBaseExposure; r["projectionDeviation"]=v~projectionDeviation; r["failedStepCount"]=v~failedStepCount; r["partialStepCount"]=v~partialStepCount; r["notExecutedStepCount"]=v~notExecutedStepCount; r["stepDeltaDeviationCount"]=v~stepDeltaDeviationCount; r["objectSemanticDeviationCount"]=v~objectSemanticDeviationCount; r["executionOrderDeviation"]=v~executionOrderDeviation; r["evidenceBookMismatch"]=v~evidenceBookMismatch; r["detail"]=v~detail; return r

::method sameExecutionEvidence private
  use strict arg existing,planId,stepId,executionSequence,executionState,sourceAuthority,sourceRef,authorityRef,actualObjectRef,delta,effectiveAt,policyRef,detail
  if existing~planId<>planId | existing~stepId<>stepId | existing~executionSequence<>executionSequence | existing~executionState<>executionState then return .false
  if existing~sourceAuthority<>sourceAuthority | existing~sourceRef<>sourceRef | existing~authorityRef<>authorityRef | existing~actualObjectRef<>actualObjectRef then return .false
  if existing~observedSignedBaseExposureDelta<>delta | existing~effectiveAt<>effectiveAt | existing~policyRef<>policyRef | existing~detail<>detail then return .false
  return .true

::method listRemediationPlans private
  expose book
  use strict arg env
  remediationId=""
  if env~payload<>.nil then if env~payload~hasIndex("remediationId") then remediationId=env~payload["remediationId"]~string
  plans=book~hedgeRemediationPlansFor(remediationId); rows=.array~new
  do p over plans; rows~append(self~planProjection(p)); end
  return .MBRiskServiceReply~new(env~commandId,env~correlationId,.true,"OK","",rows)
::method planProjection private
  use strict arg p
  r=.directory~new
  r["planId"]=p~planId; r["remediationId"]=p~remediationId; r["rootTradeId"]=p~rootTradeId; r["baselineBookAssessmentId"]=p~baselineBookAssessmentId
  r["proposer"]=p~proposer; r["policyRef"]=p~policyRef; r["proposedAt"]=p~proposedAt; r["state"]=p~state
  r["startingNetBaseExposure"]=p~startingNetBaseExposure; r["projectedNetBaseExposure"]=p~projectedNetBaseExposure; r["peakAbsBaseExposure"]=p~peakAbsBaseExposure
  r["approvalId"]=p~approvalId; r["approvedBy"]=p~approvedBy; r["approvedAt"]=p~approvedAt; r["approvalAuthorityRef"]=p~approvalAuthorityRef
  r["executionStartedAt"]=p~executionStartedAt; r["executionEvidenceCompleteAt"]=p~executionEvidenceCompleteAt; r["verificationId"]=p~verificationId; r["verificationAssessmentId"]=p~verificationAssessmentId; r["verificationState"]=p~verificationState; r["verifiedAt"]=p~verifiedAt; r["actualNetBaseExposure"]=p~actualNetBaseExposure; r["projectionDeviation"]=p~projectionDeviation
  projectedSteps=.array~new
  do i=1 to p~steps~items
    st=p~steps[i]; x=.directory~new; x["stepId"]=st~stepId; x["sequence"]=st~sequence; x["actionType"]=st~actionType; x["targetRef"]=st~targetRef; x["signedBaseExposureDelta"]=st~signedBaseExposureDelta; x["instrumentEvidenceRef"]=st~instrumentEvidenceRef; x["detail"]=st~detail; projectedSteps~append(x)
  end
  r["steps"]=projectedSteps
  return r
::method bookWorkType private
  use strict arg bookState
  select
    when bookState="DIRECTIONAL_RESIDUAL" then return "CFD_BOOK_DIRECTIONAL_RESIDUAL"
    when bookState="NET_ZERO_WITH_IMPAIRED_CONTRACTS" then return "CFD_BOOK_IMPAIRED_CONTRACTS"
    when bookState="NET_ZERO_WITH_UNPROVED_EQUIVALENCE" then return "CFD_BOOK_UNPROVED_EQUIVALENCE"
    when bookState="NET_ZERO_WITH_COUNTERPARTY_RISK" then return "CFD_BOOK_COUNTERPARTY_RISK"
    otherwise return "CFD_BOOK_MONITORING"
  end
::method openWork
  expose state
  rows=.array~new
  do id over state~workItems~allIndexes
    w=state~workItems[id]
    if w~state="OPEN" then rows~append(w)
  end
  return rows
::method emit private
  expose state
  use strict arg eventType,hedgeId,sourceEventId,objectRef,occurredAt,detail=""
  id="RISK-EVT-"||state~nextSequence
  e=.MBRiskOperationalEvent~new(id,eventType,hedgeId,sourceEventId,objectRef,occurredAt,detail)
  state~events~append(e); return e
::method sameMarketStructureNotice private
  use strict arg existing,notice
  if existing~eventType<>notice~eventType then return .false
  if existing~effectiveAt<>notice~effectiveAt then return .false
  if existing~jurisdiction<>notice~jurisdiction then return .false
  if existing~sourceAuthority<>notice~sourceAuthority then return .false
  if existing~sourceRef<>notice~sourceRef then return .false
  if existing~legalEffectRef<>notice~legalEffectRef then return .false
  if existing~affectedInstrumentEvidenceRef<>notice~affectedInstrumentEvidenceRef then return .false
  if existing~conversionAvailable<>notice~conversionAvailable then return .false
  if existing~settlementAvailable<>notice~settlementAvailable then return .false
  if existing~custodyTransferAvailable<>notice~custodyTransferAvailable then return .false
  if existing~legalTransferPermitted<>notice~legalTransferPermitted then return .false
  if existing~marketLiquidityAvailable<>notice~marketLiquidityAvailable then return .false
  if existing~reasonCode<>notice~reasonCode then return .false
  return .true
::method field private
  use strict arg payload,name
  if payload==.nil | \payload~hasIndex(name) then raise syntax 88.900 array("missing command payload field",name)
  return payload[name]~string

::requires "FederationBankMerchantBank.cls"
