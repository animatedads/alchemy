/* VectorMeridianInstitutionalDefaultQueue.cls -- bilateral institutional
 * default/cure/termination boundary v0.8 over Queue Fabric.
 */

::class VMMInstitutionalDefaultQueueBuild public
::method protocol class; return "vmm.institutional.synthetic.default/0.8"
::method instructionQueue class; return "VMM.INSTITUTIONAL.SYNTHETIC.DEFAULT.INSTRUCTION"
::method noticeQueue class; return "VMM.INSTITUTIONAL.SYNTHETIC.DEFAULT.NOTICE"
::method resultQueue class; return "VMM.INSTITUTIONAL.SYNTHETIC.DEFAULT.RESULT"
::method securityDomain class; return "VMM_INSTITUTIONAL_SYNTHETIC_DEFAULT"
::method vmmPrincipal class; return "VECTOR_MERIDIAN_SYNTHETIC_DEFAULT"
::method adminPrincipal class; return "VECTOR_MERIDIAN_SYNTHETIC_ADMIN"

::class VMMInstitutionalDefaultCureInstruction public
::method init
  expose requestId idempotencyKey correlationId eventId cureId contractId counterpartyId sourceEntity sourceAuthority curedDate cureEvidenceRef
  use arg requestId="",idempotencyKey="",correlationId="",eventId="",cureId="",contractId="",counterpartyId="",sourceEntity="",sourceAuthority="",curedDate="",cureEvidenceRef=""
  if requestId="" & correlationId="" then return
  if requestId="" | idempotencyKey="" | correlationId="" | eventId="" | cureId="" | contractId="" | counterpartyId="" | sourceEntity="" | sourceAuthority="" | curedDate="" | cureEvidenceRef="" then raise syntax 88.900 array("invalid institutional default cure instruction")
::method requestId; expose requestId; return requestId
::method idempotencyKey; expose idempotencyKey; return idempotencyKey
::method correlationId; expose correlationId; return correlationId
::method eventId; expose eventId; return eventId
::method cureId; expose cureId; return cureId
::method contractId; expose contractId; return contractId
::method counterpartyId; expose counterpartyId; return counterpartyId
::method sourceEntity; expose sourceEntity; return sourceEntity
::method sourceAuthority; expose sourceAuthority; return sourceAuthority
::method curedDate; expose curedDate; return curedDate
::method cureEvidenceRef; expose cureEvidenceRef; return cureEvidenceRef
::method queuePersistentType; return "vmm.synthetic.default.cure-instruction/1"
::method queuePersistentState
  expose requestId idempotencyKey correlationId eventId cureId contractId counterpartyId sourceEntity sourceAuthority curedDate cureEvidenceRef
  d=.table~new; d["requestId"]=requestId; d["idempotencyKey"]=idempotencyKey; d["correlationId"]=correlationId; d["eventId"]=eventId; d["cureId"]=cureId; d["contractId"]=contractId; d["counterpartyId"]=counterpartyId; d["sourceEntity"]=sourceEntity; d["sourceAuthority"]=sourceAuthority; d["curedDate"]=curedDate; d["cureEvidenceRef"]=cureEvidenceRef; return d
::method queueRestoreState
  expose requestId idempotencyKey correlationId eventId cureId contractId counterpartyId sourceEntity sourceAuthority curedDate cureEvidenceRef
  use arg d
  requestId=d["requestId"]; idempotencyKey=d["idempotencyKey"]; correlationId=d["correlationId"]; eventId=d["eventId"]; cureId=d["cureId"]; contractId=d["contractId"]; counterpartyId=d["counterpartyId"]; sourceEntity=d["sourceEntity"]; sourceAuthority=d["sourceAuthority"]; curedDate=d["curedDate"]; cureEvidenceRef=d["cureEvidenceRef"]; return .true
::class VMMInstitutionalDefaultCureInstructionFactory public
::method newBlank; return .VMMInstitutionalDefaultCureInstruction~new

