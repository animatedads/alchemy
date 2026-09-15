/* VMMSyntheticProducts.cls -- direct institutional OTC synthetic products v0.6 */

::class VMMSyntheticBuild public
::method version class; return "0.9"
::method protocol class; return "vmm.institutional.synthetic/0.5"
::method lifecycleProtocol class; return "vmm.institutional.synthetic.lifecycle/0.6"


::class VMMInstitutionalCounterparty public
::method init
  expose counterpartyId legalEntity relationshipRef jurisdiction kycEvidenceRef masterAgreementRef collateralAgreementRef onboardingAuthority status
  use strict arg counterpartyId,legalEntity,relationshipRef,jurisdiction,kycEvidenceRef,masterAgreementRef,collateralAgreementRef,onboardingAuthority
  if counterpartyId="" | legalEntity="" | relationshipRef="" | jurisdiction="" | kycEvidenceRef="" | masterAgreementRef="" | collateralAgreementRef="" | onboardingAuthority="" then raise syntax 88.900 array("invalid VMM institutional counterparty")
  if legalEntity="VECTOR_MERIDIAN_MARKETS_LTD" | legalEntity="FEDERATIONBANK_CORE" | legalEntity="FEDERATIONBANK_MERCHANT_BANK" then raise syntax 88.900 array("institutional OTC counterparty must be external to VMM/Federation",legalEntity)
  status="ACTIVE"
::method counterpartyId; expose counterpartyId; return counterpartyId
::method legalEntity; expose legalEntity; return legalEntity
::method relationshipRef; expose relationshipRef; return relationshipRef
::method jurisdiction; expose jurisdiction; return jurisdiction
::method kycEvidenceRef; expose kycEvidenceRef; return kycEvidenceRef
::method masterAgreementRef; expose masterAgreementRef; return masterAgreementRef
::method collateralAgreementRef; expose collateralAgreementRef; return collateralAgreementRef
::method onboardingAuthority; expose onboardingAuthority; return onboardingAuthority
::method status; expose status; return status
::method suspend; expose status; status="SUSPENDED"; return self
::method activate; expose status; status="ACTIVE"; return self


::class VMMPortfolioReferencePosition public
::method init
  expose positionId counterpartyId assetRef issuerEntity assetClass currency marketValue currentOwnerEntity legacyOwnerEntity sourceBookRef successionEvidenceRef valuationEvidenceRef
  use strict arg positionId,counterpartyId,assetRef,issuerEntity,assetClass,currency,marketValue,currentOwnerEntity,legacyOwnerEntity="",sourceBookRef="",successionEvidenceRef="",valuationEvidenceRef=""
  if positionId="" | counterpartyId="" | assetRef="" | issuerEntity="" | assetClass="" | currency="" | currentOwnerEntity="" | valuationEvidenceRef="" then raise syntax 88.900 array("invalid VMM portfolio reference position")
  if marketValue<=0 then raise syntax 88.900 array("portfolio reference market value must be positive")
  if legacyOwnerEntity<>"" & legacyOwnerEntity<>currentOwnerEntity & successionEvidenceRef="" then raise syntax 88.900 array("legacy merger position requires succession evidence",positionId)
::method positionId; expose positionId; return positionId
::method counterpartyId; expose counterpartyId; return counterpartyId
::method assetRef; expose assetRef; return assetRef
::method issuerEntity; expose issuerEntity; return issuerEntity
::method assetClass; expose assetClass; return assetClass
::method currency; expose currency; return currency
::method marketValue; expose marketValue; return marketValue
::method currentOwnerEntity; expose currentOwnerEntity; return currentOwnerEntity
::method legacyOwnerEntity; expose legacyOwnerEntity; return legacyOwnerEntity
::method sourceBookRef; expose sourceBookRef; return sourceBookRef
::method successionEvidenceRef; expose successionEvidenceRef; return successionEvidenceRef
::method valuationEvidenceRef; expose valuationEvidenceRef; return valuationEvidenceRef
::method inheritedThroughMerger
  expose legacyOwnerEntity currentOwnerEntity
  return legacyOwnerEntity<>"" & legacyOwnerEntity<>currentOwnerEntity


::class VMMPortfolioSnapshot public
::method init
  expose snapshotId counterpartyId counterpartyEntity reportingCurrency asOf positions sourceEvidenceRef mergerEvidenceRef authorityRef totalMarketValue inheritedCount
  use strict arg snapshotId,counterpartyId,counterpartyEntity,reportingCurrency,asOf,positions,sourceEvidenceRef,mergerEvidenceRef="",authorityRef=""
  if snapshotId="" | counterpartyId="" | counterpartyEntity="" | reportingCurrency="" | asOf="" | sourceEvidenceRef="" | authorityRef="" then raise syntax 88.900 array("invalid VMM portfolio snapshot")
  if \positions~isA(.Array) then raise syntax 88.900 array("VMM portfolio snapshot requires immutable position array")
  if positions~items=0 then raise syntax 88.900 array("VMM portfolio snapshot requires positions")
  totalMarketValue=0; inheritedCount=0
  do p over positions
    if \p~isA(.VMMPortfolioReferencePosition) then raise syntax 88.900 array("VMM portfolio snapshot contains invalid position")
    if p~counterpartyId<>counterpartyId then raise syntax 88.900 array("portfolio position/counterparty mismatch",p~positionId)
    if p~currentOwnerEntity<>counterpartyEntity then raise syntax 88.900 array("portfolio position current legal owner mismatch",p~positionId)
    if p~currency<>reportingCurrency then raise syntax 88.900 array("v0.5 synthetic snapshot requires reporting-currency normalized positions",p~positionId,p~currency,reportingCurrency)
    if p~inheritedThroughMerger then inheritedCount=inheritedCount+1
    totalMarketValue=totalMarketValue+p~marketValue
  end
  if inheritedCount>0 & mergerEvidenceRef="" then raise syntax 88.900 array("merged portfolio snapshot requires merger/succession evidence")
::method snapshotId; expose snapshotId; return snapshotId
::method counterpartyId; expose counterpartyId; return counterpartyId
::method counterpartyEntity; expose counterpartyEntity; return counterpartyEntity
::method reportingCurrency; expose reportingCurrency; return reportingCurrency
::method asOf; expose asOf; return asOf
::method positions; expose positions; return positions
::method sourceEvidenceRef; expose sourceEvidenceRef; return sourceEvidenceRef
::method mergerEvidenceRef; expose mergerEvidenceRef; return mergerEvidenceRef
::method authorityRef; expose authorityRef; return authorityRef
::method totalMarketValue; expose totalMarketValue; return totalMarketValue
::method inheritedCount; expose inheritedCount; return inheritedCount
::method issuerMarketValue
  expose positions
  use strict arg issuerEntity
  total=0
  do p over positions
    if p~issuerEntity=issuerEntity then total=total+p~marketValue
  end
  return total
::method issuerPct
  expose totalMarketValue
  use strict arg issuerEntity
  if totalMarketValue=0 then return 0
  return (self~issuerMarketValue(issuerEntity)/totalMarketValue)*100


::class VMMSyntheticRiskPolicy public
::method init
  expose policyId currency maxGrossSyntheticNotional maxSingleCounterpartyNotional maxWrongWayPct policyRef wrongWayEntities
  use strict arg policyId,currency,maxGrossSyntheticNotional,maxSingleCounterpartyNotional,maxWrongWayPct,policyRef
  if policyId="" | currency="" | policyRef="" then raise syntax 88.900 array("invalid VMM synthetic risk policy")
  if maxGrossSyntheticNotional<=0 | maxSingleCounterpartyNotional<=0 | maxWrongWayPct<0 | maxWrongWayPct>100 then raise syntax 88.900 array("invalid VMM synthetic risk economics")
  wrongWayEntities=.directory~new
::method policyId; expose policyId; return policyId
::method currency; expose currency; return currency
::method maxGrossSyntheticNotional; expose maxGrossSyntheticNotional; return maxGrossSyntheticNotional
::method maxSingleCounterpartyNotional; expose maxSingleCounterpartyNotional; return maxSingleCounterpartyNotional
::method maxWrongWayPct; expose maxWrongWayPct; return maxWrongWayPct
::method policyRef; expose policyRef; return policyRef
::method addWrongWayEntity
  expose wrongWayEntities
  use strict arg entityId,evidenceRef
  if entityId="" | evidenceRef="" then raise syntax 88.900 array("wrong-way entity requires evidence")
  wrongWayEntities[entityId]=evidenceRef; return self
::method isWrongWayEntity
  expose wrongWayEntities
  use strict arg entityId
  return wrongWayEntities~hasIndex(entityId)
