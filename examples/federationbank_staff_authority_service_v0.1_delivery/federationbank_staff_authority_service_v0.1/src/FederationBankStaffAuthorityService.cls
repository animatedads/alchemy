/*
 * FederationBank Staff Authority Service v0.1
 *
 * Durable service boundary around FederationBankStaffAuthorityEngine.  It
 * caches externally authoritative staff context snapshots, records checker
 * approvals, issues exact action-bound authority envelopes and publishes
 * durable events.  It does not submit directly to Ledger or own HR/IAM truth.
 */
::class FederationBankStaffAuthorityServiceBuild public
::constant VERSION "0.1"
::constant API_VERSION "federationbank.staff.authority.service/0.1"
::constant STATE_FORMAT "federationbank.staff.authority.service.state/1"
::constant SERVICE_ID "FB_STAFF_AUTHORITY_SERVICE"

::class FederationBankStaffServiceCanonical public
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
    rows=.array~new; s=value~supplier
    do while s~available
      rows~append(self~field("K",s~index~string)||self~field("V",self~value(s~item)))
      s~next
    end
    rows~sort; text="M"; do row over rows; text||=self~field("R",row); end; return text
  end
  if value~hasMethod("SEMANTICIDENTITY") then return "O"||self~field("ID",value~semanticIdentity)
  if value~hasMethod("QUEUEPERSISTENTTYPE") then return "P"||self~field("T",value~queuePersistentType)||self~field("S",self~value(value~queuePersistentState))
  return "X"||self~field("C",classId)||self~field("V",value~string)

::class FederationBankStaffServiceResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg okArg,codeArg,detailArg="",valueArg=.nil
  ok=okArg; code=.FederationBankStaffServiceCanonical~token(codeArg); detail=detailArg~string; value=valueArg
::method success class
  use arg value=.nil,detail=""
  return self~new(.true,"OK",detail,value)
::method failure class
  use arg code,detail="",value=.nil
  return self~new(.false,code,detail,value)

::class FederationBankStaffServiceEnvelope public
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
  commandId=commandIdArg~string; commandType=.FederationBankStaffServiceCanonical~token(commandTypeArg); actorId=actorIdArg~string; actorRole=.FederationBankStaffServiceCanonical~token(actorRoleArg)
  if correlationIdArg="" then correlationId=commandId; else correlationId=correlationIdArg~string
  causationId=causationIdArg~string; if requestedAtArg==.nil then requestedAt=.DateTime~new; else requestedAt=requestedAtArg; replyTo=replyToArg~string
  if payloadArg==.nil then payload=.directory~new; else payload=payloadArg
::method payload
  expose payload
  return payload
::method fingerprint
  expose commandType actorId actorRole payload
  return "FB-STAFF-AUTH-SVC-CMD/1"||.FederationBankStaffServiceCanonical~field("TYPE",commandType)||.FederationBankStaffServiceCanonical~field("ACTOR",actorId)||.FederationBankStaffServiceCanonical~field("ROLE",actorRole)||.FederationBankStaffServiceCanonical~field("PAYLOAD",.FederationBankStaffServiceCanonical~value(payload))
::method queuePersistentType
  return "federationbank.staff.authority.service.command/1"
::method queuePersistentState
  expose commandId commandType correlationId causationId actorId actorRole requestedAt replyTo payload
  s=.table~new; s["commandId"]=commandId; s["commandType"]=commandType; s["correlationId"]=correlationId; s["causationId"]=causationId; s["actorId"]=actorId; s["actorRole"]=actorRole; s["requestedAt"]=requestedAt~utcIsoDate; s["replyTo"]=replyTo; s["payload"]=payload; return s
::method queueRestoreState
  expose commandId commandType correlationId causationId actorId actorRole requestedAt replyTo payload
  use arg s
  commandId=s["commandId"]~string; commandType=.FederationBankStaffServiceCanonical~token(s["commandType"]); correlationId=s["correlationId"]~string; causationId=s["causationId"]~string; actorId=s["actorId"]~string; actorRole=.FederationBankStaffServiceCanonical~token(s["actorRole"]); requestedAt=.FederationBankStaffCanonical~dateValue(s["requestedAt"]); replyTo=s["replyTo"]~string; payload=s["payload"]; return self

