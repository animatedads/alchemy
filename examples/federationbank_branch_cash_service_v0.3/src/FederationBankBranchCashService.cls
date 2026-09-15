/* FederationBank Branch Cash Service v0.3
 * Durable orchestration of physical cash between branch custody endpoints.
 * Cash released from one endpoint becomes explicit IN_TRANSIT custody until
 * another endpoint accepts it. No customer-account or Ledger authority here.
 */
::class FederationBankBranchCashServiceBuild public
::constant VERSION "0.3"
::constant API_VERSION "federationbank.branch.cash.service/0.3"
::constant STATE_FORMAT "federationbank.branch.cash.service.state/3"

::class FederationBankBranchCashServiceResult public
::attribute ok get
::attribute code get
::attribute detail get
::attribute value get
::method init
  expose ok code detail value
  use arg okArg,codeArg,detailArg="",valueArg=.nil
  ok=okArg; code=.FBBranchCashUtil~token(codeArg); detail=detailArg~string; value=valueArg
::method success class
  use arg value=.nil,detail=""
  return self~new(.true,"OK",detail,value)
::method failure class
  use arg code,detail="",value=.nil
  return self~new(.false,code,detail,value)

::class FederationBankBranchCashServiceEnvelope public
::attribute commandId get
::attribute commandType get
::attribute actorId get
::attribute actorRole get
::attribute correlationId get
::attribute causationId get
::attribute replyTo get
::method init
  expose commandId commandType actorId actorRole correlationId causationId replyTo payload
  use arg commandIdArg,commandTypeArg,actorIdArg,actorRoleArg,payloadArg=.nil,correlationIdArg="",causationIdArg="",replyToArg=""
  commandId=commandIdArg~string; commandType=.FBBranchCashUtil~token(commandTypeArg); actorId=actorIdArg~string; actorRole=.FBBranchCashUtil~token(actorRoleArg)
  if correlationIdArg="" then correlationId=commandId; else correlationId=correlationIdArg~string
  causationId=causationIdArg~string; replyTo=replyToArg~string; if payloadArg==.nil then payload=.directory~new; else payload=payloadArg
  if commandId="" | commandType="" | actorId="" then raise syntax 88.985 array("service command identity required")
::method payload
  expose payload
  return payload
::method fingerprint
  expose commandType actorId actorRole payload
  text="FB-BRANCH-CASH-SERVICE-COMMAND/1|"||commandType||"|"||actorId||"|"||actorRole
  keys=.array~new; do k over payload; keys~append(k~string); end; keys~sort
  do k over keys
    v=payload[k]
    if v==.nil then value="<NIL>"
    else if v~hasMethod("SEMANTICIDENTITY") then value=v~semanticIdentity
    else if v~hasMethod("TRANSFERIDENTITY") then value=v~transferIdentity
    else value=v~string
    text||="|"||k||"="||value
  end
  return text
::method queuePersistentType
  return "federationbank.branch.cash.service.command/1"
::method queuePersistentState
  expose commandId commandType actorId actorRole correlationId causationId replyTo payload
  s=.table~new; s["commandId"]=commandId; s["commandType"]=commandType; s["actorId"]=actorId; s["actorRole"]=actorRole; s["correlationId"]=correlationId; s["causationId"]=causationId; s["replyTo"]=replyTo; s["payload"]=payload; return s
::method queueRestoreState
  expose commandId commandType actorId actorRole correlationId causationId replyTo payload
  use arg s
  commandId=s["commandId"]~string; commandType=.FBBranchCashUtil~token(s["commandType"]); actorId=s["actorId"]~string; actorRole=.FBBranchCashUtil~token(s["actorRole"]); correlationId=s["correlationId"]~string; causationId=s["causationId"]~string; replyTo=s["replyTo"]~string; payload=s["payload"]; return self

::class FederationBankBranchCashServiceReply public
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
  commandId=commandIdArg~string; correlationId=correlationIdArg~string; ok=okArg; code=.FBBranchCashUtil~token(codeArg); detail=detailArg~string; workId=workIdArg~string; value=valueArg
