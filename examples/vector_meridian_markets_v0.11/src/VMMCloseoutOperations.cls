/* VMMCloseoutOperations.cls -- post-termination close-out operations v0.9.
 *
 * Adds dispute/fallback valuation, explicit finalization, evidence-bound
 * master-agreement netting sets and segregated initial-margin custody return.
 * The v0.8 legal determination is never mutated. A v0.9 finalization either
 * adopts it after the dispute window or supersedes its amount through a
 * separately evidenced dispute resolution.
 */

::class VMMCloseoutOperationsBuild public
::method version class; return "0.9"
::method protocol class; return "vmm.institutional.synthetic.closeout/0.9"
::method legalEntity class; return "VECTOR_MERIDIAN_MARKETS_LTD"

::class VMMCloseoutOperationsPolicy public
::method init
  expose policyId currency disputeWindowDays collateralReturnDays fallbackValuationAgentRef legalOpinionPolicyRef policyRef
  use strict arg policyId,currency,disputeWindowDays,collateralReturnDays,fallbackValuationAgentRef,legalOpinionPolicyRef,policyRef
  numeric digits 50
  if policyId="" | currency="" | fallbackValuationAgentRef="" | legalOpinionPolicyRef="" | policyRef="" then raise syntax 88.900 array("invalid VMM close-out operations policy")
  if \datatype(disputeWindowDays~string,"W") | disputeWindowDays<0 | \datatype(collateralReturnDays~string,"W") | collateralReturnDays<0 then raise syntax 88.900 array("invalid VMM close-out operations day limits")
::method policyId; expose policyId; return policyId
::method currency; expose currency; return currency
::method disputeWindowDays; expose disputeWindowDays; return disputeWindowDays
::method collateralReturnDays; expose collateralReturnDays; return collateralReturnDays
::method fallbackValuationAgentRef; expose fallbackValuationAgentRef; return fallbackValuationAgentRef
::method legalOpinionPolicyRef; expose legalOpinionPolicyRef; return legalOpinionPolicyRef
::method policyRef; expose policyRef; return policyRef

::class VMMCloseoutValuationDispute public
::method init
  expose disputeId closeoutId contractId disputingEntity originalGrossAmountToVMM proposedGrossAmountToVMM disputedDate disputeEvidenceRef authorityRef state resolutionId
  use strict arg disputeId,closeoutId,contractId,disputingEntity,originalGrossAmountToVMM,proposedGrossAmountToVMM,disputedDate,disputeEvidenceRef,authorityRef
  numeric digits 50
  if disputeId="" | closeoutId="" | contractId="" | disputingEntity="" | disputeEvidenceRef="" | authorityRef="" then raise syntax 88.900 array("invalid VMM close-out valuation dispute")
  ignore=.VMMDefaultDateUtil~requireIsoDate(disputedDate,"disputedDate")
  if originalGrossAmountToVMM=proposedGrossAmountToVMM then raise syntax 88.900 array("close-out dispute must identify a different proposed amount")
  state="OPEN"; resolutionId=""
::method disputeId; expose disputeId; return disputeId
::method closeoutId; expose closeoutId; return closeoutId
::method contractId; expose contractId; return contractId
::method disputingEntity; expose disputingEntity; return disputingEntity
::method originalGrossAmountToVMM; expose originalGrossAmountToVMM; return originalGrossAmountToVMM
::method proposedGrossAmountToVMM; expose proposedGrossAmountToVMM; return proposedGrossAmountToVMM
::method disputedDate; expose disputedDate; return disputedDate
::method disputeEvidenceRef; expose disputeEvidenceRef; return disputeEvidenceRef
::method authorityRef; expose authorityRef; return authorityRef
::method state; expose state; return state
::method resolutionId; expose resolutionId; return resolutionId
::method markResolved
  expose state resolutionId
  use strict arg rid
  if state<>"OPEN" | rid="" then raise syntax 88.900 array("close-out dispute cannot be resolved",state)
  state="RESOLVED"; resolutionId=rid; return self

::class VMMCloseoutValuationResolution public
::method init
  expose resolutionId disputeId closeoutId contractId currency finalGrossAmountToVMM cashVariationMarginPosted segregatedInitialMarginRecognized netAmountToVMM resolvedDate valuationAgentRef methodologyEvidenceRef marketDataEvidenceRef authorityRef
  use strict arg resolutionId,disputeId,closeoutId,contractId,currency,finalGrossAmountToVMM,cashVariationMarginPosted,segregatedInitialMarginRecognized,resolvedDate,valuationAgentRef,methodologyEvidenceRef,marketDataEvidenceRef,authorityRef
  numeric digits 50
  if resolutionId="" | disputeId="" | closeoutId="" | contractId="" | currency="" | valuationAgentRef="" | methodologyEvidenceRef="" | marketDataEvidenceRef="" | authorityRef="" then raise syntax 88.900 array("invalid VMM close-out valuation resolution")
  ignore=.VMMDefaultDateUtil~requireIsoDate(resolvedDate,"resolvedDate")
  if cashVariationMarginPosted<0 | segregatedInitialMarginRecognized<0 then raise syntax 88.900 array("invalid VMM close-out resolution collateral values")
  netAmountToVMM=finalGrossAmountToVMM+cashVariationMarginPosted
