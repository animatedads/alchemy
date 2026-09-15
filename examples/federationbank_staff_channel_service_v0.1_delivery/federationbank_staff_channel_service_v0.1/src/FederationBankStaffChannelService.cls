/* FederationBank Staff Channel Service v0.1
 *
 * Durable orchestration service for staff-channel work.  It persists an exact
 * READY_FOR_CORE work item before submitting to Core Banking so recovery can
 * safely retry the same idempotent Core command after a process/storage fault.
 */

::class FederationBankStaffChannelServiceBuild public
::constant VERSION "0.1"
::constant API_VERSION "federationbank.staff.channel.service/0.1"
::constant PRODUCT "FederationBank Staff Channel Service"
::constant STATE_FORMAT "federationbank.staff.channel.service.state/1"

::class FederationBankStaffChannelServiceCanonical public
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
  use arg v
  if v==.nil then return "<NIL>"
  if v~hasMethod("SEMANTICIDENTITY") then return v~semanticIdentity
  if v~isA(.Directory) | v~isA(.Table) then do
    keys=.array~new; do k over v; keys~append(k~string); end; keys~sort; text="{"; do k over keys; text||=self~field(k,self~value(v[k])); end; return text||"}"
  end
  if v~isA(.Array) then do; text="["; do item over v; text||=self~field("I",self~value(item)); end; return text||"]"; end
  return v~string

::class FederationBankStaffChannelServiceResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg okArg,codeArg,detailArg="",valueArg=.nil
  ok=okArg; code=.FederationBankStaffChannelServiceCanonical~token(codeArg); detail=detailArg~string; value=valueArg
::method success class
  use arg value=.nil,detail=""
  return self~new(.true,"OK",detail,value)
::method failure class
  use arg code,detail="",value=.nil
  return self~new(.false,code,detail,value)

::class FederationBankStaffChannelServiceEnvelope public
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
  commandId=commandIdArg~string; commandType=.FederationBankStaffChannelServiceCanonical~token(commandTypeArg); actorId=actorIdArg~string; actorRole=.FederationBankStaffChannelServiceCanonical~token(actorRoleArg)
  if correlationIdArg="" then correlationId=commandId; else correlationId=correlationIdArg~string
  causationId=causationIdArg~string; if requestedAtArg==.nil then requestedAt=.DateTime~new; else requestedAt=requestedAtArg; replyTo=replyToArg~string
  if payloadArg==.nil then payload=.directory~new; else payload=payloadArg
::method payload
  expose payload
  return payload
::method fingerprint
  expose commandType actorId actorRole payload
  text="FB-STAFF-CHANNEL-SERVICE-COMMAND/1"; text||=.FederationBankStaffChannelServiceCanonical~field("TYPE",commandType); text||=.FederationBankStaffChannelServiceCanonical~field("ACTOR",actorId); text||=.FederationBankStaffChannelServiceCanonical~field("ROLE",actorRole); text||=.FederationBankStaffChannelServiceCanonical~field("PAYLOAD",.FederationBankStaffChannelServiceCanonical~value(payload)); return text
::method queuePersistentType
  return "federationbank.staff.channel.service.command/1"
::method queuePersistentState
  expose commandId commandType correlationId causationId actorId actorRole requestedAt replyTo payload
  s=.table~new; s["commandId"]=commandId; s["commandType"]=commandType; s["correlationId"]=correlationId; s["causationId"]=causationId; s["actorId"]=actorId; s["actorRole"]=actorRole; s["requestedAt"]=requestedAt~utcIsoDate; s["replyTo"]=replyTo; s["payload"]=payload; return s
::method queueRestoreState
  expose commandId commandType correlationId causationId actorId actorRole requestedAt replyTo payload
  use arg s
  commandId=s["commandId"]~string; commandType=.FederationBankStaffChannelServiceCanonical~token(s["commandType"]); correlationId=s["correlationId"]~string; causationId=s["causationId"]~string; actorId=s["actorId"]~string; actorRole=.FederationBankStaffChannelServiceCanonical~token(s["actorRole"]); requestedAt=.FederationBankStaffChannelCanonical~dateValue(s["requestedAt"]); replyTo=s["replyTo"]~string; payload=s["payload"]; return self