::method wrongWayEvidence
  expose wrongWayEntities
  use strict arg entityId
  return wrongWayEntities[entityId]


::class VMMPortfolioLossProtectionTerms public
::method init
  expose termsId snapshotId currency protectedNotional attachmentLossPct exhaustionLossPct premiumAmount effectiveAt maturity
  use strict arg termsId,snapshotId,currency,protectedNotional,attachmentLossPct,exhaustionLossPct,premiumAmount,effectiveAt,maturity
  if termsId="" | snapshotId="" | currency="" | effectiveAt="" | maturity="" then raise syntax 88.900 array("invalid VMM synthetic terms")
  if protectedNotional<=0 | premiumAmount<0 then raise syntax 88.900 array("invalid VMM synthetic economics")
  if attachmentLossPct<0 | exhaustionLossPct<=attachmentLossPct | exhaustionLossPct>100 then raise syntax 88.900 array("invalid VMM loss-protection attachment/exhaustion")
  if effectiveAt>=maturity then raise syntax 88.900 array("VMM synthetic maturity must follow effective date")
::method termsId; expose termsId; return termsId
::method snapshotId; expose snapshotId; return snapshotId
::method currency; expose currency; return currency
::method protectedNotional; expose protectedNotional; return protectedNotional
::method attachmentLossPct; expose attachmentLossPct; return attachmentLossPct
::method exhaustionLossPct; expose exhaustionLossPct; return exhaustionLossPct
::method premiumAmount; expose premiumAmount; return premiumAmount
::method effectiveAt; expose effectiveAt; return effectiveAt
::method maturity; expose maturity; return maturity
::method productType; return "PORTFOLIO_LOSS_PROTECTION"
::method protectionFraction
  expose attachmentLossPct exhaustionLossPct
  use strict arg portfolioLossPct
  if portfolioLossPct<=attachmentLossPct then return 0
  if portfolioLossPct>=exhaustionLossPct then return 1
  return (portfolioLossPct-attachmentLossPct)/(exhaustionLossPct-attachmentLossPct)
::method claimEstimate
  expose protectedNotional
  use strict arg portfolioLossPct
  return protectedNotional*self~protectionFraction(portfolioLossPct)


::class VMMSyntheticOffer public
::method init
  expose offerId requestId counterpartyId terms validUntil offeredAt modelEvidenceRef marketDataEvidenceRef riskApprovalRef state
  use strict arg offerId,requestId,counterpartyId,terms,validUntil,offeredAt,modelEvidenceRef,marketDataEvidenceRef,riskApprovalRef
  if offerId="" | requestId="" | counterpartyId="" | validUntil="" | offeredAt="" | modelEvidenceRef="" | marketDataEvidenceRef="" | riskApprovalRef="" then raise syntax 88.900 array("invalid VMM synthetic offer")
  if \terms~isA(.VMMPortfolioLossProtectionTerms) then raise syntax 88.900 array("VMMPortfolioLossProtectionTerms required")
  if offeredAt>validUntil then raise syntax 88.900 array("VMM synthetic offer validity precedes offer time")
  state="OPEN"
::method offerId; expose offerId; return offerId
::method requestId; expose requestId; return requestId
::method counterpartyId; expose counterpartyId; return counterpartyId
::method terms; expose terms; return terms
::method validUntil; expose validUntil; return validUntil
::method offeredAt; expose offeredAt; return offeredAt
::method modelEvidenceRef; expose modelEvidenceRef; return modelEvidenceRef
::method marketDataEvidenceRef; expose marketDataEvidenceRef; return marketDataEvidenceRef
::method riskApprovalRef; expose riskApprovalRef; return riskApprovalRef
::method state; expose state; return state
::method accept
  expose state
  if state<>"OPEN" then raise syntax 88.900 array("VMM synthetic offer not open",state)
  state="ACCEPTED"; return self
::method cancel
  expose state
  if state="OPEN" then state="CANCELLED"
  return self


::class VMMSyntheticContract public
::method init
  expose contractId offerId counterpartyId terms initialReferenceValue masterAgreementRef collateralAgreementRef tradeDate state currentSnapshotId sourceContractId novationTargetContractId
  use strict arg contractId,offerId,counterpartyId,terms,initialReferenceValue,masterAgreementRef,collateralAgreementRef,tradeDate,sourceContractId=""
  if contractId="" | offerId="" | counterpartyId="" | masterAgreementRef="" | collateralAgreementRef="" | tradeDate="" then raise syntax 88.900 array("invalid VMM synthetic contract")
  if \terms~isA(.VMMPortfolioLossProtectionTerms) | initialReferenceValue<=0 then raise syntax 88.900 array("invalid VMM synthetic contract economics")
  state="ACTIVE"; currentSnapshotId=terms~snapshotId; novationTargetContractId=""
::method contractId; expose contractId; return contractId
::method offerId; expose offerId; return offerId
::method counterpartyId; expose counterpartyId; return counterpartyId
::method terms; expose terms; return terms
::method initialReferenceValue; expose initialReferenceValue; return initialReferenceValue
::method masterAgreementRef; expose masterAgreementRef; return masterAgreementRef
::method collateralAgreementRef; expose collateralAgreementRef; return collateralAgreementRef
::method tradeDate; expose tradeDate; return tradeDate
::method currentSnapshotId; expose currentSnapshotId; return currentSnapshotId
::method sourceContractId; expose sourceContractId; return sourceContractId
::method novationTargetContractId; expose novationTargetContractId; return novationTargetContractId
::method state; expose state; return state
::method replaceReferenceSnapshot
  expose currentSnapshotId state
  use strict arg snapshotId
  if state<>"ACTIVE" | snapshotId="" then raise syntax 88.900 array("cannot change reference snapshot on inactive synthetic contract")
  currentSnapshotId=snapshotId; return self
::method markNovated
  expose state novationTargetContractId
  use strict arg targetContractId
  if state<>"ACTIVE" | targetContractId="" then raise syntax 88.900 array("invalid synthetic novation state")
  state="NOVATED"; novationTargetContractId=targetContractId; return self
::method terminate; expose state; state="TERMINATED"; return self


::class VMMSyntheticValuation public
::method init
  expose valuationId contractId currentPortfolioValue initialReferenceValue portfolioLossPct protectionFraction vmmLiabilityMtm valuedAt marketDataEvidenceRef modelEvidenceRef valuationAuthority
  use strict arg valuationId,contractId,currentPortfolioValue,initialReferenceValue,portfolioLossPct,protectionFraction,vmmLiabilityMtm,valuedAt,marketDataEvidenceRef,modelEvidenceRef,valuationAuthority
  if valuationId="" | contractId="" | valuedAt="" | marketDataEvidenceRef="" | modelEvidenceRef="" | valuationAuthority="" then raise syntax 88.900 array("invalid VMM synthetic valuation")
  if currentPortfolioValue<0 | initialReferenceValue<=0 | protectionFraction<0 | protectionFraction>1 | vmmLiabilityMtm<0 then raise syntax 88.900 array("invalid VMM synthetic valuation economics")
::method valuationId; expose valuationId; return valuationId
::method contractId; expose contractId; return contractId
::method currentPortfolioValue; expose currentPortfolioValue; return currentPortfolioValue
::method initialReferenceValue; expose initialReferenceValue; return initialReferenceValue
::method portfolioLossPct; expose portfolioLossPct; return portfolioLossPct
::method protectionFraction; expose protectionFraction; return protectionFraction
::method vmmLiabilityMtm; expose vmmLiabilityMtm; return vmmLiabilityMtm
::method valuedAt; expose valuedAt; return valuedAt
::method marketDataEvidenceRef; expose marketDataEvidenceRef; return marketDataEvidenceRef
::method modelEvidenceRef; expose modelEvidenceRef; return modelEvidenceRef
::method valuationAuthority; expose valuationAuthority; return valuationAuthority


::class VMMSyntheticCollateralTerms public
::method init
  expose termsId currency threshold minimumTransferAmount independentAmount collateralPolicyRef
  use strict arg termsId,currency,threshold,minimumTransferAmount,independentAmount,collateralPolicyRef
  if termsId="" | currency="" | collateralPolicyRef="" | threshold<0 | minimumTransferAmount<0 | independentAmount<0 then raise syntax 88.900 array("invalid VMM synthetic collateral terms")
::method termsId; expose termsId; return termsId
::method currency; expose currency; return currency
::method threshold; expose threshold; return threshold
::method minimumTransferAmount; expose minimumTransferAmount; return minimumTransferAmount
::method independentAmount; expose independentAmount; return independentAmount
::method collateralPolicyRef; expose collateralPolicyRef; return collateralPolicyRef