::method queuePersistentType
  return "federationbank.branch.cash.service.reply/1"
::method queuePersistentState
  expose commandId correlationId ok code detail workId value
  s=.table~new; s["commandId"]=commandId; s["correlationId"]=correlationId; if ok then s["ok"]="1"; else s["ok"]="0"; s["code"]=code; s["detail"]=detail; s["workId"]=workId; s["value"]=value; return s
::method queueRestoreState
  expose commandId correlationId ok code detail workId value
  use arg s
  commandId=s["commandId"]~string; correlationId=s["correlationId"]~string; ok=(s["ok"]~string="1"); code=.FBBranchCashUtil~token(s["code"]); detail=s["detail"]~string; workId=s["workId"]~string; value=s["value"]; return self

::class FederationBankBranchCashServiceReceipt public
::attribute commandId get
::attribute fingerprint get
::attribute workId get
::attribute outcomeCode
::method init
  expose commandId fingerprint workId outcomeCode
  use arg commandIdArg,fingerprintArg,workIdArg,outcomeCodeArg="RECEIVED"
  commandId=commandIdArg~string; fingerprint=fingerprintArg~string; workId=workIdArg~string; outcomeCode=.FBBranchCashUtil~token(outcomeCodeArg)
::method queuePersistentType
  return "federationbank.branch.cash.service.receipt/1"
::method queuePersistentState
  expose commandId fingerprint workId outcomeCode
  s=.table~new; s["commandId"]=commandId; s["fingerprint"]=fingerprint; s["workId"]=workId; s["outcomeCode"]=outcomeCode; return s
::method queueRestoreState
  expose commandId fingerprint workId outcomeCode
  use arg s
  commandId=s["commandId"]~string; fingerprint=s["fingerprint"]~string; workId=s["workId"]~string; outcomeCode=.FBBranchCashUtil~token(s["outcomeCode"]); return self

::class FederationBankBranchCashServiceEvent public
::attribute eventId get
::attribute eventType get
::attribute workId get
::attribute commandId get
::attribute correlationId get
::attribute state get
::attribute detail get
::attribute sequence get
::method init
  expose eventId eventType workId commandId correlationId state detail sequence
  use arg eventIdArg,eventTypeArg,workIdArg,commandIdArg,correlationIdArg,stateArg,detailArg="",sequenceArg=0
  eventId=eventIdArg~string; eventType=.FBBranchCashUtil~token(eventTypeArg); workId=workIdArg~string; commandId=commandIdArg~string; correlationId=correlationIdArg~string; state=.FBBranchCashUtil~token(stateArg); detail=detailArg~string; sequence=sequenceArg+0
::method queuePersistentType
  return "federationbank.branch.cash.service.event/1"
::method queuePersistentState
  expose eventId eventType workId commandId correlationId state detail sequence
  s=.table~new; s["eventId"]=eventId; s["eventType"]=eventType; s["workId"]=workId; s["commandId"]=commandId; s["correlationId"]=correlationId; s["state"]=state; s["detail"]=detail; s["sequence"]=sequence~string; return s
::method queueRestoreState
  expose eventId eventType workId commandId correlationId state detail sequence
  use arg s
  eventId=s["eventId"]~string; eventType=.FBBranchCashUtil~token(s["eventType"]); workId=s["workId"]~string; commandId=s["commandId"]~string; correlationId=s["correlationId"]~string; state=.FBBranchCashUtil~token(s["state"]); detail=s["detail"]~string; sequence=s["sequence"]+0; return self

::class FederationBankBranchCashTransferWork public
::attribute workId get
::attribute commandId get
::attribute correlationId get
::attribute transfer get
::attribute approval get
::attribute authority
::attribute state
::attribute outcomeCode
::attribute detail
::method init
  expose workId commandId correlationId transfer approval authority state outcomeCode detail
  use arg commandIdArg,correlationIdArg,transferArg,approvalArg,authorityArg=.nil
  commandId=commandIdArg~string; correlationId=correlationIdArg~string; transfer=transferArg; approval=approvalArg; authority=authorityArg; workId=transfer~transferId; state="PREPARED"; outcomeCode="RECEIVED"; detail=""