::class FederationBankStaffChannelServiceReply public
::attribute commandId get
::attribute correlationId get
::attribute ok get
::attribute code get
::attribute detail get
::attribute workId get
::method init
  expose commandId correlationId ok code detail workId value
  use arg commandIdArg,correlationIdArg,okArg,codeArg,detailArg="",workIdArg="",valueArg=.nil
  commandId=commandIdArg~string; correlationId=correlationIdArg~string; ok=okArg; code=.FederationBankStaffChannelServiceCanonical~token(codeArg); detail=detailArg~string; workId=workIdArg~string; value=valueArg
::method value
  expose value
  return value
::method queuePersistentType
  return "federationbank.staff.channel.service.reply/1"
::method queuePersistentState
  expose commandId correlationId ok code detail workId value
  s=.table~new; s["commandId"]=commandId; s["correlationId"]=correlationId; if ok then s["ok"]="1"; else s["ok"]="0"; s["code"]=code; s["detail"]=detail; s["workId"]=workId; s["value"]=value; return s
::method queueRestoreState
  expose commandId correlationId ok code detail workId value
  use arg s
  commandId=s["commandId"]~string; correlationId=s["correlationId"]~string; ok=(s["ok"]~string="1"); code=.FederationBankStaffChannelServiceCanonical~token(s["code"]); detail=s["detail"]~string; workId=s["workId"]~string; value=s["value"]; return self

::class FederationBankStaffChannelServiceReceipt public
::attribute commandId get
::attribute fingerprint get
::attribute workId get
::attribute outcomeCode get
::method init
  expose commandId fingerprint workId outcomeCode
  use arg commandIdArg,fingerprintArg,workIdArg="",outcomeCodeArg="OK"
  commandId=commandIdArg~string; fingerprint=fingerprintArg~string; workId=workIdArg~string; outcomeCode=.FederationBankStaffChannelServiceCanonical~token(outcomeCodeArg)
::method queuePersistentType
  return "federationbank.staff.channel.service.receipt/1"
::method queuePersistentState
  expose commandId fingerprint workId outcomeCode
  s=.table~new; s["commandId"]=commandId; s["fingerprint"]=fingerprint; s["workId"]=workId; s["outcomeCode"]=outcomeCode; return s
::method queueRestoreState
  expose commandId fingerprint workId outcomeCode
  use arg s
  commandId=s["commandId"]~string; fingerprint=s["fingerprint"]~string; workId=s["workId"]~string; outcomeCode=.FederationBankStaffChannelServiceCanonical~token(s["outcomeCode"]); return self

::class FederationBankStaffChannelServiceEvent public
::attribute eventId get
::attribute eventType get
::attribute workId get
::attribute correlationId get
::attribute causationId get
::attribute actorId get
::attribute actorRole get
::attribute occurredAt get
::attribute sequence get
::method init
  expose eventId eventType workId correlationId causationId actorId actorRole occurredAt sequence payload
  use arg eventIdArg,eventTypeArg,workIdArg,correlationIdArg,causationIdArg,actorIdArg,actorRoleArg,occurredAtArg,sequenceArg,payloadArg=.nil
  eventId=eventIdArg~string; eventType=.FederationBankStaffChannelServiceCanonical~token(eventTypeArg); workId=workIdArg~string; correlationId=correlationIdArg~string; causationId=causationIdArg~string; actorId=actorIdArg~string; actorRole=.FederationBankStaffChannelServiceCanonical~token(actorRoleArg); occurredAt=occurredAtArg; sequence=sequenceArg+0; if payloadArg==.nil then payload=.directory~new; else payload=payloadArg
::method payload
  expose payload
  return payload
::method queuePersistentType
  return "federationbank.staff.channel.service.event/1"
::method queuePersistentState
  expose eventId eventType workId correlationId causationId actorId actorRole occurredAt sequence payload
  s=.table~new; s["eventId"]=eventId; s["eventType"]=eventType; s["workId"]=workId; s["correlationId"]=correlationId; s["causationId"]=causationId; s["actorId"]=actorId; s["actorRole"]=actorRole; s["occurredAt"]=occurredAt~utcIsoDate; s["sequence"]=sequence~string; s["payload"]=payload; return s
