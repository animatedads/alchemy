/* FederationBank External Cash Service v0.1 */
::class FederationBankExternalCashServiceBuild public
::constant VERSION "0.1"
::constant API_VERSION "federationbank.external.cash.service/0.1"
::constant STATE_FORMAT "federationbank.external.cash.service.state/1"

::class FederationBankExternalCashServiceResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg okArg,codeArg,detailArg="",valueArg=.nil
  ok=okArg; code=.FBExternalCashUtil~token(codeArg); detail=detailArg~string; value=valueArg
::method success class
  use arg value=.nil,detail=""
  return self~new(.true,"OK",detail,value)
::method failure class
  use arg code,detail="",value=.nil
  return self~new(.false,code,detail,value)

::class FederationBankExternalCashServiceEnvelope public
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
  commandId=commandIdArg~string; commandType=.FBExternalCashUtil~token(commandTypeArg); actorId=actorIdArg~string; actorRole=.FBExternalCashUtil~token(actorRoleArg); if correlationIdArg="" then correlationId=commandId; else correlationId=correlationIdArg~string; causationId=causationIdArg~string; if requestedAtArg==.nil then requestedAt=.DateTime~new; else requestedAt=requestedAtArg; replyTo=replyToArg~string; if payloadArg==.nil then payload=.directory~new; else payload=payloadArg
::method payload
  expose payload
  return payload
::method fingerprint
  expose commandType actorId actorRole payload
  t="FBEXTERNALCASHSERVICECMD/1|"||commandType||"|"||actorId||"|"||actorRole; keys=.array~new; do k over payload; keys~append(k~string); end; keys~sort
  do k over keys
    v=payload[k]; if v==.nil then x="<NIL>"; else if v~hasMethod("SEMANTICIDENTITY") then x=v~semanticIdentity; else x=v~string
    t||="|"||k||"="||x
  end
  return t
::method queuePersistentType
  return "federationbank.external.cash.service.command/1"
::method queuePersistentState
  expose commandId commandType actorId actorRole correlationId causationId requestedAt replyTo payload
  s=.table~new; s["commandId"]=commandId; s["commandType"]=commandType; s["actorId"]=actorId; s["actorRole"]=actorRole; s["correlationId"]=correlationId; s["causationId"]=causationId; s["requestedAt"]=requestedAt~utcIsoDate; s["replyTo"]=replyTo; s["payload"]=payload; return s
::method queueRestoreState
  expose commandId commandType actorId actorRole correlationId causationId requestedAt replyTo payload
  use arg s
  commandId=s["commandId"]~string; commandType=.FBExternalCashUtil~token(s["commandType"]); actorId=s["actorId"]~string; actorRole=.FBExternalCashUtil~token(s["actorRole"]); correlationId=s["correlationId"]~string; causationId=s["causationId"]~string; requestedAt=.FBExternalCashUtil~dateValue(s["requestedAt"]); replyTo=s["replyTo"]~string; payload=s["payload"]; return self

::class FederationBankExternalCashServiceReply public
::attribute commandId get
::attribute correlationId get
::attribute ok get
::attribute code get
::attribute detail get
::attribute shipmentId get
::attribute value get
::method init
  expose commandId correlationId ok code detail shipmentId value
  use arg commandIdArg,correlationIdArg,okArg,codeArg,detailArg="",shipmentIdArg="",valueArg=.nil
  commandId=commandIdArg~string; correlationId=correlationIdArg~string; ok=okArg; code=.FBExternalCashUtil~token(codeArg); detail=detailArg~string; shipmentId=shipmentIdArg~string; value=valueArg
::method queuePersistentType
  return "federationbank.external.cash.service.reply/1"
::method queuePersistentState
  expose commandId correlationId ok code detail shipmentId value
  s=.table~new; s["commandId"]=commandId; s["correlationId"]=correlationId; if ok then s["ok"]="1"; else s["ok"]="0"; s["code"]=code; s["detail"]=detail; s["shipmentId"]=shipmentId; s["value"]=value; return s
