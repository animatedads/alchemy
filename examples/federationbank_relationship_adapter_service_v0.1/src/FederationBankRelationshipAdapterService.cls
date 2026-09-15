/*
 * FederationBank Relationship Adapter Service v0.1
 *
 * Durable service wrapper around FederationBankRelationshipAdapter.  It owns
 * submission correlation, idempotency, persistence and event delivery.  It
 * never owns the specialist decision or Core Banking outcome.
 */
::class FederationBankRelationshipAdapterServiceBuild public
::constant VERSION "0.1"
::constant API_VERSION "federationbank.relationship.adapter.service/0.1"
::constant STATE_FORMAT "federationbank.relationship.adapter.service.state/1"
::constant SERVICE_ID "FB_RELATIONSHIP_ADAPTER_SERVICE"

::class FederationBankRelationshipServiceCanonical public
::method token class
  use arg value
  if value==.nil then return ""
  return value~string~strip~upper
::method field class
  use arg tag,value=""
  if value==.nil then text="<NIL>"; else text=value~string
  return tag~string||":"||text~length||":"||text
::method copyArray class
  use arg source
  out=.array~new; if source==.nil then return out
  do item over source; out~append(item); end
  return out
::method value class
  use arg value
  if value==.nil then return "N"
  if value~class==.String then return "S"||self~field("V",value)
  if value~class==.Array then do; text="A"; do i=1 to value~items; text||=self~field("I",self~value(value[i])); end; return text; end
  classId=value~class~id
  if classId="Table" | classId="Directory" | classId="IdentityTable" then do
    rows=.array~new; supplier=value~supplier
    do while supplier~available
      rows~append(self~field("K",supplier~index~string)||self~field("V",self~value(supplier~item)))
      supplier~next
    end
    rows~sort; text="M"; do row over rows; text||=self~field("R",row); end; return text
  end
  if value~hasMethod("SEMANTICIDENTITY") then return "O"||self~field("ID",value~semanticIdentity)
  if value~hasMethod("QUEUEPERSISTENTTYPE") then return "P"||self~field("T",value~queuePersistentType)||self~field("S",self~value(value~queuePersistentState))
  return "X"||self~field("C",classId)||self~field("V",value~string)

::class FederationBankRelationshipServiceResult public
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

::class FederationBankRelationshipServiceEnvelope public
::attribute commandId get
::attribute commandType get
::attribute correlationId get
::attribute causationId get
::attribute actorId get
::attribute actorRole get
::attribute requestedAt get
::attribute replyTo get
::method init
  expose commandId commandType correlationId causationId actorId actorRole requestedAt replyTo payload
  use arg commandIdArg,commandTypeArg,actorIdArg,actorRoleArg,payloadArg=.nil,correlationIdArg="",causationIdArg="",requestedAtArg=.nil,replyToArg=""
  commandId=commandIdArg~string; commandType=.FederationBankRelationshipServiceCanonical~token(commandTypeArg); actorId=actorIdArg~string; actorRole=.FederationBankRelationshipServiceCanonical~token(actorRoleArg)
  if requestedAtArg==.nil then requestedAt=.DateTime~new; else requestedAt=requestedAtArg
  if correlationIdArg="" then correlationId=commandId; else correlationId=correlationIdArg~string
  causationId=causationIdArg~string; replyTo=replyToArg~string
  if payloadArg==.nil then payload=.directory~new; else payload=payloadArg
::method payload
  expose payload
  return payload
::method fingerprint
  expose commandType actorId actorRole payload
  text="FB-RELATIONSHIP-ADAPTER-SERVICE-COMMAND/1"
  text||=.FederationBankRelationshipServiceCanonical~field("TYPE",commandType)
  text||=.FederationBankRelationshipServiceCanonical~field("ACTOR",actorId)
  text||=.FederationBankRelationshipServiceCanonical~field("ROLE",actorRole)
  text||=.FederationBankRelationshipServiceCanonical~field("PAYLOAD",.FederationBankRelationshipServiceCanonical~value(payload))
  return text
::method queuePersistentType
  return "federationbank.relationship.adapter.service.command/1"
::method queuePersistentState
  expose commandId commandType correlationId causationId actorId actorRole requestedAt replyTo payload
  s=.table~new; s["commandId"]=commandId; s["commandType"]=commandType; s["correlationId"]=correlationId; s["causationId"]=causationId; s["actorId"]=actorId; s["actorRole"]=actorRole; s["requestedAt"]=requestedAt~string; s["replyTo"]=replyTo; s["payload"]=payload; return s
