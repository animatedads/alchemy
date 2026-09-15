/* FederationBank Teller Cash Service v0.1
 *
 * Durable coordination facade over Staff Channel Service and Teller Till
 * Service. Staff Channel remains staff-authority workflow truth; Teller Till
 * remains physical-cash truth; Core Banking remains monetary truth.
 */

::class FederationBankTellerCashServiceBuild public
::constant VERSION "0.1"
::constant API_VERSION "federationbank.teller.cash.service/0.1"
::constant STATE_FORMAT "federationbank.teller.cash.service.state/1"

::class FederationBankTellerCashServiceResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg okArg,codeArg,detailArg="",valueArg=.nil
  ok=okArg; code=.FBTellerCashUtil~token(codeArg); detail=detailArg~string; value=valueArg
::method success class
  use arg value=.nil,detail=""
  return self~new(.true,"OK",detail,value)
::method failure class
  use arg code,detail="",value=.nil
  return self~new(.false,code,detail,value)

::class FederationBankTellerCashServiceEnvelope public
::attribute commandId get
::attribute commandType get
::attribute actorId get
::attribute actorRole get
::attribute correlationId get
::attribute causationId get
::attribute requestedAt get
::attribute replyTo get
::method init
  expose commandId commandType actorId actorRole correlationId causationId requestedAt replyTo payload
  use arg commandIdArg,commandTypeArg,actorIdArg,actorRoleArg,payloadArg=.nil,correlationIdArg="",causationIdArg="",requestedAtArg=.nil,replyToArg=""
  commandId=commandIdArg~string; commandType=.FBTellerCashUtil~token(commandTypeArg); actorId=actorIdArg~string; actorRole=.FBTellerCashUtil~token(actorRoleArg)
  if correlationIdArg="" then correlationId=commandId; else correlationId=correlationIdArg~string
  causationId=causationIdArg~string; if requestedAtArg==.nil then requestedAt=.DateTime~new; else requestedAt=requestedAtArg; replyTo=replyToArg~string
  if payloadArg==.nil then payload=.directory~new; else payload=payloadArg
::method payload
  expose payload
  return payload
::method fingerprint
  expose commandType actorId actorRole payload
  text="FB-TELLER-CASH-SERVICE-COMMAND/1|"||commandType||"|"||actorId||"|"||actorRole
  keys=.array~new; do k over payload; keys~append(k~string); end; keys~sort
  do k over keys
    v=payload[k]; value="<NIL>"
    if v<>.nil then do
      if v~hasMethod("SEMANTICIDENTITY") then value=v~semanticIdentity
      else if v~isA(.Array) then do
        value="["; do item over v; if item~hasMethod("SEMANTICIDENTITY") then value||=item~semanticIdentity||";"; else value||=item~string||";"; end; value||="]"
      end
      else if v~isA(.Directory) | v~isA(.Table) then do
        value="{"; sk=.array~new; do x over v; sk~append(x~string); end; sk~sort
        do x over sk; item=v[x]; if item~hasMethod("SEMANTICIDENTITY") then iv=item~semanticIdentity; else iv=item~string; value||=x||"="||iv||";"; end; value||="}"
      end
      else value=v~string
    end
    text||="|"||k||"="||value
  end
  return text
::method queuePersistentType
  return "federationbank.teller.cash.service.command/1"
::method queuePersistentState
  expose commandId commandType actorId actorRole correlationId causationId requestedAt replyTo payload
  s=.table~new; s["commandId"]=commandId; s["commandType"]=commandType; s["actorId"]=actorId; s["actorRole"]=actorRole; s["correlationId"]=correlationId; s["causationId"]=causationId; s["requestedAt"]=requestedAt~utcIsoDate; s["replyTo"]=replyTo; s["payload"]=payload; return s