::method queuePersistentType
  return "federationbank.branch.cash.service.work/2"
::method queuePersistentState
  expose workId commandId correlationId transfer approval authority state outcomeCode detail
  s=.table~new; s["workId"]=workId; s["commandId"]=commandId; s["correlationId"]=correlationId; s["transfer"]=transfer; s["approval"]=approval; s["authority"]=authority; s["state"]=state; s["outcomeCode"]=outcomeCode; s["detail"]=detail; return s
::method queueRestoreState
  expose workId commandId correlationId transfer approval authority state outcomeCode detail
  use arg s
  workId=s["workId"]~string; commandId=s["commandId"]~string; correlationId=s["correlationId"]~string; transfer=s["transfer"]; approval=s["approval"]; authority=s["authority"]; state=.FBBranchCashUtil~token(s["state"]); outcomeCode=.FBBranchCashUtil~token(s["outcomeCode"]); detail=s["detail"]~string; return self

::class FederationBankBranchCashEndpointPort public
::method release abstract
::method accept abstract
::method snapshot abstract

::class FederationBankBranchCashMemoryEndpoint subclass FederationBankBranchCashEndpointPort public
::method init
  expose endpointKind endpointId branchId currency expectedMinor released accepted failReleaseFlag failAcceptFlag
  use arg endpointKindArg,endpointIdArg,branchIdArg,currencyArg,expectedMinorArg
  endpointKind=.FBBranchCashUtil~token(endpointKindArg); endpointId=endpointIdArg~string; branchId=branchIdArg~string; currency=.FBBranchCashUtil~token(currencyArg); expectedMinor=expectedMinorArg+0; released=.directory~new; accepted=.directory~new; failReleaseFlag=.false; failAcceptFlag=.false
::method failNextRelease
  expose failReleaseFlag
  failReleaseFlag=.true; return self
::method failNextAccept
  expose failAcceptFlag
  failAcceptFlag=.true; return self
::method release
  expose endpointKind endpointId branchId currency expectedMinor released failReleaseFlag
  use arg transfer,authority=.nil
  if authority==.nil | \authority~isA(.FederationBankBranchCashAuthorityEnvelope) then return .FederationBankBranchCashServiceResult~failure("BRANCH_CASH_AUTHORITY_REQUIRED")
  if \authority~matchesTransfer(transfer) then return .FederationBankBranchCashServiceResult~failure("BRANCH_CASH_AUTHORITY_MISMATCH")
  if failReleaseFlag then do; failReleaseFlag=.false; return .FederationBankBranchCashServiceResult~failure("ENDPOINT_RELEASE_UNAVAILABLE"); end
  if transfer~sourceKind<>endpointKind | transfer~sourceId<>endpointId | transfer~branchId<>branchId | transfer~bundle~currency<>currency then return .FederationBankBranchCashServiceResult~failure("SOURCE_ENDPOINT_MISMATCH")
  if released~hasIndex(transfer~transferId) then do
    if released[transfer~transferId]=transfer~semanticIdentity then return .FederationBankBranchCashServiceResult~success(transfer,"IDEMPOTENT_RELEASE")
    return .FederationBankBranchCashServiceResult~failure("TRANSFER_ID_CONFLICT")
  end
  if expectedMinor<transfer~bundle~totalMinor then return .FederationBankBranchCashServiceResult~failure("INSUFFICIENT_ENDPOINT_CASH")
  expectedMinor-=transfer~bundle~totalMinor; released[transfer~transferId]=transfer~semanticIdentity; return .FederationBankBranchCashServiceResult~success(transfer)
