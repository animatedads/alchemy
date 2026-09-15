/* VectorMeridianInstitutionalCloseoutQueue.cls -- bilateral valuation-dispute
 * and finalization notice boundary v0.9 over Queue Fabric.
 */

::class VMMInstitutionalCloseoutQueueBuild public
::method protocol class; return "vmm.institutional.synthetic.closeout/0.9"
::method instructionQueue class; return "VMM.INSTITUTIONAL.SYNTHETIC.CLOSEOUT.INSTRUCTION"
::method noticeQueue class; return "VMM.INSTITUTIONAL.SYNTHETIC.CLOSEOUT.NOTICE"
::method resultQueue class; return "VMM.INSTITUTIONAL.SYNTHETIC.CLOSEOUT.RESULT"
::method securityDomain class; return "VMM_INSTITUTIONAL_SYNTHETIC_CLOSEOUT"
::method vmmPrincipal class; return "VECTOR_MERIDIAN_SYNTHETIC_CLOSEOUT"
::method adminPrincipal class; return "VECTOR_MERIDIAN_SYNTHETIC_ADMIN"

::class VMMInstitutionalCloseoutDisputeInstruction public
::method init
  expose requestId idempotencyKey correlationId disputeId closeoutId contractId counterpartyId sourceEntity sourceAuthority proposedGrossAmountToVMM disputedDate disputeEvidenceRef
  use arg requestId="",idempotencyKey="",correlationId="",disputeId="",closeoutId="",contractId="",counterpartyId="",sourceEntity="",sourceAuthority="",proposedGrossAmountToVMM=0,disputedDate="",disputeEvidenceRef=""
  if requestId="" & correlationId="" then return
  if requestId="" | idempotencyKey="" | correlationId="" | disputeId="" | closeoutId="" | contractId="" | counterpartyId="" | sourceEntity="" | sourceAuthority="" | disputedDate="" | disputeEvidenceRef="" then raise syntax 88.900 array("invalid institutional close-out dispute instruction")
::method requestId; expose requestId; return requestId
::method idempotencyKey; expose idempotencyKey; return idempotencyKey
::method correlationId; expose correlationId; return correlationId
::method disputeId; expose disputeId; return disputeId
::method closeoutId; expose closeoutId; return closeoutId
::method contractId; expose contractId; return contractId
::method counterpartyId; expose counterpartyId; return counterpartyId
::method sourceEntity; expose sourceEntity; return sourceEntity
::method sourceAuthority; expose sourceAuthority; return sourceAuthority
::method proposedGrossAmountToVMM; expose proposedGrossAmountToVMM; return proposedGrossAmountToVMM
::method disputedDate; expose disputedDate; return disputedDate
::method disputeEvidenceRef; expose disputeEvidenceRef; return disputeEvidenceRef
::method queuePersistentType; return "vmm.synthetic.closeout.dispute-instruction/1"
::method queuePersistentState
  expose requestId idempotencyKey correlationId disputeId closeoutId contractId counterpartyId sourceEntity sourceAuthority proposedGrossAmountToVMM disputedDate disputeEvidenceRef
  d=.table~new; d["requestId"]=requestId; d["idempotencyKey"]=idempotencyKey; d["correlationId"]=correlationId; d["disputeId"]=disputeId; d["closeoutId"]=closeoutId; d["contractId"]=contractId; d["counterpartyId"]=counterpartyId; d["sourceEntity"]=sourceEntity; d["sourceAuthority"]=sourceAuthority; d["proposedGrossAmountToVMM"]=proposedGrossAmountToVMM; d["disputedDate"]=disputedDate; d["disputeEvidenceRef"]=disputeEvidenceRef; return d
::method queueRestoreState
  expose requestId idempotencyKey correlationId disputeId closeoutId contractId counterpartyId sourceEntity sourceAuthority proposedGrossAmountToVMM disputedDate disputeEvidenceRef
  use arg d
  requestId=d["requestId"]; idempotencyKey=d["idempotencyKey"]; correlationId=d["correlationId"]; disputeId=d["disputeId"]; closeoutId=d["closeoutId"]; contractId=d["contractId"]; counterpartyId=d["counterpartyId"]; sourceEntity=d["sourceEntity"]; sourceAuthority=d["sourceAuthority"]; proposedGrossAmountToVMM=d["proposedGrossAmountToVMM"]; disputedDate=d["disputedDate"]; disputeEvidenceRef=d["disputeEvidenceRef"]; return .true