::method queueRestoreState
  expose eventId eventType workId correlationId causationId actorId actorRole occurredAt sequence payload
  use arg s
  eventId=s["eventId"]~string; eventType=.FederationBankStaffChannelServiceCanonical~token(s["eventType"]); workId=s["workId"]~string; correlationId=s["correlationId"]~string; causationId=s["causationId"]~string; actorId=s["actorId"]~string; actorRole=.FederationBankStaffChannelServiceCanonical~token(s["actorRole"]); occurredAt=.FederationBankStaffChannelCanonical~dateValue(s["occurredAt"]); sequence=s["sequence"]+0; payload=s["payload"]; return self

::class FederationBankStaffChannelServiceState public
::method init
  expose formatVersion sequence works receipts auditEvents outbox
  formatVersion=.FederationBankStaffChannelServiceBuild~STATE_FORMAT; sequence=0; works=.directory~new; receipts=.directory~new; auditEvents=.array~new; outbox=.array~new
::method work
  expose works
  use arg workId
  if works~hasIndex(workId) then return works[workId]
  return .nil
::method putWork
  expose works
  use arg work
  works[work~workId]=work; return work
::method works
  expose works
  d=.directory~new; do k over works; d[k]=works[k]; end; return d
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
  use arg workId
  sequence+=1; return "FBSTAFFCH-EVT-"||sequence||":"||workId
::method sequence
  expose sequence
  return sequence
::method recordEvent
  expose auditEvents outbox
  use arg event
  auditEvents~append(event); outbox~append(event); return event
::method auditEvents
  expose auditEvents
  return .FederationBankStaffChannelServiceCanonical~copyArray(auditEvents)
::method outbox
  expose outbox
  return .FederationBankStaffChannelServiceCanonical~copyArray(outbox)
::method markDelivered
  expose outbox
  use arg eventId
  kept=.array~new; found=.false
  do e over outbox; if e~eventId=eventId then found=.true; else kept~append(e); end
  outbox=kept; return found
::method queuePersistentType
  return .FederationBankStaffChannelServiceBuild~STATE_FORMAT
::method queuePersistentState
  expose formatVersion sequence works receipts auditEvents outbox
  s=.table~new; s["formatVersion"]=formatVersion; s["sequence"]=sequence~string; s["works"]=works; s["receipts"]=receipts; s["auditEvents"]=auditEvents; s["outbox"]=outbox; return s
::method queueRestoreState
  expose formatVersion sequence works receipts auditEvents outbox
  use arg s
  formatVersion=s["formatVersion"]~string; sequence=s["sequence"]+0; works=s["works"]; receipts=s["receipts"]; auditEvents=s["auditEvents"]; outbox=s["outbox"]; return self

::class FederationBankStaffChannelEventSink public
::method publish abstract
::class FederationBankStaffChannelMemoryEventSink subclass FederationBankStaffChannelEventSink public
::method init
  expose events failNextFlag
  events=.array~new; failNextFlag=.false
::method failNext
  expose failNextFlag
  failNextFlag=.true; return self
::method publish
  expose events failNextFlag
  use arg event
  if failNextFlag then do; failNextFlag=.false; return .FederationBankStaffChannelServiceResult~failure("SINK_UNAVAILABLE"); end
  events~append(event); return .FederationBankStaffChannelServiceResult~success(event)
::method events
  expose events
  return .FederationBankStaffChannelServiceCanonical~copyArray(events)

::class FederationBankStaffChannelService public
::attribute accepting get
::attribute faulted get
::method init
  expose orchestrator state store sink accepting faulted
  use arg orchestratorArg,storeArg=.nil,sinkArg=.nil
  if orchestratorArg==.nil then raise syntax 98.910 array("Staff Channel orchestrator required")
  orchestrator=orchestratorArg; store=storeArg; if sinkArg==.nil then sink=.FederationBankStaffChannelMemoryEventSink~new; else sink=sinkArg; accepting=.true; faulted=.false
  if store==.nil then state=.FederationBankStaffChannelServiceState~new
  else do
    loaded=store~load
    if loaded~ok then state=loaded~value
    else do; state=.FederationBankStaffChannelServiceState~new; accepting=.false; faulted=.true; end
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
  return t="FBSTAFFCH.ACTION.SUBMIT" | t="FBSTAFFCH.ACTION.RESUME" | t="FBSTAFFCH.ACTION.RECOVER"