::class VMMInstitutionalTerminationElectionInstruction public
::method init
  expose requestId idempotencyKey correlationId eventId terminationId contractId counterpartyId sourceEntity sourceAuthority terminationDate terminationNoticeRef valuationAgentRef
  use arg requestId="",idempotencyKey="",correlationId="",eventId="",terminationId="",contractId="",counterpartyId="",sourceEntity="",sourceAuthority="",terminationDate="",terminationNoticeRef="",valuationAgentRef=""
  if requestId="" & correlationId="" then return
  if requestId="" | idempotencyKey="" | correlationId="" | eventId="" | terminationId="" | contractId="" | counterpartyId="" | sourceEntity="" | sourceAuthority="" | terminationDate="" | terminationNoticeRef="" | valuationAgentRef="" then raise syntax 88.900 array("invalid institutional termination election instruction")
::method requestId; expose requestId; return requestId
::method idempotencyKey; expose idempotencyKey; return idempotencyKey
::method correlationId; expose correlationId; return correlationId
::method eventId; expose eventId; return eventId
::method terminationId; expose terminationId; return terminationId
::method contractId; expose contractId; return contractId
::method counterpartyId; expose counterpartyId; return counterpartyId
::method sourceEntity; expose sourceEntity; return sourceEntity
::method sourceAuthority; expose sourceAuthority; return sourceAuthority
::method terminationDate; expose terminationDate; return terminationDate
::method terminationNoticeRef; expose terminationNoticeRef; return terminationNoticeRef
::method valuationAgentRef; expose valuationAgentRef; return valuationAgentRef
::method queuePersistentType; return "vmm.synthetic.default.termination-election/1"
::method queuePersistentState
  expose requestId idempotencyKey correlationId eventId terminationId contractId counterpartyId sourceEntity sourceAuthority terminationDate terminationNoticeRef valuationAgentRef
  d=.table~new; d["requestId"]=requestId; d["idempotencyKey"]=idempotencyKey; d["correlationId"]=correlationId; d["eventId"]=eventId; d["terminationId"]=terminationId; d["contractId"]=contractId; d["counterpartyId"]=counterpartyId; d["sourceEntity"]=sourceEntity; d["sourceAuthority"]=sourceAuthority; d["terminationDate"]=terminationDate; d["terminationNoticeRef"]=terminationNoticeRef; d["valuationAgentRef"]=valuationAgentRef; return d
::method queueRestoreState
  expose requestId idempotencyKey correlationId eventId terminationId contractId counterpartyId sourceEntity sourceAuthority terminationDate terminationNoticeRef valuationAgentRef
  use arg d
  requestId=d["requestId"]; idempotencyKey=d["idempotencyKey"]; correlationId=d["correlationId"]; eventId=d["eventId"]; terminationId=d["terminationId"]; contractId=d["contractId"]; counterpartyId=d["counterpartyId"]; sourceEntity=d["sourceEntity"]; sourceAuthority=d["sourceAuthority"]; terminationDate=d["terminationDate"]; terminationNoticeRef=d["terminationNoticeRef"]; valuationAgentRef=d["valuationAgentRef"]; return .true
::class VMMInstitutionalTerminationElectionInstructionFactory public
::method newBlank; return .VMMInstitutionalTerminationElectionInstruction~new

::class VMMInstitutionalDefaultNoticeMessage public
::method init
  expose noticeId correlationId eventId contractId counterpartyId defaultType defaultingEntity nonDefaultingEntity noticeDate cureDeadline defaultEvidenceRef vmmEntity publishedDate
  use arg noticeId="",correlationId="",eventId="",contractId="",counterpartyId="",defaultType="",defaultingEntity="",nonDefaultingEntity="",noticeDate="",cureDeadline="",defaultEvidenceRef="",vmmEntity="",publishedDate=""
  if noticeId="" & correlationId="" then return
  if noticeId="" | correlationId="" | eventId="" | contractId="" | counterpartyId="" | defaultType="" | defaultingEntity="" | nonDefaultingEntity="" | noticeDate="" | cureDeadline="" | defaultEvidenceRef="" | vmmEntity<>"VECTOR_MERIDIAN_MARKETS_LTD" | publishedDate="" then raise syntax 88.900 array("invalid institutional default notice message")