::method queueRestoreState
  expose commandId correlationId ok code detail shipmentId value
  use arg s
  commandId=s["commandId"]~string; correlationId=s["correlationId"]~string; ok=(s["ok"]~string="1"); code=.FBExternalCashUtil~token(s["code"]); detail=s["detail"]~string; shipmentId=s["shipmentId"]~string; value=s["value"]; return self

::class FederationBankExternalCashServiceReceiptRecord public
::attribute commandId get
::attribute fingerprint get
::attribute shipmentId get
::attribute outcomeCode
::method init
  expose commandId fingerprint shipmentId outcomeCode
  use arg commandIdArg,fingerprintArg,shipmentIdArg,outcomeCodeArg
  commandId=commandIdArg~string; fingerprint=fingerprintArg~string; shipmentId=shipmentIdArg~string; outcomeCode=.FBExternalCashUtil~token(outcomeCodeArg)
::method queuePersistentType
  return "federationbank.external.cash.service.receiptrecord/1"
::method queuePersistentState
  expose commandId fingerprint shipmentId outcomeCode
  s=.table~new; s["commandId"]=commandId; s["fingerprint"]=fingerprint; s["shipmentId"]=shipmentId; s["outcomeCode"]=outcomeCode; return s
::method queueRestoreState
  expose commandId fingerprint shipmentId outcomeCode
  use arg s
  commandId=s["commandId"]~string; fingerprint=s["fingerprint"]~string; shipmentId=s["shipmentId"]~string; outcomeCode=.FBExternalCashUtil~token(s["outcomeCode"]); return self

::class FederationBankExternalCashServiceEvent public
::attribute eventId get
::attribute eventType get
::attribute shipmentId get
::attribute commandId get
::attribute correlationId get
::attribute state get
::attribute code get
::attribute sequence get
::attribute occurredAt get
::method init
  expose eventId eventType shipmentId commandId correlationId state code sequence occurredAt
  use arg eventIdArg,eventTypeArg,shipmentIdArg,commandIdArg,correlationIdArg,stateArg,codeArg,sequenceArg,occurredAtArg=.nil
  eventId=eventIdArg~string; eventType=.FBExternalCashUtil~token(eventTypeArg); shipmentId=shipmentIdArg~string; commandId=commandIdArg~string; correlationId=correlationIdArg~string; state=.FBExternalCashUtil~token(stateArg); code=.FBExternalCashUtil~token(codeArg); sequence=sequenceArg+0; if occurredAtArg==.nil then occurredAt=.DateTime~new; else occurredAt=occurredAtArg
::method queuePersistentType
  return "federationbank.external.cash.service.event/1"
::method queuePersistentState
  expose eventId eventType shipmentId commandId correlationId state code sequence occurredAt
  s=.table~new; s["eventId"]=eventId; s["eventType"]=eventType; s["shipmentId"]=shipmentId; s["commandId"]=commandId; s["correlationId"]=correlationId; s["state"]=state; s["code"]=code; s["sequence"]=sequence~string; s["occurredAt"]=occurredAt~utcIsoDate; return s
::method queueRestoreState
  expose eventId eventType shipmentId commandId correlationId state code sequence occurredAt
  use arg s
  eventId=s["eventId"]~string; eventType=.FBExternalCashUtil~token(s["eventType"]); shipmentId=s["shipmentId"]~string; commandId=s["commandId"]~string; correlationId=s["correlationId"]~string; state=.FBExternalCashUtil~token(s["state"]); code=.FBExternalCashUtil~token(s["code"]); sequence=s["sequence"]+0; occurredAt=.FBExternalCashUtil~dateValue(s["occurredAt"]); return self

::class FederationBankExternalCashServiceWork public
::attribute shipment get
::attribute approval get
::attribute authority get
::attribute receipt
::attribute state
::attribute outcomeCode
::attribute detail
::attribute createdAt get
::attribute updatedAt get
::method init
  expose shipment approval authority receipt state outcomeCode detail createdAt updatedAt
  use arg shipmentArg,approvalArg,authorityArg
  shipment=shipmentArg; approval=approvalArg; authority=authorityArg; receipt=.nil; state="AUTHORISED"; outcomeCode="AUTHORISED"; detail=""; createdAt=.DateTime~new; updatedAt=createdAt
::method shipmentId
  expose shipment
  return shipment~shipmentId
