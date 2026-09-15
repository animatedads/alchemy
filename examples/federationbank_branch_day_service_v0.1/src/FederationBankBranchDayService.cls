/* FederationBank Branch Day Service v0.1
 * Durable lifecycle around Branch Day opening/closing certification.
 */
::class FederationBankBranchDayServiceBuild public
::constant VERSION "0.1"
::constant API_VERSION "federationbank.branch.day.service/0.1"
::constant STATE_FORMAT "federationbank.branch.day.service.state/1"

::class FederationBankBranchDayServiceResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg okArg,codeArg,detailArg="",valueArg=.nil
  ok=okArg; code=.FBBranchDayUtil~token(codeArg); detail=detailArg~string; value=valueArg
::method success class
  use arg value=.nil,detail=""
  return self~new(.true,"OK",detail,value)
::method failure class
  use arg code,detail="",value=.nil
  return self~new(.false,code,detail,value)

::class FederationBankBranchDayServiceEnvelope public
::attribute commandId get
::attribute commandType get
::attribute actorId get
::attribute correlationId get
::attribute replyTo get
::method init
  expose commandId commandType actorId correlationId replyTo payload
  use arg commandIdArg,commandTypeArg,actorIdArg,payloadArg=.nil,correlationIdArg="",replyToArg=""
  commandId=commandIdArg~string; commandType=.FBBranchDayUtil~token(commandTypeArg); actorId=actorIdArg~string; if correlationIdArg="" then correlationId=commandId; else correlationId=correlationIdArg~string; replyTo=replyToArg~string; if payloadArg==.nil then payload=.directory~new; else payload=payloadArg
  if commandId="" | commandType="" | actorId="" then raise syntax 88.975 array("branch day service command identity required")
::method payload
  expose payload
  return payload
::method queuePersistentType
  return "federationbank.branch.day.service.command/1"
::method queuePersistentState
  expose commandId commandType actorId correlationId replyTo payload
  s=.table~new; s["commandId"]=commandId; s["commandType"]=commandType; s["actorId"]=actorId; s["correlationId"]=correlationId; s["replyTo"]=replyTo; s["payload"]=payload; return s
::method queueRestoreState
  expose commandId commandType actorId correlationId replyTo payload
  use arg s
  commandId=s["commandId"]~string; commandType=.FBBranchDayUtil~token(s["commandType"]); actorId=s["actorId"]~string; correlationId=s["correlationId"]~string; replyTo=s["replyTo"]~string; payload=s["payload"]; return self

::class FederationBankBranchDayServiceReply public
::attribute commandId get
::attribute correlationId get
::attribute ok get
::attribute code get
::attribute detail get
::attribute dayId get
::attribute value get
::method init
  expose commandId correlationId ok code detail dayId value
  use arg commandIdArg,correlationIdArg,okArg,codeArg,detailArg="",dayIdArg="",valueArg=.nil
  commandId=commandIdArg~string; correlationId=correlationIdArg~string; ok=okArg; code=.FBBranchDayUtil~token(codeArg); detail=detailArg~string; dayId=dayIdArg~string; value=valueArg
::method queuePersistentType
  return "federationbank.branch.day.service.reply/1"
::method queuePersistentState
  expose commandId correlationId ok code detail dayId value
  s=.table~new; s["commandId"]=commandId; s["correlationId"]=correlationId; if ok then s["ok"]="1"; else s["ok"]="0"; s["code"]=code; s["detail"]=detail; s["dayId"]=dayId; s["value"]=value; return s
::method queueRestoreState
  expose commandId correlationId ok code detail dayId value
  use arg s
  commandId=s["commandId"]~string; correlationId=s["correlationId"]~string; ok=(s["ok"]~string="1"); code=.FBBranchDayUtil~token(s["code"]); detail=s["detail"]~string; dayId=s["dayId"]~string; value=s["value"]; return self

::class FederationBankBranchDayServiceReceipt public
::attribute commandId get
::attribute fingerprint get
::attribute dayId get
::attribute ok get
::attribute code get
::method init
  expose commandId fingerprint dayId ok code
  use arg commandIdArg,fingerprintArg,dayIdArg,okArg,codeArg
  commandId=commandIdArg~string; fingerprint=fingerprintArg~string; dayId=dayIdArg~string; ok=okArg; code=.FBBranchDayUtil~token(codeArg)