::class VMMVariationMarginCall public
::method init
  expose callId contractId valuationId currency amount calledAt authorityRef state
  use strict arg callId,contractId,valuationId,currency,amount,calledAt,authorityRef
  if callId="" | contractId="" | valuationId="" | currency="" | calledAt="" | authorityRef="" | amount<0 then raise syntax 88.900 array("invalid VMM variation margin call")
  if amount=0 then state="NOT_REQUIRED"; else state="OPEN"
::method callId; expose callId; return callId
::method contractId; expose contractId; return contractId
::method valuationId; expose valuationId; return valuationId
::method currency; expose currency; return currency
::method amount; expose amount; return amount
::method calledAt; expose calledAt; return calledAt
::method authorityRef; expose authorityRef; return authorityRef
::method state; expose state; return state
::method satisfy
  expose state
  if state="OPEN" then state="SATISFIED"
  return self


::class VMMSyntheticCollateralTransfer public
::method init
  expose transferId contractId callId currency amount direction custodianRef controlEvidenceRef transferredAt authorityRef
  use strict arg transferId,contractId,callId,currency,amount,direction,custodianRef,controlEvidenceRef,transferredAt,authorityRef
  if transferId="" | contractId="" | callId="" | currency="" | custodianRef="" | controlEvidenceRef="" | transferredAt="" | authorityRef="" then raise syntax 88.900 array("invalid VMM synthetic collateral transfer")
  if amount<=0 | direction<>"VMM_TO_COUNTERPARTY" then raise syntax 88.900 array("invalid VMM synthetic collateral transfer economics/direction")
::method transferId; expose transferId; return transferId
::method contractId; expose contractId; return contractId
::method callId; expose callId; return callId
::method currency; expose currency; return currency
::method amount; expose amount; return amount
::method direction; expose direction; return direction
::method custodianRef; expose custodianRef; return custodianRef
::method controlEvidenceRef; expose controlEvidenceRef; return controlEvidenceRef
::method transferredAt; expose transferredAt; return transferredAt
::method authorityRef; expose authorityRef; return authorityRef


::class VMMSyntheticLifecyclePolicy public
::method init
  expose policyId currency maxSubstitutionValueDriftPct maxXvaPctOfNotional minimumHedgeEffectivenessPct policyRef
  use strict arg policyId,currency,maxSubstitutionValueDriftPct,maxXvaPctOfNotional,minimumHedgeEffectivenessPct,policyRef
  if policyId="" | currency="" | policyRef="" then raise syntax 88.900 array("invalid VMM synthetic lifecycle policy")
  if maxSubstitutionValueDriftPct<0 | maxSubstitutionValueDriftPct>100 | maxXvaPctOfNotional<0 | maxXvaPctOfNotional>100 | minimumHedgeEffectivenessPct<0 | minimumHedgeEffectivenessPct>100 then raise syntax 88.900 array("invalid VMM synthetic lifecycle policy economics")
::method policyId; expose policyId; return policyId
::method currency; expose currency; return currency
::method maxSubstitutionValueDriftPct; expose maxSubstitutionValueDriftPct; return maxSubstitutionValueDriftPct
::method maxXvaPctOfNotional; expose maxXvaPctOfNotional; return maxXvaPctOfNotional
::method minimumHedgeEffectivenessPct; expose minimumHedgeEffectivenessPct; return minimumHedgeEffectivenessPct
::method policyRef; expose policyRef; return policyRef


::class VMMSyntheticPremiumPeriod public
::method init
  expose periodId currency accrualStart accrualEnd dueAt amount scheduleEvidenceRef
  use strict arg periodId,currency,accrualStart,accrualEnd,dueAt,amount,scheduleEvidenceRef
  if periodId="" | currency="" | accrualStart="" | accrualEnd="" | dueAt="" | scheduleEvidenceRef="" | amount<0 then raise syntax 88.900 array("invalid VMM synthetic premium period")
  if accrualStart>=accrualEnd | accrualEnd>dueAt then raise syntax 88.900 array("invalid VMM synthetic premium period dates",periodId)
::method periodId; expose periodId; return periodId
::method currency; expose currency; return currency
::method accrualStart; expose accrualStart; return accrualStart
::method accrualEnd; expose accrualEnd; return accrualEnd
::method dueAt; expose dueAt; return dueAt
::method amount; expose amount; return amount
::method scheduleEvidenceRef; expose scheduleEvidenceRef; return scheduleEvidenceRef


::class VMMSyntheticPremiumAccrual public
::method init
  expose accrualId contractId periodId currency elapsedDays totalDays cumulativeAccruedAmount accruedAt evidenceRef authorityRef
  use strict arg accrualId,contractId,periodId,currency,elapsedDays,totalDays,cumulativeAccruedAmount,accruedAt,evidenceRef,authorityRef
  if accrualId="" | contractId="" | periodId="" | currency="" | accruedAt="" | evidenceRef="" | authorityRef="" then raise syntax 88.900 array("invalid VMM synthetic premium accrual")
  if totalDays<=0 | elapsedDays<0 | elapsedDays>totalDays | cumulativeAccruedAmount<0 then raise syntax 88.900 array("invalid VMM synthetic premium accrual economics")
::method accrualId; expose accrualId; return accrualId
::method contractId; expose contractId; return contractId
::method periodId; expose periodId; return periodId
::method currency; expose currency; return currency
::method elapsedDays; expose elapsedDays; return elapsedDays
::method totalDays; expose totalDays; return totalDays
::method cumulativeAccruedAmount; expose cumulativeAccruedAmount; return cumulativeAccruedAmount
::method accruedAt; expose accruedAt; return accruedAt
::method evidenceRef; expose evidenceRef; return evidenceRef
::method authorityRef; expose authorityRef; return authorityRef


::class VMMSyntheticPremiumSettlement public
::method init
  expose settlementId contractId periodId currency amount payerEntity payeeEntity paymentEvidenceRef settledAt authorityRef
  use strict arg settlementId,contractId,periodId,currency,amount,payerEntity,payeeEntity,paymentEvidenceRef,settledAt,authorityRef
  if settlementId="" | contractId="" | periodId="" | currency="" | payerEntity="" | payeeEntity="" | paymentEvidenceRef="" | settledAt="" | authorityRef="" | amount<=0 then raise syntax 88.900 array("invalid VMM synthetic premium settlement")
  if payeeEntity<>"VECTOR_MERIDIAN_MARKETS_LTD" then raise syntax 88.900 array("synthetic premium must settle to VMM legal entity",payeeEntity)
::method settlementId; expose settlementId; return settlementId
::method contractId; expose contractId; return contractId
::method periodId; expose periodId; return periodId
::method currency; expose currency; return currency
::method amount; expose amount; return amount
::method payerEntity; expose payerEntity; return payerEntity
::method payeeEntity; expose payeeEntity; return payeeEntity
::method paymentEvidenceRef; expose paymentEvidenceRef; return paymentEvidenceRef
::method settledAt; expose settledAt; return settledAt
::method authorityRef; expose authorityRef; return authorityRef


::class VMMSyntheticInitialMarginTerms public
::method init
  expose termsId currency requiredAmount eligibleAssetClass maxHaircutBps collateralPolicyRef
  use strict arg termsId,currency,requiredAmount,eligibleAssetClass,maxHaircutBps,collateralPolicyRef
  if termsId="" | currency="" | eligibleAssetClass="" | collateralPolicyRef="" | requiredAmount<0 | maxHaircutBps<0 | maxHaircutBps>=10000 then raise syntax 88.900 array("invalid VMM synthetic initial margin terms")
::method termsId; expose termsId; return termsId
::method currency; expose currency; return currency
::method requiredAmount; expose requiredAmount; return requiredAmount
::method eligibleAssetClass; expose eligibleAssetClass; return eligibleAssetClass
::method maxHaircutBps; expose maxHaircutBps; return maxHaircutBps
::method collateralPolicyRef; expose collateralPolicyRef; return collateralPolicyRef


::class VMMSyntheticInitialMarginTransfer public
::method init
  expose transferId contractId currency assetRef assetClass grossMarketValue haircutBps recognizedValue postingEntity beneficiaryEntity custodianRef controlEvidenceRef transferredAt authorityRef
  use strict arg transferId,contractId,currency,assetRef,assetClass,grossMarketValue,haircutBps,postingEntity,beneficiaryEntity,custodianRef,controlEvidenceRef,transferredAt,authorityRef
  if transferId="" | contractId="" | currency="" | assetRef="" | assetClass="" | postingEntity="" | beneficiaryEntity="" | custodianRef="" | controlEvidenceRef="" | transferredAt="" | authorityRef="" then raise syntax 88.900 array("invalid VMM synthetic initial margin transfer")
  if postingEntity<>"VECTOR_MERIDIAN_MARKETS_LTD" | grossMarketValue<=0 | haircutBps<0 | haircutBps>=10000 then raise syntax 88.900 array("invalid VMM synthetic initial margin economics/posting entity")
  recognizedValue=grossMarketValue*(10000-haircutBps)/10000