::method resolutionId; expose resolutionId; return resolutionId
::method disputeId; expose disputeId; return disputeId
::method closeoutId; expose closeoutId; return closeoutId
::method contractId; expose contractId; return contractId
::method currency; expose currency; return currency
::method finalGrossAmountToVMM; expose finalGrossAmountToVMM; return finalGrossAmountToVMM
::method cashVariationMarginPosted; expose cashVariationMarginPosted; return cashVariationMarginPosted
::method segregatedInitialMarginRecognized; expose segregatedInitialMarginRecognized; return segregatedInitialMarginRecognized
::method netAmountToVMM; expose netAmountToVMM; return netAmountToVMM
::method resolvedDate; expose resolvedDate; return resolvedDate
::method valuationAgentRef; expose valuationAgentRef; return valuationAgentRef
::method methodologyEvidenceRef; expose methodologyEvidenceRef; return methodologyEvidenceRef
::method marketDataEvidenceRef; expose marketDataEvidenceRef; return marketDataEvidenceRef
::method authorityRef; expose authorityRef; return authorityRef

::class VMMCloseoutFinalization public
::method init
  expose finalizationId closeoutId contractId counterpartyEntity currency grossAmountToVMM cashVariationMarginPosted segregatedInitialMarginRecognized netAmountToVMM finalizedDate basis sourceRef methodologyEvidenceRef marketDataEvidenceRef authorityRef
  use strict arg finalizationId,closeoutId,contractId,counterpartyEntity,currency,grossAmountToVMM,cashVariationMarginPosted,segregatedInitialMarginRecognized,finalizedDate,basis,sourceRef,methodologyEvidenceRef,marketDataEvidenceRef,authorityRef
  numeric digits 50
  if finalizationId="" | closeoutId="" | contractId="" | counterpartyEntity="" | currency="" | sourceRef="" | methodologyEvidenceRef="" | marketDataEvidenceRef="" | authorityRef="" then raise syntax 88.900 array("invalid VMM close-out finalization")
  ignore=.VMMDefaultDateUtil~requireIsoDate(finalizedDate,"finalizedDate")
  if basis<>"ORIGINAL_UNDISPUTED" & basis<>"DISPUTE_RESOLUTION" then raise syntax 88.900 array("invalid VMM close-out finalization basis",basis)
  if cashVariationMarginPosted<0 | segregatedInitialMarginRecognized<0 then raise syntax 88.900 array("invalid VMM close-out finalization collateral values")
  netAmountToVMM=grossAmountToVMM+cashVariationMarginPosted
::method finalizationId; expose finalizationId; return finalizationId
::method closeoutId; expose closeoutId; return closeoutId
::method contractId; expose contractId; return contractId
::method counterpartyEntity; expose counterpartyEntity; return counterpartyEntity
::method currency; expose currency; return currency
::method grossAmountToVMM; expose grossAmountToVMM; return grossAmountToVMM
::method cashVariationMarginPosted; expose cashVariationMarginPosted; return cashVariationMarginPosted
::method segregatedInitialMarginRecognized; expose segregatedInitialMarginRecognized; return segregatedInitialMarginRecognized
::method netAmountToVMM; expose netAmountToVMM; return netAmountToVMM
::method finalizedDate; expose finalizedDate; return finalizedDate
::method basis; expose basis; return basis
::method sourceRef; expose sourceRef; return sourceRef
::method methodologyEvidenceRef; expose methodologyEvidenceRef; return methodologyEvidenceRef
::method marketDataEvidenceRef; expose marketDataEvidenceRef; return marketDataEvidenceRef
::method authorityRef; expose authorityRef; return authorityRef
::method grossDirection
  expose grossAmountToVMM
  if grossAmountToVMM>0 then return "VMM_RECEIVABLE"
  if grossAmountToVMM<0 then return "VMM_PAYABLE"
  return "FLAT"
::method netDirection
  expose netAmountToVMM
  if netAmountToVMM>0 then return "VMM_RECEIVABLE"
  if netAmountToVMM<0 then return "VMM_PAYABLE"
  return "FLAT"
::method grossAbsolute; expose grossAmountToVMM; return abs(grossAmountToVMM)
::method netAbsolute; expose netAmountToVMM; return abs(netAmountToVMM)

::class VMMMasterAgreementNettingSet public
::method init
  expose nettingSetId counterpartyId counterpartyEntity masterAgreementRef currency governingLaw legalOpinionRef closeoutNettingElectionRef contractIds createdDate authorityRef
  use strict arg nettingSetId,counterpartyId,counterpartyEntity,masterAgreementRef,currency,governingLaw,legalOpinionRef,closeoutNettingElectionRef,contractIds,createdDate,authorityRef
  if nettingSetId="" | counterpartyId="" | counterpartyEntity="" | masterAgreementRef="" | currency="" | governingLaw="" | legalOpinionRef="" | closeoutNettingElectionRef="" | authorityRef="" then raise syntax 88.900 array("invalid VMM master-agreement netting set")
  ignore=.VMMDefaultDateUtil~requireIsoDate(createdDate,"createdDate")
  if \contractIds~isA(.Array) | contractIds~items<2 then raise syntax 88.900 array("v0.9 master-agreement netting set requires at least two contracts")
  ids=.array~new; do id over contractIds; ids~append(id); end; contractIds=ids
::method nettingSetId; expose nettingSetId; return nettingSetId
::method counterpartyId; expose counterpartyId; return counterpartyId
::method counterpartyEntity; expose counterpartyEntity; return counterpartyEntity
::method masterAgreementRef; expose masterAgreementRef; return masterAgreementRef
::method currency; expose currency; return currency
::method governingLaw; expose governingLaw; return governingLaw
::method legalOpinionRef; expose legalOpinionRef; return legalOpinionRef
::method closeoutNettingElectionRef; expose closeoutNettingElectionRef; return closeoutNettingElectionRef
::method contractIds; expose contractIds; return contractIds
::method createdDate; expose createdDate; return createdDate
::method authorityRef; expose authorityRef; return authorityRef