::method reply private
  use arg env,ok,code,detail="",workId="",value=.nil
  return .FederationBankStaffChannelServiceReply~new(env~commandId,env~correlationId,ok,code,detail,workId,value)
::method persist private
  expose store state accepting faulted
  if store==.nil then return .FederationBankStaffChannelServiceResult~success(state)
  r=store~save(state)
  if \r~ok then do; accepting=.false; faulted=.true; end
  return r
::method addEvent private
  expose state
  use arg env,eventType,work
  p=.directory~new; p["state"]=work~state; p["outcomeCode"]=work~outcomeCode; p["route"]=work~route; p["revision"]=work~revision~string; if work~coreCode<>"" then p["coreCode"]=work~coreCode
  id=state~nextEventId(work~workId); e=.FederationBankStaffChannelServiceEvent~new(id,eventType,work~workId,env~correlationId,env~commandId,env~actorId,env~actorRole,.DateTime~new,state~sequence,p); state~recordEvent(e); return e
::method eventTypeFor private
  use arg work
  select
    when work~state="APPROVAL_REQUIRED" then return "FBSTAFFCH.WORK.APPROVAL_REQUIRED"
    when work~state="READY_FOR_CORE" then return "FBSTAFFCH.WORK.READY_FOR_CORE"
    when work~state="COMPLETED" then return "FBSTAFFCH.WORK.COMPLETED"
    when work~state="CORE_REJECTED" then return "FBSTAFFCH.WORK.CORE_REJECTED"
    when work~state="NO_BANK_ACTION" then return "FBSTAFFCH.WORK.NO_BANK_ACTION"
    when work~state="REJECTED" then return "FBSTAFFCH.WORK.REJECTED"
    otherwise return "FBSTAFFCH.WORK.STATE_CHANGED"
  end
::method flushOutbox
  expose state sink
  delivered=0; pending=state~outbox
  do event over pending
    r=sink~publish(event); if \r~ok then return .FederationBankStaffChannelServiceResult~failure("EVENT_DELIVERY_PENDING",r~code||":"||r~detail,delivered)
    ignore=state~markDelivered(event~eventId); delivered+=1
  end
  p=self~persist; if \p~ok then return p
  return .FederationBankStaffChannelServiceResult~success(delivered)
::method commitPrepared private
  expose state
  use arg env,work
  state~putWork(work); ignore=self~addEvent(env,self~eventTypeFor(work),work); state~putReceipt(.FederationBankStaffChannelServiceReceipt~new(env~commandId,env~fingerprint,work~workId,work~state)); return self~persist
::method finishReady private
  expose orchestrator state
  use arg env,work
  r=orchestrator~execute(work); if \r~ok then return self~reply(env,.false,r~code,r~detail,work~workId,work)
  state~putWork(work); state~putReceipt(.FederationBankStaffChannelServiceReceipt~new(env~commandId,env~fingerprint,work~workId,work~state)); ignore=self~addEvent(env,self~eventTypeFor(work),work); p=self~persist; if \p~ok then return self~reply(env,.false,p~code,p~detail,work~workId,work); ignore=self~flushOutbox
  return self~reply(env,.true,work~state,work~detail,work~workId,work)