::class VMMInstitutionalCloseoutDisputeInstructionFactory public
::method newBlank; return .VMMInstitutionalCloseoutDisputeInstruction~new

::class VMMInstitutionalCloseoutFinalizationMessage public
::method init
  expose noticeId correlationId finalizationId closeoutId contractId counterpartyId currency grossAmountToVMM netAmountToVMM basis sourceRef vmmEntity publishedDate
  use arg noticeId="",correlationId="",finalizationId="",closeoutId="",contractId="",counterpartyId="",currency="",grossAmountToVMM=0,netAmountToVMM=0,basis="",sourceRef="",vmmEntity="",publishedDate=""
  if noticeId="" & correlationId="" then return
  if noticeId="" | correlationId="" | finalizationId="" | closeoutId="" | contractId="" | counterpartyId="" | currency="" | basis="" | sourceRef="" | vmmEntity<>"VECTOR_MERIDIAN_MARKETS_LTD" | publishedDate="" then raise syntax 88.900 array("invalid institutional close-out finalization message")
::method noticeId; expose noticeId; return noticeId
::method correlationId; expose correlationId; return correlationId
::method finalizationId; expose finalizationId; return finalizationId
::method closeoutId; expose closeoutId; return closeoutId
::method contractId; expose contractId; return contractId
::method counterpartyId; expose counterpartyId; return counterpartyId
::method currency; expose currency; return currency
::method grossAmountToVMM; expose grossAmountToVMM; return grossAmountToVMM
::method netAmountToVMM; expose netAmountToVMM; return netAmountToVMM
::method basis; expose basis; return basis
::method sourceRef; expose sourceRef; return sourceRef
::method vmmEntity; expose vmmEntity; return vmmEntity
::method publishedDate; expose publishedDate; return publishedDate
::method queuePersistentType; return "vmm.synthetic.closeout.finalization-notice/1"
::method queuePersistentState
  expose noticeId correlationId finalizationId closeoutId contractId counterpartyId currency grossAmountToVMM netAmountToVMM basis sourceRef vmmEntity publishedDate
  d=.table~new; d["noticeId"]=noticeId; d["correlationId"]=correlationId; d["finalizationId"]=finalizationId; d["closeoutId"]=closeoutId; d["contractId"]=contractId; d["counterpartyId"]=counterpartyId; d["currency"]=currency; d["grossAmountToVMM"]=grossAmountToVMM; d["netAmountToVMM"]=netAmountToVMM; d["basis"]=basis; d["sourceRef"]=sourceRef; d["vmmEntity"]=vmmEntity; d["publishedDate"]=publishedDate; return d
::method queueRestoreState
  expose noticeId correlationId finalizationId closeoutId contractId counterpartyId currency grossAmountToVMM netAmountToVMM basis sourceRef vmmEntity publishedDate
  use arg d
  noticeId=d["noticeId"]; correlationId=d["correlationId"]; finalizationId=d["finalizationId"]; closeoutId=d["closeoutId"]; contractId=d["contractId"]; counterpartyId=d["counterpartyId"]; currency=d["currency"]; grossAmountToVMM=d["grossAmountToVMM"]; netAmountToVMM=d["netAmountToVMM"]; basis=d["basis"]; sourceRef=d["sourceRef"]; vmmEntity=d["vmmEntity"]; publishedDate=d["publishedDate"]; return .true
::class VMMInstitutionalCloseoutFinalizationMessageFactory public
::method newBlank; return .VMMInstitutionalCloseoutFinalizationMessage~new

::class VMMInstitutionalCloseoutResult public
::method init
  expose resultId requestId correlationId contractId closeoutId status referenceId processedDate vmmEntity
  use arg resultId="",requestId="",correlationId="",contractId="",closeoutId="",status="",referenceId="",processedDate="",vmmEntity=""
  if resultId="" & correlationId="" then return
  if resultId="" | requestId="" | correlationId="" | contractId="" | closeoutId="" | status="" | referenceId="" | processedDate="" | vmmEntity<>"VECTOR_MERIDIAN_MARKETS_LTD" then raise syntax 88.900 array("invalid institutional close-out result")