::method queuePersistentType
  return "federationbank.branch.day.service.receipt/1"
::method queuePersistentState
  expose commandId fingerprint dayId ok code
  s=.table~new; s["commandId"]=commandId; s["fingerprint"]=fingerprint; s["dayId"]=dayId; if ok then s["ok"]="1"; else s["ok"]="0"; s["code"]=code; return s
::method queueRestoreState
  expose commandId fingerprint dayId ok code
  use arg s
  commandId=s["commandId"]~string; fingerprint=s["fingerprint"]~string; dayId=s["dayId"]~string; ok=(s["ok"]~string="1"); code=.FBBranchDayUtil~token(s["code"]); return self

::class FederationBankBranchDayServiceEvent public
::attribute eventId get
::attribute eventType get
::attribute dayId get
::attribute commandId get
::attribute correlationId get
::attribute state get
::attribute sequence get
::method init
  expose eventId eventType dayId commandId correlationId state sequence
  use arg eventIdArg,eventTypeArg,dayIdArg,commandIdArg,correlationIdArg,stateArg,sequenceArg=0
  eventId=eventIdArg~string; eventType=.FBBranchDayUtil~token(eventTypeArg); dayId=dayIdArg~string; commandId=commandIdArg~string; correlationId=correlationIdArg~string; state=.FBBranchDayUtil~token(stateArg); sequence=sequenceArg+0
::method queuePersistentType
  return "federationbank.branch.day.service.event/1"
::method queuePersistentState
  expose eventId eventType dayId commandId correlationId state sequence
  s=.table~new; s["eventId"]=eventId; s["eventType"]=eventType; s["dayId"]=dayId; s["commandId"]=commandId; s["correlationId"]=correlationId; s["state"]=state; s["sequence"]=sequence~string; return s
::method queueRestoreState
  expose eventId eventType dayId commandId correlationId state sequence
  use arg s
  eventId=s["eventId"]~string; eventType=.FBBranchDayUtil~token(s["eventType"]); dayId=s["dayId"]~string; commandId=s["commandId"]~string; correlationId=s["correlationId"]~string; state=.FBBranchDayUtil~token(s["state"]); sequence=s["sequence"]+0; return self

::class FederationBankBranchDayServiceState public
::method init
  expose sequence days receipts events outbox
  sequence=0; days=.directory~new; receipts=.directory~new; events=.array~new; outbox=.array~new
::method putDay
  expose days
  use arg d
  days[d~dayId]=d; return d
::method day
  expose days
  use arg id
  if days~hasIndex(id) then return days[id]
  return .nil
::method days
  expose days
  x=.directory~new; do k over days; x[k]=days[k]; end; return x
::method putReceipt
  expose receipts
  use arg r
  receipts[r~commandId]=r; return r
::method receipt
  expose receipts
  use arg id
  if receipts~hasIndex(id) then return receipts[id]
  return .nil
::method nextEventId
  expose sequence
  use arg dayId
  sequence+=1; return "FBBRANCHDAY-E"||sequence||":"||dayId
::method sequence
  expose sequence
  return sequence
::method recordEvent
  expose events outbox
  use arg e
  events~append(e); outbox~append(e); return e
::method outbox
  expose outbox
  return .FBBranchDayUtil~copyArray(outbox)
::method markDelivered
  expose outbox
  use arg eventId
  kept=.array~new; found=.false; do e over outbox; if e~eventId=eventId then found=.true; else kept~append(e); end; outbox=kept; return found
::method queuePersistentType
  return .FederationBankBranchDayServiceBuild~STATE_FORMAT
::method queuePersistentState
  expose sequence days receipts events outbox
  s=.table~new; s["sequence"]=sequence~string; s["days"]=days; s["receipts"]=receipts; s["events"]=events; s["outbox"]=outbox; return s
::method queueRestoreState
  expose sequence days receipts events outbox
  use arg s
  sequence=s["sequence"]+0; days=s["days"]; receipts=s["receipts"]; events=s["events"]; outbox=s["outbox"]; return self

::class FederationBankBranchDayEventSink public
::method publish abstract
::class FederationBankBranchDayMemoryEventSink subclass FederationBankBranchDayEventSink public
::method init
  expose events failNextFlag
  events=.array~new; failNextFlag=.false
::method failNext
  expose failNextFlag
  failNextFlag=.true; return self