::method queueRestoreState
  expose commandId commandType actorId actorRole correlationId causationId requestedAt replyTo payload
  use arg s
  commandId=s["commandId"]~string; commandType=.FBTellerCashUtil~token(s["commandType"]); actorId=s["actorId"]~string; actorRole=.FBTellerCashUtil~token(s["actorRole"]); correlationId=s["correlationId"]~string; causationId=s["causationId"]~string; requestedAt=.FBTellerCashUtil~dateValue(s["requestedAt"]); replyTo=s["replyTo"]~string; payload=s["payload"]; return self

::class FederationBankTellerCashServiceReply public
::attribute commandId get
::attribute correlationId get
::attribute ok get
::attribute code get
::attribute detail get
::attribute workId get
::attribute value get
::method init
  expose commandId correlationId ok code detail workId value
  use arg commandIdArg,correlationIdArg,okArg,codeArg,detailArg="",workIdArg="",valueArg=.nil
  commandId=commandIdArg~string; correlationId=correlationIdArg~string; ok=okArg; code=.FBTellerCashUtil~token(codeArg); detail=detailArg~string; workId=workIdArg~string; value=valueArg
::method queuePersistentType
  return "federationbank.teller.cash.service.reply/1"
::method queuePersistentState
  expose commandId correlationId ok code detail workId value
  s=.table~new; s["commandId"]=commandId; s["correlationId"]=correlationId; if ok then s["ok"]="1"; else s["ok"]="0"; s["code"]=code; s["detail"]=detail; s["workId"]=workId; s["value"]=value; return s
::method queueRestoreState
  expose commandId correlationId ok code detail workId value
  use arg s
  commandId=s["commandId"]~string; correlationId=s["correlationId"]~string; ok=(s["ok"]~string="1"); code=.FBTellerCashUtil~token(s["code"]); detail=s["detail"]~string; workId=s["workId"]~string; value=s["value"]; return self

::class FederationBankTellerCashServiceReceipt public
::attribute commandId get
::attribute fingerprint get
::attribute workId get
::attribute outcomeCode
::method init
  expose commandId fingerprint workId outcomeCode
  use arg commandIdArg,fingerprintArg,workIdArg,outcomeCodeArg="RECEIVED"
  commandId=commandIdArg~string; fingerprint=fingerprintArg~string; workId=workIdArg~string; outcomeCode=.FBTellerCashUtil~token(outcomeCodeArg)
::method queuePersistentType
  return "federationbank.teller.cash.service.receipt/1"
::method queuePersistentState
  expose commandId fingerprint workId outcomeCode
  s=.table~new; s["commandId"]=commandId; s["fingerprint"]=fingerprint; s["workId"]=workId; s["outcomeCode"]=outcomeCode; return s
::method queueRestoreState
  expose commandId fingerprint workId outcomeCode
  use arg s
  commandId=s["commandId"]~string; fingerprint=s["fingerprint"]~string; workId=s["workId"]~string; outcomeCode=.FBTellerCashUtil~token(s["outcomeCode"]); return self

::class FederationBankTellerCashServiceEvent public
::attribute eventId get
::attribute eventType get
::attribute workId get
::attribute commandId get
::attribute correlationId get
::attribute causationId get
::attribute state get
::attribute outcomeCode get
::attribute detail get
::attribute occurredAt get
::attribute sequence get
::method init
  expose eventId eventType workId commandId correlationId causationId state outcomeCode detail occurredAt sequence
  use arg eventIdArg,eventTypeArg,workIdArg,commandIdArg,correlationIdArg,causationIdArg,stateArg,outcomeCodeArg,detailArg,occurredAtArg,sequenceArg
  eventId=eventIdArg~string; eventType=.FBTellerCashUtil~token(eventTypeArg); workId=workIdArg~string; commandId=commandIdArg~string; correlationId=correlationIdArg~string; causationId=causationIdArg~string; state=.FBTellerCashUtil~token(stateArg); outcomeCode=.FBTellerCashUtil~token(outcomeCodeArg); detail=detailArg~string; occurredAt=occurredAtArg; sequence=sequenceArg+0
::method queuePersistentType
  return "federationbank.teller.cash.service.event/1"