::class FederationBankStaffServiceReply public
::attribute commandId get
::attribute correlationId get
::attribute ok get
::attribute code get
::attribute detail get
::attribute actionId get
::method init
  expose commandId correlationId ok code detail actionId value
  use arg commandIdArg,correlationIdArg,okArg,codeArg,detailArg="",actionIdArg="",valueArg=.nil
  commandId=commandIdArg~string; correlationId=correlationIdArg~string; ok=okArg; code=.FederationBankStaffServiceCanonical~token(codeArg); detail=detailArg~string; actionId=actionIdArg~string; value=valueArg
::method value
  expose value
  return value
::method queuePersistentType
  return "federationbank.staff.authority.service.reply/1"
::method queuePersistentState
  expose commandId correlationId ok code detail actionId value
  s=.table~new; s["commandId"]=commandId; s["correlationId"]=correlationId; if ok then s["ok"]="1"; else s["ok"]="0"; s["code"]=code; s["detail"]=detail; s["actionId"]=actionId; s["value"]=value; return s
::method queueRestoreState
  expose commandId correlationId ok code detail actionId value
  use arg s
  commandId=s["commandId"]~string; correlationId=s["correlationId"]~string; ok=(s["ok"]~string="1"); code=.FederationBankStaffServiceCanonical~token(s["code"]); detail=s["detail"]~string; actionId=s["actionId"]~string; value=s["value"]; return self

::class FederationBankStaffAuthorityRecord public
::attribute actionId get
::attribute staffId get
::attribute status get
::attribute decision get
::attribute envelope get
::attribute createdAt get
::attribute revision get
::method init
  expose actionId staffId status action decision envelope createdAt revision
  use arg actionArg,decisionArg,envelopeArg=.nil,statusArg="AUTHORISED",createdAtArg=.nil
  action=actionArg; decision=decisionArg; envelope=envelopeArg; actionId=actionArg~actionId; staffId=actionArg~staffId; status=.FederationBankStaffServiceCanonical~token(statusArg); if createdAtArg==.nil then createdAt=.DateTime~new; else createdAt=createdAtArg; revision=1
::method action
  expose action
  return action
::method queuePersistentType
  return "federationbank.staff.authority.service.record/1"
::method queuePersistentState
  expose actionId staffId status action decision envelope createdAt revision
  s=.table~new; s["actionId"]=actionId; s["staffId"]=staffId; s["status"]=status; s["action"]=action; s["decision"]=decision; s["envelope"]=envelope; s["createdAt"]=createdAt~utcIsoDate; s["revision"]=revision~string; return s
::method queueRestoreState
  expose actionId staffId status action decision envelope createdAt revision
  use arg s
  actionId=s["actionId"]~string; staffId=s["staffId"]~string; status=.FederationBankStaffServiceCanonical~token(s["status"]); action=s["action"]; decision=s["decision"]; envelope=s["envelope"]; createdAt=.FederationBankStaffCanonical~dateValue(s["createdAt"]); revision=s["revision"]+0; return self

::class FederationBankStaffServiceEvent public
::attribute eventId get
::attribute eventType get
::attribute aggregateId get
::attribute correlationId get
::attribute causationId get
::attribute actorId get
::attribute actorRole get
::attribute occurredAt get
::attribute sequence get
::method init
  expose eventId eventType aggregateId correlationId causationId actorId actorRole occurredAt sequence payload
  use arg eventIdArg,eventTypeArg,aggregateIdArg,correlationIdArg,causationIdArg,actorIdArg,actorRoleArg,occurredAtArg,sequenceArg,payloadArg=.nil
  eventId=eventIdArg~string; eventType=.FederationBankStaffServiceCanonical~token(eventTypeArg); aggregateId=aggregateIdArg~string; correlationId=correlationIdArg~string; causationId=causationIdArg~string; actorId=actorIdArg~string; actorRole=.FederationBankStaffServiceCanonical~token(actorRoleArg); occurredAt=occurredAtArg; sequence=sequenceArg+0; if payloadArg==.nil then payload=.directory~new; else payload=payloadArg
::method payload
  expose payload
  return payload
::method queuePersistentType
  return "federationbank.staff.authority.service.event/1"
