/* Durable service boundary around Relationship CRM v0.1. */
::class RelationshipCRMServiceBuild public
::constant VERSION "0.1"
::constant API_VERSION "relationship.crm.service/0.1"
::constant STATE_FORMAT "relationship.crm.service.state/1"
::constant SERVICE_ID "RELATIONSHIP_CRM_SERVICE"

::class RelationshipCRMServiceCanonical public
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
  do item over source; out~append(item); end; return out
::method value class
  use arg value
  if value==.nil then return "N"
  if value~class==.String then return "S"||self~field("V",value)
  if value~class==.Array then do
    text="A"; do i=1 to value~items; text||=self~field("I",self~value(value[i])); end; return text
  end
  classId=value~class~id
  if classId="Table" | classId="Directory" | classId="IdentityTable" then do
    rows=.array~new; supplier=value~supplier
    do while supplier~available
      rows~append(self~field("K",supplier~index~string)||self~field("V",self~value(supplier~item))); supplier~next
    end
    rows~sort; text="M"; do row over rows; text||=self~field("R",row); end; return text
  end
  if value~hasMethod("SEMANTICIDENTITY") then return "O"||self~field("ID",value~semanticIdentity)
  if value~hasMethod("QUEUEPERSISTENTTYPE") then return "P"||self~field("T",value~queuePersistentType)||self~field("S",self~value(value~queuePersistentState))
  return "X"||self~field("C",classId)||self~field("V",value~string)

::class RelationshipCRMServiceResult public
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

::class RelationshipCRMServiceEnvelope public
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
  commandId=commandIdArg~string; commandType=.RelationshipCRMServiceCanonical~token(commandTypeArg); actorId=actorIdArg~string; actorRole=.RelationshipCRMServiceCanonical~token(actorRoleArg)
  if requestedAtArg==.nil then requestedAt=.DateTime~new; else requestedAt=requestedAtArg
  if correlationIdArg="" then correlationId=commandId; else correlationId=correlationIdArg~string
  causationId=causationIdArg~string; replyTo=replyToArg~string
  if payloadArg==.nil then payload=.directory~new; else payload=payloadArg
::method payload; expose payload; return payload
::method fingerprint
  expose commandType actorId actorRole payload
  text="RELATIONSHIP-CRM-SERVICE-COMMAND/1"
  text||=.RelationshipCRMServiceCanonical~field("TYPE",commandType)
  text||=.RelationshipCRMServiceCanonical~field("ACTOR",actorId)
  text||=.RelationshipCRMServiceCanonical~field("ROLE",actorRole)
  text||=.RelationshipCRMServiceCanonical~field("PAYLOAD",.RelationshipCRMServiceCanonical~value(payload))
  return text
::method queuePersistentType; return "relationship.crm.service.command/1"
::method queuePersistentState
  expose commandId commandType correlationId causationId actorId actorRole requestedAt replyTo payload
  s=.table~new; s["commandId"]=commandId; s["commandType"]=commandType; s["correlationId"]=correlationId; s["causationId"]=causationId; s["actorId"]=actorId; s["actorRole"]=actorRole; s["requestedAt"]=requestedAt~string; s["replyTo"]=replyTo; s["payload"]=payload; return s
::method queueRestoreState
  expose commandId commandType correlationId causationId actorId actorRole requestedAt replyTo payload
  use arg s
  commandId=s["commandId"]~string; commandType=s["commandType"]~string; correlationId=s["correlationId"]~string; causationId=s["causationId"]~string; actorId=s["actorId"]~string; actorRole=s["actorRole"]~string; requestedAt=.DateTime~fromIsoDate(s["requestedAt"]~string); replyTo=s["replyTo"]~string; payload=s["payload"]; return self

::class RelationshipCRMServiceReply public
::attribute commandId get
::attribute correlationId get
::attribute ok get
::attribute code get
::attribute detail get
::attribute objectId get
::method init
  expose commandId correlationId ok code detail objectId value
  use arg commandIdArg,correlationIdArg,okArg,codeArg,detailArg="",objectIdArg="",valueArg=.nil
  commandId=commandIdArg~string; correlationId=correlationIdArg~string; ok=okArg; code=codeArg~string; detail=detailArg~string; objectId=objectIdArg~string; value=valueArg