::method queueRestoreState
  expose commandId commandType correlationId causationId actorId actorRole requestedAt replyTo payload
  use arg s
  commandId=s["commandId"]~string; commandType=.FederationBankRelationshipServiceCanonical~token(s["commandType"]); correlationId=s["correlationId"]~string; causationId=s["causationId"]~string; actorId=s["actorId"]~string; actorRole=.FederationBankRelationshipServiceCanonical~token(s["actorRole"]); requestedAt=.DateTime~fromIsoDate(s["requestedAt"]~string); replyTo=s["replyTo"]~string; payload=s["payload"]; return self

::class FederationBankRelationshipServiceReply public
::attribute commandId get
::attribute correlationId get
::attribute ok get
::attribute code get
::attribute detail get
::attribute actionId get
::method init
  expose commandId correlationId ok code detail actionId value
  use arg commandIdArg,correlationIdArg,okArg,codeArg,detailArg="",actionIdArg="",valueArg=.nil
  commandId=commandIdArg~string; correlationId=correlationIdArg~string; ok=okArg; code=codeArg~string; detail=detailArg~string; actionId=actionIdArg~string; value=valueArg
::method value
  expose value
  return value
::method queuePersistentType
  return "federationbank.relationship.adapter.service.reply/1"
::method queuePersistentState
  expose commandId correlationId ok code detail actionId value
  s=.table~new; s["commandId"]=commandId; s["correlationId"]=correlationId; if ok then s["ok"]="1"; else s["ok"]="0"; s["code"]=code; s["detail"]=detail; s["actionId"]=actionId; s["value"]=value; return s
::method queueRestoreState
  expose commandId correlationId ok code detail actionId value
  use arg s
  commandId=s["commandId"]~string; correlationId=s["correlationId"]~string; ok=(s["ok"]~string="1"); code=s["code"]~string; detail=s["detail"]~string; actionId=s["actionId"]~string; value=s["value"]; return self

::class FederationBankRelationshipActionRecord public
::attribute actionId get
::attribute caseId get
::attribute customerId get
::attribute decisionId get
::attribute bankOperation get
::attribute bankCommandId get
::attribute idempotencyKey get
::attribute status get
::attribute submittedAt get
::attribute completedAt get
::attribute bankResultCode get
::attribute bankResultDetail get
::attribute revision get
::method init
  expose actionId caseId customerId decisionId bankOperation bankCommandId idempotencyKey status submittedAt completedAt bankResultCode bankResultDetail bankCommandPayload adapterPolicyEvidence revision
  use arg actionIdArg,caseIdArg,customerIdArg,decisionIdArg,bankOperationArg,bankCommandIdArg="",idempotencyKeyArg="",statusArg="NEW",submittedAtArg=.nil,bankCommandPayloadArg=.nil,adapterPolicyEvidenceArg=.nil
  actionId=actionIdArg~string; caseId=caseIdArg~string; customerId=customerIdArg~string; decisionId=decisionIdArg~string; bankOperation=.FederationBankRelationshipServiceCanonical~token(bankOperationArg); bankCommandId=bankCommandIdArg~string; idempotencyKey=idempotencyKeyArg~string; status=.FederationBankRelationshipServiceCanonical~token(statusArg); submittedAt=submittedAtArg; completedAt=.nil; bankResultCode=""; bankResultDetail=""; revision=1
  if bankCommandPayloadArg==.nil then bankCommandPayload=.directory~new; else bankCommandPayload=bankCommandPayloadArg
  if adapterPolicyEvidenceArg==.nil then adapterPolicyEvidence=.directory~new; else adapterPolicyEvidence=adapterPolicyEvidenceArg
::method bankCommandPayload
  expose bankCommandPayload
  return bankCommandPayload
::method adapterPolicyEvidence
  expose adapterPolicyEvidence
  return adapterPolicyEvidence
::method markResult
  expose status completedAt bankResultCode bankResultDetail revision
  use arg okArg,codeArg,detailArg="",atTime=.nil
  if atTime==.nil then atTime=.DateTime~new
  if okArg then status="BANK_ACCEPTED"; else status="BANK_REJECTED"
  bankResultCode=codeArg~string; bankResultDetail=detailArg~string; completedAt=atTime; revision+=1; return self
::method queuePersistentType
  return "federationbank.relationship.adapter.service.action/1"