::method accept
  expose endpointKind endpointId branchId currency expectedMinor accepted failAcceptFlag
  use arg transfer,authority=.nil
  if authority==.nil | \authority~isA(.FederationBankBranchCashAuthorityEnvelope) then return .FederationBankBranchCashServiceResult~failure("BRANCH_CASH_AUTHORITY_REQUIRED")
  if \authority~matchesTransfer(transfer) then return .FederationBankBranchCashServiceResult~failure("BRANCH_CASH_AUTHORITY_MISMATCH")
  if failAcceptFlag then do; failAcceptFlag=.false; return .FederationBankBranchCashServiceResult~failure("ENDPOINT_ACCEPT_UNAVAILABLE"); end
  if transfer~destinationKind<>endpointKind | transfer~destinationId<>endpointId | transfer~branchId<>branchId | transfer~bundle~currency<>currency then return .FederationBankBranchCashServiceResult~failure("DESTINATION_ENDPOINT_MISMATCH")
  if accepted~hasIndex(transfer~transferId) then do
    if accepted[transfer~transferId]=transfer~semanticIdentity then return .FederationBankBranchCashServiceResult~success(transfer,"IDEMPOTENT_ACCEPT")
    return .FederationBankBranchCashServiceResult~failure("TRANSFER_ID_CONFLICT")
  end
  expectedMinor+=transfer~bundle~totalMinor; accepted[transfer~transferId]=transfer~semanticIdentity; return .FederationBankBranchCashServiceResult~success(transfer)
::method expectedMinor
  expose expectedMinor
  return expectedMinor
::method releaseCount
  expose released
  return released~items
::method acceptCount
  expose accepted
  return accepted~items
::method snapshot
  expose endpointKind endpointId branchId currency expectedMinor
  return .FederationBankBranchCashEndpointSnapshot~new(endpointKind,endpointId,branchId,currency,expectedMinor,expectedMinor,0)

::class FederationBankBranchCashServiceState public
::method init
  expose sequence vaults works receipts events outbox
  sequence=0; vaults=.directory~new; works=.directory~new; receipts=.directory~new; events=.array~new; outbox=.array~new
::method putVault
  expose vaults
  use arg v
  vaults[v~vaultId]=v; return v
::method vault
  expose vaults
  use arg id
  if vaults~hasIndex(id) then return vaults[id]
  return .nil
::method vaults
  expose vaults
  return .FBBranchCashUtil~copyDir(vaults)
::method putWork
  expose works
  use arg w
  works[w~workId]=w; return w
::method work
  expose works
  use arg id
  if works~hasIndex(id) then return works[id]
  return .nil
::method works
  expose works
  return .FBBranchCashUtil~copyDir(works)
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
  use arg workId
  sequence+=1; return "FBBRANCHCASH-E"||sequence||":"||workId
::method sequence
  expose sequence
  return sequence
::method recordEvent
  expose events outbox
  use arg e
  events~append(e); outbox~append(e); return e
::method outbox
  expose outbox
  return .FBBranchCashUtil~copyArray(outbox)
::method events
  expose events
  return .FBBranchCashUtil~copyArray(events)
::method markDelivered
  expose outbox
  use arg eventId
  kept=.array~new; found=.false
  do e over outbox; if e~eventId=eventId then found=.true; else kept~append(e); end
  outbox=kept; return found
::method queuePersistentType
  return .FederationBankBranchCashServiceBuild~STATE_FORMAT
::method queuePersistentState
  expose sequence vaults works receipts events outbox
  s=.table~new; s["sequence"]=sequence~string; s["vaults"]=vaults; s["works"]=works; s["receipts"]=receipts; s["events"]=events; s["outbox"]=outbox; return s
::method queueRestoreState
  expose sequence vaults works receipts events outbox
  use arg s
  sequence=s["sequence"]+0; vaults=s["vaults"]; works=s["works"]; receipts=s["receipts"]; events=s["events"]; outbox=s["outbox"]; return self

::class FederationBankBranchCashEventSink public
::method publish abstract
::class FederationBankBranchCashMemoryEventSink subclass FederationBankBranchCashEventSink public
::method init
  expose events failNextFlag
  events=.array~new; failNextFlag=.false
::method failNext
  expose failNextFlag
  failNextFlag=.true; return self