::method noticeId; expose noticeId; return noticeId
::method correlationId; expose correlationId; return correlationId
::method eventId; expose eventId; return eventId
::method contractId; expose contractId; return contractId
::method counterpartyId; expose counterpartyId; return counterpartyId
::method defaultType; expose defaultType; return defaultType
::method defaultingEntity; expose defaultingEntity; return defaultingEntity
::method nonDefaultingEntity; expose nonDefaultingEntity; return nonDefaultingEntity
::method noticeDate; expose noticeDate; return noticeDate
::method cureDeadline; expose cureDeadline; return cureDeadline
::method defaultEvidenceRef; expose defaultEvidenceRef; return defaultEvidenceRef
::method vmmEntity; expose vmmEntity; return vmmEntity
::method publishedDate; expose publishedDate; return publishedDate
::method queuePersistentType; return "vmm.synthetic.default.notice/1"
::method queuePersistentState
  expose noticeId correlationId eventId contractId counterpartyId defaultType defaultingEntity nonDefaultingEntity noticeDate cureDeadline defaultEvidenceRef vmmEntity publishedDate
  d=.table~new; d["noticeId"]=noticeId; d["correlationId"]=correlationId; d["eventId"]=eventId; d["contractId"]=contractId; d["counterpartyId"]=counterpartyId; d["defaultType"]=defaultType; d["defaultingEntity"]=defaultingEntity; d["nonDefaultingEntity"]=nonDefaultingEntity; d["noticeDate"]=noticeDate; d["cureDeadline"]=cureDeadline; d["defaultEvidenceRef"]=defaultEvidenceRef; d["vmmEntity"]=vmmEntity; d["publishedDate"]=publishedDate; return d
::method queueRestoreState
  expose noticeId correlationId eventId contractId counterpartyId defaultType defaultingEntity nonDefaultingEntity noticeDate cureDeadline defaultEvidenceRef vmmEntity publishedDate
  use arg d
  noticeId=d["noticeId"]; correlationId=d["correlationId"]; eventId=d["eventId"]; contractId=d["contractId"]; counterpartyId=d["counterpartyId"]; defaultType=d["defaultType"]; defaultingEntity=d["defaultingEntity"]; nonDefaultingEntity=d["nonDefaultingEntity"]; noticeDate=d["noticeDate"]; cureDeadline=d["cureDeadline"]; defaultEvidenceRef=d["defaultEvidenceRef"]; vmmEntity=d["vmmEntity"]; publishedDate=d["publishedDate"]; return .true
::class VMMInstitutionalDefaultNoticeMessageFactory public
::method newBlank; return .VMMInstitutionalDefaultNoticeMessage~new

::class VMMInstitutionalDefaultResult public
::method init
  expose resultId requestId correlationId actionType contractId eventId status referenceId processedDate vmmEntity
  use arg resultId="",requestId="",correlationId="",actionType="",contractId="",eventId="",status="",referenceId="",processedDate="",vmmEntity=""
  if resultId="" & correlationId="" then return
  if resultId="" | requestId="" | correlationId="" | actionType="" | contractId="" | eventId="" | status="" | referenceId="" | processedDate="" | vmmEntity<>"VECTOR_MERIDIAN_MARKETS_LTD" then raise syntax 88.900 array("invalid institutional default result")
::method resultId; expose resultId; return resultId
::method requestId; expose requestId; return requestId
::method correlationId; expose correlationId; return correlationId
::method actionType; expose actionType; return actionType
::method contractId; expose contractId; return contractId
::method eventId; expose eventId; return eventId
::method status; expose status; return status
::method referenceId; expose referenceId; return referenceId
::method processedDate; expose processedDate; return processedDate
::method vmmEntity; expose vmmEntity; return vmmEntity
::method queuePersistentType; return "vmm.synthetic.default.result/1"
::method queuePersistentState
  expose resultId requestId correlationId actionType contractId eventId status referenceId processedDate vmmEntity
  d=.table~new; d["resultId"]=resultId; d["requestId"]=requestId; d["correlationId"]=correlationId; d["actionType"]=actionType; d["contractId"]=contractId; d["eventId"]=eventId; d["status"]=status; d["referenceId"]=referenceId; d["processedDate"]=processedDate; d["vmmEntity"]=vmmEntity; return d