::method queuePersistentState
  expose actionId caseId customerId decisionId bankOperation bankCommandId idempotencyKey status submittedAt completedAt bankResultCode bankResultDetail bankCommandPayload adapterPolicyEvidence revision
  s=.table~new; s["actionId"]=actionId; s["caseId"]=caseId; s["customerId"]=customerId; s["decisionId"]=decisionId; s["bankOperation"]=bankOperation; s["bankCommandId"]=bankCommandId; s["idempotencyKey"]=idempotencyKey; s["status"]=status; if submittedAt==.nil then s["submittedAt"]=""; else s["submittedAt"]=submittedAt~string; if completedAt==.nil then s["completedAt"]=""; else s["completedAt"]=completedAt~string; s["bankResultCode"]=bankResultCode; s["bankResultDetail"]=bankResultDetail; s["bankCommandPayload"]=bankCommandPayload; s["adapterPolicyEvidence"]=adapterPolicyEvidence; s["revision"]=revision~string; return s
::method queueRestoreState
  expose actionId caseId customerId decisionId bankOperation bankCommandId idempotencyKey status submittedAt completedAt bankResultCode bankResultDetail bankCommandPayload adapterPolicyEvidence revision
  use arg s
  actionId=s["actionId"]~string; caseId=s["caseId"]~string; customerId=s["customerId"]~string; decisionId=s["decisionId"]~string; bankOperation=.FederationBankRelationshipServiceCanonical~token(s["bankOperation"]); bankCommandId=s["bankCommandId"]~string; idempotencyKey=s["idempotencyKey"]~string; status=.FederationBankRelationshipServiceCanonical~token(s["status"])
  if s["submittedAt"]~string="" then submittedAt=.nil; else submittedAt=.DateTime~fromIsoDate(s["submittedAt"]~string)
  if s["completedAt"]~string="" then completedAt=.nil; else completedAt=.DateTime~fromIsoDate(s["completedAt"]~string)
  bankResultCode=s["bankResultCode"]~string; bankResultDetail=s["bankResultDetail"]~string; bankCommandPayload=s["bankCommandPayload"]; adapterPolicyEvidence=s["adapterPolicyEvidence"]; revision=s["revision"]+0; return self

::class FederationBankRelationshipServiceEvent public
::attribute eventId get
::attribute eventType get
::attribute actionId get
::attribute caseId get
::attribute customerId get
::attribute correlationId get
::attribute causationId get
::attribute occurredAt get
::attribute revision get
::method init
  expose eventId eventType actionId caseId customerId correlationId causationId occurredAt revision payload
  use arg eventIdArg,eventTypeArg,actionIdArg,caseIdArg,customerIdArg,correlationIdArg,causationIdArg,occurredAtArg,revisionArg,payloadArg=.nil
  eventId=eventIdArg~string; eventType=.FederationBankRelationshipServiceCanonical~token(eventTypeArg); actionId=actionIdArg~string; caseId=caseIdArg~string; customerId=customerIdArg~string; correlationId=correlationIdArg~string; causationId=causationIdArg~string; occurredAt=occurredAtArg; revision=revisionArg~string
  if payloadArg==.nil then payload=.directory~new; else payload=payloadArg
::method payload
  expose payload
  return payload
::method queuePersistentType
  return "federationbank.relationship.adapter.service.event/1"
::method queuePersistentState
  expose eventId eventType actionId caseId customerId correlationId causationId occurredAt revision payload
  s=.table~new; s["eventId"]=eventId; s["eventType"]=eventType; s["actionId"]=actionId; s["caseId"]=caseId; s["customerId"]=customerId; s["correlationId"]=correlationId; s["causationId"]=causationId; s["occurredAt"]=occurredAt~string; s["revision"]=revision; s["payload"]=payload; return s
::method queueRestoreState
  expose eventId eventType actionId caseId customerId correlationId causationId occurredAt revision payload
  use arg s
  eventId=s["eventId"]~string; eventType=.FederationBankRelationshipServiceCanonical~token(s["eventType"]); actionId=s["actionId"]~string; caseId=s["caseId"]~string; customerId=s["customerId"]~string; correlationId=s["correlationId"]~string; causationId=s["causationId"]~string; occurredAt=.DateTime~fromIsoDate(s["occurredAt"]~string); revision=s["revision"]~string; payload=s["payload"]; return self

::class FederationBankRelationshipServiceReceipt public
::attribute commandId get
::attribute fingerprint get
::attribute commandType get
::attribute actionId get
::attribute code get
::method init
  expose commandId fingerprint commandType actionId code
  use arg commandIdArg,fingerprintArg,commandTypeArg,actionIdArg="",codeArg="OK"
  commandId=commandIdArg~string; fingerprint=fingerprintArg~string; commandType=.FederationBankRelationshipServiceCanonical~token(commandTypeArg); actionId=actionIdArg~string; code=codeArg~string