::method transferId; expose transferId; return transferId
::method contractId; expose contractId; return contractId
::method currency; expose currency; return currency
::method assetRef; expose assetRef; return assetRef
::method assetClass; expose assetClass; return assetClass
::method grossMarketValue; expose grossMarketValue; return grossMarketValue
::method haircutBps; expose haircutBps; return haircutBps
::method recognizedValue; expose recognizedValue; return recognizedValue
::method postingEntity; expose postingEntity; return postingEntity
::method beneficiaryEntity; expose beneficiaryEntity; return beneficiaryEntity
::method custodianRef; expose custodianRef; return custodianRef
::method controlEvidenceRef; expose controlEvidenceRef; return controlEvidenceRef
::method transferredAt; expose transferredAt; return transferredAt
::method authorityRef; expose authorityRef; return authorityRef


::class VMMReferencePortfolioChange public
::method init
  expose changeId contractId changeType fromSnapshotId toSnapshotId effectiveAt changeEvidenceRef riskApprovalRef authorityRef valueDriftPct
  use strict arg changeId,contractId,changeType,fromSnapshotId,toSnapshotId,effectiveAt,changeEvidenceRef,riskApprovalRef,authorityRef,valueDriftPct
  if changeId="" | contractId="" | fromSnapshotId="" | toSnapshotId="" | effectiveAt="" | changeEvidenceRef="" | riskApprovalRef="" | authorityRef="" then raise syntax 88.900 array("invalid VMM reference portfolio change")
  if changeType<>"CLIENT_SUBSTITUTION" & changeType<>"CORPORATE_ACTION" then raise syntax 88.900 array("invalid VMM reference portfolio change type",changeType)
  if fromSnapshotId=toSnapshotId | valueDriftPct<0 then raise syntax 88.900 array("invalid VMM reference portfolio change economics")
::method changeId; expose changeId; return changeId
::method contractId; expose contractId; return contractId
::method changeType; expose changeType; return changeType
::method fromSnapshotId; expose fromSnapshotId; return fromSnapshotId
::method toSnapshotId; expose toSnapshotId; return toSnapshotId
::method effectiveAt; expose effectiveAt; return effectiveAt
::method changeEvidenceRef; expose changeEvidenceRef; return changeEvidenceRef
::method riskApprovalRef; expose riskApprovalRef; return riskApprovalRef
::method authorityRef; expose authorityRef; return authorityRef
::method valueDriftPct; expose valueDriftPct; return valueDriftPct


::class VMMSyntheticNovation public
::method init
  expose novationId sourceContractId targetContractId oldCounterpartyId newCounterpartyId replacementSnapshotId novatedAt novationAgreementRef outgoingAuthority incomingAuthority vmmAuthority
  use strict arg novationId,sourceContractId,targetContractId,oldCounterpartyId,newCounterpartyId,replacementSnapshotId,novatedAt,novationAgreementRef,outgoingAuthority,incomingAuthority,vmmAuthority
  if novationId="" | sourceContractId="" | targetContractId="" | oldCounterpartyId="" | newCounterpartyId="" | replacementSnapshotId="" | novatedAt="" | novationAgreementRef="" | outgoingAuthority="" | incomingAuthority="" | vmmAuthority="" then raise syntax 88.900 array("invalid VMM synthetic novation")
  if sourceContractId=targetContractId | oldCounterpartyId=newCounterpartyId then raise syntax 88.900 array("synthetic novation requires changed contract and counterparty")
::method novationId; expose novationId; return novationId
::method sourceContractId; expose sourceContractId; return sourceContractId
::method targetContractId; expose targetContractId; return targetContractId
::method oldCounterpartyId; expose oldCounterpartyId; return oldCounterpartyId
::method newCounterpartyId; expose newCounterpartyId; return newCounterpartyId
::method replacementSnapshotId; expose replacementSnapshotId; return replacementSnapshotId
::method novatedAt; expose novatedAt; return novatedAt
::method novationAgreementRef; expose novationAgreementRef; return novationAgreementRef
::method outgoingAuthority; expose outgoingAuthority; return outgoingAuthority
::method incomingAuthority; expose incomingAuthority; return incomingAuthority
::method vmmAuthority; expose vmmAuthority; return vmmAuthority


::class VMMSyntheticXVAReport public
::method init
  expose reportId contractId valuationId currency cvaAmount fvaAmount calculatedAt creditEvidenceRef fundingCurveEvidenceRef modelEvidenceRef authorityRef
  use strict arg reportId,contractId,valuationId,currency,cvaAmount,fvaAmount,calculatedAt,creditEvidenceRef,fundingCurveEvidenceRef,modelEvidenceRef,authorityRef
  if reportId="" | contractId="" | valuationId="" | currency="" | calculatedAt="" | creditEvidenceRef="" | fundingCurveEvidenceRef="" | modelEvidenceRef="" | authorityRef="" then raise syntax 88.900 array("invalid VMM synthetic XVA report")
  if cvaAmount<0 | fvaAmount<0 then raise syntax 88.900 array("invalid VMM synthetic XVA amounts")
::method reportId; expose reportId; return reportId
::method contractId; expose contractId; return contractId
::method valuationId; expose valuationId; return valuationId
::method currency; expose currency; return currency
::method cvaAmount; expose cvaAmount; return cvaAmount
::method fvaAmount; expose fvaAmount; return fvaAmount
::method totalXva; expose cvaAmount fvaAmount; return cvaAmount+fvaAmount
::method calculatedAt; expose calculatedAt; return calculatedAt
::method creditEvidenceRef; expose creditEvidenceRef; return creditEvidenceRef
::method fundingCurveEvidenceRef; expose fundingCurveEvidenceRef; return fundingCurveEvidenceRef
::method modelEvidenceRef; expose modelEvidenceRef; return modelEvidenceRef
::method authorityRef; expose authorityRef; return authorityRef


::class VMMSyntheticHedgeEffectiveness public
::method init
  expose assessmentId contractId fromValuationId toValuationId currency liabilityChange hedgePnl offsetPct residualAmount minimumRequiredPct status assessedAt methodologyEvidenceRef marketDataEvidenceRef authorityRef
  use strict arg assessmentId,contractId,fromValuationId,toValuationId,currency,liabilityChange,hedgePnl,minimumRequiredPct,assessedAt,methodologyEvidenceRef,marketDataEvidenceRef,authorityRef
  if assessmentId="" | contractId="" | fromValuationId="" | toValuationId="" | currency="" | assessedAt="" | methodologyEvidenceRef="" | marketDataEvidenceRef="" | authorityRef="" then raise syntax 88.900 array("invalid VMM synthetic hedge-effectiveness assessment")
  if minimumRequiredPct<0 | minimumRequiredPct>100 then raise syntax 88.900 array("invalid VMM hedge-effectiveness threshold")
  residualAmount=liabilityChange-hedgePnl
  if liabilityChange=0 then do
    if hedgePnl=0 then offsetPct=100; else offsetPct=0
  end
  else offsetPct=(hedgePnl/liabilityChange)*100
  if offsetPct>=minimumRequiredPct & offsetPct<=200 then status="EFFECTIVE"; else status="INEFFECTIVE"
::method assessmentId; expose assessmentId; return assessmentId
::method contractId; expose contractId; return contractId
::method fromValuationId; expose fromValuationId; return fromValuationId
::method toValuationId; expose toValuationId; return toValuationId
::method currency; expose currency; return currency
::method liabilityChange; expose liabilityChange; return liabilityChange
::method hedgePnl; expose hedgePnl; return hedgePnl
::method offsetPct; expose offsetPct; return offsetPct
::method residualAmount; expose residualAmount; return residualAmount
::method minimumRequiredPct; expose minimumRequiredPct; return minimumRequiredPct
::method status; expose status; return status
::method assessedAt; expose assessedAt; return assessedAt
::method methodologyEvidenceRef; expose methodologyEvidenceRef; return methodologyEvidenceRef
::method marketDataEvidenceRef; expose marketDataEvidenceRef; return marketDataEvidenceRef
::method authorityRef; expose authorityRef; return authorityRef