::class VMMNettingSetDetermination public
::method init
  expose determinationId nettingSetId currency totalReceivable totalPayable netAmountToVMM determinedDate calculationEvidenceRef authorityRef
  use strict arg determinationId,nettingSetId,currency,totalReceivable,totalPayable,netAmountToVMM,determinedDate,calculationEvidenceRef,authorityRef
  numeric digits 50
  if determinationId="" | nettingSetId="" | currency="" | calculationEvidenceRef="" | authorityRef="" then raise syntax 88.900 array("invalid VMM netting-set determination")
  ignore=.VMMDefaultDateUtil~requireIsoDate(determinedDate,"determinedDate")
  if totalReceivable<0 | totalPayable<0 | netAmountToVMM<>totalReceivable-totalPayable then raise syntax 88.900 array("invalid VMM netting-set arithmetic")
::method determinationId; expose determinationId; return determinationId
::method nettingSetId; expose nettingSetId; return nettingSetId
::method currency; expose currency; return currency
::method totalReceivable; expose totalReceivable; return totalReceivable
::method totalPayable; expose totalPayable; return totalPayable
::method netAmountToVMM; expose netAmountToVMM; return netAmountToVMM
::method determinedDate; expose determinedDate; return determinedDate
::method calculationEvidenceRef; expose calculationEvidenceRef; return calculationEvidenceRef
::method authorityRef; expose authorityRef; return authorityRef
::method netDirection
  expose netAmountToVMM
  if netAmountToVMM>0 then return "VMM_RECEIVABLE"
  if netAmountToVMM<0 then return "VMM_PAYABLE"
  return "FLAT"
::method netAbsolute; expose netAmountToVMM; return abs(netAmountToVMM)

::class VMMNettingSetSettlement public
::method init
  expose settlementId determinationId nettingSetId currency amount payerEntity payeeEntity settledDate paymentEvidenceRef authorityRef
  use strict arg settlementId,determinationId,nettingSetId,currency,amount,payerEntity,payeeEntity,settledDate,paymentEvidenceRef,authorityRef
  numeric digits 50
  if settlementId="" | determinationId="" | nettingSetId="" | currency="" | paymentEvidenceRef="" | authorityRef="" | amount<0 then raise syntax 88.900 array("invalid VMM netting-set settlement")
  ignore=.VMMDefaultDateUtil~requireIsoDate(settledDate,"settledDate")
  if amount>0 & (payerEntity="" | payeeEntity="" | payerEntity=payeeEntity) then raise syntax 88.900 array("netting-set cash settlement requires distinct payer/payee")
  if amount=0 & (payerEntity<>"" | payeeEntity<>"") then raise syntax 88.900 array("zero netting-set settlement must not invent payer/payee")
::method settlementId; expose settlementId; return settlementId
::method determinationId; expose determinationId; return determinationId
::method nettingSetId; expose nettingSetId; return nettingSetId
::method currency; expose currency; return currency
::method amount; expose amount; return amount
::method payerEntity; expose payerEntity; return payerEntity
::method payeeEntity; expose payeeEntity; return payeeEntity
::method settledDate; expose settledDate; return settledDate
::method paymentEvidenceRef; expose paymentEvidenceRef; return paymentEvidenceRef
::method authorityRef; expose authorityRef; return authorityRef

::class VMMPostTerminationCollateralReturn public
::method init
  expose returnId finalizationId closeoutId contractId originalTransferId currency assetRef assetClass grossCarryingAmount recognizedRiskValue custodianRef beneficiaryEntity returnToEntity instructedDate dueDate instructionEvidenceRef authorityRef state
  use strict arg returnId,finalizationId,closeoutId,contractId,originalTransferId,currency,assetRef,assetClass,grossCarryingAmount,recognizedRiskValue,custodianRef,beneficiaryEntity,returnToEntity,instructedDate,dueDate,instructionEvidenceRef,authorityRef
  numeric digits 50
  if returnId="" | finalizationId="" | closeoutId="" | contractId="" | originalTransferId="" | currency="" | assetRef="" | assetClass="" | custodianRef="" | beneficiaryEntity="" | returnToEntity="" | instructionEvidenceRef="" | authorityRef="" then raise syntax 88.900 array("invalid VMM post-termination collateral return")
  ignore=.VMMDefaultDateUtil~requireIsoDate(instructedDate,"instructedDate"); ignore=.VMMDefaultDateUtil~requireIsoDate(dueDate,"dueDate")
  if dueDate<instructedDate | grossCarryingAmount<=0 | recognizedRiskValue<0 | recognizedRiskValue>grossCarryingAmount then raise syntax 88.900 array("invalid VMM collateral-return economics/dates")
  if returnToEntity<>.VMMCloseoutOperationsBuild~legalEntity then raise syntax 88.900 array("segregated VMM initial margin must return to VMM legal entity",returnToEntity)
  state="INSTRUCTED"