::method touch
  expose updatedAt
  updatedAt=.DateTime~new; return self
::method semanticIdentity
  expose shipment authority state
  return "FBEXTERNALCASHWORK/1|"||shipment~semanticIdentity||"|"||authority~semanticIdentity||"|"||state
::method queuePersistentType
  return "federationbank.external.cash.service.work/1"
::method queuePersistentState
  expose shipment approval authority receipt state outcomeCode detail createdAt updatedAt
  s=.table~new; s["shipment"]=shipment; s["approval"]=approval; s["authority"]=authority; s["receipt"]=receipt; s["state"]=state; s["outcomeCode"]=outcomeCode; s["detail"]=detail; s["createdAt"]=createdAt~utcIsoDate; s["updatedAt"]=updatedAt~utcIsoDate; return s
::method queueRestoreState
  expose shipment approval authority receipt state outcomeCode detail createdAt updatedAt
  use arg s
  shipment=s["shipment"]; approval=s["approval"]; authority=s["authority"]; receipt=s["receipt"]; state=.FBExternalCashUtil~token(s["state"]); outcomeCode=.FBExternalCashUtil~token(s["outcomeCode"]); detail=s["detail"]~string; createdAt=.FBExternalCashUtil~dateValue(s["createdAt"]); updatedAt=.FBExternalCashUtil~dateValue(s["updatedAt"]); return self

::class FederationBankExternalCashVaultPort public
::method releaseOutbound abstract
::method acceptInbound abstract

::class FederationBankExternalCashMemoryVaultPort subclass FederationBankExternalCashVaultPort public
::method init
  expose branchId vaultId currency expectedMinor releases accepts failReleaseFlag failAcceptFlag
  use arg branchIdArg,vaultIdArg,currencyArg,expectedArg
  branchId=branchIdArg~string; vaultId=vaultIdArg~string; currency=.FBExternalCashUtil~token(currencyArg); expectedMinor=expectedArg+0; releases=.directory~new; accepts=.directory~new; failReleaseFlag=.false; failAcceptFlag=.false
::method failNextRelease
  expose failReleaseFlag
  failReleaseFlag=.true; return self
::method failNextAccept
  expose failAcceptFlag
  failAcceptFlag=.true; return self
::method releaseOutbound
  expose branchId vaultId currency expectedMinor releases failReleaseFlag
  use arg shipment,authority
  if authority==.nil | \authority~matchesShipment(shipment) then return .FederationBankExternalCashServiceResult~failure("EXTERNAL_CASH_AUTHORITY_MISMATCH")
  if shipment~direction<>"OUTBOUND" | shipment~branchId<>branchId | shipment~vaultId<>vaultId | shipment~bundle~currency<>currency then return .FederationBankExternalCashServiceResult~failure("VAULT_SCOPE_MISMATCH")
  if releases~hasIndex(shipment~shipmentId) then return .FederationBankExternalCashServiceResult~success(shipment,"IDEMPOTENT_RELEASE")
  if failReleaseFlag then do; failReleaseFlag=.false; return .FederationBankExternalCashServiceResult~failure("VAULT_RELEASE_UNAVAILABLE"); end
  if expectedMinor<shipment~bundle~totalMinor then return .FederationBankExternalCashServiceResult~failure("INSUFFICIENT_VAULT_CASH")
  expectedMinor-=shipment~bundle~totalMinor; releases[shipment~shipmentId]=shipment~semanticIdentity; return .FederationBankExternalCashServiceResult~success(shipment)
::method acceptInbound
  expose branchId vaultId currency expectedMinor accepts failAcceptFlag
  use arg shipment,authority,receipt
  if authority==.nil | \authority~matchesShipment(shipment) then return .FederationBankExternalCashServiceResult~failure("EXTERNAL_CASH_AUTHORITY_MISMATCH")
  if receipt==.nil | \receipt~matchesShipment(shipment) then return .FederationBankExternalCashServiceResult~failure("RECEIPT_MISMATCH")
  if shipment~direction<>"INBOUND" | shipment~branchId<>branchId | shipment~vaultId<>vaultId | shipment~bundle~currency<>currency then return .FederationBankExternalCashServiceResult~failure("VAULT_SCOPE_MISMATCH")
  if accepts~hasIndex(shipment~shipmentId) then return .FederationBankExternalCashServiceResult~success(shipment,"IDEMPOTENT_ACCEPT")
  if failAcceptFlag then do; failAcceptFlag=.false; return .FederationBankExternalCashServiceResult~failure("VAULT_ACCEPT_UNAVAILABLE"); end
  expectedMinor+=shipment~bundle~totalMinor; accepts[shipment~shipmentId]=shipment~semanticIdentity; return .FederationBankExternalCashServiceResult~success(shipment)