::class VMMInstitutionalSyntheticService public
::method init
  expose vmm counterparties snapshots riskPolicies lifecyclePolicies offers contracts valuations collateralTerms marginCalls collateralTransfers postedCollateral premiumSchedules premiumPeriodIndex premiumAccruals premiumAccruedByPeriod premiumAccruedByContract premiumSettlements premiumSettledByPeriod premiumSettledByContract initialMarginTerms initialMarginTransfers initialMarginRecognizedByContract portfolioChanges novations xvaReports hedgeEffectiveness
  use strict arg vmm
  if vmm==.nil | \vmm~isA(.VectorMeridianMarkets) then raise syntax 88.900 array("VMM institutional synthetic service requires VectorMeridianMarkets engine")
  counterparties=.directory~new; snapshots=.directory~new; riskPolicies=.directory~new; lifecyclePolicies=.directory~new; offers=.directory~new; contracts=.directory~new; valuations=.directory~new; collateralTerms=.directory~new; marginCalls=.directory~new; collateralTransfers=.directory~new; postedCollateral=.directory~new
  premiumSchedules=.directory~new; premiumPeriodIndex=.directory~new; premiumAccruals=.directory~new; premiumAccruedByPeriod=.directory~new; premiumAccruedByContract=.directory~new; premiumSettlements=.directory~new; premiumSettledByPeriod=.directory~new; premiumSettledByContract=.directory~new
  initialMarginTerms=.directory~new; initialMarginTransfers=.directory~new; initialMarginRecognizedByContract=.directory~new; portfolioChanges=.directory~new; novations=.directory~new; xvaReports=.directory~new; hedgeEffectiveness=.directory~new
::method vmm; expose vmm; return vmm
::method registerCounterparty
  expose vmm counterparties
  use strict arg c
  if \c~isA(.VMMInstitutionalCounterparty) then raise syntax 88.900 array("VMMInstitutionalCounterparty required")
  if counterparties~hasIndex(c~counterpartyId) then raise syntax 88.900 array("duplicate VMM institutional counterparty",c~counterpartyId)
  counterparties[c~counterpartyId]=c
  vmm~journal~put("synthetic:counterparty:"||c~counterpartyId,c,"VMM_SYNTHETIC_COUNTERPARTY_ONBOARDED",self~meta("entity",c~legalEntity))
  return c
::method counterparty
  expose counterparties
  use strict arg counterpartyId
  return counterparties[counterpartyId]
::method registerPortfolioSnapshot
  expose vmm counterparties snapshots
  use strict arg s
  if \s~isA(.VMMPortfolioSnapshot) then raise syntax 88.900 array("VMMPortfolioSnapshot required")
  if snapshots~hasIndex(s~snapshotId) then raise syntax 88.900 array("duplicate VMM portfolio snapshot",s~snapshotId)
  c=counterparties[s~counterpartyId]
  if c==.nil | c~status<>"ACTIVE" then raise syntax 88.900 array("portfolio snapshot requires active VMM institutional counterparty",s~counterpartyId)
  if c~legalEntity<>s~counterpartyEntity then raise syntax 88.900 array("portfolio snapshot legal entity mismatch")
  snapshots[s~snapshotId]=s
  vmm~journal~put("synthetic:portfolio:"||s~snapshotId,s,"VMM_SYNTHETIC_PORTFOLIO_SNAPSHOT_ACCEPTED",self~meta("counterparty",s~counterpartyId))
  return s
::method portfolioSnapshot
  expose snapshots
  use strict arg snapshotId
  return snapshots[snapshotId]
::method setRiskPolicy
  expose vmm riskPolicies
  use strict arg p,authorityRef
  if \p~isA(.VMMSyntheticRiskPolicy) | authorityRef="" then raise syntax 88.900 array("VMMSyntheticRiskPolicy and authority required")
  riskPolicies[p~currency]=p
  vmm~journal~put("synthetic:riskPolicy:"||p~currency,p,"VMM_SYNTHETIC_RISK_POLICY_SET",self~meta("authority",authorityRef))
  return p
::method setLifecyclePolicy
  expose vmm lifecyclePolicies
  use strict arg p,authorityRef
  if \p~isA(.VMMSyntheticLifecyclePolicy) | authorityRef="" then raise syntax 88.900 array("VMMSyntheticLifecyclePolicy and authority required")
  lifecyclePolicies[p~currency]=p
  vmm~journal~put("synthetic:lifecyclePolicy:"||p~currency,p,"VMM_SYNTHETIC_LIFECYCLE_POLICY_SET",self~meta("authority",authorityRef))
  return p
::method lifecyclePolicy
  expose lifecyclePolicies
  use strict arg currency
  return lifecyclePolicies[currency]
::method createOffer
  expose vmm counterparties snapshots riskPolicies offers contracts
  use strict arg offerId,requestId,counterpartyId,snapshotId,currency,protectedNotional,attachmentLossPct,exhaustionLossPct,premiumAmount,effectiveAt,maturity,validUntil,offeredAt,modelEvidenceRef,marketDataEvidenceRef,riskApprovalRef
  if offers~hasIndex(offerId) then raise syntax 88.900 array("duplicate VMM synthetic offer",offerId)
  c=counterparties[counterpartyId]; if c==.nil | c~status<>"ACTIVE" then raise syntax 88.900 array("synthetic offer requires active institutional counterparty")
  s=snapshots[snapshotId]; if s==.nil then raise syntax 88.900 array("unknown VMM portfolio snapshot",snapshotId)
  if s~counterpartyId<>counterpartyId | s~reportingCurrency<>currency then raise syntax 88.900 array("synthetic offer/snapshot counterparty or currency mismatch")
  p=riskPolicies[currency]; if p==.nil then raise syntax 88.900 array("no VMM synthetic risk policy for currency",currency)
  self~checkOfferRisk(p,counterpartyId,s,protectedNotional)
  terms=.VMMPortfolioLossProtectionTerms~new("TERMS-"||offerId,snapshotId,currency,protectedNotional,attachmentLossPct,exhaustionLossPct,premiumAmount,effectiveAt,maturity)
  o=.VMMSyntheticOffer~new(offerId,requestId,counterpartyId,terms,validUntil,offeredAt,modelEvidenceRef,marketDataEvidenceRef,riskApprovalRef)
  offers[offerId]=o
  vmm~journal~put("synthetic:offer:"||offerId,o,"VMM_SYNTHETIC_OFFER_CREATED",self~meta("counterparty",counterpartyId))
  return o
::method offer
  expose offers
  use strict arg offerId
  return offers[offerId]
::method acceptOffer
  expose vmm counterparties snapshots offers contracts collateralTerms postedCollateral
  use strict arg contractId,offerId,acceptedAt,acceptingEntity,acceptanceAuthority
  if contracts~hasIndex(contractId) then raise syntax 88.900 array("duplicate VMM synthetic contract",contractId)
  o=offers[offerId]; if o==.nil then raise syntax 88.900 array("unknown VMM synthetic offer",offerId)
  c=counterparties[o~counterpartyId]; if c==.nil | c~status<>"ACTIVE" then raise syntax 88.900 array("institutional counterparty not active at acceptance")
  if c~legalEntity<>acceptingEntity then raise syntax 88.900 array("synthetic offer acceptance legal entity mismatch")
  if acceptanceAuthority="" then raise syntax 88.900 array("synthetic offer acceptance authority required")
  if acceptedAt>o~validUntil then raise syntax 88.900 array("VMM synthetic offer expired before acceptance",offerId)
  s=snapshots[o~terms~snapshotId]; if s==.nil then raise syntax 88.900 array("synthetic offer lost reference snapshot")
  o~accept
  k=.VMMSyntheticContract~new(contractId,offerId,o~counterpartyId,o~terms,s~totalMarketValue,c~masterAgreementRef,c~collateralAgreementRef,acceptedAt)
  contracts[contractId]=k; postedCollateral[contractId]=0
  vmm~journal~put("synthetic:contract:"||contractId,k,"VMM_SYNTHETIC_CONTRACT_BOOKED",self~meta("counterparty",o~counterpartyId))
  return k
::method contract
  expose contracts
  use strict arg contractId
  return contracts[contractId]
::method setCollateralTerms
  expose vmm contracts collateralTerms
  use strict arg contractId,terms,authorityRef
  if contracts[contractId]==.nil then raise syntax 88.900 array("unknown VMM synthetic contract",contractId)
  if \terms~isA(.VMMSyntheticCollateralTerms) | authorityRef="" then raise syntax 88.900 array("synthetic collateral terms and authority required")
  if terms~currency<>contracts[contractId]~terms~currency then raise syntax 88.900 array("synthetic collateral currency mismatch")
  collateralTerms[contractId]=terms
  vmm~journal~put("synthetic:collateralTerms:"||contractId,terms,"VMM_SYNTHETIC_COLLATERAL_TERMS_SET",self~meta("authority",authorityRef))
  return terms