::method publish
  expose events failNextFlag
  use arg event
  if failNextFlag then do; failNextFlag=.false; return .FederationBankBranchCashServiceResult~failure("SINK_UNAVAILABLE"); end
  events~append(event); return .FederationBankBranchCashServiceResult~success(event)
::method events
  expose events
  return .FBBranchCashUtil~copyArray(events)

::class FederationBankBranchCashService public
::attribute accepting get
::attribute faulted get
::method init
  expose policy endpointPorts store sink state accepting faulted
  use arg policyArg,endpointPortsArg=.nil,storeArg=.nil,sinkArg=.nil
  if policyArg==.nil then raise syntax 88.986 array("branch cash policy required")
  policy=policyArg; if endpointPortsArg==.nil then endpointPorts=.directory~new; else endpointPorts=endpointPortsArg; store=storeArg; if sinkArg==.nil then sink=.FederationBankBranchCashMemoryEventSink~new; else sink=sinkArg; accepting=.true; faulted=.false
  if store==.nil then state=.FederationBankBranchCashServiceState~new
  else do
    r=store~load; if r~ok then state=r~value; else do; state=.FederationBankBranchCashServiceState~new; accepting=.false; faulted=.true; end
  end
::method state
  expose state
  return state
::method addVault
  expose state
  use arg vault
  state~putVault(vault); return self~persist
::method work
  expose state
  use arg id
  return state~work(id)
::method inTransitMinor
  expose state
  use arg branchId,currency
  total=0; ws=state~works
  do id over ws
    w=ws[id]; if w~transfer~branchId=branchId & w~transfer~bundle~currency=currency then if w~state="IN_TRANSIT" | w~state="RECONCILIATION_REQUIRED" then total+=w~transfer~bundle~totalMinor
  end
  return total
::method branchPosition
  expose state endpointPorts
  use arg branchId,currency
  snaps=.array~new; vs=state~vaults; do id over vs; snaps~append(vs[id]~endpointSnapshot); end
  do id over endpointPorts; snaps~append(endpointPorts[id]~snapshot); end
  return .FederationBankBranchCashPosition~new(branchId,currency,snaps,self~inTransitMinor(branchId,currency))
::method persist private
  expose store state accepting faulted
  if store==.nil then return .FederationBankBranchCashServiceResult~success(state)
  r=store~save(state); if \r~ok then do; accepting=.false; faulted=.true; return r; end
  return r
::method emit private
  expose state
  use arg kind,w,detail=""
  e=.FederationBankBranchCashServiceEvent~new(state~nextEventId(w~workId),kind,w~workId,w~commandId,w~correlationId,w~state,detail,state~sequence); state~recordEvent(e); return e
::method endpointPort private
  expose endpointPorts
  use arg kind,id
  key=.FBBranchCashUtil~token(kind)||":"||id
  if endpointPorts~hasIndex(key) then return endpointPorts[key]
  return .nil
::method authoriseWork private
  expose policy
  use arg w
  if w~authority<>.nil then do
    if \w~authority~matchesTransfer(w~transfer) then return .FederationBankBranchCashServiceResult~failure("BRANCH_CASH_AUTHORITY_MISMATCH")
    return .FederationBankBranchCashServiceResult~success(w~authority,"ALREADY_AUTHORISED")
  end
  r=.FederationBankBranchCashAuthorityIssuer~new~issue(w~transfer,w~approval,policy)
  if \r~ok then return .FederationBankBranchCashServiceResult~failure(r~code,r~detail)
  w~authority=r~value
  return .FederationBankBranchCashServiceResult~success(w~authority)