::method expectedMinor
  expose expectedMinor
  return expectedMinor
::method releaseCount
  expose releases
  return releases~items
::method acceptCount
  expose accepts
  return accepts~items

::class FederationBankExternalCashServiceState public
::method init
  expose sequence works receipts events outbox
  sequence=0; works=.directory~new; receipts=.directory~new; events=.array~new; outbox=.array~new
::method work
  expose works
  use arg id
  if works~hasIndex(id) then return works[id]
  return .nil
::method putWork
  expose works
  use arg w
  works[w~shipmentId]=w; return w
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
  use arg shipmentId
  sequence+=1; return "FBEXTCASH-EVT-"||sequence||":"||shipmentId
::method sequence
  expose sequence
  return sequence
::method recordEvent
  expose events outbox
  use arg e
  events~append(e); outbox~append(e); return e
::method events
  expose events
  a=.array~new; do e over events; a~append(e); end; return a
::method outbox
  expose outbox
  a=.array~new; do e over outbox; a~append(e); end; return a
::method markDelivered
  expose outbox
  use arg id
  n=.array~new; found=.false; do e over outbox; if e~eventId=id then found=.true; else n~append(e); end; outbox=n; return found
::method queuePersistentType
  return .FederationBankExternalCashServiceBuild~STATE_FORMAT
::method queuePersistentState
  expose sequence works receipts events outbox
  s=.table~new; s["sequence"]=sequence~string; s["works"]=works; s["receipts"]=receipts; s["events"]=events; s["outbox"]=outbox; return s
::method queueRestoreState
  expose sequence works receipts events outbox
  use arg s
  sequence=s["sequence"]+0; works=s["works"]; receipts=s["receipts"]; events=s["events"]; outbox=s["outbox"]; return self

::class FederationBankExternalCashEventSink public
::method publish abstract
::class FederationBankExternalCashMemoryEventSink subclass FederationBankExternalCashEventSink public
::method init
  expose events failFlag
  events=.array~new; failFlag=.false
::method failNext
  expose failFlag
  failFlag=.true; return self
::method publish
  expose events failFlag
  use arg event
  if failFlag then do; failFlag=.false; return .FederationBankExternalCashServiceResult~failure("EVENT_SINK_UNAVAILABLE"); end
  events~append(event); return .FederationBankExternalCashServiceResult~success(event)
::method events
  expose events
  a=.array~new; do e over events; a~append(e); end; return a

::class FederationBankExternalCashService public
::attribute accepting get
::attribute faulted get
::method init
  expose policy vaultPort store sink state accepting faulted
  use arg policyArg,vaultPortArg,storeArg=.nil,sinkArg=.nil
  if policyArg==.nil | vaultPortArg==.nil then raise syntax 88.995 array("external cash policy/vault port required")
  policy=policyArg; vaultPort=vaultPortArg; store=storeArg; if sinkArg==.nil then sink=.FederationBankExternalCashMemoryEventSink~new; else sink=sinkArg; accepting=.true; faulted=.false
  if store==.nil then state=.FederationBankExternalCashServiceState~new
  else do; r=store~load; if r~ok then state=r~value; else do; state=.FederationBankExternalCashServiceState~new; accepting=.false; faulted=.true; end; end
::method state
  expose state
  return state
::method work
  expose state
  use arg id
  return state~work(id)
::method persist private
  expose store state accepting faulted
  if store==.nil then return .FederationBankExternalCashServiceResult~success(state)
  r=store~save(state); if \r~ok then do; accepting=.false; faulted=.true; end; return r