::method value; expose value; return value
::method queuePersistentType; return "relationship.crm.service.reply/1"
::method queuePersistentState
  expose commandId correlationId ok code detail objectId value
  s=.table~new; s["commandId"]=commandId; s["correlationId"]=correlationId; if ok then s["ok"]="1"; else s["ok"]="0"; s["code"]=code; s["detail"]=detail; s["objectId"]=objectId; s["value"]=value; return s
::method queueRestoreState
  expose commandId correlationId ok code detail objectId value
  use arg s
  commandId=s["commandId"]~string; correlationId=s["correlationId"]~string; ok=(s["ok"]~string="1"); code=s["code"]~string; detail=s["detail"]~string; objectId=s["objectId"]~string; value=s["value"]; return self

::class RelationshipCRMServiceEvent public
::attribute eventId get
::attribute eventType get
::attribute relationshipId get
::attribute objectId get
::attribute correlationId get
::attribute causationId get
::attribute actorId get
::attribute actorRole get
::attribute occurredAt get
::attribute policyId get
::attribute policyVersion get
::attribute policyIdentity get
::attribute policyRuleId get
::method init
  expose eventId eventType relationshipId objectId correlationId causationId actorId actorRole occurredAt policyId policyVersion policyIdentity policyRuleId
  use arg eventIdArg,eventTypeArg,relationshipArg,objectIdArg,correlationArg,causationArg,actorIdArg,actorRoleArg,occurredAtArg,policyIdArg="",policyVersionArg="",policyIdentityArg="",policyRuleArg=""
  eventId=eventIdArg~string; eventType=.RelationshipCRMServiceCanonical~token(eventTypeArg); relationshipId=relationshipArg~string; objectId=objectIdArg~string; correlationId=correlationArg~string; causationId=causationArg~string; actorId=actorIdArg~string; actorRole=.RelationshipCRMServiceCanonical~token(actorRoleArg); occurredAt=occurredAtArg; policyId=policyIdArg~string; policyVersion=policyVersionArg~string; policyIdentity=policyIdentityArg~string; policyRuleId=policyRuleArg~string
::method queuePersistentType; return "relationship.crm.service.event/1"
::method queuePersistentState
  expose eventId eventType relationshipId objectId correlationId causationId actorId actorRole occurredAt policyId policyVersion policyIdentity policyRuleId
  s=.table~new; s["eventId"]=eventId; s["eventType"]=eventType; s["relationshipId"]=relationshipId; s["objectId"]=objectId; s["correlationId"]=correlationId; s["causationId"]=causationId; s["actorId"]=actorId; s["actorRole"]=actorRole; s["occurredAt"]=occurredAt~string; s["policyId"]=policyId; s["policyVersion"]=policyVersion; s["policyIdentity"]=policyIdentity; s["policyRuleId"]=policyRuleId; return s
::method queueRestoreState
  expose eventId eventType relationshipId objectId correlationId causationId actorId actorRole occurredAt policyId policyVersion policyIdentity policyRuleId
  use arg s
  eventId=s["eventId"]~string; eventType=s["eventType"]~string; relationshipId=s["relationshipId"]~string; objectId=s["objectId"]~string; correlationId=s["correlationId"]~string; causationId=s["causationId"]~string; actorId=s["actorId"]~string; actorRole=s["actorRole"]~string; occurredAt=.DateTime~fromIsoDate(s["occurredAt"]~string); policyId=s["policyId"]~string; policyVersion=s["policyVersion"]~string; policyIdentity=s["policyIdentity"]~string; policyRuleId=s["policyRuleId"]~string; return self