::method returnId; expose returnId; return returnId
::method finalizationId; expose finalizationId; return finalizationId
::method closeoutId; expose closeoutId; return closeoutId
::method contractId; expose contractId; return contractId
::method originalTransferId; expose originalTransferId; return originalTransferId
::method currency; expose currency; return currency
::method assetRef; expose assetRef; return assetRef
::method assetClass; expose assetClass; return assetClass
::method grossCarryingAmount; expose grossCarryingAmount; return grossCarryingAmount
::method recognizedRiskValue; expose recognizedRiskValue; return recognizedRiskValue
::method custodianRef; expose custodianRef; return custodianRef
::method beneficiaryEntity; expose beneficiaryEntity; return beneficiaryEntity
::method returnToEntity; expose returnToEntity; return returnToEntity
::method instructedDate; expose instructedDate; return instructedDate
::method dueDate; expose dueDate; return dueDate
::method instructionEvidenceRef; expose instructionEvidenceRef; return instructionEvidenceRef
::method authorityRef; expose authorityRef; return authorityRef
::method state; expose state; return state
::method acknowledge
  expose state
  if state<>"INSTRUCTED" then raise syntax 88.900 array("collateral return is not awaiting custodian acknowledgement",state)
  state="ACKNOWLEDGED"; return self
::method settle
  expose state
  if state<>"ACKNOWLEDGED" then raise syntax 88.900 array("collateral return requires custodian acknowledgement before settlement",state)
  state="SETTLED"; return self

::class VMMCustodyReturnAcknowledgement public
::method init
  expose acknowledgementId returnId acknowledgedDate custodianAckEvidenceRef authorityRef
  use strict arg acknowledgementId,returnId,acknowledgedDate,custodianAckEvidenceRef,authorityRef
  if acknowledgementId="" | returnId="" | custodianAckEvidenceRef="" | authorityRef="" then raise syntax 88.900 array("invalid VMM custody return acknowledgement")
  ignore=.VMMDefaultDateUtil~requireIsoDate(acknowledgedDate,"acknowledgedDate")
::method acknowledgementId; expose acknowledgementId; return acknowledgementId
::method returnId; expose returnId; return returnId
::method acknowledgedDate; expose acknowledgedDate; return acknowledgedDate
::method custodianAckEvidenceRef; expose custodianAckEvidenceRef; return custodianAckEvidenceRef
::method authorityRef; expose authorityRef; return authorityRef

::class VMMCustodyReturnSettlement public
::method init
  expose settlementId returnId contractId assetRef currency grossCarryingAmount custodianRef returnedToEntity settledDate controlEvidenceRef custodianReceiptRef authorityRef
  use strict arg settlementId,returnId,contractId,assetRef,currency,grossCarryingAmount,custodianRef,returnedToEntity,settledDate,controlEvidenceRef,custodianReceiptRef,authorityRef
  numeric digits 50
  if settlementId="" | returnId="" | contractId="" | assetRef="" | currency="" | custodianRef="" | returnedToEntity="" | controlEvidenceRef="" | custodianReceiptRef="" | authorityRef="" | grossCarryingAmount<=0 then raise syntax 88.900 array("invalid VMM custody return settlement")
  ignore=.VMMDefaultDateUtil~requireIsoDate(settledDate,"settledDate")
  if returnedToEntity<>.VMMCloseoutOperationsBuild~legalEntity then raise syntax 88.900 array("VMM initial margin custody return must settle to VMM",returnedToEntity)
::method settlementId; expose settlementId; return settlementId
::method returnId; expose returnId; return returnId
::method contractId; expose contractId; return contractId
::method assetRef; expose assetRef; return assetRef
::method currency; expose currency; return currency
::method grossCarryingAmount; expose grossCarryingAmount; return grossCarryingAmount
::method custodianRef; expose custodianRef; return custodianRef
::method returnedToEntity; expose returnedToEntity; return returnedToEntity
::method settledDate; expose settledDate; return settledDate
::method controlEvidenceRef; expose controlEvidenceRef; return controlEvidenceRef
::method custodianReceiptRef; expose custodianReceiptRef; return custodianReceiptRef
::method authorityRef; expose authorityRef; return authorityRef

::class VMMCloseoutOperationsService public
::method init
  expose defaultService productService policies determinations disputes disputeByCloseout resolutions finalizations finalizationByCloseout directSettlementByCloseout nettingSets nettingSetByContract nettingDeterminations nettingDeterminationBySet nettingSettlements nettingSettlementBySet cashSettledByCloseout collateralReturns returnByTransfer custodyAcks ackByReturn custodySettlements custodySettlementByReturn
  use strict arg defaultService
  if defaultService==.nil | \defaultService~isA(.VMMInstitutionalDefaultCloseoutService) then raise syntax 88.900 array("VMM close-out operations requires default/close-out service")
  productService=defaultService~productService
  policies=.directory~new; determinations=.directory~new; disputes=.directory~new; disputeByCloseout=.directory~new; resolutions=.directory~new; finalizations=.directory~new; finalizationByCloseout=.directory~new; directSettlementByCloseout=.directory~new
  nettingSets=.directory~new; nettingSetByContract=.directory~new; nettingDeterminations=.directory~new; nettingDeterminationBySet=.directory~new; nettingSettlements=.directory~new; nettingSettlementBySet=.directory~new; cashSettledByCloseout=.directory~new
  collateralReturns=.directory~new; returnByTransfer=.directory~new; custodyAcks=.directory~new; ackByReturn=.directory~new; custodySettlements=.directory~new; custodySettlementByReturn=.directory~new
  defaultService~setSettlementController(self)
::method defaultService; expose defaultService; return defaultService
::method productService; expose productService; return productService
::method setPolicy
  expose productService policies
  use strict arg policy,authorityRef
  if \policy~isA(.VMMCloseoutOperationsPolicy) | authorityRef="" then raise syntax 88.900 array("VMMCloseoutOperationsPolicy and authority required")
  policies[policy~currency]=policy
  productService~vmm~journal~put("synthetic:closeoutOpsPolicy:"||policy~currency,policy,"VMM_CLOSEOUT_OPERATIONS_POLICY_SET",self~meta("authority",authorityRef))
  return policy