::method queuePersistentType
  return "federationbank.relationship.adapter.service.receipt/1"
::method queuePersistentState
  expose commandId fingerprint commandType actionId code
  s=.table~new; s["commandId"]=commandId; s["fingerprint"]=fingerprint; s["commandType"]=commandType; s["actionId"]=actionId; s["code"]=code; return s
::method queueRestoreState
  expose commandId fingerprint commandType actionId code
  use arg s
  commandId=s["commandId"]~string; fingerprint=s["fingerprint"]~string; commandType=.FederationBankRelationshipServiceCanonical~token(s["commandType"]); actionId=s["actionId"]~string; code=s["code"]~string; return self

::class FederationBankRelationshipServiceState public
::attribute formatVersion get
::attribute sequence get
::method init
  expose formatVersion sequence actions receipts auditEvents outbox
  formatVersion=.FederationBankRelationshipAdapterServiceBuild~STATE_FORMAT; sequence=0; actions=.array~new; receipts=.table~new; auditEvents=.array~new; outbox=.array~new
::method action
  expose actions
  use arg actionId
  do a over actions; if a~actionId=actionId~string then return a; end
  return .nil
::method actionByBankCommand
  expose actions
  use arg bankCommandId
  do a over actions; if a~bankCommandId=bankCommandId~string then return a; end
  return .nil
::method actions
  expose actions
  return .FederationBankRelationshipServiceCanonical~copyArray(actions)
::method addAction
  expose actions
  use arg action
  old=self~action(action~actionId); if old<>.nil then return old
  actions~append(action); return action
::method receipt
  expose receipts
  use arg commandId
  return receipts[commandId~string]
::method addReceipt
  expose receipts
  use arg receipt
  receipts[receipt~commandId]=receipt; return receipt
::method nextEventId
  expose sequence
  use arg actionId
  sequence+=1; return "FBREL-SVC-EVT-"||sequence||":"||actionId~string
::method recordEvent
  expose auditEvents outbox
  use arg event
  auditEvents~append(event); outbox~append(event); return event
::method auditEvents
  expose auditEvents
  return .FederationBankRelationshipServiceCanonical~copyArray(auditEvents)
::method outbox
  expose outbox
  return .FederationBankRelationshipServiceCanonical~copyArray(outbox)
::method markDelivered
  expose outbox
  use arg eventId
  kept=.array~new; found=.false
  do e over outbox; if e~eventId=eventId~string then found=.true; else kept~append(e); end
  outbox=kept; return found
::method queuePersistentType
  return .FederationBankRelationshipAdapterServiceBuild~STATE_FORMAT
::method queuePersistentState
  expose formatVersion sequence actions receipts auditEvents outbox
  s=.table~new; s["formatVersion"]=formatVersion; s["sequence"]=sequence~string; s["actions"]=actions; s["receipts"]=receipts; s["auditEvents"]=auditEvents; s["outbox"]=outbox; return s
::method queueRestoreState
  expose formatVersion sequence actions receipts auditEvents outbox
  use arg s
  formatVersion=s["formatVersion"]~string; sequence=s["sequence"]+0; actions=s["actions"]; receipts=s["receipts"]; auditEvents=s["auditEvents"]; outbox=s["outbox"]; return self

::class FederationBankRelationshipEventSink public
::method publish abstract
::class FederationBankRelationshipMemoryEventSink subclass FederationBankRelationshipEventSink public
::method init
  expose events failNextFlag
  events=.array~new; failNextFlag=.false
::method failNext
  expose failNextFlag
  failNextFlag=.true; return self
::method publish
  expose events failNextFlag
  use arg event
  if failNextFlag then do; failNextFlag=.false; return .FederationBankRelationshipServiceResult~failure("SINK_UNAVAILABLE"); end
  events~append(event); return .FederationBankRelationshipServiceResult~success(event)
::method events
  expose events
  return .FederationBankRelationshipServiceCanonical~copyArray(events)

/* Port can target split Core Banking queues, JMS or a test double. */
::class FederationBankRelationshipBankPort public
::method submit abstract