::method valueContract
  expose vmm contracts valuations
  use strict arg valuationId,contractId,currentPortfolioValue,valuedAt,marketDataEvidenceRef,modelEvidenceRef,valuationAuthority
  if valuations~hasIndex(valuationId) then raise syntax 88.900 array("duplicate VMM synthetic valuation",valuationId)
  k=contracts[contractId]; if k==.nil | k~state<>"ACTIVE" then raise syntax 88.900 array("synthetic valuation requires active contract",contractId)
  if currentPortfolioValue<0 then raise syntax 88.900 array("invalid synthetic current portfolio value")
  initial=k~initialReferenceValue
  lossPct=((initial-currentPortfolioValue)/initial)*100
  fraction=k~terms~protectionFraction(lossPct); mtm=k~terms~claimEstimate(lossPct)
  x=.VMMSyntheticValuation~new(valuationId,contractId,currentPortfolioValue,initial,lossPct,fraction,mtm,valuedAt,marketDataEvidenceRef,modelEvidenceRef,valuationAuthority)
  valuations[valuationId]=x
  vmm~journal~put("synthetic:valuation:"||valuationId,x,"VMM_SYNTHETIC_VALUATION_RECORDED",self~meta("contract",contractId))
  return x
::method valuation
  expose valuations
  use strict arg valuationId
  return valuations[valuationId]
::method issueVariationMarginCall
  expose vmm contracts valuations collateralTerms marginCalls postedCollateral
  use strict arg callId,contractId,valuationId,calledAt,authorityRef
  if marginCalls~hasIndex(callId) then raise syntax 88.900 array("duplicate VMM variation margin call",callId)
  k=contracts[contractId]; if k==.nil | k~state<>"ACTIVE" then raise syntax 88.900 array("unknown/inactive synthetic contract",contractId)
  val=valuations[valuationId]; if val==.nil | val~contractId<>contractId then raise syntax 88.900 array("synthetic margin call valuation mismatch")
  terms=collateralTerms[contractId]; if terms==.nil then raise syntax 88.900 array("synthetic collateral terms required before margin call")
  posted=self~number(postedCollateral[contractId])
  amount=max(0,val~vmmLiabilityMtm+terms~independentAmount-terms~threshold-posted)
  if amount<terms~minimumTransferAmount then amount=0
  c=.VMMVariationMarginCall~new(callId,contractId,valuationId,terms~currency,amount,calledAt,authorityRef); marginCalls[callId]=c
  vmm~journal~put("synthetic:marginCall:"||callId,c,"VMM_SYNTHETIC_VARIATION_MARGIN_CALLED",self~meta("contract",contractId))
  return c
::method marginCall
  expose marginCalls
  use strict arg callId
  return marginCalls[callId]
::method recordCollateralTransfer
  expose vmm contracts marginCalls collateralTransfers postedCollateral
  use strict arg transfer
  if \transfer~isA(.VMMSyntheticCollateralTransfer) then raise syntax 88.900 array("VMMSyntheticCollateralTransfer required")
  if collateralTransfers~hasIndex(transfer~transferId) then raise syntax 88.900 array("duplicate VMM synthetic collateral transfer",transfer~transferId)
  call=marginCalls[transfer~callId]; if call==.nil | call~contractId<>transfer~contractId then raise syntax 88.900 array("synthetic collateral transfer/call mismatch")
  if transfer~currency<>call~currency then raise syntax 88.900 array("synthetic collateral transfer currency mismatch")
  if call~state<>"OPEN" then raise syntax 88.900 array("synthetic margin call not open",call~state)
  if transfer~amount<call~amount then raise syntax 88.900 array("partial synthetic collateral transfers not supported in v0.5")
  collateralTransfers[transfer~transferId]=transfer
  postedCollateral[transfer~contractId]=self~number(postedCollateral[transfer~contractId])+transfer~amount
  call~satisfy
  vmm~journal~put("synthetic:collateralTransfer:"||transfer~transferId,transfer,"VMM_SYNTHETIC_COLLATERAL_POSTED",self~meta("contract",transfer~contractId))
  return transfer
::method collateralPosted
  expose postedCollateral
  use strict arg contractId
  return self~number(postedCollateral[contractId])
::method setPremiumSchedule
  expose vmm contracts premiumSchedules premiumPeriodIndex premiumAccruedByContract premiumSettledByContract
  use strict arg contractId,periods,authorityRef
  k=contracts[contractId]; if k==.nil | k~state<>"ACTIVE" then raise syntax 88.900 array("synthetic premium schedule requires active contract",contractId)
  if authorityRef="" | \periods~isA(.Array) | periods~items=0 then raise syntax 88.900 array("synthetic premium schedule and authority required")
  total=0; seen=.directory~new
  do p over periods
    if \p~isA(.VMMSyntheticPremiumPeriod) then raise syntax 88.900 array("VMMSyntheticPremiumPeriod required")
    if p~currency<>k~terms~currency then raise syntax 88.900 array("synthetic premium schedule currency mismatch",p~periodId)
    if seen~hasIndex(p~periodId) then raise syntax 88.900 array("duplicate synthetic premium period",p~periodId)
    seen[p~periodId]=.true; total=total+p~amount
  end
  if abs(total-k~terms~premiumAmount)>0.000001 then raise syntax 88.900 array("synthetic premium schedule must equal contracted premium",total,k~terms~premiumAmount)
  if premiumSchedules~hasIndex(contractId) then raise syntax 88.900 array("synthetic premium schedule already fixed",contractId)
  premiumSchedules[contractId]=periods; premiumAccruedByContract[contractId]=0; premiumSettledByContract[contractId]=0
  do p over periods
    premiumPeriodIndex[contractId||"|"||p~periodId]=p
  end
  vmm~journal~put("synthetic:premiumSchedule:"||contractId,periods,"VMM_SYNTHETIC_PREMIUM_SCHEDULE_FIXED",self~meta("authority",authorityRef))
  return periods
::method premiumPeriod
  expose premiumPeriodIndex
  use strict arg contractId,periodId
  return premiumPeriodIndex[contractId||"|"||periodId]
::method recordPremiumAccrual
  expose vmm contracts premiumPeriodIndex premiumAccruals premiumAccruedByPeriod premiumAccruedByContract
  use strict arg accrualId,contractId,periodId,elapsedDays,totalDays,accruedAt,evidenceRef,authorityRef
  if premiumAccruals~hasIndex(accrualId) then raise syntax 88.900 array("duplicate VMM synthetic premium accrual",accrualId)
  k=contracts[contractId]; if k==.nil | (k~state<>"ACTIVE" & k~state<>"NOVATED") then raise syntax 88.900 array("unknown synthetic contract for premium accrual",contractId)
  p=premiumPeriodIndex[contractId||"|"||periodId]; if p==.nil then raise syntax 88.900 array("unknown synthetic premium period",periodId)
  if totalDays<=0 | elapsedDays<0 | elapsedDays>totalDays then raise syntax 88.900 array("invalid synthetic premium accrual day fraction")
  amount=p~amount*elapsedDays/totalDays
  prior=self~number(premiumAccruedByPeriod[contractId||"|"||periodId])
  if amount+0.000001<prior then raise syntax 88.900 array("synthetic premium cumulative accrual cannot reverse",amount,prior)
  x=.VMMSyntheticPremiumAccrual~new(accrualId,contractId,periodId,p~currency,elapsedDays,totalDays,amount,accruedAt,evidenceRef,authorityRef)
  premiumAccruals[accrualId]=x; premiumAccruedByPeriod[contractId||"|"||periodId]=amount; premiumAccruedByContract[contractId]=self~number(premiumAccruedByContract[contractId])+(amount-prior)
  vmm~journal~put("synthetic:premiumAccrual:"||accrualId,x,"VMM_SYNTHETIC_PREMIUM_ACCRUED",self~meta("contract",contractId))
  return x
::method premiumAccrued
  expose premiumAccruedByContract
  use strict arg contractId
  return self~number(premiumAccruedByContract[contractId])