::method queuePersistentState
  expose eventId eventType workId commandId correlationId causationId state outcomeCode detail occurredAt sequence
  s=.table~new; s["eventId"]=eventId; s["eventType"]=eventType; s["workId"]=workId; s["commandId"]=commandId; s["correlationId"]=correlationId; s["causationId"]=causationId; s["state"]=state; s["outcomeCode"]=outcomeCode; s["detail"]=detail; s["occurredAt"]=occurredAt~utcIsoDate; s["sequence"]=sequence~string; return s
::method queueRestoreState
  expose eventId eventType workId commandId correlationId causationId state outcomeCode detail occurredAt sequence
  use arg s
  eventId=s["eventId"]~string; eventType=.FBTellerCashUtil~token(s["eventType"]); workId=s["workId"]~string; commandId=s["commandId"]~string; correlationId=s["correlationId"]~string; causationId=s["causationId"]~string; state=.FBTellerCashUtil~token(s["state"]); outcomeCode=.FBTellerCashUtil~token(s["outcomeCode"]); detail=s["detail"]~string; occurredAt=.FBTellerCashUtil~dateValue(s["occurredAt"]); sequence=s["sequence"]+0; return self

::class FederationBankTellerCashServiceWork public
::attribute workId get
::attribute staffChannelWorkId get
::attribute commandId get
::attribute request get
::attribute instruction get
::attribute state
::attribute staffState
::attribute tillState
::attribute outcomeCode
::attribute detail
::attribute createdAt get
::attribute updatedAt get
::attribute revision get
::method init
  expose workId staffChannelWorkId commandId request instruction state staffState tillState outcomeCode detail createdAt updatedAt revision
  use arg requestArg,instructionArg
  if requestArg==.nil | instructionArg==.nil then raise syntax 88.970 array("teller cash work request/instruction required")
  request=requestArg; instruction=instructionArg; workId=instruction~cashWorkId; staffChannelWorkId=request~workId; commandId=instruction~commandId; state="RECEIVED"; staffState=""; tillState=""; outcomeCode="RECEIVED"; detail=""; createdAt=.DateTime~new; updatedAt=createdAt; revision=1
::method touch
  expose updatedAt revision
  updatedAt=.DateTime~new; revision+=1; return self
::method queuePersistentType
  return "federationbank.teller.cash.service.work/1"
::method queuePersistentState
  expose workId staffChannelWorkId commandId request instruction state staffState tillState outcomeCode detail createdAt updatedAt revision
  s=.table~new; s["workId"]=workId; s["staffChannelWorkId"]=staffChannelWorkId; s["commandId"]=commandId; s["request"]=request; s["instruction"]=instruction; s["state"]=state; s["staffState"]=staffState; s["tillState"]=tillState; s["outcomeCode"]=outcomeCode; s["detail"]=detail; s["createdAt"]=createdAt~utcIsoDate; s["updatedAt"]=updatedAt~utcIsoDate; s["revision"]=revision~string; return s
::method queueRestoreState
  expose workId staffChannelWorkId commandId request instruction state staffState tillState outcomeCode detail createdAt updatedAt revision
  use arg s
  workId=s["workId"]~string; staffChannelWorkId=s["staffChannelWorkId"]~string; commandId=s["commandId"]~string; request=s["request"]; instruction=s["instruction"]; state=.FBTellerCashUtil~token(s["state"]); staffState=.FBTellerCashUtil~token(s["staffState"]); tillState=.FBTellerCashUtil~token(s["tillState"]); outcomeCode=.FBTellerCashUtil~token(s["outcomeCode"]); detail=s["detail"]~string; createdAt=.FBTellerCashUtil~dateValue(s["createdAt"]); updatedAt=.FBTellerCashUtil~dateValue(s["updatedAt"]); revision=s["revision"]+0; return self

::class FederationBankTellerCashServiceState public
::method init
  expose formatVersion sequence works receipts auditEvents outbox
  formatVersion=.FederationBankTellerCashServiceBuild~STATE_FORMAT; sequence=0; works=.directory~new; receipts=.directory~new; auditEvents=.array~new; outbox=.array~new