::class FederationBankRelationshipAdapterService public
::attribute accepting get
::attribute faulted get
::method init
  expose adapter bankPort state store sink accepting faulted
  use arg adapterArg,bankPortArg,storeArg=.nil,sinkArg=.nil
  if adapterArg==.nil then raise syntax 88.950 array("FederationBank Relationship adapter required")
  adapter=adapterArg; bankPort=bankPortArg; store=storeArg
  if sinkArg==.nil then sink=.FederationBankRelationshipMemoryEventSink~new; else sink=sinkArg
  accepting=.true; faulted=.false
  if store==.nil then state=.FederationBankRelationshipServiceState~new
  else do
    loaded=store~load
    if loaded~ok then state=loaded~value
    else do; state=.FederationBankRelationshipServiceState~new; accepting=.false; faulted=.true; end
  end
::method state
  expose state
  return state
::method eventSink
  expose sink
  return sink
::method isMutation private
  use arg t
  return t="FBREL.ACTION.SUBMIT" | t="FBREL.ACTION.RESULT.RECORD"
::method reply private
  use arg envelope,ok,code,detail="",action=.nil,value=.nil
  actionId=""; if action<>.nil then actionId=action~actionId
  return .FederationBankRelationshipServiceReply~new(envelope~commandId,envelope~correlationId,ok,code,detail,actionId,value)
::method payloadValue private
  use arg p,key,defaultValue=.nil
  if p==.nil then return defaultValue
  if p~hasIndex(key) then return p[key]
  return defaultValue
::method handle
  expose accepting faulted state
  use arg envelope
  if envelope==.nil then return .FederationBankRelationshipServiceReply~new("","",.false,"COMMAND_REQUIRED")
  if envelope~commandId="" | envelope~commandType="" | envelope~actorId="" | envelope~actorRole="" then return self~reply(envelope,.false,"COMMAND_INVALID")
  if faulted then return self~reply(envelope,.false,"SERVICE_FAULTED")
  if \accepting then return self~reply(envelope,.false,"SERVICE_QUIESCED")
  if self~isMutation(envelope~commandType) then do
    prior=state~receipt(envelope~commandId)
    if prior<>.nil then do
      if prior~fingerprint\=envelope~fingerprint then return self~reply(envelope,.false,"COMMAND_ID_CONFLICT")
      action=state~action(prior~actionId)
      return self~reply(envelope,.true,"IDEMPOTENT_REPLAY","original mutation already committed",action,action)
    end
  end
  select
    when envelope~commandType="FBREL.ACTION.SUBMIT" then return self~submitAction(envelope)
    when envelope~commandType="FBREL.ACTION.RESULT.RECORD" then return self~recordResult(envelope)
    when envelope~commandType="FBREL.ACTION.GET" then return self~getAction(envelope)
    otherwise return self~reply(envelope,.false,"COMMAND_UNSUPPORTED",envelope~commandType)
  end
::method submitAction private
  expose adapter bankPort state
  use arg envelope
  decision=self~payloadValue(envelope~payload,"decision",.nil); request=self~payloadValue(envelope~payload,"request",.nil); caseElement=self~payloadValue(envelope~payload,"caseElement",.nil)
  translated=adapter~translate(decision,request,caseElement)
  if \translated~ok then return self~reply(envelope,.false,translated~code,translated~detail)
  t=translated~value
  if t~outcome="NO_BANK_ACTION" then do
    action=.FederationBankRelationshipActionRecord~new(request~requestId,decision~caseId,decision~customerId,decision~decisionId,"NONE","","","NO_BANK_ACTION",request~requestedAt,.nil,t~policyEvidence)
    state~addAction(action)
    eventType="FBREL.ACTION.NO_BANK_ACTION"
  end
  else do
    if bankPort==.nil then return self~reply(envelope,.false,"BANK_PORT_REQUIRED")
    submitted=bankPort~submit(t~bankCommand)
    if submitted==.nil | \submitted~hasMethod("OK") then return self~reply(envelope,.false,"BANK_PORT_INVALID")
    if \submitted~ok then return self~reply(envelope,.false,"BANK_SUBMISSION_FAILED",submitted~code||":"||submitted~detail)
    action=.FederationBankRelationshipActionRecord~new(request~requestId,decision~caseId,decision~customerId,decision~decisionId,request~bankOperation,t~bankCommand~commandId,t~bankCommand~idempotencyKey,"SUBMITTED",request~requestedAt,t~bankCommand~asPayload,t~policyEvidence)
    state~addAction(action)
    eventType="FBREL.ACTION.SUBMITTED"
  end
  state~addReceipt(.FederationBankRelationshipServiceReceipt~new(envelope~commandId,envelope~fingerprint,envelope~commandType,action~actionId,"OK"))
  p=.directory~new; p["decisionId"]=decision~decisionId; p["bankOperation"]=action~bankOperation; p["bankCommandId"]=action~bankCommandId; p["status"]=action~status
  event=.FederationBankRelationshipServiceEvent~new(state~nextEventId(action~actionId),eventType,action~actionId,action~caseId,action~customerId,envelope~correlationId,envelope~commandId,envelope~requestedAt,action~revision,p)
  state~recordEvent(event)
  committed=self~persist
  if \committed~ok then return self~reply(envelope,.false,committed~code,committed~detail,action)
  flushed=self~flushOutbox
  detail=""; if \flushed~ok then detail="EVENT_PENDING_DELIVERY:"||flushed~code
  return self~reply(envelope,.true,"OK",detail,action,action)