::method queueRestoreState
  expose resultId requestId correlationId actionType contractId eventId status referenceId processedDate vmmEntity
  use arg d
  resultId=d["resultId"]; requestId=d["requestId"]; correlationId=d["correlationId"]; actionType=d["actionType"]; contractId=d["contractId"]; eventId=d["eventId"]; status=d["status"]; referenceId=d["referenceId"]; processedDate=d["processedDate"]; vmmEntity=d["vmmEntity"]; return .true
::class VMMInstitutionalDefaultResultFactory public
::method newBlank; return .VMMInstitutionalDefaultResult~new

::class VMMInstitutionalDefaultQueueService public
::method init
  expose defaultService manager adminPrincipal clientPrincipal vmmPrincipal clientEntity counterpartyId processedByKey noticesPublished
  use strict arg defaultService,stateRoot,clientPrincipal,clientEntity,counterpartyId,adminPrincipal="VECTOR_MERIDIAN_SYNTHETIC_ADMIN",vmmPrincipal="VECTOR_MERIDIAN_SYNTHETIC_DEFAULT"
  if defaultService==.nil | \defaultService~isA(.VMMInstitutionalDefaultCloseoutService) | stateRoot="" | clientPrincipal="" | clientEntity="" | counterpartyId="" then raise syntax 88.900 array("institutional default queue service requires default service, durable root and client identity")
  registry=.QueuePayloadTypeRegistry~new
  ignore=registry~register("vmm.synthetic.default.cure-instruction/1",.VMMInstitutionalDefaultCureInstructionFactory~new)
  ignore=registry~register("vmm.synthetic.default.termination-election/1",.VMMInstitutionalTerminationElectionInstructionFactory~new)
  ignore=registry~register("vmm.synthetic.default.notice/1",.VMMInstitutionalDefaultNoticeMessageFactory~new)
  ignore=registry~register("vmm.synthetic.default.result/1",.VMMInstitutionalDefaultResultFactory~new)
  manager=.ObjectQueueManager~new(stateRoot,.QueueGraphPayloadCodec~new(registry),adminPrincipal)
  processedByKey=.directory~new; noticesPublished=.directory~new
  self~ensureQueues
::method manager; expose manager; return manager
::method publishDefaultNotice
  expose defaultService noticesPublished vmmPrincipal counterpartyId
  use strict arg eventId,publishedDate
  d=defaultService~defaultEvent(eventId); if d==.nil then raise syntax 88.900 array("unknown default event",eventId)
  k=defaultService~productService~contract(d~contractId); if k==.nil | k~counterpartyId<>counterpartyId then raise syntax 88.900 array("default notice counterparty mismatch",eventId)
  prior=noticesPublished[eventId]; if prior<>.nil then return .QueueOperationResult~success(prior,"idempotent default notice publication")
  msg=.VMMInstitutionalDefaultNoticeMessage~new("NOTICE-"||eventId,d~contractId,eventId,d~contractId,k~counterpartyId,d~defaultType,d~defaultingEntity,d~nonDefaultingEntity,d~noticeDate,d~cureDeadline,d~defaultEvidenceRef,.VMMDefaultCloseoutBuild~legalEntity,publishedDate)
  r=self~put(.VMMInstitutionalDefaultQueueBuild~noticeQueue,msg,d~contractId,"NOTICE",eventId,vmmPrincipal)
  if r~ok then noticesPublished[eventId]=msg
  return r