::method recordPremiumSettlement
  expose vmm contracts counterparties premiumPeriodIndex premiumSettlements premiumSettledByPeriod premiumSettledByContract
  use strict arg settlement
  if \settlement~isA(.VMMSyntheticPremiumSettlement) then raise syntax 88.900 array("VMMSyntheticPremiumSettlement required")
  if premiumSettlements~hasIndex(settlement~settlementId) then raise syntax 88.900 array("duplicate VMM synthetic premium settlement",settlement~settlementId)
  k=contracts[settlement~contractId]; if k==.nil then raise syntax 88.900 array("unknown synthetic contract for premium settlement",settlement~contractId)
  p=premiumPeriodIndex[settlement~contractId||"|"||settlement~periodId]; if p==.nil then raise syntax 88.900 array("unknown synthetic premium period",settlement~periodId)
  c=counterparties[k~counterpartyId]; if c==.nil | settlement~payerEntity<>c~legalEntity then raise syntax 88.900 array("synthetic premium payer legal entity mismatch")
  if settlement~currency<>p~currency then raise syntax 88.900 array("synthetic premium settlement currency mismatch")
  key=settlement~contractId||"|"||settlement~periodId; prior=self~number(premiumSettledByPeriod[key])
  if prior+settlement~amount>p~amount+0.000001 then raise syntax 88.900 array("synthetic premium over-settlement rejected",prior+settlement~amount,p~amount)
  premiumSettlements[settlement~settlementId]=settlement; premiumSettledByPeriod[key]=prior+settlement~amount; premiumSettledByContract[settlement~contractId]=self~number(premiumSettledByContract[settlement~contractId])+settlement~amount
  vmm~journal~put("synthetic:premiumSettlement:"||settlement~settlementId,settlement,"VMM_SYNTHETIC_PREMIUM_SETTLED",self~meta("contract",settlement~contractId))
  return settlement
::method premiumSettled
  expose premiumSettledByContract
  use strict arg contractId
  return self~number(premiumSettledByContract[contractId])
::method premiumReceivable
  expose premiumAccruedByContract premiumSettledByContract
  use strict arg contractId
  return max(0,self~number(premiumAccruedByContract[contractId])-self~number(premiumSettledByContract[contractId]))
::method setInitialMarginTerms
  expose vmm contracts counterparties initialMarginTerms initialMarginRecognizedByContract
  use strict arg contractId,terms,authorityRef
  k=contracts[contractId]; if k==.nil | k~state<>"ACTIVE" then raise syntax 88.900 array("synthetic initial margin terms require active contract",contractId)
  if \terms~isA(.VMMSyntheticInitialMarginTerms) | authorityRef="" then raise syntax 88.900 array("VMMSyntheticInitialMarginTerms and authority required")
  if terms~currency<>k~terms~currency then raise syntax 88.900 array("synthetic initial margin currency mismatch")
  initialMarginTerms[contractId]=terms; initialMarginRecognizedByContract[contractId]=0
  vmm~journal~put("synthetic:initialMarginTerms:"||contractId,terms,"VMM_SYNTHETIC_INITIAL_MARGIN_TERMS_SET",self~meta("authority",authorityRef))
  return terms
::method recordInitialMarginTransfer
  expose vmm contracts counterparties initialMarginTerms initialMarginTransfers initialMarginRecognizedByContract
  use strict arg transfer
  if \transfer~isA(.VMMSyntheticInitialMarginTransfer) then raise syntax 88.900 array("VMMSyntheticInitialMarginTransfer required")
  if initialMarginTransfers~hasIndex(transfer~transferId) then raise syntax 88.900 array("duplicate VMM synthetic initial margin transfer",transfer~transferId)
  k=contracts[transfer~contractId]; if k==.nil | k~state<>"ACTIVE" then raise syntax 88.900 array("synthetic initial margin transfer requires active contract",transfer~contractId)
  t=initialMarginTerms[transfer~contractId]; if t==.nil then raise syntax 88.900 array("synthetic initial margin terms required")
  c=counterparties[k~counterpartyId]; if c==.nil | transfer~beneficiaryEntity<>c~legalEntity then raise syntax 88.900 array("synthetic initial margin beneficiary mismatch")
  if transfer~currency<>t~currency | transfer~assetClass<>t~eligibleAssetClass then raise syntax 88.900 array("synthetic initial margin collateral ineligible")
  if transfer~haircutBps>t~maxHaircutBps then raise syntax 88.900 array("synthetic initial margin haircut exceeds policy",transfer~haircutBps,t~maxHaircutBps)
  initialMarginTransfers[transfer~transferId]=transfer; initialMarginRecognizedByContract[transfer~contractId]=self~number(initialMarginRecognizedByContract[transfer~contractId])+transfer~recognizedValue
  vmm~journal~put("synthetic:initialMargin:"||transfer~transferId,transfer,"VMM_SYNTHETIC_INITIAL_MARGIN_POSTED",self~meta("contract",transfer~contractId))
  return transfer
::method initialMarginRecognized
  expose initialMarginRecognizedByContract
  use strict arg contractId
  return self~number(initialMarginRecognizedByContract[contractId])
::method initialMarginTransfer
  expose initialMarginTransfers
  use strict arg transferId
  return initialMarginTransfers[transferId]
::method initialMarginTransfersForContract
  expose initialMarginTransfers
  use strict arg contractId
  a=.array~new
  do transferId over initialMarginTransfers
    t=initialMarginTransfers[transferId]
    if t~contractId=contractId then a~append(t)
  end
  return a
::method initialMarginShortfall
  expose initialMarginTerms initialMarginRecognizedByContract
  use strict arg contractId
  t=initialMarginTerms[contractId]; if t==.nil then raise syntax 88.900 array("synthetic initial margin terms not set",contractId)
  return max(0,t~requiredAmount-self~number(initialMarginRecognizedByContract[contractId]))
::method applyPortfolioChange
  expose vmm contracts snapshots riskPolicies lifecyclePolicies portfolioChanges
  use strict arg changeId,contractId,newSnapshotId,changeType,effectiveAt,changeEvidenceRef,riskApprovalRef,authorityRef
  if portfolioChanges~hasIndex(changeId) then raise syntax 88.900 array("duplicate VMM reference portfolio change",changeId)
  k=contracts[contractId]; if k==.nil | k~state<>"ACTIVE" then raise syntax 88.900 array("reference portfolio change requires active contract",contractId)
  old=snapshots[k~currentSnapshotId]; new=snapshots[newSnapshotId]; if old==.nil | new==.nil then raise syntax 88.900 array("reference portfolio change requires registered snapshots")
  if new~counterpartyId<>k~counterpartyId | new~reportingCurrency<>k~terms~currency then raise syntax 88.900 array("replacement reference snapshot counterparty/currency mismatch")
  drift=abs(new~totalMarketValue-old~totalMarketValue)/old~totalMarketValue*100
  lp=lifecyclePolicies[k~terms~currency]; if lp==.nil then raise syntax 88.900 array("synthetic lifecycle policy required before portfolio change")
  if changeType="CLIENT_SUBSTITUTION" & drift>lp~maxSubstitutionValueDriftPct then raise syntax 88.900 array("synthetic portfolio substitution value drift exceeds policy",drift,lp~maxSubstitutionValueDriftPct)
  rp=riskPolicies[k~terms~currency]; if rp==.nil then raise syntax 88.900 array("synthetic risk policy required before portfolio change")
  self~checkSnapshotRisk(rp,new)
  ch=.VMMReferencePortfolioChange~new(changeId,contractId,changeType,old~snapshotId,new~snapshotId,effectiveAt,changeEvidenceRef,riskApprovalRef,authorityRef,drift)
  portfolioChanges[changeId]=ch; k~replaceReferenceSnapshot(new~snapshotId)
  vmm~journal~put("synthetic:portfolioChange:"||changeId,ch,"VMM_SYNTHETIC_REFERENCE_PORTFOLIO_CHANGED",self~meta("contract",contractId))
  return ch
::method portfolioChange
  expose portfolioChanges
  use strict arg changeId
  return portfolioChanges[changeId]