::method resultId; expose resultId; return resultId
::method requestId; expose requestId; return requestId
::method correlationId; expose correlationId; return correlationId
::method contractId; expose contractId; return contractId
::method closeoutId; expose closeoutId; return closeoutId
::method status; expose status; return status
::method referenceId; expose referenceId; return referenceId
::method processedDate; expose processedDate; return processedDate
::method vmmEntity; expose vmmEntity; return vmmEntity
::method queuePersistentType; return "vmm.synthetic.closeout.result/1"
::method queuePersistentState
  expose resultId requestId correlationId contractId closeoutId status referenceId processedDate vmmEntity
  d=.table~new; d["resultId"]=resultId; d["requestId"]=requestId; d["correlationId"]=correlationId; d["contractId"]=contractId; d["closeoutId"]=closeoutId; d["status"]=status; d["referenceId"]=referenceId; d["processedDate"]=processedDate; d["vmmEntity"]=vmmEntity; return d
::method queueRestoreState
  expose resultId requestId correlationId contractId closeoutId status referenceId processedDate vmmEntity
  use arg d
  resultId=d["resultId"]; requestId=d["requestId"]; correlationId=d["correlationId"]; contractId=d["contractId"]; closeoutId=d["closeoutId"]; status=d["status"]; referenceId=d["referenceId"]; processedDate=d["processedDate"]; vmmEntity=d["vmmEntity"]; return .true
::class VMMInstitutionalCloseoutResultFactory public
::method newBlank; return .VMMInstitutionalCloseoutResult~new

::class VMMInstitutionalCloseoutQueueService public
::method init
  expose operationsService manager adminPrincipal clientPrincipal vmmPrincipal clientEntity counterpartyId processedByKey noticesPublished
  use strict arg operationsService,stateRoot,clientPrincipal,clientEntity,counterpartyId,adminPrincipal="VECTOR_MERIDIAN_SYNTHETIC_ADMIN",vmmPrincipal="VECTOR_MERIDIAN_SYNTHETIC_CLOSEOUT"
  if operationsService==.nil | \operationsService~isA(.VMMCloseoutOperationsService) | stateRoot="" | clientPrincipal="" | clientEntity="" | counterpartyId="" then raise syntax 88.900 array("institutional close-out queue service requires operations service, durable root and client identity")
  cp=operationsService~productService~counterparty(counterpartyId); if cp==.nil | cp~legalEntity<>clientEntity then raise syntax 88.900 array("institutional close-out queue client/counterparty identity mismatch")
  registry=.QueuePayloadTypeRegistry~new
  ignore=registry~register("vmm.synthetic.closeout.dispute-instruction/1",.VMMInstitutionalCloseoutDisputeInstructionFactory~new)
  ignore=registry~register("vmm.synthetic.closeout.finalization-notice/1",.VMMInstitutionalCloseoutFinalizationMessageFactory~new)
  ignore=registry~register("vmm.synthetic.closeout.result/1",.VMMInstitutionalCloseoutResultFactory~new)
  manager=.ObjectQueueManager~new(stateRoot,.QueueGraphPayloadCodec~new(registry),adminPrincipal)
  processedByKey=.directory~new; noticesPublished=.directory~new
  self~ensureQueues