::method work
  expose works
  use arg id
  if works~hasIndex(id) then return works[id]
  return .nil
::method putWork
  expose works
  use arg w
  works[w~workId]=w; return w
::method works
  expose works
  d=.directory~new; do k over works; d[k]=works[k]; end; return d
::method receipt
  expose receipts
  use arg id
  if receipts~hasIndex(id) then return receipts[id]
  return .nil
::method putReceipt
  expose receipts
  use arg r
  receipts[r~commandId]=r; return r
::method nextEventId
  expose sequence
  use arg workId
  sequence+=1; return "FBTELCASH-EVT-"||sequence||":"||workId
::method sequence
  expose sequence
  return sequence
::method recordEvent
  expose auditEvents outbox
  use arg e
  auditEvents~append(e); outbox~append(e); return e
::method auditEvents
  expose auditEvents
  return .FBTellerCashUtil~copyArray(auditEvents)
::method outbox
  expose outbox
  return .FBTellerCashUtil~copyArray(outbox)
::method markDelivered
  expose outbox
  use arg eventId
  kept=.array~new; found=.false
  do e over outbox; if e~eventId=eventId then found=.true; else kept~append(e); end
  outbox=kept; return found
::method queuePersistentType
  return .FederationBankTellerCashServiceBuild~STATE_FORMAT
::method queuePersistentState
  expose formatVersion sequence works receipts auditEvents outbox
  s=.table~new; s["formatVersion"]=formatVersion; s["sequence"]=sequence~string; s["works"]=works; s["receipts"]=receipts; s["auditEvents"]=auditEvents; s["outbox"]=outbox; return s
::method queueRestoreState
  expose formatVersion sequence works receipts auditEvents outbox
  use arg s
  formatVersion=s["formatVersion"]~string; sequence=s["sequence"]+0; works=s["works"]; receipts=s["receipts"]; auditEvents=s["auditEvents"]; outbox=s["outbox"]; return self

::class FederationBankTellerCashEventSink public
::method publish abstract

::class FederationBankTellerCashMemoryEventSink subclass FederationBankTellerCashEventSink public
::method init
  expose events failNextFlag
  events=.array~new; failNextFlag=.false
::method failNext
  expose failNextFlag
  failNextFlag=.true; return self
::method publish
  expose events failNextFlag
  use arg event
  if failNextFlag then do; failNextFlag=.false; return .FederationBankTellerCashServiceResult~failure("SINK_UNAVAILABLE"); end
  events~append(event); return .FederationBankTellerCashServiceResult~success(event)
::method events
  expose events
  return .FBTellerCashUtil~copyArray(events)

::class FederationBankTellerCashService public
::attribute accepting get
::attribute faulted get
::method init
  expose staffService dispatchPort state store sink accepting faulted
  use arg staffServiceArg,dispatchPortArg,storeArg=.nil,sinkArg=.nil
  if staffServiceArg==.nil | dispatchPortArg==.nil then raise syntax 88.971 array("staff service/dispatch port required")
  staffService=staffServiceArg; dispatchPort=dispatchPortArg; store=storeArg; if sinkArg==.nil then sink=.FederationBankTellerCashMemoryEventSink~new; else sink=sinkArg; accepting=.true; faulted=.false
  if store==.nil then state=.FederationBankTellerCashServiceState~new
  else do
    loaded=store~load
    if loaded~ok then state=loaded~value
    else do; state=.FederationBankTellerCashServiceState~new; accepting=.false; faulted=.true; end
  end
  recoveredWorks=state~works
  do id over recoveredWorks
    w=recoveredWorks[id]; rr=dispatchPort~registerInstruction(w~instruction); if \rr~ok then do; accepting=.false; faulted=.true; leave; end
  end
::method state
  expose state
  return state
::method work
  expose state
  use arg workId
  return state~work(workId)
::method eventSink
  expose sink
  return sink
::method payloadValue private
  use arg payload,key,default=.nil
  if payload<>.nil then if payload~hasIndex(key) then return payload[key]
  return default