::method policy
  expose policies
  use strict arg currency
  return policies[currency]
::method registerDetermination
  expose determinations
  use strict arg closeout
  if \closeout~isA(.VMMSyntheticCloseoutDetermination) then raise syntax 88.900 array("VMMSyntheticCloseoutDetermination required")
  if determinations~hasIndex(closeout~closeoutId) then do
    if determinations[closeout~closeoutId]<>closeout then raise syntax 88.900 array("conflicting VMM close-out determination registration",closeout~closeoutId)
    return closeout
  end
  determinations[closeout~closeoutId]=closeout
  return closeout
::method disputeCloseout
  expose productService defaultService policies determinations disputes disputeByCloseout finalizationByCloseout
  use strict arg disputeId,closeoutId,disputingEntity,proposedGrossAmountToVMM,disputedDate,disputeEvidenceRef,authorityRef
  numeric digits 50
  if disputes~hasIndex(disputeId) | disputeByCloseout~hasIndex(closeoutId) then raise syntax 88.900 array("duplicate VMM close-out dispute",disputeId,closeoutId)
  if finalizationByCloseout~hasIndex(closeoutId) then raise syntax 88.900 array("finalized close-out cannot be disputed",closeoutId)
  c=determinations[closeoutId]; if c==.nil then raise syntax 88.900 array("unknown VMM close-out determination for dispute",closeoutId)
  p=policies[c~currency]; if p==.nil then raise syntax 88.900 array("VMM close-out operations policy required",c~currency)
  k=productService~contract(c~contractId); cp=productService~counterparty(k~counterpartyId)
  if disputingEntity<>cp~legalEntity & disputingEntity<>.VMMCloseoutOperationsBuild~legalEntity then raise syntax 88.900 array("close-out dispute entity is not a contract party",disputingEntity)
  ignore=.VMMDefaultDateUtil~requireIsoDate(disputedDate,"disputedDate")
  deadline=.VMMDefaultDateUtil~addDays(c~determinedDate,p~disputeWindowDays)
  if disputedDate<c~determinedDate | disputedDate>deadline then raise syntax 88.900 array("close-out dispute outside contractual dispute window",disputedDate,deadline)
  d=.VMMCloseoutValuationDispute~new(disputeId,closeoutId,c~contractId,disputingEntity,c~grossAmountToVMM,proposedGrossAmountToVMM,disputedDate,disputeEvidenceRef,authorityRef)
  disputes[disputeId]=d; disputeByCloseout[closeoutId]=disputeId
  productService~vmm~journal~put("synthetic:closeoutDispute:"||disputeId,d,"VMM_SYNTHETIC_CLOSEOUT_DISPUTED",self~meta("closeout",closeoutId))
  return d
::method dispute
  expose disputes
  use strict arg disputeId
  return disputes[disputeId]
::method resolveDispute
  expose productService defaultService policies determinations disputes resolutions
  use strict arg resolutionId,disputeId,finalGrossAmountToVMM,resolvedDate,valuationAgentRef,methodologyEvidenceRef,marketDataEvidenceRef,authorityRef
  if resolutions~hasIndex(resolutionId) then raise syntax 88.900 array("duplicate VMM close-out dispute resolution",resolutionId)
  d=disputes[disputeId]; if d==.nil | d~state<>"OPEN" then raise syntax 88.900 array("open VMM close-out dispute required",disputeId)
  c=determinations[d~closeoutId]; p=policies[c~currency]; if p==.nil then raise syntax 88.900 array("VMM close-out operations policy required",c~currency)
  t=defaultService~termination(c~terminationId)
  if valuationAgentRef<>p~fallbackValuationAgentRef then raise syntax 88.900 array("disputed close-out must use configured fallback valuation agent",valuationAgentRef,p~fallbackValuationAgentRef)
  if t<>.nil & valuationAgentRef=t~valuationAgentRef then raise syntax 88.900 array("fallback valuation agent must be independent of original termination valuation agent",valuationAgentRef)
  ignore=.VMMDefaultDateUtil~requireIsoDate(resolvedDate,"resolvedDate"); if resolvedDate<d~disputedDate then raise syntax 88.900 array("close-out dispute resolution precedes dispute")
  r=.VMMCloseoutValuationResolution~new(resolutionId,disputeId,c~closeoutId,c~contractId,c~currency,finalGrossAmountToVMM,c~cashVariationMarginPosted,c~segregatedInitialMarginRecognized,resolvedDate,valuationAgentRef,methodologyEvidenceRef,marketDataEvidenceRef,authorityRef)
  resolutions[resolutionId]=r; d~markResolved(resolutionId)
  productService~vmm~journal~put("synthetic:closeoutResolution:"||resolutionId,r,"VMM_SYNTHETIC_CLOSEOUT_DISPUTE_RESOLVED",self~meta("closeout",c~closeoutId))
  return r
::method resolution
  expose resolutions
  use strict arg resolutionId
  return resolutions[resolutionId]