::method queuePersistentState
  expose eventId eventType aggregateId correlationId causationId actorId actorRole occurredAt sequence payload
  s=.table~new; s["eventId"]=eventId; s["eventType"]=eventType; s["aggregateId"]=aggregateId; s["correlationId"]=correlationId; s["causationId"]=causationId; s["actorId"]=actorId; s["actorRole"]=actorRole; s["occurredAt"]=occurredAt~utcIsoDate; s["sequence"]=sequence~string; s["payload"]=payload; return s
::method queueRestoreState
  expose eventId eventType aggregateId correlationId causationId actorId actorRole occurredAt sequence payload
  use arg s
  eventId=s["eventId"]~string; eventType=.FederationBankStaffServiceCanonical~token(s["eventType"]); aggregateId=s["aggregateId"]~string; correlationId=s["correlationId"]~string; causationId=s["causationId"]~string; actorId=s["actorId"]~string; actorRole=.FederationBankStaffServiceCanonical~token(s["actorRole"]); occurredAt=.FederationBankStaffCanonical~dateValue(s["occurredAt"]); sequence=s["sequence"]+0; payload=s["payload"]; return self

::class FederationBankStaffServiceReceipt public
::attribute commandId get
::attribute fingerprint get
::attribute actionId get
::attribute outcomeCode get
::method init
  expose commandId fingerprint actionId outcomeCode
  use arg commandIdArg,fingerprintArg,actionIdArg="",outcomeCodeArg="OK"
  commandId=commandIdArg~string; fingerprint=fingerprintArg~string; actionId=actionIdArg~string; outcomeCode=.FederationBankStaffServiceCanonical~token(outcomeCodeArg)
::method queuePersistentType
  return "federationbank.staff.authority.service.receipt/1"
::method queuePersistentState
  expose commandId fingerprint actionId outcomeCode
  s=.table~new; s["commandId"]=commandId; s["fingerprint"]=fingerprint; s["actionId"]=actionId; s["outcomeCode"]=outcomeCode; return s
::method queueRestoreState
  expose commandId fingerprint actionId outcomeCode
  use arg s
  commandId=s["commandId"]~string; fingerprint=s["fingerprint"]~string; actionId=s["actionId"]~string; outcomeCode=.FederationBankStaffServiceCanonical~token(s["outcomeCode"]); return self

::class FederationBankStaffAuthorityServiceState public
::method init
  expose formatVersion sequence contexts approvalsByAction records receipts auditEvents outbox
  formatVersion=.FederationBankStaffAuthorityServiceBuild~STATE_FORMAT; sequence=0; contexts=.directory~new; approvalsByAction=.directory~new; records=.directory~new; receipts=.directory~new; auditEvents=.array~new; outbox=.array~new
::method context
  expose contexts
  use arg staffId
  if contexts~hasIndex(staffId) then return contexts[staffId]
  return .nil
::method contexts
  expose contexts
  out=.directory~new; do k over contexts; out[k]=contexts[k]; end; return out
::method putContext
  expose contexts
  use arg context
  contexts[context~principal~staffId]=context; return context
::method approvalsFor
  expose approvalsByAction
  use arg actionId
  if \approvalsByAction~hasIndex(actionId) then return .array~new
  return .FederationBankStaffServiceCanonical~copyArray(approvalsByAction[actionId])
::method addApproval
  expose approvalsByAction
  use arg approval
  actionId=approval~actionId
  if \approvalsByAction~hasIndex(actionId) then approvalsByAction[actionId]=.array~new
  do existing over approvalsByAction[actionId]; if existing~approvalId=approval~approvalId then return .false; end
  approvalsByAction[actionId]~append(approval); return .true
::method record
  expose records
  use arg actionId
  if records~hasIndex(actionId) then return records[actionId]
  return .nil
::method putRecord
  expose records
  use arg record
  records[record~actionId]=record; return record
::method receipt
  expose receipts
  use arg commandId
  if receipts~hasIndex(commandId) then return receipts[commandId]
  return .nil
::method putReceipt
  expose receipts
  use arg receipt
  receipts[receipt~commandId]=receipt; return receipt
::method nextEventId
  expose sequence
  use arg aggregateId
  sequence+=1; return "FBSTAFF-EVT-"||sequence||":"||aggregateId