::method reply private
  use arg env,ok,code,detail="",workId="",value=.nil
  return .FederationBankTellerCashServiceReply~new(env~commandId,env~correlationId,ok,code,detail,workId,value)
::method persist private
  expose store state accepting faulted
  if store==.nil then return .FederationBankTellerCashServiceResult~success(state)
  r=store~save(state)
  if \r~ok then do; accepting=.false; faulted=.true; end
  return r
::method eventTypeFor private
  use arg w
  select
    when w~state="APPROVAL_REQUIRED" then return "FBTELCASH.WORK.APPROVAL_REQUIRED"
    when w~state="READY_FOR_CORE" then return "FBTELCASH.WORK.READY_FOR_CORE"
    when w~state="COMPLETED" then return "FBTELCASH.WORK.COMPLETED"
    when w~state="COMPENSATION_REQUIRED" then return "FBTELCASH.WORK.COMPENSATION_REQUIRED"
    when w~state="RECONCILIATION_REQUIRED" then return "FBTELCASH.WORK.RECONCILIATION_REQUIRED"
    when w~state="CORE_REJECTED" then return "FBTELCASH.WORK.CORE_REJECTED"
    otherwise return "FBTELCASH.WORK.STATE_CHANGED"
  end
::method addEvent private
  expose state
  use arg env,w
  id=state~nextEventId(w~workId)
  e=.FederationBankTellerCashServiceEvent~new(id,self~eventTypeFor(w),w~workId,env~commandId,env~correlationId,env~causationId,w~state,w~outcomeCode,w~detail,.DateTime~new,state~sequence)
  state~recordEvent(e); return e
::method flushOutbox
  expose state sink
  delivered=0
  do e over state~outbox
    r=sink~publish(e); if \r~ok then return .FederationBankTellerCashServiceResult~failure("EVENT_DELIVERY_PENDING",r~code||":"||r~detail,delivered)
    ignore=state~markDelivered(e~eventId); delivered+=1
  end
  p=self~persist; if \p~ok then return p
  return .FederationBankTellerCashServiceResult~success(delivered)
::method institutionalState private
  use arg stateName
  s=.FBTellerCashUtil~token(stateName)
  return s="COMPLETED" | s="APPROVAL_REQUIRED" | s="COMPENSATION_REQUIRED" | s="RECONCILIATION_REQUIRED" | s="CORE_REJECTED"
::method commitState private
  expose state
  use arg env,w,priorState=""
  state~putWork(w); rec=state~receipt(env~commandId); if rec<>.nil then rec~outcomeCode=w~state
  if priorState<>w~state then ignore=self~addEvent(env,w)
  p=self~persist; if \p~ok then return self~reply(env,.false,p~code,p~detail,w~workId,w)
  ignore=self~flushOutbox
  if self~institutionalState(w~state) then return self~reply(env,.true,w~state,w~detail,w~workId,w)
  return self~reply(env,.false,w~state,w~detail,w~workId,w)
::method updateFromStaff private
  expose dispatchPort
  use arg w,staffReply
  if staffReply~value<>.nil then if staffReply~value~hasMethod("STATE") then w~staffState=staffReply~value~state
  cash=dispatchPort~cashResult(w~commandId)
  if cash<>.nil then do
    tw=cash~value
    if tw<>.nil then if tw~hasMethod("STATE") then w~tillState=tw~state
  end
  if w~tillState="COMPLETED" then do; w~state="COMPLETED"; w~outcomeCode="TELLER_CASH_COMPLETED"; end
  else if w~tillState="COMPENSATION_REQUIRED" then do; w~state="COMPENSATION_REQUIRED"; w~outcomeCode="COMPENSATION_REQUIRED"; end
  else if w~tillState="RECONCILIATION_REQUIRED" then do; w~state="RECONCILIATION_REQUIRED"; w~outcomeCode="RECONCILIATION_REQUIRED"; end
  else if w~staffState="APPROVAL_REQUIRED" then do; w~state="APPROVAL_REQUIRED"; w~outcomeCode="APPROVAL_REQUIRED"; end
  else if w~staffState="CORE_REJECTED" then do; w~state="CORE_REJECTED"; w~outcomeCode=staffReply~code; end
  else if w~staffState="READY_FOR_CORE" then do; w~state="READY_FOR_CORE"; w~outcomeCode=staffReply~code; end
  else if w~staffState="COMPLETED" then do; w~state="COMPLETED"; w~outcomeCode=staffReply~code; end
  else do; w~state="FAILED"; w~outcomeCode=staffReply~code; end
  w~detail=staffReply~detail; w~touch; return w