::method finalizeCloseout
  expose productService policies determinations disputes disputeByCloseout resolutions finalizations finalizationByCloseout
  use strict arg finalizationId,closeoutId,finalizedDate,authorityRef
  if finalizations~hasIndex(finalizationId) | finalizationByCloseout~hasIndex(closeoutId) then raise syntax 88.900 array("duplicate VMM close-out finalization",finalizationId,closeoutId)
  c=determinations[closeoutId]; if c==.nil then raise syntax 88.900 array("unknown VMM close-out determination for finalization",closeoutId)
  p=policies[c~currency]; if p==.nil then raise syntax 88.900 array("VMM close-out operations policy required",c~currency)
  ignore=.VMMDefaultDateUtil~requireIsoDate(finalizedDate,"finalizedDate")
  disputeId=disputeByCloseout[closeoutId]
  if disputeId==.nil then do
    deadline=.VMMDefaultDateUtil~addDays(c~determinedDate,p~disputeWindowDays)
    if finalizedDate<=deadline then raise syntax 88.900 array("undisputed close-out cannot finalize before dispute window expires",finalizedDate,deadline)
    gross=c~grossAmountToVMM; basis="ORIGINAL_UNDISPUTED"; sourceRef=c~closeoutId; methodologyEvidenceRef=c~methodologyEvidenceRef; marketDataEvidenceRef=c~marketDataEvidenceRef
  end
  else do
    d=disputes[disputeId]; if d==.nil | d~state<>"RESOLVED" then raise syntax 88.900 array("disputed close-out cannot finalize before resolution",closeoutId)
    r=resolutions[d~resolutionId]; if r==.nil then raise syntax 88.900 array("resolved dispute lost resolution evidence",disputeId)
    if finalizedDate<r~resolvedDate then raise syntax 88.900 array("close-out finalization precedes dispute resolution")
    gross=r~finalGrossAmountToVMM; basis="DISPUTE_RESOLUTION"; sourceRef=r~resolutionId; methodologyEvidenceRef=r~methodologyEvidenceRef; marketDataEvidenceRef=r~marketDataEvidenceRef
  end
  f=.VMMCloseoutFinalization~new(finalizationId,c~closeoutId,c~contractId,c~counterpartyEntity,c~currency,gross,c~cashVariationMarginPosted,c~segregatedInitialMarginRecognized,finalizedDate,basis,sourceRef,methodologyEvidenceRef,marketDataEvidenceRef,authorityRef)
  finalizations[finalizationId]=f; finalizationByCloseout[closeoutId]=finalizationId
  productService~vmm~journal~put("synthetic:closeoutFinalization:"||finalizationId,f,"VMM_SYNTHETIC_CLOSEOUT_FINALIZED",self~meta("closeout",closeoutId))
  return f
::method finalization
  expose finalizations
  use strict arg finalizationId
  return finalizations[finalizationId]
::method finalizationForCloseout
  expose finalizations finalizationByCloseout
  use strict arg closeoutId
  fid=finalizationByCloseout[closeoutId]; if fid==.nil then return .nil; return finalizations[fid]
::method settlementAuthorization
  expose productService finalizations finalizationByCloseout directSettlementByCloseout nettingSetByContract cashSettledByCloseout determinations
  use strict arg closeoutId
  if directSettlementByCloseout~hasIndex(closeoutId) | cashSettledByCloseout~hasIndex(closeoutId) then return .nil
  fid=finalizationByCloseout[closeoutId]; if fid==.nil then return .nil
  f=finalizations[fid]; c=determinations[closeoutId]; if c==.nil then return .nil
  if nettingSetByContract~hasIndex(c~contractId) then return .nil
  return f
::method recordDirectSettlement
  expose directSettlementByCloseout cashSettledByCloseout finalizations finalizationByCloseout
  use strict arg settlement
  if \settlement~isA(.VMMSyntheticCloseoutSettlement) then raise syntax 88.900 array("VMMSyntheticCloseoutSettlement required")
  fid=finalizationByCloseout[settlement~closeoutId]; if fid==.nil | settlement~finalizationId<>fid then raise syntax 88.900 array("direct close-out settlement missing matching v0.9 finalization",settlement~closeoutId)
  directSettlementByCloseout[settlement~closeoutId]=settlement~settlementId; cashSettledByCloseout[settlement~closeoutId]=settlement~settlementId
  return settlement
::method isCloseoutCashSettled
  expose cashSettledByCloseout
  use strict arg closeoutId
  return cashSettledByCloseout~hasIndex(closeoutId)
::method createNettingSet
  expose productService defaultService policies determinations finalizations finalizationByCloseout nettingSets nettingSetByContract cashSettledByCloseout
  use strict arg nettingSetId,contractIds,governingLaw,legalOpinionRef,closeoutNettingElectionRef,createdDate,authorityRef
  if nettingSets~hasIndex(nettingSetId) then raise syntax 88.900 array("duplicate VMM master-agreement netting set",nettingSetId)
  if \contractIds~isA(.Array) | contractIds~items<2 then raise syntax 88.900 array("v0.9 netting set requires at least two contracts")
  seen=.directory~new; cpId=""; cpEntity=""; master=""; currency=""
  do contractId over contractIds
    if contractId="" | seen~hasIndex(contractId) then raise syntax 88.900 array("duplicate/blank contract in VMM netting set",contractId)
    seen[contractId]=.true
    if nettingSetByContract~hasIndex(contractId) then raise syntax 88.900 array("contract already belongs to VMM netting set",contractId,nettingSetByContract[contractId])
    k=productService~contract(contractId); if k==.nil | k~state<>"TERMINATED" then raise syntax 88.900 array("netting-set contract must be terminated",contractId)
    cp=productService~counterparty(k~counterpartyId); if cp==.nil then raise syntax 88.900 array("netting-set counterparty missing",contractId)
    fid=.nil
    do cid over determinations
      c=determinations[cid]; if c~contractId=contractId then do; fid=finalizationByCloseout[cid]; leave; end
    end
    if fid==.nil then raise syntax 88.900 array("netting-set contract requires finalized close-out",contractId)
    if cashSettledByCloseout~hasIndex(cid) then raise syntax 88.900 array("already settled close-out cannot enter netting set",cid)
    if cpId="" then do; cpId=k~counterpartyId; cpEntity=cp~legalEntity; master=k~masterAgreementRef; currency=k~terms~currency; end
    else if k~counterpartyId<>cpId | cp~legalEntity<>cpEntity | k~masterAgreementRef<>master | k~terms~currency<>currency then raise syntax 88.900 array("netting set requires exact counterparty/master-agreement/currency identity",contractId)
  end
  p=policies[currency]; if p==.nil then raise syntax 88.900 array("VMM close-out operations policy required",currency)
  if legalOpinionRef="" | closeoutNettingElectionRef="" | governingLaw="" | authorityRef="" then raise syntax 88.900 array("master-agreement netting requires legal opinion, election, governing law and authority")
  n=.VMMMasterAgreementNettingSet~new(nettingSetId,cpId,cpEntity,master,currency,governingLaw,legalOpinionRef,closeoutNettingElectionRef,contractIds,createdDate,authorityRef)
  nettingSets[nettingSetId]=n; do contractId over contractIds; nettingSetByContract[contractId]=nettingSetId; end
  productService~vmm~journal~put("synthetic:nettingSet:"||nettingSetId,n,"VMM_SYNTHETIC_MASTER_NETTING_SET_FIXED",self~meta("legalOpinionPolicy",p~legalOpinionPolicyRef))
  return n