::method handle
  expose accepting faulted state
  use arg env
  if env==.nil then return .FederationBankStaffChannelServiceReply~new("","",.false,"COMMAND_REQUIRED")
  if env~commandId="" | env~commandType="" | env~actorId="" | env~actorRole="" then return self~reply(env,.false,"COMMAND_INVALID")
  if faulted then return self~reply(env,.false,"SERVICE_FAULTED")
  if \accepting then return self~reply(env,.false,"SERVICE_QUIESCED")
  if self~isMutation(env~commandType) then do
    prior=state~receipt(env~commandId)
    if prior<>.nil then do
      if prior~fingerprint\=env~fingerprint then return self~reply(env,.false,"COMMAND_ID_CONFLICT")
      work=.nil; if prior~workId<>"" then work=state~work(prior~workId)
      if work<>.nil then if work~state="READY_FOR_CORE" then return self~finishReady(env,work)
      return self~reply(env,.true,"IDEMPOTENT_REPLAY","original mutation already committed",prior~workId,work)
    end
  end
  select
    when env~commandType="FBSTAFFCH.ACTION.SUBMIT" then return self~submit(env)
    when env~commandType="FBSTAFFCH.ACTION.RESUME" then return self~resume(env)
    when env~commandType="FBSTAFFCH.ACTION.RECOVER" then return self~recover(env)
    when env~commandType="FBSTAFFCH.ACTION.GET" then return self~getWork(env)
    otherwise return self~reply(env,.false,"COMMAND_UNSUPPORTED",env~commandType)
  end
::method submit private
  expose orchestrator state
  use arg env
  request=self~payloadValue(env~payload,"request",.nil); contexts=self~payloadValue(env~payload,"contexts",.nil); approvals=self~payloadValue(env~payload,"approvals",.nil); envelopeId=self~payloadValue(env~payload,"envelopeId","")
  if request==.nil then return self~reply(env,.false,"STAFF_CHANNEL_REQUEST_REQUIRED")
  existing=state~work(request~workId); if existing<>.nil then return self~reply(env,.false,"WORK_ID_CONFLICT","work already exists",request~workId,existing)
  r=orchestrator~prepare(request,contexts,approvals,envelopeId); if \r~ok then return self~reply(env,.false,r~code,r~detail,request~workId,r~value)
  work=r~value; p=self~commitPrepared(env,work); if \p~ok then return self~reply(env,.false,p~code,p~detail,work~workId,work)
  if work~state="READY_FOR_CORE" then return self~finishReady(env,work)
  ignore=self~flushOutbox
  return self~reply(env,.true,work~state,work~detail,work~workId,work)
::method resume private
  expose orchestrator state
  use arg env
  workId=self~payloadValue(env~payload,"workId",""); contexts=self~payloadValue(env~payload,"contexts",.nil); approvals=self~payloadValue(env~payload,"approvals",.nil); envelopeId=self~payloadValue(env~payload,"envelopeId","")
  if workId="" then return self~reply(env,.false,"WORK_ID_REQUIRED")
  work=state~work(workId); if work==.nil then return self~reply(env,.false,"WORK_NOT_FOUND","",workId)
  r=orchestrator~prepareResume(work,contexts,approvals,envelopeId); if \r~ok then return self~reply(env,.false,r~code,r~detail,workId,r~value)
  state~putWork(work); ignore=self~addEvent(env,self~eventTypeFor(work),work); state~putReceipt(.FederationBankStaffChannelServiceReceipt~new(env~commandId,env~fingerprint,workId,work~state)); p=self~persist; if \p~ok then return self~reply(env,.false,p~code,p~detail,workId,work)
  if work~state="READY_FOR_CORE" then return self~finishReady(env,work)
  ignore=self~flushOutbox; return self~reply(env,.true,work~state,work~detail,workId,work)
::method recover private
  expose state
  use arg env
  workId=self~payloadValue(env~payload,"workId",""); if workId="" then return self~reply(env,.false,"WORK_ID_REQUIRED")
  work=state~work(workId); if work==.nil then return self~reply(env,.false,"WORK_NOT_FOUND","",workId)
  if work~state<>"READY_FOR_CORE" then return self~reply(env,.false,"WORK_NOT_READY_FOR_CORE",work~state,workId,work)
  state~putReceipt(.FederationBankStaffChannelServiceReceipt~new(env~commandId,env~fingerprint,workId,"RECOVERING")); p=self~persist; if \p~ok then return self~reply(env,.false,p~code,p~detail,workId,work)
  return self~finishReady(env,work)
::method getWork private
  expose state
  use arg env
  workId=self~payloadValue(env~payload,"workId",""); if workId="" then return self~reply(env,.false,"WORK_ID_REQUIRED")
  work=state~work(workId); if work==.nil then return self~reply(env,.false,"WORK_NOT_FOUND","",workId)
  return self~reply(env,.true,"OK","",workId,work)

::requires "FederationBankStaffChannel.cls"