::method staffSubmit private
  expose staffService
  use arg env,w,contexts,approvals
  p=.directory~new; p["request"]=w~request; p["contexts"]=contexts; p["approvals"]=approvals
  return staffService~handle(.FederationBankStaffChannelServiceEnvelope~new("FBTELCASH:STAFF:"||env~commandId,"FBSTAFFCH.ACTION.SUBMIT",env~actorId,env~actorRole,p,env~correlationId,env~commandId))
::method staffResume private
  expose staffService
  use arg env,w,contexts,approvals
  p=.directory~new; p["workId"]=w~staffChannelWorkId; p["contexts"]=contexts; p["approvals"]=approvals
  return staffService~handle(.FederationBankStaffChannelServiceEnvelope~new("FBTELCASH:STAFF:"||env~commandId,"FBSTAFFCH.ACTION.RESUME",env~actorId,env~actorRole,p,env~correlationId,env~commandId))
::method staffRecover private
  expose staffService
  use arg env,w
  p=.directory~new; p["workId"]=w~staffChannelWorkId
  return staffService~handle(.FederationBankStaffChannelServiceEnvelope~new("FBTELCASH:STAFF:RECOVER:"||env~commandId,"FBSTAFFCH.ACTION.RECOVER",env~actorId,env~actorRole,p,env~correlationId,env~commandId))
::method handle
  expose accepting faulted state
  use arg env
  if env==.nil then return .FederationBankTellerCashServiceReply~new("","",.false,"COMMAND_REQUIRED")
  if env~commandId="" | env~commandType="" | env~actorId="" | env~actorRole="" then return self~reply(env,.false,"COMMAND_INVALID")
  if faulted then return self~reply(env,.false,"SERVICE_FAULTED")
  if \accepting then return self~reply(env,.false,"SERVICE_QUIESCED")
  if env~commandType="FBTELCASH.ACTION.SUBMIT" | env~commandType="FBTELCASH.ACTION.RESUME" | env~commandType="FBTELCASH.ACTION.RECOVER" then do
    prior=state~receipt(env~commandId)
    if prior<>.nil then do
      if prior~fingerprint<>env~fingerprint then return self~reply(env,.false,"COMMAND_ID_CONFLICT","same command id with different semantics",prior~workId,state~work(prior~workId))
      w=state~work(prior~workId)
      if w<>.nil & env~commandType="FBTELCASH.ACTION.SUBMIT" & (w~state="RECEIVED" | w~state="READY_FOR_CORE") then return self~continueSubmit(env,w)
      return self~reply(env,.true,"IDEMPOTENT_REPLAY","original mutation already committed",prior~workId,w)
    end
  end
  select
    when env~commandType="FBTELCASH.ACTION.SUBMIT" then return self~submit(env)
    when env~commandType="FBTELCASH.ACTION.RESUME" then return self~resume(env)
    when env~commandType="FBTELCASH.ACTION.RECOVER" then return self~recover(env)
    when env~commandType="FBTELCASH.ACTION.GET" then return self~getWork(env)
    otherwise return self~reply(env,.false,"COMMAND_UNSUPPORTED",env~commandType)
  end