::method nettingSet
  expose nettingSets
  use strict arg nettingSetId
  return nettingSets[nettingSetId]
::method determineNettingSet
  expose productService determinations finalizations finalizationByCloseout nettingSets nettingDeterminations nettingDeterminationBySet
  use strict arg determinationId,nettingSetId,determinedDate,calculationEvidenceRef,authorityRef
  numeric digits 50
  if nettingDeterminations~hasIndex(determinationId) | nettingDeterminationBySet~hasIndex(nettingSetId) then raise syntax 88.900 array("duplicate VMM netting-set determination",determinationId,nettingSetId)
  n=nettingSets[nettingSetId]; if n==.nil then raise syntax 88.900 array("unknown VMM master-agreement netting set",nettingSetId)
  receivable=0; payable=0
  do contractId over n~contractIds
    found=.false
    do closeoutId over determinations
      c=determinations[closeoutId]
      if c~contractId<>contractId then iterate
      fid=finalizationByCloseout[closeoutId]; f=finalizations[fid]
      if f==.nil then raise syntax 88.900 array("netting-set finalization missing",contractId)
      if f~netDirection="VMM_RECEIVABLE" then receivable=receivable+f~netAbsolute
      if f~netDirection="VMM_PAYABLE" then payable=payable+f~netAbsolute
      found=.true; leave
    end
    if \found then raise syntax 88.900 array("netting-set close-out determination missing",contractId)
  end
  x=.VMMNettingSetDetermination~new(determinationId,nettingSetId,n~currency,receivable,payable,receivable-payable,determinedDate,calculationEvidenceRef,authorityRef)
  nettingDeterminations[determinationId]=x; nettingDeterminationBySet[nettingSetId]=determinationId
  productService~vmm~journal~put("synthetic:nettingDetermination:"||determinationId,x,"VMM_SYNTHETIC_MASTER_NETTING_DETERMINED",self~meta("nettingSet",nettingSetId))
  return x
::method nettingDetermination
  expose nettingDeterminations
  use strict arg determinationId
  return nettingDeterminations[determinationId]
::method settleNettingSet
  expose productService nettingSets nettingDeterminations nettingDeterminationBySet nettingSettlements nettingSettlementBySet cashSettledByCloseout determinations
  use strict arg settlementId,nettingSetId,settledDate,paymentEvidenceRef,authorityRef
  if nettingSettlements~hasIndex(settlementId) | nettingSettlementBySet~hasIndex(nettingSetId) then raise syntax 88.900 array("duplicate VMM netting-set settlement",settlementId,nettingSetId)
  n=nettingSets[nettingSetId]; if n==.nil then raise syntax 88.900 array("unknown VMM netting set",nettingSetId)
  did=nettingDeterminationBySet[nettingSetId]; d=nettingDeterminations[did]; if d==.nil then raise syntax 88.900 array("netting set requires final determination before settlement",nettingSetId)
  if d~netDirection="VMM_RECEIVABLE" then do; payer=n~counterpartyEntity; payee=.VMMCloseoutOperationsBuild~legalEntity; end
  else if d~netDirection="VMM_PAYABLE" then do; payer=.VMMCloseoutOperationsBuild~legalEntity; payee=n~counterpartyEntity; end
  else do; payer=""; payee=""; end
  s=.VMMNettingSetSettlement~new(settlementId,d~determinationId,nettingSetId,n~currency,d~netAbsolute,payer,payee,settledDate,paymentEvidenceRef,authorityRef)
  nettingSettlements[settlementId]=s; nettingSettlementBySet[nettingSetId]=settlementId
  do contractId over n~contractIds
    do closeoutId over determinations
      if determinations[closeoutId]~contractId=contractId then do; cashSettledByCloseout[closeoutId]=settlementId; leave; end
    end
  end
  productService~vmm~journal~put("synthetic:nettingSettlement:"||settlementId,s,"VMM_SYNTHETIC_MASTER_NETTING_SETTLED",self~meta("nettingSet",nettingSetId))
  return s
::method nettingSettlement
  expose nettingSettlements
  use strict arg settlementId
  return nettingSettlements[settlementId]