::method emit private
  expose state
  use arg env,w,type,code
  e=.FederationBankExternalCashServiceEvent~new(state~nextEventId(w~shipmentId),type,w~shipmentId,env~commandId,env~correlationId,w~state,code,state~sequence); state~recordEvent(e); return e
::method commit private
  expose state
  use arg env,w,type
  state~putWork(w); state~putReceipt(.FederationBankExternalCashServiceReceiptRecord~new(env~commandId,env~fingerprint,w~shipmentId,w~outcomeCode)); ignore=self~emit(env,w,type,w~outcomeCode); p=self~persist; if \p~ok then return .FederationBankExternalCashServiceReply~new(env~commandId,env~correlationId,.false,p~code,p~detail,w~shipmentId,w); ignore=self~flushOutbox; return .FederationBankExternalCashServiceReply~new(env~commandId,env~correlationId,.true,w~state,w~detail,w~shipmentId,w)
::method replay private
  expose state
  use arg env
  r=state~receipt(env~commandId); if r==.nil then return .nil
  if r~fingerprint<>env~fingerprint then return .FederationBankExternalCashServiceReply~new(env~commandId,env~correlationId,.false,"COMMAND_ID_CONFLICT","same command id different semantics",r~shipmentId,state~work(r~shipmentId))
  return .FederationBankExternalCashServiceReply~new(env~commandId,env~correlationId,.true,"IDEMPOTENT_REPLAY","",r~shipmentId,state~work(r~shipmentId))
::method handle
  expose accepting faulted state policy vaultPort
  use arg env
  if env==.nil then return .FederationBankExternalCashServiceReply~new("","",.false,"COMMAND_REQUIRED")
  if faulted then return .FederationBankExternalCashServiceReply~new(env~commandId,env~correlationId,.false,"SERVICE_FAULTED")
  if \accepting then return .FederationBankExternalCashServiceReply~new(env~commandId,env~correlationId,.false,"SERVICE_QUIESCED")
  old=self~replay(env); if old<>.nil then return old
  select
    when env~commandType="FBEXTCASH.SHIPMENT.SUBMIT" then do
      s=env~payload["shipment"]; a=env~payload["approval"]; if s==.nil | a==.nil then return .FederationBankExternalCashServiceReply~new(env~commandId,env~correlationId,.false,"SHIPMENT_APPROVAL_REQUIRED")
      if state~work(s~shipmentId)<>.nil then return .FederationBankExternalCashServiceReply~new(env~commandId,env~correlationId,.false,"SHIPMENT_ID_CONFLICT","",s~shipmentId,state~work(s~shipmentId))
      ar=.FederationBankExternalCashAuthorityIssuer~new~issue(s,a,policy); if \ar~ok then return .FederationBankExternalCashServiceReply~new(env~commandId,env~correlationId,.false,ar~code,ar~detail,s~shipmentId)
      w=.FederationBankExternalCashServiceWork~new(s,a,ar~value); return self~commit(env,w,"FBEXTCASH.SHIPMENT.AUTHORISED")
    end
    when env~commandType="FBEXTCASH.SHIPMENT.DISPATCH" then do
      id=env~payload["shipmentId"]~string; w=state~work(id); if w==.nil then return .FederationBankExternalCashServiceReply~new(env~commandId,env~correlationId,.false,"SHIPMENT_NOT_FOUND","",id)
      if w~state<>"AUTHORISED" then return .FederationBankExternalCashServiceReply~new(env~commandId,env~correlationId,.false,"SHIPMENT_NOT_AUTHORISED",w~state,id,w)
      d=policy~decide("DISPATCH",w~shipment); if \d~allow then return .FederationBankExternalCashServiceReply~new(env~commandId,env~correlationId,.false,d~code,"",id,w)
      if w~shipment~direction="OUTBOUND" then do; vr=vaultPort~releaseOutbound(w~shipment,w~authority); if \vr~ok then return .FederationBankExternalCashServiceReply~new(env~commandId,env~correlationId,.false,vr~code,vr~detail,id,w); end
      w~state="IN_TRANSIT"; w~outcomeCode="IN_TRANSIT"; w~detail="carrier custody "||w~shipment~carrierId; w~touch; return self~commit(env,w,"FBEXTCASH.SHIPMENT.IN_TRANSIT")
    end
    when env~commandType="FBEXTCASH.SHIPMENT.RECEIVE" then do
      id=env~payload["shipmentId"]~string; rec=env~payload["receipt"]; w=state~work(id); if w==.nil then return .FederationBankExternalCashServiceReply~new(env~commandId,env~correlationId,.false,"SHIPMENT_NOT_FOUND","",id)
      if w~state<>"IN_TRANSIT" then return .FederationBankExternalCashServiceReply~new(env~commandId,env~correlationId,.false,"SHIPMENT_NOT_IN_TRANSIT",w~state,id,w)
      d=policy~decide("RECEIVE",w~shipment); if \d~allow then return .FederationBankExternalCashServiceReply~new(env~commandId,env~correlationId,.false,d~code,"",id,w)
      w~receipt=rec
      if rec==.nil | \rec~matchesShipment(w~shipment) then do; w~state="RECONCILIATION_REQUIRED"; w~outcomeCode="RECEIPT_MISMATCH"; w~detail="external cash receipt does not match manifest/seal/count"; w~touch; return self~commit(env,w,"FBEXTCASH.SHIPMENT.RECONCILIATION_REQUIRED"); end
      if w~shipment~direction="INBOUND" then do
        vr=vaultPort~acceptInbound(w~shipment,w~authority,rec); if \vr~ok then do; w~state="RECONCILIATION_REQUIRED"; w~outcomeCode=vr~code; w~detail=vr~detail; w~touch; return self~commit(env,w,"FBEXTCASH.SHIPMENT.RECONCILIATION_REQUIRED"); end
      end
      w~state="COMPLETED"; w~outcomeCode="COMPLETED"; w~detail=rec~custodyRef; w~touch; return self~commit(env,w,"FBEXTCASH.SHIPMENT.COMPLETED")
    end
    when env~commandType="FBEXTCASH.SHIPMENT.GET" then do
      id=env~payload["shipmentId"]~string; w=state~work(id); if w==.nil then return .FederationBankExternalCashServiceReply~new(env~commandId,env~correlationId,.false,"SHIPMENT_NOT_FOUND","",id)
      return .FederationBankExternalCashServiceReply~new(env~commandId,env~correlationId,.true,"OK","",id,w)
    end
    otherwise return .FederationBankExternalCashServiceReply~new(env~commandId,env~correlationId,.false,"COMMAND_UNSUPPORTED",env~commandType)
  end