::method sequence
  expose sequence
  return sequence
::method recordEvent
  expose auditEvents outbox
  use arg event
  auditEvents~append(event); outbox~append(event); return event
::method auditEvents
  expose auditEvents
  return .FederationBankStaffServiceCanonical~copyArray(auditEvents)
::method outbox
  expose outbox
  return .FederationBankStaffServiceCanonical~copyArray(outbox)
::method markDelivered
  expose outbox
  use arg eventId
  kept=.array~new; found=.false
  do e over outbox; if e~eventId=eventId then found=.true; else kept~append(e); end
  outbox=kept; return found
::method queuePersistentType
  return .FederationBankStaffAuthorityServiceBuild~STATE_FORMAT
::method queuePersistentState
  expose formatVersion sequence contexts approvalsByAction records receipts auditEvents outbox
  s=.table~new; s["formatVersion"]=formatVersion; s["sequence"]=sequence~string; s["contexts"]=contexts; s["approvalsByAction"]=approvalsByAction; s["records"]=records; s["receipts"]=receipts; s["auditEvents"]=auditEvents; s["outbox"]=outbox; return s
::method queueRestoreState
  expose formatVersion sequence contexts approvalsByAction records receipts auditEvents outbox
  use arg s
  formatVersion=s["formatVersion"]~string; sequence=s["sequence"]+0; contexts=s["contexts"]; approvalsByAction=s["approvalsByAction"]; records=s["records"]; receipts=s["receipts"]; auditEvents=s["auditEvents"]; outbox=s["outbox"]; return self

::class FederationBankStaffEventSink public
::method publish abstract
::class FederationBankStaffMemoryEventSink subclass FederationBankStaffEventSink public
::method init
  expose events failNextFlag
  events=.array~new; failNextFlag=.false
::method failNext
  expose failNextFlag
  failNextFlag=.true; return self
::method publish
  expose events failNextFlag
  use arg event
  if failNextFlag then do; failNextFlag=.false; return .FederationBankStaffServiceResult~failure("SINK_UNAVAILABLE"); end
  events~append(event); return .FederationBankStaffServiceResult~success(event)
::method events
  expose events
  return .FederationBankStaffServiceCanonical~copyArray(events)

::class FederationBankStaffAuthorityService public
::attribute accepting get
::attribute faulted get
::method init
  expose engine state store sink accepting faulted
  use arg engineArg,storeArg=.nil,sinkArg=.nil
  if engineArg==.nil then raise syntax 98.900 array("Staff authority engine required")
  engine=engineArg; store=storeArg; if sinkArg==.nil then sink=.FederationBankStaffMemoryEventSink~new; else sink=sinkArg; accepting=.true; faulted=.false
  if store==.nil then state=.FederationBankStaffAuthorityServiceState~new
  else do
    loaded=store~load
    if loaded~ok then state=loaded~value
    else do; state=.FederationBankStaffAuthorityServiceState~new; accepting=.false; faulted=.true; end
  end
::method state
  expose state
  return state
::method eventSink
  expose sink
  return sink
::method payloadValue private
  use arg p,key,defaultValue=.nil
  if p<>.nil then if p~hasIndex(key) then return p[key]
  return defaultValue
::method isMutation private
  use arg t
  return t="FBSTAFF.CONTEXT.PUT" | t="FBSTAFF.APPROVAL.RECORD" | t="FBSTAFF.ACTION.AUTHORISE"
::method reply private
  use arg env,ok,code,detail="",actionId="",value=.nil
  return .FederationBankStaffServiceReply~new(env~commandId,env~correlationId,ok,code,detail,actionId,value)
::method persist private
  expose store state accepting faulted
  if store==.nil then return .FederationBankStaffServiceResult~success(state)
  r=store~save(state)
  if \r~ok then do; accepting=.false; faulted=.true; end
  return r
::method addEvent private
  expose state
  use arg env,eventType,aggregateId,payload=.nil
  id=state~nextEventId(aggregateId); e=.FederationBankStaffServiceEvent~new(id,eventType,aggregateId,env~correlationId,env~commandId,env~actorId,env~actorRole,env~requestedAt,state~sequence,payload); state~recordEvent(e); return e