::method instructInitialMarginReturn
  expose productService policies determinations finalizations finalizationByCloseout collateralReturns returnByTransfer cashSettledByCloseout
  use strict arg returnId,closeoutId,originalTransferId,instructedDate,instructionEvidenceRef,authorityRef
  if collateralReturns~hasIndex(returnId) | returnByTransfer~hasIndex(originalTransferId) then raise syntax 88.900 array("duplicate VMM initial-margin return",returnId,originalTransferId)
  c=determinations[closeoutId]; if c==.nil then raise syntax 88.900 array("unknown close-out for initial-margin return",closeoutId)
  if \cashSettledByCloseout~hasIndex(closeoutId) then raise syntax 88.900 array("segregated initial margin return requires close-out/netting cash settlement first",closeoutId)
  fid=finalizationByCloseout[closeoutId]; f=finalizations[fid]; if f==.nil then raise syntax 88.900 array("initial-margin return requires close-out finalization",closeoutId)
  t=productService~initialMarginTransfer(originalTransferId); if t==.nil | t~contractId<>c~contractId then raise syntax 88.900 array("initial-margin transfer/close-out mismatch",originalTransferId)
  p=policies[c~currency]; if p==.nil then raise syntax 88.900 array("VMM close-out operations policy required",c~currency)
  due=.VMMDefaultDateUtil~addDays(instructedDate,p~collateralReturnDays)
  r=.VMMPostTerminationCollateralReturn~new(returnId,fid,closeoutId,c~contractId,t~transferId,t~currency,t~assetRef,t~assetClass,t~grossMarketValue,t~recognizedValue,t~custodianRef,t~beneficiaryEntity,.VMMCloseoutOperationsBuild~legalEntity,instructedDate,due,instructionEvidenceRef,authorityRef)
  collateralReturns[returnId]=r; returnByTransfer[originalTransferId]=returnId
  productService~vmm~journal~put("synthetic:imReturn:"||returnId,r,"VMM_SYNTHETIC_INITIAL_MARGIN_RETURN_INSTRUCTED",self~meta("closeout",closeoutId))
  return r
::method collateralReturn
  expose collateralReturns
  use strict arg returnId
  return collateralReturns[returnId]
::method acknowledgeCustodyReturn
  expose productService collateralReturns custodyAcks ackByReturn
  use strict arg acknowledgementId,returnId,acknowledgedDate,custodianAckEvidenceRef,authorityRef
  if custodyAcks~hasIndex(acknowledgementId) | ackByReturn~hasIndex(returnId) then raise syntax 88.900 array("duplicate VMM custody return acknowledgement",acknowledgementId,returnId)
  r=collateralReturns[returnId]; if r==.nil then raise syntax 88.900 array("unknown VMM collateral return",returnId)
  if acknowledgedDate<r~instructedDate then raise syntax 88.900 array("custodian acknowledgement precedes return instruction")
  a=.VMMCustodyReturnAcknowledgement~new(acknowledgementId,returnId,acknowledgedDate,custodianAckEvidenceRef,authorityRef)
  custodyAcks[acknowledgementId]=a; ackByReturn[returnId]=acknowledgementId; r~acknowledge
  productService~vmm~journal~put("synthetic:imReturnAck:"||acknowledgementId,a,"VMM_SYNTHETIC_INITIAL_MARGIN_RETURN_ACKNOWLEDGED",self~meta("return",returnId))
  return a
::method settleCustodyReturn
  expose productService collateralReturns ackByReturn custodyAcks custodySettlements custodySettlementByReturn
  use strict arg settlementId,returnId,settledDate,controlEvidenceRef,custodianReceiptRef,authorityRef
  if custodySettlements~hasIndex(settlementId) | custodySettlementByReturn~hasIndex(returnId) then raise syntax 88.900 array("duplicate VMM custody return settlement",settlementId,returnId)
  r=collateralReturns[returnId]; if r==.nil then raise syntax 88.900 array("unknown VMM collateral return",returnId)
  aid=ackByReturn[returnId]; a=custodyAcks[aid]; if a==.nil then raise syntax 88.900 array("custodian acknowledgement required before initial-margin return settlement",returnId)
  if settledDate<a~acknowledgedDate then raise syntax 88.900 array("custody return settlement precedes acknowledgement")
  s=.VMMCustodyReturnSettlement~new(settlementId,returnId,r~contractId,r~assetRef,r~currency,r~grossCarryingAmount,r~custodianRef,.VMMCloseoutOperationsBuild~legalEntity,settledDate,controlEvidenceRef,custodianReceiptRef,authorityRef)
  custodySettlements[settlementId]=s; custodySettlementByReturn[returnId]=settlementId; r~settle
  productService~vmm~journal~put("synthetic:imReturnSettlement:"||settlementId,s,"VMM_SYNTHETIC_INITIAL_MARGIN_RETURN_SETTLED",self~meta("return",returnId))
  return s
::method custodySettlement
  expose custodySettlements
  use strict arg settlementId
  return custodySettlements[settlementId]
::method effectiveInitialMarginRecognized
  expose productService returnByTransfer collateralReturns custodySettlementByReturn
  use strict arg contractId
  numeric digits 50
  total=0
  do t over productService~initialMarginTransfersForContract(contractId)
    rid=returnByTransfer[t~transferId]
    if rid<>.nil & custodySettlementByReturn~hasIndex(rid) then iterate
    total=total+t~recognizedValue
  end
  return total
::method meta private
  use strict arg key,value
  m=.directory~new; m[key]=value; return m

::requires "VMMDefaultCloseout.cls"