::method branchInTransitMinor
  expose state
  use arg branchId,currency
  total=0; ws=state~works; do id over ws; w=ws[id]; if w~shipment~branchId=branchId & w~shipment~bundle~currency=.FBExternalCashUtil~token(currency) then if w~state="IN_TRANSIT" | w~state="RECONCILIATION_REQUIRED" then total+=w~shipment~bundle~totalMinor; end; return total
::method branchOutstandingCount
  expose state
  use arg branchId,currency
  n=0; ws=state~works; do id over ws; w=ws[id]; if w~shipment~branchId=branchId & w~shipment~bundle~currency=.FBExternalCashUtil~token(currency) then if w~state<>"COMPLETED" then n+=1; end; return n
::method completedMinor
  expose state
  use arg branchId,currency,direction,businessDate=""
  total=0; ws=state~works; dir=.FBExternalCashUtil~token(direction); cur=.FBExternalCashUtil~token(currency)
  do id over ws
    w=ws[id]; if w~state="COMPLETED" & w~shipment~branchId=branchId & w~shipment~bundle~currency=cur & w~shipment~direction=dir then do
      if businessDate="" | w~updatedAt~utcIsoDate~left(10)=businessDate then total+=w~shipment~bundle~totalMinor
    end
  end
  return total
::method flushOutbox
  expose state sink
  sent=0; do e over state~outbox; r=sink~publish(e); if \r~ok then return .FederationBankExternalCashServiceResult~failure("EVENT_DELIVERY_PENDING",r~code,sent); ignore=state~markDelivered(e~eventId); sent+=1; end; p=self~persist; if \p~ok then return p; return .FederationBankExternalCashServiceResult~success(sent)
::requires "FederationBankExternalCash.cls"