::method publish
  expose events failNextFlag
  use arg event
  if failNextFlag then do; failNextFlag=.false; return .FederationBankBranchDayServiceResult~failure("SINK_UNAVAILABLE"); end
  events~append(event); return .FederationBankBranchDayServiceResult~success(event)
::method events
  expose events
  return .FBBranchDayUtil~copyArray(events)

::class FederationBankBranchDayService public
::attribute accepting get
::attribute faulted get
::method init
  expose policy store sink state accepting faulted
  use arg policyArg,storeArg=.nil,sinkArg=.nil
  if policyArg==.nil then raise syntax 88.976 array("branch day policy required")
  policy=policyArg; store=storeArg; if sinkArg==.nil then sink=.FederationBankBranchDayMemoryEventSink~new; else sink=sinkArg; accepting=.true; faulted=.false
  if store==.nil then state=.FederationBankBranchDayServiceState~new
  else do; r=store~load; if r~ok then state=r~value; else do; state=.FederationBankBranchDayServiceState~new; accepting=.false; faulted=.true; end; end
::method state
  expose state
  return state
::method day
  expose state
  use arg id
  return state~day(id)
::method persist private
  expose store state accepting faulted
  if store==.nil then return .FederationBankBranchDayServiceResult~success(state)
  r=store~save(state); if \r~ok then do; accepting=.false; faulted=.true; end; return r
::method canonical private
  use arg prefix,objects=.nil
  text=prefix; if objects==.nil then return text
  ids=.array~new; do o over objects; if o~hasMethod("SEMANTICIDENTITY") then ids~append(o~semanticIdentity); else ids~append(o~string); end; ids~sort; do id over ids; text||="|"||id; end; return text
::method checkReceipt private
  expose state
  use arg commandId,fingerprint
  old=state~receipt(commandId); if old==.nil then return .FederationBankBranchDayServiceResult~success(.nil)
  if old~fingerprint<>fingerprint then return .FederationBankBranchDayServiceResult~failure("COMMAND_ID_REUSE_CONFLICT")
  d=state~day(old~dayId); if old~ok then return .FederationBankBranchDayServiceResult~success(d,"IDEMPOTENT_REPLAY")
  return .FederationBankBranchDayServiceResult~failure(old~code,"IDEMPOTENT_REPLAY",d)
::method record private
  expose state
  use arg commandId,fingerprint,dayId,result
  state~putReceipt(.FederationBankBranchDayServiceReceipt~new(commandId,fingerprint,dayId,result~ok,result~code)); return self~persist
::method emit private
  expose state
  use arg eventType,day,commandId,correlationId
  e=.FederationBankBranchDayServiceEvent~new(state~nextEventId(day~dayId),eventType,day~dayId,commandId,correlationId,day~state,state~sequence); state~recordEvent(e); return e
::method createDay
  expose accepting state
  use arg commandId,correlationId,dayId,branchId,businessDate
  if \accepting then return .FederationBankBranchDayServiceResult~failure("SERVICE_NOT_ACCEPTING")
  fp="CREATE|"||dayId||"|"||branchId||"|"||businessDate; old=self~checkReceipt(commandId,fp); if old~value<>.nil | \old~ok then return old
  if state~day(dayId)<>.nil then return .FederationBankBranchDayServiceResult~failure("DAY_ID_CONFLICT")
  d=.FederationBankBranchDay~new(dayId,branchId,businessDate); state~putDay(d); r=.FederationBankBranchDayServiceResult~success(d); ignore=self~emit("FBBRANCHDAY.DAY.CREATED",d,commandId,correlationId); p=self~record(commandId,fp,dayId,r); if \p~ok then return p; return r
::method openDay
  expose accepting state policy
  use arg commandId,correlationId,dayId,endpoints,positions,requestedBy,approval
  if \accepting then return .FederationBankBranchDayServiceResult~failure("SERVICE_NOT_ACCEPTING")
  fp=self~canonical("OPEN|"||dayId||"|"||requestedBy,endpoints)||self~canonical("|P",positions)||"|"||approval~actionIdentity; old=self~checkReceipt(commandId,fp); if old~value<>.nil | \old~ok then return old
  d=state~day(dayId); if d==.nil then return .FederationBankBranchDayServiceResult~failure("DAY_NOT_FOUND")
  x=d~open(endpoints,positions,requestedBy,approval,policy); r=.FederationBankBranchDayServiceResult~new(x~ok,x~code,x~detail,d); if x~ok then ignore=self~emit("FBBRANCHDAY.DAY.OPENED",d,commandId,correlationId); p=self~record(commandId,fp,dayId,r); if \p~ok then return p; return r