::method releaseSource private
  expose state policy
  use arg w
  t=w~transfer
  if t~sourceKind="VAULT" then do
    v=state~vault(t~sourceId); if v==.nil then return .FederationBankBranchCashServiceResult~failure("SOURCE_VAULT_NOT_FOUND")
    if w~state="AUTHORISED" then do
      r=v~reserveOut(t,w~approval,policy); if \r~ok then return .FederationBankBranchCashServiceResult~failure(r~code,r~detail)
      w~state="SOURCE_RESERVED"; self~emit("FBBRANCHCASH.SOURCE.RESERVED",w); r=self~persist; if \r~ok then return r
    end
    r=v~commitOut(t); if \r~ok then return .FederationBankBranchCashServiceResult~failure(r~code,r~detail)
    return .FederationBankBranchCashServiceResult~success(t)
  end
  p=self~endpointPort(t~sourceKind,t~sourceId); if p==.nil then return .FederationBankBranchCashServiceResult~failure("SOURCE_ENDPOINT_NOT_FOUND")
  return p~release(t,w~authority)
::method acceptDestination private
  expose state policy
  use arg w
  t=w~transfer
  if t~destinationKind="VAULT" then do
    v=state~vault(t~destinationId); if v==.nil then return .FederationBankBranchCashServiceResult~failure("DESTINATION_VAULT_NOT_FOUND")
    r=v~acceptIn(t,w~approval,policy); if \r~ok then return .FederationBankBranchCashServiceResult~failure(r~code,r~detail)
    return .FederationBankBranchCashServiceResult~success(t)
  end
  p=self~endpointPort(t~destinationKind,t~destinationId); if p==.nil then return .FederationBankBranchCashServiceResult~failure("DESTINATION_ENDPOINT_NOT_FOUND")
  return p~accept(t,w~authority)
::method submit
  expose accepting state
  use arg commandId,correlationId,transfer,approval
  if \accepting then return .FederationBankBranchCashServiceResult~failure("SERVICE_NOT_ACCEPTING")
  fp=transfer~semanticIdentity||"|"||approval~transferIdentity||"|"||approval~approverStaffId
  old=state~receipt(commandId)
  if old<>.nil then do
    if old~fingerprint<>fp then return .FederationBankBranchCashServiceResult~failure("COMMAND_ID_REUSE_CONFLICT")
    return .FederationBankBranchCashServiceResult~success(state~work(old~workId),"IDEMPOTENT_REPLAY")
  end
  if state~work(transfer~transferId)<>.nil then return .FederationBankBranchCashServiceResult~failure("WORK_ID_CONFLICT")
  w=.FederationBankBranchCashTransferWork~new(commandId,correlationId,transfer,approval); state~putWork(w); state~putReceipt(.FederationBankBranchCashServiceReceipt~new(commandId,fp,w~workId)); self~emit("FBBRANCHCASH.TRANSFER.PREPARED",w); r=self~persist; if \r~ok then return r
  return self~continueWork(w)
::method resume
  expose state
  use arg workId
  w=state~work(workId); if w==.nil then return .FederationBankBranchCashServiceResult~failure("WORK_NOT_FOUND")
  if w~state="RECONCILIATION_REQUIRED" then return .FederationBankBranchCashServiceResult~failure("RECONCILIATION_REQUIRED",w~detail,w)
  return self~continueWork(w)
::method resolve
  expose state
  use arg workId,resolution
  w=state~work(workId); if w==.nil then return .FederationBankBranchCashServiceResult~failure("WORK_NOT_FOUND")
  if w~state<>"RECONCILIATION_REQUIRED" then return .FederationBankBranchCashServiceResult~failure("WORK_NOT_RECONCILIATION")
  if .FBBranchCashUtil~token(resolution)<>"RETRY_DESTINATION" then return .FederationBankBranchCashServiceResult~failure("RESOLUTION_NOT_SUPPORTED")
  w~state="IN_TRANSIT"; w~outcomeCode="RETRY_DESTINATION"; self~emit("FBBRANCHCASH.RECONCILIATION.RETRY",w); r=self~persist; if \r~ok then return r; return self~continueWork(w)