::class RelationshipCRMServiceReceipt public
::attribute commandId get
::attribute fingerprint get
::attribute commandType get
::attribute relationshipId get
::attribute objectId get
::method init
  expose commandId fingerprint commandType relationshipId objectId
  use arg commandIdArg,fingerprintArg,commandTypeArg,relationshipArg="",objectIdArg=""
  commandId=commandIdArg~string; fingerprint=fingerprintArg~string; commandType=.RelationshipCRMServiceCanonical~token(commandTypeArg); relationshipId=relationshipArg~string; objectId=objectIdArg~string
::method queuePersistentType; return "relationship.crm.service.receipt/1"
::method queuePersistentState
  expose commandId fingerprint commandType relationshipId objectId
  s=.table~new; s["commandId"]=commandId; s["fingerprint"]=fingerprint; s["commandType"]=commandType; s["relationshipId"]=relationshipId; s["objectId"]=objectId; return s
::method queueRestoreState
  expose commandId fingerprint commandType relationshipId objectId
  use arg s
  commandId=s["commandId"]~string; fingerprint=s["fingerprint"]~string; commandType=s["commandType"]~string; relationshipId=s["relationshipId"]~string; objectId=s["objectId"]~string; return self

::class RelationshipCRMServiceState public
::attribute sequence get
::method init
  expose sequence relationships interactions communications promises tasks complaints profiles receipts auditEvents outbox
  sequence=0; relationships=.array~new; interactions=.array~new; communications=.array~new; promises=.array~new; tasks=.array~new; complaints=.array~new; profiles=.array~new; receipts=.table~new; auditEvents=.array~new; outbox=.array~new
::method relationships; expose relationships; return .RelationshipCRMServiceCanonical~copyArray(relationships)
::method interactions; expose interactions; return .RelationshipCRMServiceCanonical~copyArray(interactions)
::method communications; expose communications; return .RelationshipCRMServiceCanonical~copyArray(communications)
::method promises; expose promises; return .RelationshipCRMServiceCanonical~copyArray(promises)
::method tasks; expose tasks; return .RelationshipCRMServiceCanonical~copyArray(tasks)
::method complaints; expose complaints; return .RelationshipCRMServiceCanonical~copyArray(complaints)
::method profiles; expose profiles; return .RelationshipCRMServiceCanonical~copyArray(profiles)
::method addUnique private
  use arg target,obj,idMethod
  id=obj~send(idMethod); do existing over target; if existing~send(idMethod)=id then return existing; end; target~append(obj); return obj
::method addRelationship; expose relationships; use arg o; return self~addUnique(relationships,o,"RELATIONSHIPID")
::method addInteraction; expose interactions; use arg o; return self~addUnique(interactions,o,"INTERACTIONID")
::method addCommunication; expose communications; use arg o; return self~addUnique(communications,o,"COMMUNICATIONID")
::method addPromise; expose promises; use arg o; return self~addUnique(promises,o,"PROMISEID")
::method addTask; expose tasks; use arg o; return self~addUnique(tasks,o,"TASKID")
::method addComplaint; expose complaints; use arg o; return self~addUnique(complaints,o,"COMPLAINTID")
::method addProfile
  expose profiles
  use arg o
  kept=.array~new; do existing over profiles; if existing~relationshipId\=o~relationshipId then kept~append(existing); end; kept~append(o); profiles=kept; return o
::method receipt; expose receipts; use arg id; return receipts[id~string]
::method addReceipt; expose receipts; use arg r; receipts[r~commandId]=r; return r
::method nextEventId
  expose sequence
  use arg relationshipId
  sequence+=1; return "CRM-SVC-EVT-"||sequence||":"||relationshipId
::method recordEvent; expose auditEvents outbox; use arg e; auditEvents~append(e); outbox~append(e); return e
::method auditEvents; expose auditEvents; return .RelationshipCRMServiceCanonical~copyArray(auditEvents)
::method outbox; expose outbox; return .RelationshipCRMServiceCanonical~copyArray(outbox)
::method markDelivered
  expose outbox
  use arg eventId
  kept=.array~new; found=.false; do e over outbox; if e~eventId=eventId~string then found=.true; else kept~append(e); end; outbox=kept; return found