::method processNextInstruction
  expose defaultService manager vmmPrincipal clientEntity counterpartyId processedByKey
  use strict arg processedDate
  claim=manager~claim(.VMMInstitutionalDefaultQueueBuild~instructionQueue,vmmPrincipal); if \claim~ok then return claim
  package=claim~value; msg=package~payload
  if msg==.nil then return self~reject(package,"INVALID_DEFAULT_INSTRUCTION")
  if \msg~isA(.VMMInstitutionalDefaultCureInstruction) & \msg~isA(.VMMInstitutionalTerminationElectionInstruction) then return self~reject(package,"INVALID_DEFAULT_INSTRUCTION")
  if msg~sourceEntity<>clientEntity | msg~counterpartyId<>counterpartyId then return self~reject(package,"INSTITUTIONAL_IDENTITY_MISMATCH")
  prior=processedByKey[msg~idempotencyKey]
  if prior<>.nil then do
    pub=self~put(.VMMInstitutionalDefaultQueueBuild~resultQueue,prior,msg~correlationId,"RESULT",msg~idempotencyKey,vmmPrincipal); if \pub~ok then return self~retry(package,pub)
    ignore=self~ack(package); return .QueueOperationResult~success(prior,"idempotent institutional default instruction")
  end
  d=defaultService~defaultEvent(msg~eventId); if d==.nil | d~contractId<>msg~contractId then return self~reject(package,"DEFAULT_EVENT_MISMATCH")
  if msg~isA(.VMMInstitutionalDefaultCureInstruction) then do
    if d~defaultingEntity<>clientEntity then return self~reject(package,"CLIENT_NOT_DEFAULTING_PARTY")
    c=defaultService~cureDefault(msg~cureId,msg~eventId,msg~sourceEntity,msg~curedDate,msg~cureEvidenceRef,msg~sourceAuthority)
    result=.VMMInstitutionalDefaultResult~new("RESULT-"||msg~requestId,msg~requestId,msg~correlationId,"CURE",msg~contractId,msg~eventId,"CURED",c~cureId,processedDate,.VMMDefaultCloseoutBuild~legalEntity)
  end
  else do
    if d~defaultingEntity<>.VMMDefaultCloseoutBuild~legalEntity | d~nonDefaultingEntity<>clientEntity then return self~reject(package,"CLIENT_NOT_TERMINATION_ELECTOR")
    t=defaultService~electTermination(msg~terminationId,msg~eventId,msg~sourceEntity,msg~terminationDate,msg~terminationNoticeRef,msg~valuationAgentRef,msg~sourceAuthority)
    result=.VMMInstitutionalDefaultResult~new("RESULT-"||msg~requestId,msg~requestId,msg~correlationId,"TERMINATION_ELECTION",msg~contractId,msg~eventId,"TERMINATED",t~terminationId,processedDate,.VMMDefaultCloseoutBuild~legalEntity)
  end
  pub=self~put(.VMMInstitutionalDefaultQueueBuild~resultQueue,result,msg~correlationId,"RESULT",msg~idempotencyKey,vmmPrincipal); if \pub~ok then return self~retry(package,pub)
  processedByKey[msg~idempotencyKey]=result; ignore=self~ack(package)
  return .QueueOperationResult~success(result,"institutional default instruction processed")
::method ensureQueues private
  expose manager adminPrincipal clientPrincipal vmmPrincipal
  domain=.VMMInstitutionalDefaultQueueBuild~securityDomain
  do q over .array~of(.VMMInstitutionalDefaultQueueBuild~instructionQueue,.VMMInstitutionalDefaultQueueBuild~noticeQueue,.VMMInstitutionalDefaultQueueBuild~resultQueue)
    if manager~queue(q)==.nil then self~must(manager~createQueue(q,"PERMANENT",domain,0,adminPrincipal),"create "||q)
  end
  self~must(manager~grant(.VMMInstitutionalDefaultQueueBuild~instructionQueue,clientPrincipal,.QueueAccess~PUT,adminPrincipal),"client instruction PUT")
  self~must(manager~grant(.VMMInstitutionalDefaultQueueBuild~instructionQueue,vmmPrincipal,.QueueAccess~GET,adminPrincipal),"VMM instruction GET")
  self~must(manager~grant(.VMMInstitutionalDefaultQueueBuild~noticeQueue,vmmPrincipal,.QueueAccess~PUT,adminPrincipal),"VMM notice PUT")
  self~must(manager~grant(.VMMInstitutionalDefaultQueueBuild~noticeQueue,clientPrincipal,.QueueAccess~GET,adminPrincipal),"client notice GET")
  self~must(manager~grant(.VMMInstitutionalDefaultQueueBuild~resultQueue,vmmPrincipal,.QueueAccess~PUT,adminPrincipal),"VMM result PUT")
  self~must(manager~grant(.VMMInstitutionalDefaultQueueBuild~resultQueue,clientPrincipal,.QueueAccess~GET,adminPrincipal),"client result GET")