::method manager; expose manager; return manager
::method processNextInstruction
  expose operationsService manager vmmPrincipal clientEntity counterpartyId processedByKey
  use strict arg processedDate
  claim=manager~claim(.VMMInstitutionalCloseoutQueueBuild~instructionQueue,vmmPrincipal); if \claim~ok then return claim
  package=claim~value; msg=package~payload
  if msg==.nil | \msg~isA(.VMMInstitutionalCloseoutDisputeInstruction) then return self~reject(package,"INVALID_CLOSEOUT_INSTRUCTION")
  if msg~sourceEntity<>clientEntity | msg~counterpartyId<>counterpartyId then return self~reject(package,"INSTITUTIONAL_IDENTITY_MISMATCH")
  prior=processedByKey[msg~idempotencyKey]
  if prior<>.nil then do
    pub=self~put(.VMMInstitutionalCloseoutQueueBuild~resultQueue,prior,msg~correlationId,"RESULT",msg~idempotencyKey,vmmPrincipal); if \pub~ok then return self~retry(package,pub)
    ignore=self~ack(package); return .QueueOperationResult~success(prior,"idempotent institutional close-out instruction")
  end
  c=operationsService~defaultService~closeout(msg~closeoutId); if c==.nil | c~contractId<>msg~contractId then return self~reject(package,"CLOSEOUT_IDENTITY_MISMATCH")
  k=operationsService~productService~contract(msg~contractId); if k==.nil | k~counterpartyId<>counterpartyId then return self~reject(package,"CLOSEOUT_COUNTERPARTY_MISMATCH")
  d=operationsService~disputeCloseout(msg~disputeId,msg~closeoutId,msg~sourceEntity,msg~proposedGrossAmountToVMM,msg~disputedDate,msg~disputeEvidenceRef,msg~sourceAuthority)
  result=.VMMInstitutionalCloseoutResult~new("RESULT-"||msg~requestId,msg~requestId,msg~correlationId,msg~contractId,msg~closeoutId,"DISPUTE_OPEN",d~disputeId,processedDate,.VMMCloseoutOperationsBuild~legalEntity)
  pub=self~put(.VMMInstitutionalCloseoutQueueBuild~resultQueue,result,msg~correlationId,"RESULT",msg~idempotencyKey,vmmPrincipal); if \pub~ok then return self~retry(package,pub)
  processedByKey[msg~idempotencyKey]=result; ignore=self~ack(package)
  return .QueueOperationResult~success(result,"institutional close-out dispute processed")
::method publishFinalization
  expose operationsService noticesPublished vmmPrincipal counterpartyId
  use strict arg finalizationId,publishedDate
  f=operationsService~finalization(finalizationId); if f==.nil then raise syntax 88.900 array("unknown VMM close-out finalization",finalizationId)
  k=operationsService~productService~contract(f~contractId); if k==.nil | k~counterpartyId<>counterpartyId then raise syntax 88.900 array("finalization counterparty mismatch",finalizationId)
  prior=noticesPublished[finalizationId]; if prior<>.nil then return .QueueOperationResult~success(prior,"idempotent close-out finalization publication")
  msg=.VMMInstitutionalCloseoutFinalizationMessage~new("NOTICE-"||finalizationId,f~closeoutId,finalizationId,f~closeoutId,f~contractId,counterpartyId,f~currency,f~grossAmountToVMM,f~netAmountToVMM,f~basis,f~sourceRef,.VMMCloseoutOperationsBuild~legalEntity,publishedDate)
  r=self~put(.VMMInstitutionalCloseoutQueueBuild~noticeQueue,msg,f~closeoutId,"FINALIZATION",finalizationId,vmmPrincipal); if r~ok then noticesPublished[finalizationId]=msg; return r
::method ensureQueues private
  expose manager adminPrincipal clientPrincipal vmmPrincipal
  domain=.VMMInstitutionalCloseoutQueueBuild~securityDomain
  do q over .array~of(.VMMInstitutionalCloseoutQueueBuild~instructionQueue,.VMMInstitutionalCloseoutQueueBuild~noticeQueue,.VMMInstitutionalCloseoutQueueBuild~resultQueue)
    if manager~queue(q)==.nil then self~must(manager~createQueue(q,"PERMANENT",domain,0,adminPrincipal),"create "||q)
  end
  self~must(manager~grant(.VMMInstitutionalCloseoutQueueBuild~instructionQueue,clientPrincipal,.QueueAccess~PUT,adminPrincipal),"client instruction PUT")
  self~must(manager~grant(.VMMInstitutionalCloseoutQueueBuild~instructionQueue,vmmPrincipal,.QueueAccess~GET,adminPrincipal),"VMM instruction GET")
  self~must(manager~grant(.VMMInstitutionalCloseoutQueueBuild~noticeQueue,vmmPrincipal,.QueueAccess~PUT,adminPrincipal),"VMM notice PUT")
  self~must(manager~grant(.VMMInstitutionalCloseoutQueueBuild~noticeQueue,clientPrincipal,.QueueAccess~GET,adminPrincipal),"client notice GET")
  self~must(manager~grant(.VMMInstitutionalCloseoutQueueBuild~resultQueue,vmmPrincipal,.QueueAccess~PUT,adminPrincipal),"VMM result PUT")
  self~must(manager~grant(.VMMInstitutionalCloseoutQueueBuild~resultQueue,clientPrincipal,.QueueAccess~GET,adminPrincipal),"client result GET")