::method beginClose
  expose accepting state policy
  use arg commandId,correlationId,dayId,requestedBy,approval
  if \accepting then return .FederationBankBranchDayServiceResult~failure("SERVICE_NOT_ACCEPTING")
  fp="BEGIN_CLOSE|"||dayId||"|"||requestedBy||"|"||approval~actionIdentity; old=self~checkReceipt(commandId,fp); if old~value<>.nil | \old~ok then return old
  d=state~day(dayId); if d==.nil then return .FederationBankBranchDayServiceResult~failure("DAY_NOT_FOUND")
  x=d~beginClose(requestedBy,approval,policy); r=.FederationBankBranchDayServiceResult~new(x~ok,x~code,x~detail,d); if x~ok then ignore=self~emit("FBBRANCHDAY.DAY.CLOSING",d,commandId,correlationId); p=self~record(commandId,fp,dayId,r); if \p~ok then return p; return r
::method closeDay
  expose accepting state policy
  use arg commandId,correlationId,dayId,endpoints,positions,totals,requestedBy,approval
  if \accepting then return .FederationBankBranchDayServiceResult~failure("SERVICE_NOT_ACCEPTING")
  fp=self~canonical("CLOSE|"||dayId||"|"||requestedBy,endpoints)||self~canonical("|P",positions)||self~canonical("|T",totals)||"|"||approval~actionIdentity; old=self~checkReceipt(commandId,fp); if old~value<>.nil | \old~ok then return old
  d=state~day(dayId); if d==.nil then return .FederationBankBranchDayServiceResult~failure("DAY_NOT_FOUND")
  x=d~close(endpoints,positions,totals,requestedBy,approval,policy); r=.FederationBankBranchDayServiceResult~new(x~ok,x~code,x~detail,d); if x~ok then ignore=self~emit("FBBRANCHDAY.DAY.CLOSED",d,commandId,correlationId); p=self~record(commandId,fp,dayId,r); if \p~ok then return p; return r
::method handle
  use arg env
  if env==.nil | \env~isA(.FederationBankBranchDayServiceEnvelope) then return .FederationBankBranchDayServiceReply~new("","",.false,"INVALID_COMMAND")
  p=env~payload
  select
    when env~commandType="FBBRANCHDAY.DAY.CREATE" then r=self~createDay(env~commandId,env~correlationId,p["dayId"],p["branchId"],p["businessDate"])
    when env~commandType="FBBRANCHDAY.DAY.OPEN" then r=self~openDay(env~commandId,env~correlationId,p["dayId"],p["endpoints"],p["positions"],p["requestedBy"],p["approval"])
    when env~commandType="FBBRANCHDAY.DAY.BEGIN_CLOSE" then r=self~beginClose(env~commandId,env~correlationId,p["dayId"],p["requestedBy"],p["approval"])
    when env~commandType="FBBRANCHDAY.DAY.CLOSE" then r=self~closeDay(env~commandId,env~correlationId,p["dayId"],p["endpoints"],p["positions"],p["totals"],p["requestedBy"],p["approval"])
    when env~commandType="FBBRANCHDAY.DAY.GET" then do; d=self~day(p["dayId"]); if d==.nil then r=.FederationBankBranchDayServiceResult~failure("DAY_NOT_FOUND"); else r=.FederationBankBranchDayServiceResult~success(d); end
    otherwise r=.FederationBankBranchDayServiceResult~failure("COMMAND_TYPE_NOT_SUPPORTED")
  end
  dayId=""; if r~value<>.nil then if r~value~hasMethod("DAYID") then dayId=r~value~dayId
  return .FederationBankBranchDayServiceReply~new(env~commandId,env~correlationId,r~ok,r~code,r~detail,dayId,r~value)
::method flushOutbox
  expose state sink
  sent=0; copy=state~outbox
  do e over copy
    r=sink~publish(e); if \r~ok then return .FederationBankBranchDayServiceResult~failure("EVENT_DELIVERY_FAILED",r~code,sent)
    ignore=state~markDelivered(e~eventId); sent+=1; p=self~persist; if \p~ok then return p
  end
  return .FederationBankBranchDayServiceResult~success(sent)

::requires "FederationBankBranchDay.cls"