::method novateContract
  expose vmm contracts counterparties snapshots riskPolicies novations postedCollateral
  use strict arg novationId,targetContractId,sourceContractId,newCounterpartyId,replacementSnapshotId,novatedAt,novationAgreementRef,outgoingAuthority,incomingAuthority,vmmAuthority
  if novations~hasIndex(novationId) | contracts~hasIndex(targetContractId) then raise syntax 88.900 array("duplicate VMM synthetic novation/target contract")
  old=contracts[sourceContractId]; if old==.nil | old~state<>"ACTIVE" then raise syntax 88.900 array("synthetic novation source contract not active",sourceContractId)
  oldC=counterparties[old~counterpartyId]; newC=counterparties[newCounterpartyId]; if oldC==.nil | newC==.nil | newC~status<>"ACTIVE" then raise syntax 88.900 array("synthetic novation requires active old/new counterparties")
  s=snapshots[replacementSnapshotId]; if s==.nil | s~counterpartyId<>newCounterpartyId | s~counterpartyEntity<>newC~legalEntity | s~reportingCurrency<>old~terms~currency then raise syntax 88.900 array("synthetic novation replacement snapshot mismatch")
  rp=riskPolicies[old~terms~currency]; if rp==.nil then raise syntax 88.900 array("synthetic risk policy required before novation")
  self~checkReplacementContractRisk(rp,newCounterpartyId,old~terms~protectedNotional,sourceContractId)
  self~checkSnapshotRisk(rp,s)
  terms=.VMMPortfolioLossProtectionTerms~new("TERMS-NOV-"||targetContractId,replacementSnapshotId,old~terms~currency,old~terms~protectedNotional,old~terms~attachmentLossPct,old~terms~exhaustionLossPct,old~terms~premiumAmount,old~terms~effectiveAt,old~terms~maturity)
  newK=.VMMSyntheticContract~new(targetContractId,old~offerId,newCounterpartyId,terms,old~initialReferenceValue,newC~masterAgreementRef,newC~collateralAgreementRef,novatedAt,sourceContractId)
  n=.VMMSyntheticNovation~new(novationId,sourceContractId,targetContractId,old~counterpartyId,newCounterpartyId,replacementSnapshotId,novatedAt,novationAgreementRef,outgoingAuthority,incomingAuthority,vmmAuthority)
  contracts[targetContractId]=newK; novations[novationId]=n; postedCollateral[targetContractId]=0
  old~markNovated(targetContractId)
  vmm~journal~put("synthetic:novation:"||novationId,n,"VMM_SYNTHETIC_CONTRACT_NOVATED",self~meta("targetContract",targetContractId))
  return newK
::method novation
  expose novations
  use strict arg novationId
  return novations[novationId]
::method recordXVA
  expose vmm contracts valuations lifecyclePolicies xvaReports
  use strict arg report
  if \report~isA(.VMMSyntheticXVAReport) then raise syntax 88.900 array("VMMSyntheticXVAReport required")
  if xvaReports~hasIndex(report~reportId) then raise syntax 88.900 array("duplicate VMM synthetic XVA report",report~reportId)
  k=contracts[report~contractId]; val=valuations[report~valuationId]
  if k==.nil | val==.nil | val~contractId<>report~contractId | report~currency<>k~terms~currency then raise syntax 88.900 array("synthetic XVA contract/valuation mismatch")
  lp=lifecyclePolicies[report~currency]; if lp==.nil then raise syntax 88.900 array("synthetic lifecycle policy required before XVA")
  if report~totalXva>k~terms~protectedNotional*lp~maxXvaPctOfNotional/100 then raise syntax 88.900 array("synthetic XVA exceeds policy",report~totalXva)
  xvaReports[report~reportId]=report
  vmm~journal~put("synthetic:xva:"||report~reportId,report,"VMM_SYNTHETIC_XVA_RECORDED",self~meta("contract",report~contractId))
  return report
::method xva
  expose xvaReports
  use strict arg reportId
  return xvaReports[reportId]
::method assessHedgeEffectiveness
  expose vmm contracts valuations lifecyclePolicies hedgeEffectiveness
  use strict arg assessmentId,contractId,fromValuationId,toValuationId,hedgePnl,assessedAt,methodologyEvidenceRef,marketDataEvidenceRef,authorityRef
  if hedgeEffectiveness~hasIndex(assessmentId) then raise syntax 88.900 array("duplicate VMM synthetic hedge-effectiveness assessment",assessmentId)
  k=contracts[contractId]; a=valuations[fromValuationId]; b=valuations[toValuationId]
  if k==.nil | a==.nil | b==.nil | a~contractId<>contractId | b~contractId<>contractId then raise syntax 88.900 array("synthetic hedge-effectiveness valuation mismatch")
  lp=lifecyclePolicies[k~terms~currency]; if lp==.nil then raise syntax 88.900 array("synthetic lifecycle policy required before hedge-effectiveness assessment")
  change=b~vmmLiabilityMtm-a~vmmLiabilityMtm
  h=.VMMSyntheticHedgeEffectiveness~new(assessmentId,contractId,fromValuationId,toValuationId,k~terms~currency,change,hedgePnl,lp~minimumHedgeEffectivenessPct,assessedAt,methodologyEvidenceRef,marketDataEvidenceRef,authorityRef)
  hedgeEffectiveness[assessmentId]=h
  event="VMM_SYNTHETIC_HEDGE_EFFECTIVENESS_RECORDED"; if h~status="INEFFECTIVE" then event="VMM_SYNTHETIC_HEDGE_INEFFECTIVE_ALERT"
  vmm~journal~put("synthetic:hedgeEffectiveness:"||assessmentId,h,event,self~meta("contract",contractId))
  return h
::method hedgeEffectiveness
  expose hedgeEffectiveness
  use strict arg assessmentId
  return hedgeEffectiveness[assessmentId]
::method createHedgeOrder
  expose vmm contracts
  use strict arg orderId,contractId,strategyId,instrumentIdentity,side,notional,orderType,limitPrice,createdAt,executionAuthority
  k=contracts[contractId]; if k==.nil | k~state<>"ACTIVE" then raise syntax 88.900 array("synthetic hedge requires active contract",contractId)
  if instrumentIdentity~quoteCurrency<>k~terms~currency then raise syntax 88.900 array("v0.5 synthetic hedge currency must match contract")
  return vmm~createSyntheticHedgeOrder(orderId,contractId,strategyId,instrumentIdentity,side,notional,orderType,limitPrice,createdAt,executionAuthority)

::method checkReplacementContractRisk private
  expose offers contracts
  use strict arg policy,counterpartyId,newNotional,excludedContractId
  gross=newNotional; cpty=newNotional
  do id over offers
    o=offers[id]
    if o~state="OPEN" then do
      gross=gross+o~terms~protectedNotional
      if o~counterpartyId=counterpartyId then cpty=cpty+o~terms~protectedNotional
    end
  end
  do id over contracts
    if id<>excludedContractId then do
      k=contracts[id]
      if k~state="ACTIVE" then do
        gross=gross+k~terms~protectedNotional
        if k~counterpartyId=counterpartyId then cpty=cpty+k~terms~protectedNotional
      end
    end
  end
  if gross>policy~maxGrossSyntheticNotional then raise syntax 88.900 array("VMM synthetic gross notional limit exceeded",gross,policy~maxGrossSyntheticNotional)
  if cpty>policy~maxSingleCounterpartyNotional then raise syntax 88.900 array("VMM synthetic counterparty notional limit exceeded",cpty,policy~maxSingleCounterpartyNotional)
  return .true
::method checkSnapshotRisk private
  use strict arg policy,snapshot
  if snapshot~issuerMarketValue("VECTOR_MERIDIAN_MARKETS_LTD")>0 then raise syntax 88.900 array("VMM synthetic product cannot reference VMM itself")
  wrong=0
  do p over snapshot~positions
    if policy~isWrongWayEntity(p~issuerEntity) then wrong=wrong+p~marketValue
  end
  pct=0; if snapshot~totalMarketValue>0 then pct=(wrong/snapshot~totalMarketValue)*100
  if pct>policy~maxWrongWayPct then raise syntax 88.900 array("VMM synthetic wrong-way reference concentration exceeded",pct,policy~maxWrongWayPct)
  return .true
::method checkOfferRisk private
  expose offers contracts
  use strict arg policy,counterpartyId,snapshot,newNotional
  if snapshot~issuerMarketValue("VECTOR_MERIDIAN_MARKETS_LTD")>0 then raise syntax 88.900 array("VMM synthetic product cannot reference VMM itself")
  gross=newNotional; cpty=newNotional
  do id over offers
    o=offers[id]
    if o~state="OPEN" then do
      gross=gross+o~terms~protectedNotional
      if o~counterpartyId=counterpartyId then cpty=cpty+o~terms~protectedNotional
    end
  end
  do id over contracts
    k=contracts[id]
    if k~state="ACTIVE" then do
      gross=gross+k~terms~protectedNotional
      if k~counterpartyId=counterpartyId then cpty=cpty+k~terms~protectedNotional
    end
  end
  if gross>policy~maxGrossSyntheticNotional then raise syntax 88.900 array("VMM synthetic gross notional limit exceeded",gross,policy~maxGrossSyntheticNotional)
  if cpty>policy~maxSingleCounterpartyNotional then raise syntax 88.900 array("VMM synthetic counterparty notional limit exceeded",cpty,policy~maxSingleCounterpartyNotional)
  return self~checkSnapshotRisk(policy,snapshot)
::method meta private
  use strict arg key,value
  m=.directory~new; m[key]=value; return m
::method number private
  use strict arg value
  if value==.nil then return 0
  return value+0

::requires "VectorMeridianMarkets.cls"