::method queuePersistentType; return .RelationshipCRMServiceBuild~STATE_FORMAT
::method queuePersistentState
  expose sequence relationships interactions communications promises tasks complaints profiles receipts auditEvents outbox
  s=.table~new; s["sequence"]=sequence~string; s["relationships"]=relationships; s["interactions"]=interactions; s["communications"]=communications; s["promises"]=promises; s["tasks"]=tasks; s["complaints"]=complaints; s["profiles"]=profiles; s["receipts"]=receipts; s["auditEvents"]=auditEvents; s["outbox"]=outbox; return s
::method queueRestoreState
  expose sequence relationships interactions communications promises tasks complaints profiles receipts auditEvents outbox
  use arg s
  sequence=s["sequence"]+0; relationships=s["relationships"]; interactions=s["interactions"]; communications=s["communications"]; promises=s["promises"]; tasks=s["tasks"]; complaints=s["complaints"]; profiles=s["profiles"]; receipts=s["receipts"]; auditEvents=s["auditEvents"]; outbox=s["outbox"]; return self

::class RelationshipCRMEventSink public
::method publish abstract
::class RelationshipCRMMemoryEventSink subclass RelationshipCRMEventSink public
::method init; expose events failNext; events=.array~new; failNext=.false
::method failNext; expose failNext; failNext=.true; return self
::method publish
  expose events failNext
  use arg e
  if failNext then do; failNext=.false; return .RelationshipCRMServiceResult~failure("SINK_UNAVAILABLE"); end
  events~append(e); return .RelationshipCRMServiceResult~success(e)
::method events; expose events; return .RelationshipCRMServiceCanonical~copyArray(events)

::class RelationshipCRMService public
::attribute accepting get
::attribute faulted get
::method init
  expose state store sink repository engine accepting faulted
  use arg policyCatalog,policyId=.nil,storeArg=.nil,sinkArg=.nil
  store=storeArg; if sinkArg==.nil then sink=.RelationshipCRMMemoryEventSink~new; else sink=sinkArg
  accepting=.true; faulted=.false
  if store==.nil then state=.RelationshipCRMServiceState~new
  else do
    loaded=store~load
    if loaded~ok then state=loaded~value; else do; state=.RelationshipCRMServiceState~new; accepting=.false; faulted=.true; end
  end
  repository=.RelationshipCRMRepository~new
  do o over state~relationships; ignore=repository~addRelationship(o); end
  do o over state~interactions; repository~putInteraction(o); end
  do o over state~communications; repository~putCommunication(o); end
  do o over state~promises; repository~putPromise(o); end
  do o over state~tasks; repository~putTask(o); end
  do o over state~complaints; repository~putComplaint(o); end
  do o over state~profiles; repository~putProfile(o); end
  engine=.RelationshipCRMEngine~new(policyCatalog,policyId,repository)
::method state; expose state; return state
::method repository; expose repository; return repository
::method eventSink; expose sink; return sink
::method quiesce; expose accepting; accepting=.false; return self~flushOutbox
::method resume; expose accepting faulted; if faulted then return .RelationshipCRMServiceResult~failure("SERVICE_FAULTED"); accepting=.true; return .RelationshipCRMServiceResult~success(self)
::method isMutation private
  use arg t
  return t\="CRM.PROJECT" & t\="CRM.FOR_SUBJECT"
::method payloadValue private
  use arg payload,key,defaultValue=""
  if payload==.nil then return defaultValue
  if payload~hasIndex(key) then return payload[key]
  return defaultValue
::method objectId private
  use arg o
  if o==.nil then return ""
  names=.array~of("RELATIONSHIPID","INTERACTIONID","COMMUNICATIONID","PROMISEID","TASKID","COMPLAINTID","PROFILEID")
  do name over names; if o~hasMethod(name) then return o~send(name); end
  return ""
::method relationshipId private
  use arg o
  if o==.nil then return ""
  if o~hasMethod("RELATIONSHIPID") then return o~relationshipId
  return ""