::method flushOutbox
  expose state sink
  delivered=0
  pending=state~outbox
  do event over pending
    r=sink~publish(event)
    if \r~ok then return .FederationBankStaffServiceResult~failure("EVENT_DELIVERY_PENDING",r~code||":"||r~detail,delivered)
    ignore=state~markDelivered(event~eventId); delivered+=1
  end
  p=self~persist
  if \p~ok then return p
  return .FederationBankStaffServiceResult~success(delivered)
::method handle
  expose accepting faulted state
  use arg env
  if env==.nil then return .FederationBankStaffServiceReply~new("","",.false,"COMMAND_REQUIRED")
  if env~commandId="" | env~commandType="" | env~actorId="" | env~actorRole="" then return self~reply(env,.false,"COMMAND_INVALID")
  if faulted then return self~reply(env,.false,"SERVICE_FAULTED")
  if \accepting then return self~reply(env,.false,"SERVICE_QUIESCED")
  if self~isMutation(env~commandType) then do
    prior=state~receipt(env~commandId)
    if prior<>.nil then do
      if prior~fingerprint\=env~fingerprint then return self~reply(env,.false,"COMMAND_ID_CONFLICT")
      rec=.nil; if prior~actionId<>"" then rec=state~record(prior~actionId)
      return self~reply(env,.true,"IDEMPOTENT_REPLAY","original mutation already committed",prior~actionId,rec)
    end
  end
  select
    when env~commandType="FBSTAFF.CONTEXT.PUT" then return self~putContext(env)
    when env~commandType="FBSTAFF.APPROVAL.RECORD" then return self~recordApproval(env)
    when env~commandType="FBSTAFF.ACTION.AUTHORISE" then return self~authorise(env)
    when env~commandType="FBSTAFF.AUTHORITY.GET" then return self~getAuthority(env)
    when env~commandType="FBSTAFF.CONTEXT.GET" then return self~getContext(env)
    otherwise return self~reply(env,.false,"COMMAND_UNSUPPORTED",env~commandType)
  end
::method putContext private
  expose state
  use arg env
  ctx=self~payloadValue(env~payload,"context",.nil)
  if ctx==.nil | \ctx~isA(.FederationBankStaffContextSnapshot) | \ctx~sealed then return self~reply(env,.false,"STAFF_CONTEXT_REQUIRED")
  state~putContext(ctx); state~putReceipt(.FederationBankStaffServiceReceipt~new(env~commandId,env~fingerprint,"","CONTEXT_STORED")); payload=.directory~new; payload["staffId"]=ctx~principal~staffId; payload["contextIdentity"]=ctx~semanticIdentity; ignore=self~addEvent(env,"FBSTAFF.CONTEXT.STORED",ctx~principal~staffId,payload)
  p=self~persist; if \p~ok then return self~reply(env,.false,p~code,p~detail)
  ignore=self~flushOutbox
  return self~reply(env,.true,"CONTEXT_STORED","",ctx~principal~staffId,ctx)
::method recordApproval private
  expose state
  use arg env
  action=self~payloadValue(env~payload,"action",.nil); approval=self~payloadValue(env~payload,"approval",.nil)
  if action==.nil | \action~isA(.FederationBankStaffActionIntent) | \action~sealed then return self~reply(env,.false,"STAFF_ACTION_REQUIRED")
  if approval==.nil | \approval~isA(.FederationBankStaffApproval) | \approval~sealed then return self~reply(env,.false,"STAFF_APPROVAL_REQUIRED", "", action~actionId)
  if \approval~matchesAction(action) then return self~reply(env,.false,"APPROVAL_ACTION_MISMATCH","",action~actionId)
  if approval~approverStaffId=action~staffId then return self~reply(env,.false,"MAKER_CHECKER_NOT_DISTINCT","",action~actionId)
  ctx=state~context(approval~approverStaffId)
  if ctx==.nil | \ctx~validAt(approval~approvedAt) then return self~reply(env,.false,"APPROVER_CONTEXT_NOT_EFFECTIVE","",action~actionId)
  if ctx~session~sessionId<>approval~approverSessionId | ctx~session~branchId<>action~branchId then return self~reply(env,.false,"APPROVER_WORK_CONTEXT_MISMATCH","",action~actionId)
  roleOk=.false
  do a over ctx~assignments; if a~activeAt(approval~approvedAt) & a~inBranch(action~branchId) & a~roleClass=approval~approvalClass then roleOk=.true; end
  if \roleOk then return self~reply(env,.false,"APPROVER_ROLE_NOT_EFFECTIVE",approval~approvalClass,action~actionId)
  if \state~addApproval(approval) then do
    state~putReceipt(.FederationBankStaffServiceReceipt~new(env~commandId,env~fingerprint,action~actionId,"APPROVAL_DUPLICATE")); return self~reply(env,.true,"APPROVAL_DUPLICATE","",action~actionId,approval)
  end
  state~putReceipt(.FederationBankStaffServiceReceipt~new(env~commandId,env~fingerprint,action~actionId,"APPROVAL_RECORDED")); payload=.directory~new; payload["approval"]=approval; ignore=self~addEvent(env,"FBSTAFF.APPROVAL.RECORDED",action~actionId,payload); p=self~persist; if \p~ok then return self~reply(env,.false,p~code,p~detail,action~actionId); ignore=self~flushOutbox
  return self~reply(env,.true,"APPROVAL_RECORDED","",action~actionId,approval)