::method submit private
  expose state dispatchPort
  use arg env
  request=self~payloadValue(env~payload,"request",.nil); instruction=self~payloadValue(env~payload,"instruction",.nil)
  if request==.nil | instruction==.nil then return self~reply(env,.false,"CASH_REQUEST_INSTRUCTION_REQUIRED")
  if request~command==.nil | request~command~commandId<>instruction~commandId then return self~reply(env,.false,"CASH_REQUEST_COMMAND_MISMATCH")
  if request~staffId<>instruction~custodyContext~staffId | request~sessionId<>instruction~custodyContext~sessionId | request~branchId<>instruction~custodyContext~branchId then return self~reply(env,.false,"CASH_CUSTODY_REQUEST_MISMATCH")
  if state~work(instruction~cashWorkId)<>.nil then return self~reply(env,.false,"WORK_ID_CONFLICT","",instruction~cashWorkId,state~work(instruction~cashWorkId))
  rr=dispatchPort~registerInstruction(instruction); if \rr~ok then return self~reply(env,.false,rr~code,rr~detail)
  w=.FederationBankTellerCashServiceWork~new(request,instruction); state~putWork(w); state~putReceipt(.FederationBankTellerCashServiceReceipt~new(env~commandId,env~fingerprint,w~workId,"RECEIVED")); p=self~persist
  if \p~ok then return self~reply(env,.false,p~code,p~detail,w~workId,w)
  return self~continueSubmit(env,w)
::method continueSubmit private
  expose dispatchPort
  use arg env,w
  rr=dispatchPort~registerInstruction(w~instruction); if \rr~ok then return self~reply(env,.false,rr~code,rr~detail,w~workId,w)
  prior=w~state
  if prior="READY_FOR_CORE" then sr=self~staffRecover(env,w)
  else do
    contexts=self~payloadValue(env~payload,"contexts",.nil); approvals=self~payloadValue(env~payload,"approvals",.nil)
    sr=self~staffSubmit(env,w,contexts,approvals)
  end
  self~updateFromStaff(w,sr)
  return self~commitState(env,w,prior)
::method resume private
  expose state dispatchPort
  use arg env
  workId=self~payloadValue(env~payload,"workId",""); w=state~work(workId); if w==.nil then return self~reply(env,.false,"WORK_NOT_FOUND","",workId)
  if w~state<>"APPROVAL_REQUIRED" then return self~reply(env,.false,"WORK_NOT_APPROVAL_REQUIRED",w~state,workId,w)
  rr=dispatchPort~registerInstruction(w~instruction); if \rr~ok then return self~reply(env,.false,rr~code,rr~detail,workId,w)
  state~putReceipt(.FederationBankTellerCashServiceReceipt~new(env~commandId,env~fingerprint,workId,"RESUMING")); p=self~persist; if \p~ok then return self~reply(env,.false,p~code,p~detail,workId,w)
  contexts=self~payloadValue(env~payload,"contexts",.nil); approvals=self~payloadValue(env~payload,"approvals",.nil); prior=w~state; sr=self~staffResume(env,w,contexts,approvals); self~updateFromStaff(w,sr); return self~commitState(env,w,prior)
::method recover private
  expose state dispatchPort
  use arg env
  workId=self~payloadValue(env~payload,"workId",""); w=state~work(workId); if w==.nil then return self~reply(env,.false,"WORK_NOT_FOUND","",workId)
  if w~state<>"READY_FOR_CORE" then return self~reply(env,.false,"WORK_NOT_READY_FOR_CORE",w~state,workId,w)
  rr=dispatchPort~registerInstruction(w~instruction); if \rr~ok then return self~reply(env,.false,rr~code,rr~detail,workId,w)
  state~putReceipt(.FederationBankTellerCashServiceReceipt~new(env~commandId,env~fingerprint,workId,"RECOVERING")); p=self~persist; if \p~ok then return self~reply(env,.false,p~code,p~detail,workId,w)
  prior=w~state; sr=self~staffRecover(env,w); self~updateFromStaff(w,sr); return self~commitState(env,w,prior)
::method getWork private
  expose state
  use arg env
  workId=self~payloadValue(env~payload,"workId",""); w=state~work(workId); if w==.nil then return self~reply(env,.false,"WORK_NOT_FOUND","",workId)
  return self~reply(env,.true,"OK","",workId,w)

::requires "FederationBankTellerCash.cls"
::requires "FederationBankStaffChannelService.cls"