::method reply private
  use arg env,ok,code,detail="",value=.nil
  return .RelationshipCRMServiceReply~new(env~commandId,env~correlationId,ok,code,detail,self~objectId(value),value)
::method handle
  expose accepting faulted state engine repository
  use arg env
  if env==.nil then return .RelationshipCRMServiceReply~new("","",.false,"COMMAND_REQUIRED")
  if env~commandId="" | env~commandType="" | env~actorId="" | env~actorRole="" then return self~reply(env,.false,"COMMAND_INVALID")
  if faulted then return self~reply(env,.false,"SERVICE_FAULTED")
  if \accepting then return self~reply(env,.false,"SERVICE_QUIESCED")
  t=env~commandType
  if self~isMutation(t) then do
    prior=state~receipt(env~commandId)
    if prior<>.nil then do
      if prior~fingerprint\=env~fingerprint then return self~reply(env,.false,"COMMAND_ID_CONFLICT","same commandId with different command semantics")
      if prior~relationshipId\="" then do; rr=repository~relationship(prior~relationshipId); if rr~ok then return self~reply(env,.true,"IDEMPOTENT_REPLAY","original mutation already committed",rr~value); end
      return self~reply(env,.true,"IDEMPOTENT_REPLAY","original mutation already committed")
    end
  end
  p=env~payload
  select
    when t="CRM.RELATIONSHIP.OPEN" then result=engine~openRelationship(self~payloadValue(p,"relationship",.nil),env~actorId,env~actorRole,env~requestedAt)
    when t="CRM.INTERACTION.RECORD" then result=engine~recordInteraction(self~payloadValue(p,"interaction",.nil),env~actorId,env~actorRole,env~requestedAt)
    when t="CRM.COMMUNICATION.RECORD" then result=engine~recordCommunication(self~payloadValue(p,"communication",.nil),env~actorId,env~actorRole,env~requestedAt)
    when t="CRM.COMMUNICATION.TRANSITION" then result=engine~transitionCommunication(self~payloadValue(p,"communicationId"),self~payloadValue(p,"action"),env~actorId,env~actorRole,env~requestedAt)
    when t="CRM.PROMISE.RECORD" then result=engine~recordPromise(self~payloadValue(p,"promise",.nil),env~actorId,env~actorRole,env~requestedAt)
    when t="CRM.PROMISE.TRANSITION" then result=engine~transitionPromise(self~payloadValue(p,"promiseId"),self~payloadValue(p,"action"),env~actorId,env~actorRole,env~requestedAt)
    when t="CRM.TASK.CREATE" then result=engine~createTask(self~payloadValue(p,"task",.nil),env~actorId,env~actorRole,env~requestedAt)
    when t="CRM.TASK.TRANSITION" then result=engine~transitionTask(self~payloadValue(p,"taskId"),self~payloadValue(p,"action"),env~actorId,env~actorRole,env~requestedAt)
    when t="CRM.COMPLAINT.RECOGNISE" then result=engine~recogniseComplaint(self~payloadValue(p,"complaint",.nil),env~actorId,env~actorRole,env~requestedAt)
    when t="CRM.COMPLAINT.LINK_CASE" then result=engine~linkComplaintCase(self~payloadValue(p,"complaintId"),self~payloadValue(p,"caseRef"),env~actorId,env~actorRole,env~requestedAt)
    when t="CRM.COMPLAINT.TRANSITION" then result=engine~transitionComplaint(self~payloadValue(p,"complaintId"),self~payloadValue(p,"action"),env~actorId,env~actorRole,env~requestedAt)
    when t="CRM.PROFILE.SET" then result=engine~setServiceProfile(self~payloadValue(p,"profile",.nil),env~actorId,env~actorRole,env~requestedAt)
    when t="CRM.PROJECT" then return self~handleProject(env)
    when t="CRM.FOR_SUBJECT" then return self~handleForSubject(env)
    otherwise return self~reply(env,.false,"COMMAND_UNSUPPORTED",t)
  end
  if \result~ok then return self~reply(env,.false,result~code,result~detail,result~value)
  committed=self~commitMutation(env,result~value)
  if \committed~ok then return self~reply(env,.false,committed~code,committed~detail,result~value)
  return self~reply(env,.true,"OK",committed~detail,result~value)