::method authorise private
  expose state engine
  use arg env
  action=self~payloadValue(env~payload,"action",.nil); envelopeId=self~payloadValue(env~payload,"envelopeId","")
  if action==.nil | \action~isA(.FederationBankStaffActionIntent) | \action~sealed then return self~reply(env,.false,"STAFF_ACTION_REQUIRED")
  if envelopeId="" then envelopeId="ENV:"||action~actionId
  approvals=state~approvalsFor(action~actionId); contexts=state~contexts
  r=engine~authorise(envelopeId,action,contexts,approvals)
  if \r~ok then do
    decision=r~value
    if decision<>.nil then if decision~isA(.FederationBankStaffAuthorityDecision) then do
      rec=.FederationBankStaffAuthorityRecord~new(action,decision,.nil,"APPROVAL_REQUIRED",env~requestedAt); state~putRecord(rec); state~putReceipt(.FederationBankStaffServiceReceipt~new(env~commandId,env~fingerprint,action~actionId,r~code)); payload=.directory~new; payload["decision"]=decision; ignore=self~addEvent(env,"FBSTAFF.AUTHORITY.APPROVAL_REQUIRED",action~actionId,payload); p=self~persist; if \p~ok then return self~reply(env,.false,p~code,p~detail,action~actionId); ignore=self~flushOutbox; return self~reply(env,.false,r~code,r~detail,action~actionId,decision)
    end
    return self~reply(env,.false,r~code,r~detail,action~actionId,r~value)
  end
  decision=r~value["decision"]; authority=r~value["envelope"]; rec=.FederationBankStaffAuthorityRecord~new(action,decision,authority,"AUTHORISED",env~requestedAt); state~putRecord(rec); state~putReceipt(.FederationBankStaffServiceReceipt~new(env~commandId,env~fingerprint,action~actionId,"AUTHORISED")); payload=.directory~new; payload["decision"]=decision; payload["envelope"]=authority; ignore=self~addEvent(env,"FBSTAFF.AUTHORITY.ISSUED",action~actionId,payload); p=self~persist; if \p~ok then return self~reply(env,.false,p~code,p~detail,action~actionId); ignore=self~flushOutbox
  return self~reply(env,.true,"AUTHORISED","",action~actionId,rec)
::method getAuthority private
  expose state
  use arg env
  actionId=self~payloadValue(env~payload,"actionId",""); if actionId="" then return self~reply(env,.false,"ACTION_ID_REQUIRED")
  rec=state~record(actionId); if rec==.nil then return self~reply(env,.false,"AUTHORITY_NOT_FOUND","",actionId)
  return self~reply(env,.true,"OK","",actionId,rec)
::method getContext private
  expose state
  use arg env
  staffId=self~payloadValue(env~payload,"staffId",""); if staffId="" then return self~reply(env,.false,"STAFF_ID_REQUIRED")
  ctx=state~context(staffId); if ctx==.nil then return self~reply(env,.false,"STAFF_CONTEXT_NOT_FOUND")
  return self~reply(env,.true,"OK","",staffId,ctx)

::requires "FederationBankStaffAuthority.cls"