::method put private
  expose manager
  use strict arg queueName,payload,correlationId,kind,idempotencyKey,principal
  o=.table~new; o["persistent"]=.true; o["correlationId"]=correlationId; h=.table~new; h["protocol"]=.VMMInstitutionalDefaultQueueBuild~protocol; h["kind"]=kind; h["idempotencyKey"]=idempotencyKey; o["headers"]=h
  return manager~put(queueName,payload,o,principal)
::method ack private
  expose manager vmmPrincipal
  use strict arg package
  return manager~ack(.VMMInstitutionalDefaultQueueBuild~instructionQueue,package~packageId,package~claimToken,vmmPrincipal)
::method reject private
  expose manager vmmPrincipal
  use strict arg package,code
  ignore=manager~nack(.VMMInstitutionalDefaultQueueBuild~instructionQueue,package~packageId,package~claimToken,vmmPrincipal); return .QueueOperationResult~failure(code)
::method retry private
  expose manager vmmPrincipal
  use strict arg package,failure
  ignore=manager~nack(.VMMInstitutionalDefaultQueueBuild~instructionQueue,package~packageId,package~claimToken,vmmPrincipal); return failure
::method must private
  use strict arg result,label
  if \result~ok then raise syntax 88.900 array("institutional default Queue Fabric setup failed",label,result~code,result~detail)
  return result

::class VMMInstitutionalDefaultQueueClient public
::method init
  expose manager clientPrincipal clientEntity counterpartyId submitted
  use strict arg manager,clientPrincipal,clientEntity,counterpartyId
  if manager==.nil | clientPrincipal="" | clientEntity="" | counterpartyId="" then raise syntax 88.900 array("institutional default client requires manager and legal identity")
  submitted=.directory~new
::method submitInstruction
  expose manager clientPrincipal clientEntity counterpartyId submitted
  use strict arg msg
  if \msg~isA(.VMMInstitutionalDefaultCureInstruction) & \msg~isA(.VMMInstitutionalTerminationElectionInstruction) then raise syntax 88.900 array("default instruction required")
  if msg~sourceEntity<>clientEntity | msg~counterpartyId<>counterpartyId then raise syntax 88.900 array("institutional default client identity mismatch")
  prior=submitted[msg~idempotencyKey]; if prior<>.nil then return .QueueOperationResult~success(prior,"idempotent default client submission")
  r=self~put(.VMMInstitutionalDefaultQueueBuild~instructionQueue,msg,msg~correlationId,"INSTRUCTION",msg~idempotencyKey); if r~ok then submitted[msg~idempotencyKey]=msg; return r
::method receiveNotice
  expose manager clientPrincipal
  return self~receive(.VMMInstitutionalDefaultQueueBuild~noticeQueue,clientPrincipal)
::method receiveResult
  expose manager clientPrincipal
  return self~receive(.VMMInstitutionalDefaultQueueBuild~resultQueue,clientPrincipal)
::method receive private
  expose manager
  use strict arg queueName,principal
  r=manager~claim(queueName,principal); if \r~ok then return r
  p=r~value; payload=p~payload; a=manager~ack(queueName,p~packageId,p~claimToken,principal); if \a~ok then return a; return .QueueOperationResult~success(payload,"institutional default message received")
::method put private
  expose manager clientPrincipal
  use strict arg queueName,payload,correlationId,kind,idempotencyKey
  o=.table~new; o["persistent"]=.true; o["correlationId"]=correlationId; h=.table~new; h["protocol"]=.VMMInstitutionalDefaultQueueBuild~protocol; h["kind"]=kind; h["idempotencyKey"]=idempotencyKey; o["headers"]=h
  return manager~put(queueName,payload,o,clientPrincipal)

::requires "VMMDefaultCloseout.cls"
::requires "ObjectQueueFabric.cls"