::method syncState private
  expose state
  use arg value
  if value==.nil then return
  select
    when value~isA(.RelationshipRecord) then state~addRelationship(value)
    when value~isA(.RelationshipInteractionRef) then state~addInteraction(value)
    when value~isA(.RelationshipCommunication) then state~addCommunication(value)
    when value~isA(.RelationshipPromise) then state~addPromise(value)
    when value~isA(.RelationshipTask) then state~addTask(value)
    when value~isA(.ComplaintRecord) then state~addComplaint(value)
    when value~isA(.RelationshipServiceProfile) then state~addProfile(value)
    otherwise nop
  end
::method latestDomainEvent private
  expose repository
  use arg relationshipId
  rr=repository~relationship(relationshipId); if \rr~ok then return .nil
  evs=rr~value~events; if evs~items=0 then return .nil
  return evs[evs~items]
::method commitMutation private
  expose state store faulted accepting sink repository
  use arg env,value
  self~syncState(value)
  relId=self~relationshipId(value)
  if relId="" & value<>.nil & value~isA(.RelationshipRecord) then relId=value~relationshipId
  domain=self~latestDomainEvent(relId)
  policyId=""; policyVersion=""; policyIdentity=""; policyRule=""; eventType=env~commandType
  if domain<>.nil then do
    eventType=domain~eventType
    if domain~policyEvidence<>.nil then do; policyId=domain~policyEvidence~policyId; policyVersion=domain~policyEvidence~policyVersion; policyIdentity=domain~policyEvidence~policyIdentity; policyRule=domain~policyEvidence~ruleId; end
  end
  e=.RelationshipCRMServiceEvent~new(state~nextEventId(relId),eventType,relId,self~objectId(value),env~correlationId,env~causationId,env~actorId,env~actorRole,env~requestedAt,policyId,policyVersion,policyIdentity,policyRule)
  state~addReceipt(.RelationshipCRMServiceReceipt~new(env~commandId,env~fingerprint,env~commandType,relId,self~objectId(value)))
  state~recordEvent(e)
  if store<>.nil then do
    saved=store~save(state)
    if \saved~ok then do; faulted=.true; accepting=.false; return saved; end
  end
  published=sink~publish(e)
  if \published~ok then return .RelationshipCRMServiceResult~success(value,"committed; event pending")
  ignore=state~markDelivered(e~eventId)
  if store<>.nil then do
    saved=store~save(state)
    if \saved~ok then do; faulted=.true; accepting=.false; return saved; end
  end
  return .RelationshipCRMServiceResult~success(value,"committed and event published")
::method flushOutbox
  expose state sink store faulted accepting
  do e over state~outbox
    pub=sink~publish(e); if \pub~ok then return pub
    ignore=state~markDelivered(e~eventId)
    if store<>.nil then do; saved=store~save(state); if \saved~ok then do; faulted=.true; accepting=.false; return saved; end; end
  end
  return .RelationshipCRMServiceResult~success(state)
::method handleProject private
  expose engine
  use arg env
  p=env~payload; rr=engine~project(self~payloadValue(p,"relationshipId"),env~actorRole,env~requestedAt)
  if \rr~ok then return self~reply(env,.false,rr~code,rr~detail)
  return self~reply(env,.true,"OK","",rr~value)
::method handleForSubject private
  expose repository engine
  use arg env
  p=env~payload; rr=repository~forSubject(self~payloadValue(p,"subjectSystem"),self~payloadValue(p,"subjectRef"))
  if \rr~ok then return self~reply(env,.false,rr~code,rr~detail)
  pr=engine~project(rr~value~relationshipId,env~actorRole,env~requestedAt); if \pr~ok then return self~reply(env,.false,pr~code,pr~detail)
  return self~reply(env,.true,"OK","",pr~value)

::requires "RelationshipCRM.cls"