::method continueWork private
  expose state
  use arg w
  if w~state="COMPLETED" then return .FederationBankBranchCashServiceResult~success(w,"ALREADY_COMPLETED")
  if w~state="PREPARED" then do
    r=self~authoriseWork(w)
    if \r~ok then do; w~outcomeCode=r~code; w~detail=r~detail; self~emit("FBBRANCHCASH.TRANSFER.AUTHORITY.DENIED",w,r~code); self~persist; return r; end
    w~state="AUTHORISED"; w~outcomeCode="AUTHORISED"; w~detail=w~authority~authorityId; self~emit("FBBRANCHCASH.TRANSFER.AUTHORISED",w,w~detail); r=self~persist; if \r~ok then return r
  end
  if w~state="AUTHORISED" | w~state="SOURCE_RESERVED" then do
    r=self~releaseSource(w)
    if \r~ok then do; w~outcomeCode=r~code; w~detail=r~detail; self~emit("FBBRANCHCASH.SOURCE.RELEASE.FAILED",w,r~code); self~persist; return r; end
    w~state="IN_TRANSIT"; w~outcomeCode="IN_TRANSIT"; w~detail=w~transfer~transitCustodyRef; self~emit("FBBRANCHCASH.CASH.IN_TRANSIT",w,w~detail); r=self~persist; if \r~ok then return r
  end
  if w~state="IN_TRANSIT" then do
    r=self~acceptDestination(w)
    if \r~ok then do
      w~state="RECONCILIATION_REQUIRED"; w~outcomeCode=r~code; w~detail=w~transfer~transitCustodyRef||"|"||r~code||":"||r~detail; self~emit("FBBRANCHCASH.RECONCILIATION.REQUIRED",w,w~detail); self~persist; return .FederationBankBranchCashServiceResult~failure("RECONCILIATION_REQUIRED",w~detail,w)
    end
    w~state="COMPLETED"; w~outcomeCode="COMPLETED"; w~detail=""; self~emit("FBBRANCHCASH.TRANSFER.COMPLETED",w); r=self~persist; if \r~ok then return r; return .FederationBankBranchCashServiceResult~success(w)
  end
  if w~state="RECONCILIATION_REQUIRED" then return .FederationBankBranchCashServiceResult~failure("RECONCILIATION_REQUIRED",w~detail,w)
  return .FederationBankBranchCashServiceResult~failure("INVALID_WORK_STATE",w~state,w)
::method handle
  use arg env
  if env==.nil | \env~isA(.FederationBankBranchCashServiceEnvelope) then return .FederationBankBranchCashServiceReply~new("","",.false,"INVALID_COMMAND")
  p=env~payload
  select
    when env~commandType="FBBRANCHCASH.TRANSFER.SUBMIT" then r=self~submit(env~commandId,env~correlationId,p["transfer"],p["approval"])
    when env~commandType="FBBRANCHCASH.TRANSFER.RESUME" then r=self~resume(p["workId"])
    when env~commandType="FBBRANCHCASH.TRANSFER.RESOLVE" then r=self~resolve(p["workId"],p["resolution"])
    when env~commandType="FBBRANCHCASH.TRANSFER.GET" then do; w=self~work(p["workId"]); if w==.nil then r=.FederationBankBranchCashServiceResult~failure("WORK_NOT_FOUND"); else r=.FederationBankBranchCashServiceResult~success(w); end
    otherwise r=.FederationBankBranchCashServiceResult~failure("COMMAND_TYPE_NOT_SUPPORTED")
  end
  workId=""; if r~value<>.nil then if r~value~hasMethod("WORKID") then workId=r~value~workId
  return .FederationBankBranchCashServiceReply~new(env~commandId,env~correlationId,r~ok,r~code,r~detail,workId,r~value)
::method flushOutbox
  expose state sink
  sent=0
  copy=state~outbox
  do e over copy
    r=sink~publish(e); if \r~ok then return .FederationBankBranchCashServiceResult~failure("EVENT_DELIVERY_FAILED",r~code||":"||r~detail,sent)
    ignore=state~markDelivered(e~eventId); sent+=1; p=self~persist; if \p~ok then return p
  end
  return .FederationBankBranchCashServiceResult~success(sent)

::requires "FederationBankBranchCash.cls"