::method put private
  expose manager
  use strict arg queueName,payload,correlationId,kind,idempotencyKey,principal
  o=.table~new; o["persistent"]=.true; o["correlationId"]=correlationId; h=.table~new; h["protocol"]=.VMMInstitutionalCloseoutQueueBuild~protocol; h["kind"]=kind; h["idempotencyKey"]=idempotencyKey; o["headers"]=h
  return manager~put(queueName,payload,o,principal)
::method ack private
  expose manager vmmPrincipal
  use strict arg package
  return manager~ack(.VMMInstitutionalCloseoutQueueBuild~instructionQueue,package~packageId,package~claimToken,vmmPrincipal)
::method reject private
  expose manager vmmPrincipal
  use strict arg package,code
  ignore=manager~nack(.VMMInstitutionalCloseoutQueueBuild~instructionQueue,package~packageId,package~claimToken,vmmPrincipal); return .QueueOperationResult~failure(code)
::method retry private
  expose manager vmmPrincipal
  use strict arg package,failure
  ignore=manager~nack(.VMMInstitutionalCloseoutQueueBuild~instructionQueue,package~packageId,package~claimToken,vmmPrincipal); return failure
::method must private
  use strict arg result,label
  if \result~ok then raise syntax 88.900 array("institutional close-out Queue Fabric setup failed",label,result~code,result~detail)
  return result

::class VMMInstitutionalCloseoutQueueClient public
::method init
  expose manager clientPrincipal clientEntity counterpartyId submitted
  use strict arg manager,clientPrincipal,clientEntity,counterpartyId
  if manager==.nil | clientPrincipal="" | clientEntity="" | counterpartyId="" then raise syntax 88.900 array("institutional close-out client requires manager and legal identity")
  submitted=.directory~new
::method submitDispute
  expose manager clientPrincipal clientEntity counterpartyId submitted
  use strict arg msg
  if \msg~isA(.VMMInstitutionalCloseoutDisputeInstruction) then raise syntax 88.900 array("close-out dispute instruction required")
  if msg~sourceEntity<>clientEntity | msg~counterpartyId<>counterpartyId then raise syntax 88.900 array("institutional close-out client identity mismatch")
  prior=submitted[msg~idempotencyKey]; if prior<>.nil then return .QueueOperationResult~success(prior,"idempotent close-out client submission")
  r=self~put(.VMMInstitutionalCloseoutQueueBuild~instructionQueue,msg,msg~correlationId,"DISPUTE",msg~idempotencyKey); if r~ok then submitted[msg~idempotencyKey]=msg; return r
::method receiveNotice
  expose manager clientPrincipal
  return self~receive(.VMMInstitutionalCloseoutQueueBuild~noticeQueue,clientPrincipal)
::method receiveResult
  expose manager clientPrincipal
  return self~receive(.VMMInstitutionalCloseoutQueueBuild~resultQueue,clientPrincipal)
::method receive private
  expose manager
  use strict arg queueName,principal
  r=manager~claim(queueName,principal); if \r~ok then return r
  p=r~value; payload=p~payload; a=manager~ack(queueName,p~packageId,p~claimToken,principal); if \a~ok then return a; return .QueueOperationResult~success(payload,"institutional close-out message received")
::method put private
  expose manager clientPrincipal
  use strict arg queueName,payload,correlationId,kind,idempotencyKey
  o=.table~new; o["persistent"]=.true; o["correlationId"]=correlationId; h=.table~new; h["protocol"]=.VMMInstitutionalCloseoutQueueBuild~protocol; h["kind"]=kind; h["idempotencyKey"]=idempotencyKey; o["headers"]=h
  return manager~put(queueName,payload,o,clientPrincipal)

::requires "VMMCloseoutOperations.cls"
::requires "ObjectQueueFabric.cls"