::method recordResult private
  expose state
  use arg envelope
  p=envelope~payload; bankCommandId=self~payloadValue(p,"bankCommandId","")~string; okArg=self~payloadValue(p,"ok",.false); code=self~payloadValue(p,"code","")~string; detail=self~payloadValue(p,"detail","")~string
  action=state~actionByBankCommand(bankCommandId)
  if action==.nil then return self~reply(envelope,.false,"BANK_COMMAND_UNKNOWN",bankCommandId)
  if action~status="BANK_ACCEPTED" | action~status="BANK_REJECTED" then do
    state~addReceipt(.FederationBankRelationshipServiceReceipt~new(envelope~commandId,envelope~fingerprint,envelope~commandType,action~actionId,"OK"))
    persisted=self~persist; if \persisted~ok then return self~reply(envelope,.false,persisted~code,persisted~detail,action)
    return self~reply(envelope,.true,"IDEMPOTENT_RESULT","bank result already recorded",action,action)
  end
  truth=(okArg==.true | okArg~string~upper="TRUE" | okArg~string="1")
  action~markResult(truth,code,detail,envelope~requestedAt)
  state~addReceipt(.FederationBankRelationshipServiceReceipt~new(envelope~commandId,envelope~fingerprint,envelope~commandType,action~actionId,"OK"))
  ep=.directory~new; ep["bankCommandId"]=bankCommandId; ep["bankOperation"]=action~bankOperation; ep["bankResultCode"]=code; ep["status"]=action~status
  event=.FederationBankRelationshipServiceEvent~new(state~nextEventId(action~actionId),"FBREL.ACTION.RESULT",action~actionId,action~caseId,action~customerId,envelope~correlationId,envelope~commandId,envelope~requestedAt,action~revision,ep); state~recordEvent(event)
  committed=self~persist; if \committed~ok then return self~reply(envelope,.false,committed~code,committed~detail,action)
  flushed=self~flushOutbox; outDetail=""; if \flushed~ok then outDetail="EVENT_PENDING_DELIVERY:"||flushed~code
  return self~reply(envelope,.true,"OK",outDetail,action,action)
::method getAction private
  expose state
  use arg envelope
  id=self~payloadValue(envelope~payload,"actionId","")~string; action=state~action(id)
  if action==.nil then return self~reply(envelope,.false,"ACTION_NOT_FOUND",id)
  return self~reply(envelope,.true,"OK","",action,action)
::method persist private
  expose store state faulted accepting
  if store==.nil then return .FederationBankRelationshipServiceResult~success(state)
  r=store~save(state)
  if \r~ok then do; faulted=.true; accepting=.false; return .FederationBankRelationshipServiceResult~failure("SERVICE_PERSISTENCE_FAILED",r~code||":"||r~detail); end
  return r
::method flushOutbox
  expose state sink
  pending=state~outbox; delivered=0
  do event over pending
    r=sink~publish(event)
    if r==.nil | \r~hasMethod("OK") then return .FederationBankRelationshipServiceResult~failure("EVENT_SINK_INVALID")
    if \r~ok then return .FederationBankRelationshipServiceResult~failure(r~code,r~detail)
    state~markDelivered(event~eventId); delivered+=1
    p=self~persist; if \p~ok then return p
  end
  return .FederationBankRelationshipServiceResult~success(delivered)
::method quiesce
  expose accepting
  accepting=.false; return self~flushOutbox
::method resume
  expose accepting faulted
  if faulted then return .FederationBankRelationshipServiceResult~failure("SERVICE_FAULTED")
  accepting=.true; return .FederationBankRelationshipServiceResult~success(self)

::requires "FederationBankRelationshipAdapter.cls"
