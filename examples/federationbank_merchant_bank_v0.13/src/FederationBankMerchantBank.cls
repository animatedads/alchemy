/* FederationBankMerchantBank.cls
 *
 * Federation Bank Australia IOM - Merchant Banking authority.
 * v0.13 adds attributable remediation execution evidence and current whole-book verification over the v0.12 governed planning model.
 * Wrong-way/partial/failed execution is retained as evidence rather than hidden.
 * Replacement activity is assessed as a graph rooted at the original CFD,
 * including reversing legs and reversals of those legs.  A healthy-looking new
 * pair therefore cannot conceal doubled aggregate directional exposure.
 *
 * Regulatory boundary: this package is NOT part of FederationBank Retail/Core.
 * It owns derivative contractual state, valuation/risk facts, margin/default and
 * close-out decisions.  It never mutates a retail/Core Banking account or
 * Ledger.  Core collateral is usable only after an explicit arm's-length
 * control acknowledgement issued by the Core Banking perimeter.
 */

::class MBDecisionEvidence public
::method init
  expose legalDecision policyDecision legalEffectRef policyRef
  use strict arg legalDecision,policyDecision,legalEffectRef,policyRef
::method legalDecision; expose legalDecision; return legalDecision
::method policyDecision; expose policyDecision; return policyDecision
::method legalEffectRef; expose legalEffectRef; return legalEffectRef
::method policyRef; expose policyRef; return policyRef
::method permitted
  expose legalDecision policyDecision legalEffectRef policyRef
  return legalDecision="PERMITTED" & policyDecision="PERMITTED" & legalEffectRef<>"" & policyRef<>""


::class MBCollateralAgreement public
::method init
  expose agreementId obligor securedParty collateralProvider securedObligations maximumSecuredAmount currency evidence status
  use strict arg agreementId,obligor,securedParty,collateralProvider,securedObligations,maximumSecuredAmount,currency,evidence
  if agreementId="" | obligor="" | securedParty="" | collateralProvider="" then raise syntax 88.900 array("invalid collateral agreement identity")
  if \evidence~isA(.MBDecisionEvidence) then raise syntax 88.900 array("collateral agreement requires MBDecisionEvidence")
  if \evidence~permitted then raise syntax 88.900 array("collateral agreement not legally/policy permitted")
  if maximumSecuredAmount < 0 then raise syntax 88.900 array("negative secured amount")
  status="ACTIVE"
::method agreementId; expose agreementId; return agreementId
::method obligor; expose obligor; return obligor
::method securedParty; expose securedParty; return securedParty
::method collateralProvider; expose collateralProvider; return collateralProvider
::method securedObligations; expose securedObligations; return securedObligations
::method maximumSecuredAmount; expose maximumSecuredAmount; return maximumSecuredAmount
::method currency; expose currency; return currency
::method evidence; expose evidence; return evidence
::method status; expose status; return status


::class MBCollateralAsset public
::method init
  expose assetId owner coreAssetRef assetType currency grossValue haircutBps
  use strict arg assetId,owner,coreAssetRef,assetType,currency,grossValue,haircutBps=0
  if assetId="" | owner="" | coreAssetRef="" then raise syntax 88.900 array("invalid collateral asset identity")
  if grossValue < 0 then raise syntax 88.900 array("negative collateral value")
  if haircutBps < 0 | haircutBps > 10000 then raise syntax 88.900 array("invalid haircut")
::method assetId; expose assetId; return assetId
::method owner; expose owner; return owner
::method coreAssetRef; expose coreAssetRef; return coreAssetRef
::method assetType; expose assetType; return assetType
::method currency; expose currency; return currency
::method grossValue; expose grossValue; return grossValue
::method haircutBps; expose haircutBps; return haircutBps
::method haircutAdjustedValue
  expose grossValue haircutBps
  return grossValue * (10000 - haircutBps) / 10000


::class MBCollateralControlReceipt public
::method init
  expose controlId agreementId assetId coreAuthorityRef owner encumbranceValid enforceable priority controlledAmount currency acknowledgedAt
  use strict arg controlId,agreementId,assetId,coreAuthorityRef,owner,encumbranceValid,enforceable,priority,controlledAmount,currency,acknowledgedAt
  if controlId="" | coreAuthorityRef="" then raise syntax 88.900 array("invalid Core Banking control receipt")
::method controlId; expose controlId; return controlId
::method agreementId; expose agreementId; return agreementId
::method assetId; expose assetId; return assetId
::method coreAuthorityRef; expose coreAuthorityRef; return coreAuthorityRef
::method owner; expose owner; return owner
::method encumbranceValid; expose encumbranceValid; return encumbranceValid
::method enforceable; expose enforceable; return enforceable
::method priority; expose priority; return priority
::method controlledAmount; expose controlledAmount; return controlledAmount
::method currency; expose currency; return currency
::method acknowledgedAt; expose acknowledgedAt; return acknowledgedAt
::method usable
  expose encumbranceValid enforceable controlledAmount
  return encumbranceValid & enforceable & controlledAmount > 0


::class MBDerivativeTrade public
::method init
  expose tradeId portfolioId obligor productType side currency notional strike premium maturity quantity status marketRef productId underlyingRef executedAt counterpartyEntity sourceType contractState clientViewState riskState
  use strict arg tradeId,portfolioId,obligor,productType,side,currency,notional,strike=0,premium=0,maturity="",quantity=1,marketRef="",productId="",underlyingRef="",executedAt="",counterpartyEntity="",sourceType="CLIENT"
  if productType<>"CFD" & productType<>"OPTION" then raise syntax 88.900 array("unsupported derivative product",productType)
  if side<>"LONG" & side<>"SHORT" then raise syntax 88.900 array("invalid trade side",side)
  if notional < 0 | quantity <= 0 then raise syntax 88.900 array("invalid trade economics")
  if sourceType<>"CLIENT" & sourceType<>"EXTERNAL_HEDGE" & sourceType<>"INTERNAL_HEDGE" then raise syntax 88.900 array("invalid trade source type",sourceType)
  status="OPEN"
  contractState="ACTIVE"
  clientViewState="OPEN"
  riskState="EXPOSED"
::method tradeId; expose tradeId; return tradeId
::method portfolioId; expose portfolioId; return portfolioId
::method obligor; expose obligor; return obligor
::method productType; expose productType; return productType
::method side; expose side; return side
::method currency; expose currency; return currency
::method notional; expose notional; return notional
::method strike; expose strike; return strike
::method premium; expose premium; return premium
::method maturity; expose maturity; return maturity
::method quantity; expose quantity; return quantity
::method marketRef; expose marketRef; return marketRef
::method productId; expose productId; return productId
::method underlyingRef; expose underlyingRef; return underlyingRef
::method executedAt; expose executedAt; return executedAt
::method counterpartyEntity; expose counterpartyEntity; return counterpartyEntity
::method sourceType; expose sourceType; return sourceType
::method status; expose status; return status
::method contractState; expose contractState; return contractState
::method clientViewState; expose clientViewState; return clientViewState
::method riskState; expose riskState; return riskState
::method contractualActive
  expose contractState
  return contractState="ACTIVE"
::method markClientView
  expose clientViewState
  use strict arg newState
  if newState<>"OPEN" & newState<>"PARTIAL" & newState<>"CLOSED" & newState<>"HEDGE" then raise syntax 88.900 array("invalid client view state",newState)
  clientViewState=newState
  return self
::method markRiskState
  expose riskState
  use strict arg newState
  if newState="" then raise syntax 88.900 array("risk state required")
  riskState=newState
  return self
::method close
  expose status productType contractState clientViewState riskState
  if productType="CFD" then raise syntax 88.900 array("CFD contracts are offset/netted, not closed")
  if status<>"OPEN" then raise syntax 88.900 array("trade is not open")
  status="CLOSED"
  contractState="TERMINATED"
  clientViewState="CLOSED"
  riskState="TERMINATED"
  return self


::class MBPortfolio public
::method init
  expose portfolioId clientEntity currency trades status relationshipId
  use strict arg portfolioId,clientEntity,currency,relationshipId=""
  if portfolioId="" | clientEntity="" then raise syntax 88.900 array("invalid portfolio identity")
  trades=.directory~new
  status="OPEN"
::method portfolioId; expose portfolioId; return portfolioId
::method clientEntity; expose clientEntity; return clientEntity
::method currency; expose currency; return currency
::method relationshipId; expose relationshipId; return relationshipId
::method status; expose status; return status
::method addTrade
  expose trades portfolioId clientEntity currency
  use strict arg trade
  if \trade~isA(.MBDerivativeTrade) then raise syntax 88.900 array("MBDerivativeTrade required")
  if trade~portfolioId<>portfolioId | trade~obligor<>clientEntity | trade~currency<>currency then raise syntax 88.900 array("trade/portfolio identity mismatch")
  if trades~hasIndex(trade~tradeId) then raise syntax 88.900 array("duplicate trade",trade~tradeId)
  trades[trade~tradeId]=trade
  return trade
::method trade
  expose trades
  use strict arg tradeId
  return trades[tradeId]
::method tradeIds; expose trades; return trades~allIndexes
::method tradeCount; expose trades; return trades~items
::method openTradeCount
  expose trades
  n=0
  do id over trades~allIndexes
    if trades[id]~status="OPEN" then n=n+1
  end
  return n
::method clientPositionCount
  expose trades
  n=0
  do id over trades~allIndexes
    t=trades[id]
    if t~contractualActive & t~clientViewState<>"CLOSED" & t~clientViewState<>"HEDGE" then n=n+1
  end
  return n
::method monitoredContractCount
  expose trades
  n=0
  do id over trades~allIndexes
    if trades[id]~contractualActive then n=n+1
  end
  return n
::method grossNotional
  expose trades
  total=0
  do id over trades~allIndexes
    t=trades[id]
    if t~status="OPEN" then total=total+t~notional
  end
  return total


::class MBValuationSnapshot public
::method init
  expose valuationId portfolioId asAt currency marketValue unrealisedPnL grossExposure marketEvidenceRef realisedPnL valuationStatus positionCount riskExposure
  use strict arg valuationId,portfolioId,asAt,currency,marketValue,unrealisedPnL,grossExposure,marketEvidenceRef,realisedPnL=0,valuationStatus="CURRENT",positionCount=0,riskExposure=""
  if valuationId="" | marketEvidenceRef="" then raise syntax 88.900 array("valuation requires market evidence")
  if riskExposure="" then riskExposure=grossExposure
  if riskExposure<0 | grossExposure<0 then raise syntax 88.900 array("negative exposure")
::method valuationId; expose valuationId; return valuationId
::method portfolioId; expose portfolioId; return portfolioId
::method asAt; expose asAt; return asAt
::method currency; expose currency; return currency
::method marketValue; expose marketValue; return marketValue
::method unrealisedPnL; expose unrealisedPnL; return unrealisedPnL
::method realisedPnL; expose realisedPnL; return realisedPnL
::method grossExposure; expose grossExposure; return grossExposure
::method riskExposure; expose riskExposure; return riskExposure
::method marketEvidenceRef; expose marketEvidenceRef; return marketEvidenceRef
::method valuationStatus; expose valuationStatus; return valuationStatus
::method positionCount; expose positionCount; return positionCount


::class MBRiskPolicy public
::method init
  expose policyRef maximumLeverage liquidityBufferRequired cureSeconds concentrationLimitBps
  use strict arg policyRef,maximumLeverage,liquidityBufferRequired,cureSeconds,concentrationLimitBps=10000
  if policyRef="" | maximumLeverage<=0 | liquidityBufferRequired<0 | cureSeconds<=0 then raise syntax 88.900 array("invalid merchant risk policy")
  if concentrationLimitBps<=0 | concentrationLimitBps>10000 then raise syntax 88.900 array("invalid concentration limit")
::method policyRef; expose policyRef; return policyRef
::method maximumLeverage; expose maximumLeverage; return maximumLeverage
::method liquidityBufferRequired; expose liquidityBufferRequired; return liquidityBufferRequired
::method cureSeconds; expose cureSeconds; return cureSeconds
::method concentrationLimitBps; expose concentrationLimitBps; return concentrationLimitBps


::class MBMarginAssessment public
::method init
  expose assessmentId portfolioId policyRef grossExposure eligibleCollateral adjustedCollateral availableLiquidity requiredLiquidity effectiveLeverage deficit state assessedAt requiredMargin availableMargin concentrationBps
  use strict arg assessmentId,portfolioId,policyRef,grossExposure,eligibleCollateral,adjustedCollateral,availableLiquidity,requiredLiquidity,effectiveLeverage,deficit,state,assessedAt,requiredMargin=0,availableMargin=0,concentrationBps=0
::method assessmentId; expose assessmentId; return assessmentId
::method portfolioId; expose portfolioId; return portfolioId
::method policyRef; expose policyRef; return policyRef
::method grossExposure; expose grossExposure; return grossExposure
::method eligibleCollateral; expose eligibleCollateral; return eligibleCollateral
::method adjustedCollateral; expose adjustedCollateral; return adjustedCollateral
::method availableLiquidity; expose availableLiquidity; return availableLiquidity
::method requiredLiquidity; expose requiredLiquidity; return requiredLiquidity
::method effectiveLeverage; expose effectiveLeverage; return effectiveLeverage
::method deficit; expose deficit; return deficit
::method state; expose state; return state
::method assessedAt; expose assessedAt; return assessedAt
::method requiredMargin; expose requiredMargin; return requiredMargin
::method availableMargin; expose availableMargin; return availableMargin
::method concentrationBps; expose concentrationBps; return concentrationBps


::class MBMarginCall public
::method init
  expose callId portfolioId assessmentId amount currency issuedAt cureBy state cureRecordId defaultedAt
  use strict arg callId,portfolioId,assessmentId,amount,currency,issuedAt,cureBy
  if callId="" | portfolioId="" | assessmentId="" | currency="" | issuedAt="" | cureBy="" then raise syntax 88.900 array("invalid margin call")
  if amount<=0 then raise syntax 88.900 array("margin call amount must be positive")
  state="OPEN"; cureRecordId=""; defaultedAt=""
::method callId; expose callId; return callId
::method portfolioId; expose portfolioId; return portfolioId
::method assessmentId; expose assessmentId; return assessmentId
::method amount; expose amount; return amount
::method currency; expose currency; return currency
::method issuedAt; expose issuedAt; return issuedAt
::method cureBy; expose cureBy; return cureBy
::method state; expose state; return state
::method cureRecordId; expose cureRecordId; return cureRecordId
::method defaultedAt; expose defaultedAt; return defaultedAt
::method cureWithEvidence
  expose state cureRecordId
  use strict arg recordId
  if state<>"OPEN" then raise syntax 88.900 array("margin call not open")
  if recordId="" then raise syntax 88.900 array("cure evidence required")
  state="CURED"; cureRecordId=recordId
  return self
::method defaultAt
  expose state defaultedAt
  use strict arg at
  if state<>"OPEN" then raise syntax 88.900 array("margin call not open")
  if at="" then raise syntax 88.900 array("default time required")
  state="DEFAULTED"; defaultedAt=at
  return self


::class MBLiquidityEvidence public
::method init
  expose evidenceId portfolioId currency availableAmount sourceAuthority sourceRef asAt
  use strict arg evidenceId,portfolioId,currency,availableAmount,sourceAuthority,sourceRef,asAt
  if evidenceId="" | portfolioId="" | currency="" | sourceAuthority="" | sourceRef="" | asAt="" then raise syntax 88.900 array("invalid Merchant liquidity evidence")
  if availableAmount<0 then raise syntax 88.900 array("negative Merchant liquidity")
::method evidenceId; expose evidenceId; return evidenceId
::method portfolioId; expose portfolioId; return portfolioId
::method currency; expose currency; return currency
::method availableAmount; expose availableAmount; return availableAmount
::method sourceAuthority; expose sourceAuthority; return sourceAuthority
::method sourceRef; expose sourceRef; return sourceRef
::method asAt; expose asAt; return asAt


::class MBMarginCureRecord public
::method init
  expose cureId callId portfolioId mechanism evidenceRef authorityRef assessmentId curedAt state
  use strict arg cureId,callId,portfolioId,mechanism,evidenceRef,authorityRef,assessmentId,curedAt
  if cureId="" | callId="" | portfolioId="" | evidenceRef="" | authorityRef="" | assessmentId="" | curedAt="" then raise syntax 88.900 array("invalid margin cure evidence")
  if mechanism<>"LIQUIDITY" & mechanism<>"COLLATERAL" & mechanism<>"POSITION_REDUCTION" & mechanism<>"RISK_REDUCTION" then raise syntax 88.900 array("invalid margin cure mechanism",mechanism)
  state="PROVED"
::method cureId; expose cureId; return cureId
::method callId; expose callId; return callId
::method portfolioId; expose portfolioId; return portfolioId
::method mechanism; expose mechanism; return mechanism
::method evidenceRef; expose evidenceRef; return evidenceRef
::method authorityRef; expose authorityRef; return authorityRef
::method assessmentId; expose assessmentId; return assessmentId
::method curedAt; expose curedAt; return curedAt
::method state; expose state; return state


::class MBCloseOutInstruction public
::method init
  expose instructionId portfolioId reason authorityRef createdAt state executionId
  use strict arg instructionId,portfolioId,reason,authorityRef,createdAt
  if instructionId="" | portfolioId="" | authorityRef="" | createdAt="" then raise syntax 88.900 array("close-out requires Merchant Banking authority evidence")
  state="REQUIRED"; executionId=""
::method instructionId; expose instructionId; return instructionId
::method portfolioId; expose portfolioId; return portfolioId
::method reason; expose reason; return reason
::method authorityRef; expose authorityRef; return authorityRef
::method createdAt; expose createdAt; return createdAt
::method state; expose state; return state
::method executionId; expose executionId; return executionId
::method markExecuted
  expose state executionId
  use strict arg id
  if state<>"REQUIRED" | id="" then raise syntax 88.900 array("close-out instruction not executable")
  state="EXECUTED"; executionId=id
  return self


::class MBCloseOutTradeResult public
::method init
  expose resultId tradeId marketEvidenceRef realisedPnL signedSettlementAmount authorityRef
  use strict arg resultId,tradeId,marketEvidenceRef,realisedPnL,signedSettlementAmount,authorityRef
  if resultId="" | tradeId="" | marketEvidenceRef="" | authorityRef="" then raise syntax 88.900 array("invalid close-out trade result")
::method resultId; expose resultId; return resultId
::method tradeId; expose tradeId; return tradeId
::method marketEvidenceRef; expose marketEvidenceRef; return marketEvidenceRef
::method realisedPnL; expose realisedPnL; return realisedPnL
::method signedSettlementAmount; expose signedSettlementAmount; return signedSettlementAmount
::method authorityRef; expose authorityRef; return authorityRef


::class MBCloseOutExecution public
::method init
  expose executionId instructionId portfolioId currency executedAt authorityRef tradeCount signedNetSettlement state
  use strict arg executionId,instructionId,portfolioId,currency,executedAt,authorityRef,tradeCount,signedNetSettlement
  if executionId="" | instructionId="" | portfolioId="" | currency="" | executedAt="" | authorityRef="" then raise syntax 88.900 array("invalid close-out execution")
  if tradeCount<0 then raise syntax 88.900 array("invalid close-out trade count")
  state="COMPLETE"
::method executionId; expose executionId; return executionId
::method instructionId; expose instructionId; return instructionId
::method portfolioId; expose portfolioId; return portfolioId
::method currency; expose currency; return currency
::method executedAt; expose executedAt; return executedAt
::method authorityRef; expose authorityRef; return authorityRef
::method tradeCount; expose tradeCount; return tradeCount
::method signedNetSettlement; expose signedNetSettlement; return signedNetSettlement
::method state; expose state; return state


::class MBSettlementObligation public
::method init
  expose obligationId debtor creditor currency amount reason sourceRef status
  use strict arg obligationId,debtor,creditor,currency,amount,reason,sourceRef
  if amount < 0 | sourceRef="" then raise syntax 88.900 array("invalid settlement obligation")
  status="UNSETTLED"
::method obligationId; expose obligationId; return obligationId
::method debtor; expose debtor; return debtor
::method creditor; expose creditor; return creditor
::method currency; expose currency; return currency
::method amount; expose amount; return amount
::method reason; expose reason; return reason
::method sourceRef; expose sourceRef; return sourceRef
::method status; expose status; return status


::class MBMerchantRelationship public
::method init
  expose relationshipId clientEntity externalSubjectRef linkageAuthorityRef openedAt status
  use strict arg relationshipId,clientEntity,externalSubjectRef,linkageAuthorityRef,openedAt=""
  if relationshipId="" | clientEntity="" | externalSubjectRef="" | linkageAuthorityRef="" then raise syntax 88.900 array("invalid merchant relationship")
  status="ACTIVE"
::method relationshipId; expose relationshipId; return relationshipId
::method clientEntity; expose clientEntity; return clientEntity
::method externalSubjectRef; expose externalSubjectRef; return externalSubjectRef
::method linkageAuthorityRef; expose linkageAuthorityRef; return linkageAuthorityRef
::method openedAt; expose openedAt; return openedAt
::method status; expose status; return status


::class MBReferenceDocumentEvidence public
::method init
  expose documentEvidenceId sourceAuthority sourceUri sourceTitle sourceVersion observedAt contentDigest provenanceStrength
  use strict arg documentEvidenceId,sourceAuthority,sourceUri,sourceTitle,sourceVersion,observedAt,contentDigest="",provenanceStrength="SOURCE_OBSERVED"
  if documentEvidenceId="" | sourceAuthority="" | sourceUri="" | sourceTitle="" | observedAt="" then raise syntax 88.900 array("invalid reference document evidence")
  if provenanceStrength<>"SOURCE_OBSERVED" & provenanceStrength<>"CONTENT_BOUND" & provenanceStrength<>"SIGNED_SOURCE" then raise syntax 88.900 array("invalid reference provenance strength",provenanceStrength)
::method documentEvidenceId; expose documentEvidenceId; return documentEvidenceId
::method sourceAuthority; expose sourceAuthority; return sourceAuthority
::method sourceUri; expose sourceUri; return sourceUri
::method sourceTitle; expose sourceTitle; return sourceTitle
::method sourceVersion; expose sourceVersion; return sourceVersion
::method observedAt; expose observedAt; return observedAt
::method contentDigest; expose contentDigest; return contentDigest
::method provenanceStrength; expose provenanceStrength; return provenanceStrength


::class MBInstrumentResolutionEvidence public
::method init
  expose evidenceId documentEvidenceId economicUnderlyingId isin venueMic denominationCurrency securityLineRef placeOfSafekeeping representationType quoteCurrency settlementCurrency sourceLocator observedAt
  use strict arg evidenceId,documentEvidenceId,economicUnderlyingId,isin,venueMic,denominationCurrency,securityLineRef,placeOfSafekeeping,representationType,quoteCurrency,settlementCurrency,sourceLocator,observedAt
  if evidenceId="" | documentEvidenceId="" | economicUnderlyingId="" | venueMic="" | denominationCurrency="" | representationType="" | quoteCurrency="" | settlementCurrency="" | sourceLocator="" | observedAt="" then raise syntax 88.900 array("invalid instrument resolution evidence")
::method evidenceId; expose evidenceId; return evidenceId
::method documentEvidenceId; expose documentEvidenceId; return documentEvidenceId
::method economicUnderlyingId; expose economicUnderlyingId; return economicUnderlyingId
::method isin; expose isin; return isin
::method venueMic; expose venueMic; return venueMic
::method denominationCurrency; expose denominationCurrency; return denominationCurrency
::method securityLineRef; expose securityLineRef; return securityLineRef
::method placeOfSafekeeping; expose placeOfSafekeeping; return placeOfSafekeeping
::method representationType; expose representationType; return representationType
::method quoteCurrency; expose quoteCurrency; return quoteCurrency
::method settlementCurrency; expose settlementCurrency; return settlementCurrency
::method sourceLocator; expose sourceLocator; return sourceLocator
::method observedAt; expose observedAt; return observedAt
::method matchesIdentity
  expose economicUnderlyingId isin venueMic denominationCurrency representationType quoteCurrency settlementCurrency
  use strict arg identity
  if \identity~isA(.MBInstrumentIdentity) then return .false
  return economicUnderlyingId=identity~economicUnderlyingId & isin=identity~isin & venueMic=identity~venueMic & denominationCurrency=identity~denominationCurrency & representationType=identity~representationType & quoteCurrency=identity~quoteCurrency & settlementCurrency=identity~settlementCurrency


::class MBInstrumentResolutionAttestation public
::method init
  expose attestationId productId productVersion resolutionEvidenceRef settlementLineKey sourceAuthority sourceRef attestedAt
  use strict arg attestationId,productId,productVersion,resolutionEvidenceRef,settlementLineKey,sourceAuthority,sourceRef,attestedAt
  if attestationId="" | productId="" | productVersion="" | resolutionEvidenceRef="" | settlementLineKey="" | sourceAuthority="" | sourceRef="" | attestedAt="" then raise syntax 88.900 array("invalid instrument resolution attestation")
::method attestationId; expose attestationId; return attestationId
::method productId; expose productId; return productId
::method productVersion; expose productVersion; return productVersion
::method resolutionEvidenceRef; expose resolutionEvidenceRef; return resolutionEvidenceRef
::method settlementLineKey; expose settlementLineKey; return settlementLineKey
::method sourceAuthority; expose sourceAuthority; return sourceAuthority
::method sourceRef; expose sourceRef; return sourceRef
::method attestedAt; expose attestedAt; return attestedAt


::class MBInstrumentIdentity public
::method init
  expose economicUnderlyingId isin venueMic representationType quoteCurrency settlementCurrency contractCurrency conversionRatio issuerRef denominationCurrency settlementLineRef placeOfSafekeeping resolutionEvidenceRef
  use strict arg economicUnderlyingId,isin,venueMic,representationType,quoteCurrency,settlementCurrency,contractCurrency,conversionRatio=1,issuerRef="",denominationCurrency="",settlementLineRef="",placeOfSafekeeping="",resolutionEvidenceRef=""
  if economicUnderlyingId="" | venueMic="" | representationType="" | quoteCurrency="" | settlementCurrency="" | contractCurrency="" then raise syntax 88.900 array("invalid instrument identity")
  if conversionRatio<=0 then raise syntax 88.900 array("invalid instrument conversion ratio")
  if denominationCurrency="" then denominationCurrency=quoteCurrency
::method economicUnderlyingId; expose economicUnderlyingId; return economicUnderlyingId
::method isin; expose isin; return isin
::method venueMic; expose venueMic; return venueMic
::method representationType; expose representationType; return representationType
::method quoteCurrency; expose quoteCurrency; return quoteCurrency
::method settlementCurrency; expose settlementCurrency; return settlementCurrency
::method contractCurrency; expose contractCurrency; return contractCurrency
::method conversionRatio; expose conversionRatio; return conversionRatio
::method issuerRef; expose issuerRef; return issuerRef
::method denominationCurrency; expose denominationCurrency; return denominationCurrency
::method settlementLineRef; expose settlementLineRef; return settlementLineRef
::method placeOfSafekeeping; expose placeOfSafekeeping; return placeOfSafekeeping
::method resolutionEvidenceRef; expose resolutionEvidenceRef; return resolutionEvidenceRef
::method settlementLineKey
  expose isin venueMic denominationCurrency settlementLineRef placeOfSafekeeping
  return isin || "|" || venueMic || "|" || denominationCurrency || "|" || settlementLineRef || "|" || placeOfSafekeeping
::method sameEconomicUnderlying
  expose economicUnderlyingId
  use strict arg other
  if \other~isA(.MBInstrumentIdentity) then return .false
  return economicUnderlyingId=other~economicUnderlyingId
::method sameSettlementLineIdentity
  expose economicUnderlyingId isin venueMic representationType settlementCurrency denominationCurrency settlementLineRef placeOfSafekeeping
  use strict arg other
  if \other~isA(.MBInstrumentIdentity) then return .false
  return economicUnderlyingId=other~economicUnderlyingId & isin=other~isin & venueMic=other~venueMic & representationType=other~representationType & settlementCurrency=other~settlementCurrency & denominationCurrency=other~denominationCurrency & settlementLineRef=other~settlementLineRef & placeOfSafekeeping=other~placeOfSafekeeping
::method exactContractIdentity
  expose economicUnderlyingId isin venueMic representationType quoteCurrency settlementCurrency contractCurrency conversionRatio issuerRef denominationCurrency settlementLineRef placeOfSafekeeping
  use strict arg other
  if \other~isA(.MBInstrumentIdentity) then return .false
  return economicUnderlyingId=other~economicUnderlyingId & isin=other~isin & venueMic=other~venueMic & representationType=other~representationType & quoteCurrency=other~quoteCurrency & settlementCurrency=other~settlementCurrency & contractCurrency=other~contractCurrency & conversionRatio=other~conversionRatio & issuerRef=other~issuerRef & denominationCurrency=other~denominationCurrency & settlementLineRef=other~settlementLineRef & placeOfSafekeeping=other~placeOfSafekeeping


::class MBDerivativeProductDefinition public
::method init
  expose productId productVersion productType underlyingRef currency settlementType evidence optionRight optionStyle contractMultiplier status instrumentIdentity
  use strict arg productId,productVersion,productType,underlyingRef,currency,settlementType,evidence,optionRight="",optionStyle="",contractMultiplier=1,instrumentIdentity=.nil
  if productId="" | productVersion="" | underlyingRef="" | currency="" then raise syntax 88.900 array("invalid derivative product")
  if productType<>"CFD" & productType<>"OPTION" then raise syntax 88.900 array("unsupported derivative product",productType)
  if settlementType<>"CASH" then raise syntax 88.900 array("v0.4 supports cash-settled derivatives only")
  if \evidence~isA(.MBDecisionEvidence) | \evidence~permitted then raise syntax 88.900 array("product requires Legal Effect and Institutional Policy permission")
  if productType="OPTION" then do
    if optionRight<>"CALL" & optionRight<>"PUT" then raise syntax 88.900 array("option right required")
    if optionStyle<>"EUROPEAN" & optionStyle<>"AMERICAN" then raise syntax 88.900 array("option style required")
  end
  if contractMultiplier<=0 then raise syntax 88.900 array("invalid contract multiplier")
  if instrumentIdentity<>.nil then do
    if \instrumentIdentity~isA(.MBInstrumentIdentity) then raise syntax 88.900 array("MBInstrumentIdentity required")
    if instrumentIdentity~economicUnderlyingId<>underlyingRef then raise syntax 88.900 array("product/instrument economic underlying mismatch")
    if instrumentIdentity~contractCurrency<>currency then raise syntax 88.900 array("product/instrument contract currency mismatch")
  end
  status="ACTIVE"
::method productId; expose productId; return productId
::method productVersion; expose productVersion; return productVersion
::method productType; expose productType; return productType
::method underlyingRef; expose underlyingRef; return underlyingRef
::method currency; expose currency; return currency
::method settlementType; expose settlementType; return settlementType
::method evidence; expose evidence; return evidence
::method optionRight; expose optionRight; return optionRight
::method optionStyle; expose optionStyle; return optionStyle
::method contractMultiplier; expose contractMultiplier; return contractMultiplier
::method instrumentIdentity; expose instrumentIdentity; return instrumentIdentity
::method status; expose status; return status


::class MBMarketEvidence public
::method init
  expose evidenceId sourceAuthority instrumentRef observedAt currency markPrice valuationStatus
  use strict arg evidenceId,sourceAuthority,instrumentRef,observedAt,currency,markPrice,valuationStatus="CURRENT"
  if evidenceId="" | sourceAuthority="" | instrumentRef="" | observedAt="" | currency="" then raise syntax 88.900 array("invalid market evidence")
  if markPrice<0 then raise syntax 88.900 array("negative market mark")
  if valuationStatus<>"CURRENT" & valuationStatus<>"INDICATIVE" & valuationStatus<>"STALE" & valuationStatus<>"CLOSED" & valuationStatus<>"RESTRICTED" & valuationStatus<>"UNPRICEABLE" then raise syntax 88.900 array("invalid valuation status")
::method evidenceId; expose evidenceId; return evidenceId
::method sourceAuthority; expose sourceAuthority; return sourceAuthority
::method instrumentRef; expose instrumentRef; return instrumentRef
::method observedAt; expose observedAt; return observedAt
::method currency; expose currency; return currency
::method markPrice; expose markPrice; return markPrice
::method valuationStatus; expose valuationStatus; return valuationStatus


::class MBTradeMark public
::method init
  expose markId tradeId asAt currency marketValue unrealisedPnL grossExposure marketEvidenceRef
  use strict arg markId,tradeId,asAt,currency,marketValue,unrealisedPnL,grossExposure,marketEvidenceRef
  if markId="" | tradeId="" | asAt="" | currency="" | marketEvidenceRef="" then raise syntax 88.900 array("invalid trade mark")
  if grossExposure<0 then raise syntax 88.900 array("negative gross exposure")
::method markId; expose markId; return markId
::method tradeId; expose tradeId; return tradeId
::method asAt; expose asAt; return asAt
::method currency; expose currency; return currency
::method marketValue; expose marketValue; return marketValue
::method unrealisedPnL; expose unrealisedPnL; return unrealisedPnL
::method grossExposure; expose grossExposure; return grossExposure
::method marketEvidenceRef; expose marketEvidenceRef; return marketEvidenceRef


::class MBTradeLifecycleEvent public
::method init
  expose eventId tradeId eventType effectiveAt realisedPnL marketEvidenceRef authorityRef
  use strict arg eventId,tradeId,eventType,effectiveAt,realisedPnL,marketEvidenceRef,authorityRef
  if eventId="" | tradeId="" | effectiveAt="" | marketEvidenceRef="" | authorityRef="" then raise syntax 88.900 array("invalid trade lifecycle evidence")
  if eventType<>"CLOSED" & eventType<>"EXERCISED" & eventType<>"EXPIRED" then raise syntax 88.900 array("invalid trade lifecycle event",eventType)
::method eventId; expose eventId; return eventId
::method tradeId; expose tradeId; return tradeId
::method eventType; expose eventType; return eventType
::method effectiveAt; expose effectiveAt; return effectiveAt
::method realisedPnL; expose realisedPnL; return realisedPnL
::method marketEvidenceRef; expose marketEvidenceRef; return marketEvidenceRef
::method authorityRef; expose authorityRef; return authorityRef


::class MBFXEvidence public
::method init
  expose evidenceId sourceAuthority baseCurrency quoteCurrency rate observedAt status
  use strict arg evidenceId,sourceAuthority,baseCurrency,quoteCurrency,rate,observedAt,status="CURRENT"
  if evidenceId="" | sourceAuthority="" | baseCurrency="" | quoteCurrency="" | observedAt="" then raise syntax 88.900 array("invalid FX evidence")
  if baseCurrency=quoteCurrency | rate<=0 then raise syntax 88.900 array("invalid FX pair/rate")
  if status<>"CURRENT" & status<>"INDICATIVE" & status<>"STALE" then raise syntax 88.900 array("invalid FX evidence status")
::method evidenceId; expose evidenceId; return evidenceId
::method sourceAuthority; expose sourceAuthority; return sourceAuthority
::method baseCurrency; expose baseCurrency; return baseCurrency
::method quoteCurrency; expose quoteCurrency; return quoteCurrency
::method rate; expose rate; return rate
::method observedAt; expose observedAt; return observedAt
::method status; expose status; return status
::method supports
  expose baseCurrency quoteCurrency
  use strict arg fromCurrency,toCurrency
  return (fromCurrency=baseCurrency & toCurrency=quoteCurrency) | (fromCurrency=quoteCurrency & toCurrency=baseCurrency)
::method convert
  expose baseCurrency quoteCurrency rate
  use strict arg amount,fromCurrency,toCurrency
  if fromCurrency=toCurrency then return amount
  if fromCurrency=baseCurrency & toCurrency=quoteCurrency then return amount*rate
  if fromCurrency=quoteCurrency & toCurrency=baseCurrency then return amount/rate
  raise syntax 88.900 array("FX evidence does not support conversion",fromCurrency,toCurrency)


::class MBCounterpartyRiskEvidence public
::method init
  expose evidenceId tradeId counterpartyEntity currentExposure replacementCost sourceAuthority sourceRef asAt
  use strict arg evidenceId,tradeId,counterpartyEntity,currentExposure,replacementCost,sourceAuthority,sourceRef,asAt
  if evidenceId="" | tradeId="" | counterpartyEntity="" | sourceAuthority="" | sourceRef="" | asAt="" then raise syntax 88.900 array("invalid counterparty risk evidence")
  if currentExposure<0 | replacementCost<0 then raise syntax 88.900 array("negative counterparty risk")
::method evidenceId; expose evidenceId; return evidenceId
::method tradeId; expose tradeId; return tradeId
::method counterpartyEntity; expose counterpartyEntity; return counterpartyEntity
::method currentExposure; expose currentExposure; return currentExposure
::method replacementCost; expose replacementCost; return replacementCost
::method sourceAuthority; expose sourceAuthority; return sourceAuthority
::method sourceRef; expose sourceRef; return sourceRef
::method asAt; expose asAt; return asAt


::class MBBasisRiskEvidence public
::method init
  expose evidenceId hedgeId amountBaseCurrency sourceAuthority sourceRef asAt valuationStatus
  use strict arg evidenceId,hedgeId,amountBaseCurrency,sourceAuthority,sourceRef,asAt,valuationStatus="CURRENT"
  if evidenceId="" | hedgeId="" | sourceAuthority="" | sourceRef="" | asAt="" then raise syntax 88.900 array("invalid basis risk evidence")
  if amountBaseCurrency<0 then raise syntax 88.900 array("negative basis risk amount")
::method evidenceId; expose evidenceId; return evidenceId
::method hedgeId; expose hedgeId; return hedgeId
::method amountBaseCurrency; expose amountBaseCurrency; return amountBaseCurrency
::method sourceAuthority; expose sourceAuthority; return sourceAuthority
::method sourceRef; expose sourceRef; return sourceRef
::method asAt; expose asAt; return asAt
::method valuationStatus; expose valuationStatus; return valuationStatus


::class MBHedgeFungibilityEvidence public
::method init
  expose evidenceId hedgeId jurisdiction conversionAvailable settlementAvailable custodyTransferAvailable legalTransferPermitted marketLiquidityAvailable sourceAuthority legalEffectRef asAt
  use strict arg evidenceId,hedgeId,jurisdiction,conversionAvailable,settlementAvailable,custodyTransferAvailable,legalTransferPermitted,marketLiquidityAvailable,sourceAuthority,legalEffectRef,asAt
  if evidenceId="" | hedgeId="" | jurisdiction="" | sourceAuthority="" | legalEffectRef="" | asAt="" then raise syntax 88.900 array("invalid hedge fungibility evidence")
::method evidenceId; expose evidenceId; return evidenceId
::method hedgeId; expose hedgeId; return hedgeId
::method jurisdiction; expose jurisdiction; return jurisdiction
::method conversionAvailable; expose conversionAvailable; return conversionAvailable
::method settlementAvailable; expose settlementAvailable; return settlementAvailable
::method custodyTransferAvailable; expose custodyTransferAvailable; return custodyTransferAvailable
::method legalTransferPermitted; expose legalTransferPermitted; return legalTransferPermitted
::method marketLiquidityAvailable; expose marketLiquidityAvailable; return marketLiquidityAvailable
::method sourceAuthority; expose sourceAuthority; return sourceAuthority
::method legalEffectRef; expose legalEffectRef; return legalEffectRef
::method asAt; expose asAt; return asAt
::method healthy
  expose conversionAvailable settlementAvailable custodyTransferAvailable legalTransferPermitted marketLiquidityAvailable
  return conversionAvailable & settlementAvailable & custodyTransferAvailable & legalTransferPermitted & marketLiquidityAvailable


::class MBHedgeEquivalenceEvidence public
::method init
  expose evidenceId hedgeId version supersedesEvidenceRef effectiveAt jurisdiction sourceAuthority sourceRef legalEffectRef originalInstrumentEvidenceRef offsetInstrumentEvidenceRef conversionAvailable settlementAvailable custodyTransferAvailable legalTransferPermitted marketLiquidityAvailable reasonCode
  use strict arg evidenceId,hedgeId,version,supersedesEvidenceRef,effectiveAt,jurisdiction,sourceAuthority,sourceRef,legalEffectRef,originalInstrumentEvidenceRef="",offsetInstrumentEvidenceRef="",conversionAvailable=.true,settlementAvailable=.true,custodyTransferAvailable=.true,legalTransferPermitted=.true,marketLiquidityAvailable=.true,reasonCode=""
  if evidenceId="" | hedgeId="" | effectiveAt="" | jurisdiction="" | sourceAuthority="" | sourceRef="" | legalEffectRef="" then raise syntax 88.900 array("invalid hedge equivalence evidence")
  if version<1 | version<>version~trunc then raise syntax 88.900 array("invalid hedge equivalence evidence version",version)
  if version=1 & supersedesEvidenceRef<>"" then raise syntax 88.900 array("first hedge equivalence evidence cannot supersede prior evidence")
  if version>1 & supersedesEvidenceRef="" then raise syntax 88.900 array("later hedge equivalence evidence must supersede prior evidence")
::method evidenceId; expose evidenceId; return evidenceId
::method hedgeId; expose hedgeId; return hedgeId
::method version; expose version; return version
::method supersedesEvidenceRef; expose supersedesEvidenceRef; return supersedesEvidenceRef
::method effectiveAt; expose effectiveAt; return effectiveAt
::method jurisdiction; expose jurisdiction; return jurisdiction
::method sourceAuthority; expose sourceAuthority; return sourceAuthority
::method sourceRef; expose sourceRef; return sourceRef
::method legalEffectRef; expose legalEffectRef; return legalEffectRef
::method originalInstrumentEvidenceRef; expose originalInstrumentEvidenceRef; return originalInstrumentEvidenceRef
::method offsetInstrumentEvidenceRef; expose offsetInstrumentEvidenceRef; return offsetInstrumentEvidenceRef
::method conversionAvailable; expose conversionAvailable; return conversionAvailable
::method settlementAvailable; expose settlementAvailable; return settlementAvailable
::method custodyTransferAvailable; expose custodyTransferAvailable; return custodyTransferAvailable
::method legalTransferPermitted; expose legalTransferPermitted; return legalTransferPermitted
::method marketLiquidityAvailable; expose marketLiquidityAvailable; return marketLiquidityAvailable
::method reasonCode; expose reasonCode; return reasonCode
::method healthy
  expose conversionAvailable settlementAvailable custodyTransferAvailable legalTransferPermitted marketLiquidityAvailable
  return conversionAvailable & settlementAvailable & custodyTransferAvailable & legalTransferPermitted & marketLiquidityAvailable
::method equivalenceState
  if self~healthy then return "EQUIVALENT"
  return "IMPAIRED"


::class MBMarketStructureEvent public
::method init
  expose eventId eventType effectiveAt jurisdiction sourceAuthority sourceRef legalEffectRef affectedInstrumentEvidenceRef conversionAvailable settlementAvailable custodyTransferAvailable legalTransferPermitted marketLiquidityAvailable reasonCode
  use strict arg eventId,eventType,effectiveAt,jurisdiction,sourceAuthority,sourceRef,legalEffectRef,affectedInstrumentEvidenceRef,conversionAvailable=.true,settlementAvailable=.true,custodyTransferAvailable=.true,legalTransferPermitted=.true,marketLiquidityAvailable=.true,reasonCode=""
  if eventId="" | eventType="" | effectiveAt="" | jurisdiction="" | sourceAuthority="" | sourceRef="" | legalEffectRef="" | affectedInstrumentEvidenceRef="" then raise syntax 88.900 array("invalid market structure event")
::method eventId; expose eventId; return eventId
::method eventType; expose eventType; return eventType
::method effectiveAt; expose effectiveAt; return effectiveAt
::method jurisdiction; expose jurisdiction; return jurisdiction
::method sourceAuthority; expose sourceAuthority; return sourceAuthority
::method sourceRef; expose sourceRef; return sourceRef
::method legalEffectRef; expose legalEffectRef; return legalEffectRef
::method affectedInstrumentEvidenceRef; expose affectedInstrumentEvidenceRef; return affectedInstrumentEvidenceRef
::method conversionAvailable; expose conversionAvailable; return conversionAvailable
::method settlementAvailable; expose settlementAvailable; return settlementAvailable
::method custodyTransferAvailable; expose custodyTransferAvailable; return custodyTransferAvailable
::method legalTransferPermitted; expose legalTransferPermitted; return legalTransferPermitted
::method marketLiquidityAvailable; expose marketLiquidityAvailable; return marketLiquidityAvailable
::method reasonCode; expose reasonCode; return reasonCode
::method healthy
  expose conversionAvailable settlementAvailable custodyTransferAvailable legalTransferPermitted marketLiquidityAvailable
  return conversionAvailable & settlementAvailable & custodyTransferAvailable & legalTransferPermitted & marketLiquidityAvailable
::method equivalenceState
  if self~healthy then return "EQUIVALENT"
  return "IMPAIRED"


::class MBOffsetIntent public
::method init
  expose intentId originalTradeId requestedAt authorityRef state hedgeId
  use strict arg intentId,originalTradeId,requestedAt,authorityRef
  if intentId="" | originalTradeId="" | requestedAt="" | authorityRef="" then raise syntax 88.900 array("invalid offset intent")
  state="REQUESTED"; hedgeId=""
::method intentId; expose intentId; return intentId
::method originalTradeId; expose originalTradeId; return originalTradeId
::method requestedAt; expose requestedAt; return requestedAt
::method authorityRef; expose authorityRef; return authorityRef
::method state; expose state; return state
::method hedgeId; expose hedgeId; return hedgeId
::method markExecuted
  expose state hedgeId
  use strict arg id
  if state<>"REQUESTED" | id="" then raise syntax 88.900 array("offset intent not executable")
  state="OFFSET_BOOKED"; hedgeId=id
  return self


::class MBHedgeRelationship public
::method init
  expose hedgeId intentId originalTradeId offsetTradeId relationshipType sizingFxEvidenceRef sizingAt baseCurrency sizingNetExposure economicState equivalenceState equivalenceEvidenceRef monitoringRequired
  use strict arg hedgeId,intentId,originalTradeId,offsetTradeId,relationshipType,sizingFxEvidenceRef,sizingAt,baseCurrency,sizingNetExposure,economicState
  if hedgeId="" | intentId="" | originalTradeId="" | offsetTradeId="" | sizingAt="" | baseCurrency="" then raise syntax 88.900 array("invalid hedge relationship")
  if relationshipType<>"EXACT_OFFSET" & relationshipType<>"SETTLEMENT_LINE_HEDGE" & relationshipType<>"CROSS_LISTED_HEDGE" & relationshipType<>"DLC_EQUIVALENCE" & relationshipType<>"DEPOSITARY_HEDGE" & relationshipType<>"UNDERLYING_HEDGE" then raise syntax 88.900 array("invalid hedge relationship type",relationshipType)
  equivalenceState="EQUIVALENCE_UNPROVED"
  equivalenceEvidenceRef=""
  if relationshipType="EXACT_OFFSET" then equivalenceState="EQUIVALENT"
  monitoringRequired=.true
::method hedgeId; expose hedgeId; return hedgeId
::method intentId; expose intentId; return intentId
::method originalTradeId; expose originalTradeId; return originalTradeId
::method offsetTradeId; expose offsetTradeId; return offsetTradeId
::method relationshipType; expose relationshipType; return relationshipType
::method sizingFxEvidenceRef; expose sizingFxEvidenceRef; return sizingFxEvidenceRef
::method sizingAt; expose sizingAt; return sizingAt
::method baseCurrency; expose baseCurrency; return baseCurrency
::method sizingNetExposure; expose sizingNetExposure; return sizingNetExposure
::method economicState; expose economicState; return economicState
::method equivalenceState; expose equivalenceState; return equivalenceState
::method equivalenceEvidenceRef; expose equivalenceEvidenceRef; return equivalenceEvidenceRef
::method monitoringRequired; expose monitoringRequired; return monitoringRequired
::method markEquivalence
  expose equivalenceState equivalenceEvidenceRef
  use strict arg newState,evidenceRef=""
  if newState<>"EQUIVALENT" & newState<>"IMPAIRED" & newState<>"EQUIVALENCE_UNPROVED" then raise syntax 88.900 array("invalid equivalence state",newState)
  equivalenceState=newState
  if evidenceRef<>"" then equivalenceEvidenceRef=evidenceRef
  return self
::method markEconomicState
  expose economicState
  use strict arg newState
  economicState=newState
  return self


::class MBHedgeRiskAssessment public
::method init
  expose assessmentId hedgeId asAt baseCurrency directionalExposure fxTranslationExposure basisExposure counterpartyExposure replacementCost equivalenceState riskState monitoringRequired fxEvidenceRef basisEvidenceRef counterpartyEvidenceRef fungibilityEvidenceRef equivalenceEvidenceRef
  use strict arg assessmentId,hedgeId,asAt,baseCurrency,directionalExposure,fxTranslationExposure,basisExposure,counterpartyExposure,replacementCost,equivalenceState,riskState,monitoringRequired,fxEvidenceRef="",basisEvidenceRef="",counterpartyEvidenceRef="",fungibilityEvidenceRef="",equivalenceEvidenceRef=""
  if assessmentId="" | hedgeId="" | asAt="" | baseCurrency="" then raise syntax 88.900 array("invalid hedge risk assessment")
::method assessmentId; expose assessmentId; return assessmentId
::method hedgeId; expose hedgeId; return hedgeId
::method asAt; expose asAt; return asAt
::method baseCurrency; expose baseCurrency; return baseCurrency
::method directionalExposure; expose directionalExposure; return directionalExposure
::method fxTranslationExposure; expose fxTranslationExposure; return fxTranslationExposure
::method basisExposure; expose basisExposure; return basisExposure
::method counterpartyExposure; expose counterpartyExposure; return counterpartyExposure
::method replacementCost; expose replacementCost; return replacementCost
::method equivalenceState; expose equivalenceState; return equivalenceState
::method riskState; expose riskState; return riskState
::method monitoringRequired; expose monitoringRequired; return monitoringRequired
::method fxEvidenceRef; expose fxEvidenceRef; return fxEvidenceRef
::method basisEvidenceRef; expose basisEvidenceRef; return basisEvidenceRef
::method counterpartyEvidenceRef; expose counterpartyEvidenceRef; return counterpartyEvidenceRef
::method fungibilityEvidenceRef; expose fungibilityEvidenceRef; return fungibilityEvidenceRef
::method equivalenceEvidenceRef; expose equivalenceEvidenceRef; return equivalenceEvidenceRef
::method riskTotal
  expose directionalExposure fxTranslationExposure basisExposure counterpartyExposure replacementCost
  return abs(directionalExposure)+fxTranslationExposure+basisExposure+counterpartyExposure+replacementCost


::class MBCFDHedgeBookAssessment public
::method init
  expose assessmentId rootTradeId asAt baseCurrency contractCount hedgeCount grossBaseExposure netBaseExposure impairedHedgeCount unprovedHedgeCount openRemediationCount counterpartyExposure replacementCost state tradeIds hedgeIds
  use strict arg assessmentId,rootTradeId,asAt,baseCurrency,contractCount,hedgeCount,grossBaseExposure,netBaseExposure,impairedHedgeCount,unprovedHedgeCount,openRemediationCount,counterpartyExposure,replacementCost,state,tradeIds,hedgeIds
  if assessmentId="" | rootTradeId="" | asAt="" | baseCurrency="" then raise syntax 88.900 array("invalid CFD hedge-book assessment")
::method assessmentId; expose assessmentId; return assessmentId
::method rootTradeId; expose rootTradeId; return rootTradeId
::method asAt; expose asAt; return asAt
::method baseCurrency; expose baseCurrency; return baseCurrency
::method contractCount; expose contractCount; return contractCount
::method hedgeCount; expose hedgeCount; return hedgeCount
::method grossBaseExposure; expose grossBaseExposure; return grossBaseExposure
::method netBaseExposure; expose netBaseExposure; return netBaseExposure
::method impairedHedgeCount; expose impairedHedgeCount; return impairedHedgeCount
::method unprovedHedgeCount; expose unprovedHedgeCount; return unprovedHedgeCount
::method openRemediationCount; expose openRemediationCount; return openRemediationCount
::method counterpartyExposure; expose counterpartyExposure; return counterpartyExposure
::method replacementCost; expose replacementCost; return replacementCost
::method state; expose state; return state
::method tradeIds; expose tradeIds; return tradeIds
::method hedgeIds; expose hedgeIds; return hedgeIds
::method hasTrade
  expose tradeIds
  use strict arg tradeId
  do id over tradeIds
    if id=tradeId then return .true
  end
  return .false
::method hasHedge
  expose hedgeIds
  use strict arg hedgeId
  do id over hedgeIds
    if id=hedgeId then return .true
  end
  return .false
::method directionallyNetted
  expose netBaseExposure
  return netBaseExposure=0


::class MBHedgeRemediationObligation public
::method init
  expose remediationId hedgeId triggerAssessmentId triggerEquivalenceEvidenceRef policyRef openedAt dueBy state actionEvidenceRef resolutionAssessmentId resolvedAt disposition escalatedAt escalationAuthority escalationReason
  use strict arg remediationId,hedgeId,triggerAssessmentId,triggerEquivalenceEvidenceRef,policyRef,openedAt,dueBy=""
  if remediationId="" | hedgeId="" | triggerAssessmentId="" | policyRef="" | openedAt="" then raise syntax 88.900 array("invalid hedge remediation obligation")
  state="OPEN"; actionEvidenceRef=""; resolutionAssessmentId=""; resolvedAt=""; disposition=""
  escalatedAt=""; escalationAuthority=""; escalationReason=""
::method remediationId; expose remediationId; return remediationId
::method hedgeId; expose hedgeId; return hedgeId
::method triggerAssessmentId; expose triggerAssessmentId; return triggerAssessmentId
::method triggerEquivalenceEvidenceRef; expose triggerEquivalenceEvidenceRef; return triggerEquivalenceEvidenceRef
::method policyRef; expose policyRef; return policyRef
::method openedAt; expose openedAt; return openedAt
::method dueBy; expose dueBy; return dueBy
::method state; expose state; return state
::method actionEvidenceRef; expose actionEvidenceRef; return actionEvidenceRef
::method resolutionAssessmentId; expose resolutionAssessmentId; return resolutionAssessmentId
::method resolvedAt; expose resolvedAt; return resolvedAt
::method disposition; expose disposition; return disposition
::method escalatedAt; expose escalatedAt; return escalatedAt
::method escalationAuthority; expose escalationAuthority; return escalationAuthority
::method escalationReason; expose escalationReason; return escalationReason
::method markAction
  expose state actionEvidenceRef
  use strict arg evidenceId
  if state="RESOLVED" then raise syntax 88.900 array("resolved hedge remediation cannot accept action evidence")
  if evidenceId="" then raise syntax 88.900 array("remediation action evidence required")
  actionEvidenceRef=evidenceId
  if state="OPEN" then state="ACTION_RECORDED"
  return self
::method markEscalated
  expose state escalatedAt escalationAuthority escalationReason
  use strict arg at,authority,reason
  if state="RESOLVED" then raise syntax 88.900 array("resolved hedge remediation cannot be escalated")
  if at="" | authority="" | reason="" then raise syntax 88.900 array("hedge remediation escalation requires evidence")
  state="ESCALATED"; escalatedAt=at; escalationAuthority=authority; escalationReason=reason
  return self
::method markMitigated
  expose state actionEvidenceRef resolutionAssessmentId resolvedAt disposition
  use strict arg evidenceId,assessmentId,at,resultDisposition
  if state="RESOLVED" then raise syntax 88.900 array("resolved hedge remediation cannot be mitigated")
  if evidenceId="" | assessmentId="" | at="" | resultDisposition="" then raise syntax 88.900 array("hedge remediation mitigation requires evidence")
  state="MITIGATED_MONITORING"; actionEvidenceRef=evidenceId; resolutionAssessmentId=assessmentId; resolvedAt=at; disposition=resultDisposition
  return self
::method resolve
  expose state actionEvidenceRef resolutionAssessmentId resolvedAt disposition
  use strict arg evidenceId,assessmentId,at,resultDisposition
  if state="RESOLVED" then raise syntax 88.900 array("hedge remediation already resolved")
  if evidenceId="" | assessmentId="" | at="" | resultDisposition="" then raise syntax 88.900 array("hedge remediation resolution requires evidence")
  state="RESOLVED"; actionEvidenceRef=evidenceId; resolutionAssessmentId=assessmentId; resolvedAt=at; disposition=resultDisposition
  return self


::class MBHedgeRemediationActionEvidence public
::method init
  expose evidenceId remediationId actionType sourceAuthority sourceRef effectiveAt replacementHedgeId legalEffectRef policyRef
  use strict arg evidenceId,remediationId,actionType,sourceAuthority,sourceRef,effectiveAt,replacementHedgeId="",legalEffectRef="",policyRef=""
  if evidenceId="" | remediationId="" | sourceAuthority="" | sourceRef="" | effectiveAt="" then raise syntax 88.900 array("invalid hedge remediation action evidence")
  if actionType<>"RESTORE_FUNGIBILITY" & actionType<>"REHOME_CUSTODY" & actionType<>"REPLACE_HEDGE" & actionType<>"TRANSFER_HEDGE" & actionType<>"RISK_REDUCTION" then raise syntax 88.900 array("invalid hedge remediation action type",actionType)
  if (actionType="REPLACE_HEDGE" | actionType="TRANSFER_HEDGE") & replacementHedgeId="" then raise syntax 88.900 array("replacement/transfer remediation requires replacement hedge")
::method evidenceId; expose evidenceId; return evidenceId
::method remediationId; expose remediationId; return remediationId
::method actionType; expose actionType; return actionType
::method sourceAuthority; expose sourceAuthority; return sourceAuthority
::method sourceRef; expose sourceRef; return sourceRef
::method effectiveAt; expose effectiveAt; return effectiveAt
::method replacementHedgeId; expose replacementHedgeId; return replacementHedgeId
::method legalEffectRef; expose legalEffectRef; return legalEffectRef
::method policyRef; expose policyRef; return policyRef


::class MBHedgeRemediationPlanStep public
::method init
  expose stepId sequence actionType targetRef signedBaseExposureDelta instrumentEvidenceRef detail
  use strict arg stepId,sequence,actionType,targetRef="",signedBaseExposureDelta=0,instrumentEvidenceRef="",detail=""
  if stepId="" | sequence<=0 then raise syntax 88.900 array("invalid hedge remediation plan step")
  if actionType<>"RESTORE_FUNGIBILITY" & actionType<>"REHOME_CUSTODY" & actionType<>"NEUTRALISE_EXISTING_HEDGE" & actionType<>"ADD_REPLACEMENT_HEDGE" & actionType<>"TRANSFER_HEDGE" & actionType<>"REDUCE_CLIENT_EXPOSURE" then raise syntax 88.900 array("invalid hedge remediation plan action",actionType)
  if (actionType="RESTORE_FUNGIBILITY" | actionType="REHOME_CUSTODY" | actionType="TRANSFER_HEDGE") & signedBaseExposureDelta<>0 then raise syntax 88.900 array("non-directional remediation plan step cannot change exposure",actionType)
  if (actionType="NEUTRALISE_EXISTING_HEDGE" | actionType="ADD_REPLACEMENT_HEDGE" | actionType="REDUCE_CLIENT_EXPOSURE") & signedBaseExposureDelta=0 then raise syntax 88.900 array("directional remediation plan step requires exposure delta",actionType)
  if actionType="ADD_REPLACEMENT_HEDGE" & instrumentEvidenceRef="" then raise syntax 88.900 array("replacement hedge plan requires intended instrument evidence")
::method stepId; expose stepId; return stepId
::method sequence; expose sequence; return sequence
::method actionType; expose actionType; return actionType
::method targetRef; expose targetRef; return targetRef
::method signedBaseExposureDelta; expose signedBaseExposureDelta; return signedBaseExposureDelta
::method instrumentEvidenceRef; expose instrumentEvidenceRef; return instrumentEvidenceRef
::method detail; expose detail; return detail


::class MBHedgeRemediationPlan public
::method init
  expose planId remediationId rootTradeId baselineBookAssessmentId proposer policyRef proposedAt steps state startingNetBaseExposure projectedNetBaseExposure peakAbsBaseExposure approvalId approvedBy approvedAt approvalAuthorityRef executionStartedAt executionEvidenceCompleteAt verificationId verificationAssessmentId verificationState verifiedAt actualNetBaseExposure projectionDeviation
  use strict arg planId,remediationId,rootTradeId,baselineBookAssessmentId,proposer,policyRef,proposedAt,steps
  if planId="" | remediationId="" | rootTradeId="" | baselineBookAssessmentId="" | proposer="" | policyRef="" | proposedAt="" then raise syntax 88.900 array("invalid hedge remediation plan")
  if \steps~isA(.array) | steps~items=0 then raise syntax 88.900 array("hedge remediation plan requires ordered steps")
  state="PROPOSED"; startingNetBaseExposure=0; projectedNetBaseExposure=0; peakAbsBaseExposure=0; approvalId=""; approvedBy=""; approvedAt=""; approvalAuthorityRef=""
  executionStartedAt=""; executionEvidenceCompleteAt=""; verificationId=""; verificationAssessmentId=""; verificationState=""; verifiedAt=""; actualNetBaseExposure=0; projectionDeviation=0
::method planId; expose planId; return planId
::method remediationId; expose remediationId; return remediationId
::method rootTradeId; expose rootTradeId; return rootTradeId
::method baselineBookAssessmentId; expose baselineBookAssessmentId; return baselineBookAssessmentId
::method proposer; expose proposer; return proposer
::method policyRef; expose policyRef; return policyRef
::method proposedAt; expose proposedAt; return proposedAt
::method steps; expose steps; return steps
::method state; expose state; return state
::method startingNetBaseExposure; expose startingNetBaseExposure; return startingNetBaseExposure
::method projectedNetBaseExposure; expose projectedNetBaseExposure; return projectedNetBaseExposure
::method peakAbsBaseExposure; expose peakAbsBaseExposure; return peakAbsBaseExposure
::method approvalId; expose approvalId; return approvalId
::method approvedBy; expose approvedBy; return approvedBy
::method approvedAt; expose approvedAt; return approvedAt
::method approvalAuthorityRef; expose approvalAuthorityRef; return approvalAuthorityRef
::method executionStartedAt; expose executionStartedAt; return executionStartedAt
::method executionEvidenceCompleteAt; expose executionEvidenceCompleteAt; return executionEvidenceCompleteAt
::method verificationId; expose verificationId; return verificationId
::method verificationAssessmentId; expose verificationAssessmentId; return verificationAssessmentId
::method verificationState; expose verificationState; return verificationState
::method verifiedAt; expose verifiedAt; return verifiedAt
::method actualNetBaseExposure; expose actualNetBaseExposure; return actualNetBaseExposure
::method projectionDeviation; expose projectionDeviation; return projectionDeviation
::method semanticFingerprint
  expose planId remediationId rootTradeId baselineBookAssessmentId proposer policyRef steps
  f=planId||"|"||remediationId||"|"||rootTradeId||"|"||baselineBookAssessmentId||"|"||proposer||"|"||policyRef
  do i=1 to steps~items
    st=steps[i]; f=f||"|"||st~stepId||":"||st~sequence||":"||st~actionType||":"||st~targetRef||":"||st~signedBaseExposureDelta||":"||st~instrumentEvidenceRef
  end
  return f
::method acceptProjection
  expose startingNetBaseExposure projectedNetBaseExposure peakAbsBaseExposure
  use strict arg startingNet,projectedNet,peakAbs
  startingNetBaseExposure=startingNet; projectedNetBaseExposure=projectedNet; peakAbsBaseExposure=peakAbs
  return self
::method markApproved
  expose state approvalId approvedBy approvedAt approvalAuthorityRef
  use strict arg id,by,at,authorityRef
  if state<>"PROPOSED" then raise syntax 88.900 array("only proposed remediation plan may be approved",state)
  if id="" | by="" | at="" | authorityRef="" then raise syntax 88.900 array("remediation plan approval evidence required")
  state="APPROVED"; approvalId=id; approvedBy=by; approvedAt=at; approvalAuthorityRef=authorityRef
  return self
::method markExecutionStarted
  expose state executionStartedAt
  use strict arg at
  if state<>"APPROVED" & state<>"EXECUTING" then raise syntax 88.900 array("remediation plan is not executable",state)
  if at="" then raise syntax 88.900 array("execution evidence time required")
  if state="APPROVED" then do; state="EXECUTING"; executionStartedAt=at; end
  return self
::method markExecutionEvidenceComplete
  expose state executionEvidenceCompleteAt
  use strict arg at
  if state<>"APPROVED" & state<>"EXECUTING" then raise syntax 88.900 array("remediation plan execution evidence cannot complete",state)
  if at="" then raise syntax 88.900 array("execution evidence completion time required")
  state="EVIDENCE_COMPLETE"; executionEvidenceCompleteAt=at
  return self
::method markExecutionVerified
  expose state verificationId verificationAssessmentId verificationState verifiedAt actualNetBaseExposure projectionDeviation
  use strict arg id,assessmentId,resultState,at,actualNet,deviation
  if state<>"EVIDENCE_COMPLETE" then raise syntax 88.900 array("remediation plan execution evidence is not complete",state)
  if id="" | assessmentId="" | resultState="" | at="" then raise syntax 88.900 array("remediation execution verification evidence required")
  verificationId=id; verificationAssessmentId=assessmentId; verificationState=resultState; verifiedAt=at; actualNetBaseExposure=actualNet; projectionDeviation=deviation
  if resultState="MATCHED_PROJECTED_BOOK" then state="VERIFIED"
  else state="DEVIATED"
  return self


::class MBHedgeRemediationPlanApproval public
::method init
  expose approvalId planId approver approvalAuthorityRef policyRef approvedAt
  use strict arg approvalId,planId,approver,approvalAuthorityRef,policyRef,approvedAt
  if approvalId="" | planId="" | approver="" | approvalAuthorityRef="" | policyRef="" | approvedAt="" then raise syntax 88.900 array("invalid hedge remediation plan approval")
::method approvalId; expose approvalId; return approvalId
::method planId; expose planId; return planId
::method approver; expose approver; return approver
::method approvalAuthorityRef; expose approvalAuthorityRef; return approvalAuthorityRef
::method policyRef; expose policyRef; return policyRef
::method approvedAt; expose approvedAt; return approvedAt
::method semanticFingerprint
  expose approvalId planId approver approvalAuthorityRef policyRef approvedAt
  return approvalId||"|"||planId||"|"||approver||"|"||approvalAuthorityRef||"|"||policyRef||"|"||approvedAt


::class MBHedgeRemediationPlanStepExecutionEvidence public
::method init
  expose evidenceId planId stepId executionSequence executionState sourceAuthority sourceRef authorityRef actualObjectRef observedSignedBaseExposureDelta effectiveAt policyRef detail
  use strict arg evidenceId,planId,stepId,executionSequence,executionState,sourceAuthority,sourceRef,authorityRef,actualObjectRef,observedSignedBaseExposureDelta,effectiveAt,policyRef,detail=""
  if evidenceId="" | planId="" | stepId="" | executionSequence<=0 | sourceAuthority="" | sourceRef="" | authorityRef="" | effectiveAt="" | policyRef="" then raise syntax 88.900 array("invalid remediation plan execution evidence")
  if executionState<>"COMPLETED" & executionState<>"PARTIAL" & executionState<>"FAILED" & executionState<>"NOT_EXECUTED" then raise syntax 88.900 array("invalid remediation plan execution state",executionState)
  if (executionState="COMPLETED" | executionState="PARTIAL") & actualObjectRef="" then raise syntax 88.900 array("completed/partial execution evidence requires actual object reference")
::method evidenceId; expose evidenceId; return evidenceId
::method planId; expose planId; return planId
::method stepId; expose stepId; return stepId
::method executionSequence; expose executionSequence; return executionSequence
::method executionState; expose executionState; return executionState
::method sourceAuthority; expose sourceAuthority; return sourceAuthority
::method sourceRef; expose sourceRef; return sourceRef
::method authorityRef; expose authorityRef; return authorityRef
::method actualObjectRef; expose actualObjectRef; return actualObjectRef
::method observedSignedBaseExposureDelta; expose observedSignedBaseExposureDelta; return observedSignedBaseExposureDelta
::method effectiveAt; expose effectiveAt; return effectiveAt
::method policyRef; expose policyRef; return policyRef
::method detail; expose detail; return detail
::method terminal; return .true


::class MBHedgeRemediationPlanExecutionVerification public
::method init
  expose verificationId planId bookAssessmentId verifiedAt resultState expectedNetBaseExposure actualNetBaseExposure projectionDeviation expectedStepCount observedStepCount failedStepCount partialStepCount notExecutedStepCount stepDeltaDeviationCount objectSemanticDeviationCount executionOrderDeviation evidenceBookMismatch detail
  use strict arg verificationId,planId,bookAssessmentId,verifiedAt,resultState,expectedNetBaseExposure,actualNetBaseExposure,projectionDeviation,expectedStepCount,observedStepCount,failedStepCount,partialStepCount,notExecutedStepCount,stepDeltaDeviationCount,objectSemanticDeviationCount,executionOrderDeviation,evidenceBookMismatch,detail=""
  if verificationId="" | planId="" | bookAssessmentId="" | verifiedAt="" | resultState="" then raise syntax 88.900 array("invalid remediation plan execution verification")
::method verificationId; expose verificationId; return verificationId
::method planId; expose planId; return planId
::method bookAssessmentId; expose bookAssessmentId; return bookAssessmentId
::method verifiedAt; expose verifiedAt; return verifiedAt
::method resultState; expose resultState; return resultState
::method expectedNetBaseExposure; expose expectedNetBaseExposure; return expectedNetBaseExposure
::method actualNetBaseExposure; expose actualNetBaseExposure; return actualNetBaseExposure
::method projectionDeviation; expose projectionDeviation; return projectionDeviation
::method expectedStepCount; expose expectedStepCount; return expectedStepCount
::method observedStepCount; expose observedStepCount; return observedStepCount
::method failedStepCount; expose failedStepCount; return failedStepCount
::method partialStepCount; expose partialStepCount; return partialStepCount
::method notExecutedStepCount; expose notExecutedStepCount; return notExecutedStepCount
::method stepDeltaDeviationCount; expose stepDeltaDeviationCount; return stepDeltaDeviationCount
::method objectSemanticDeviationCount; expose objectSemanticDeviationCount; return objectSemanticDeviationCount
::method executionOrderDeviation; expose executionOrderDeviation; return executionOrderDeviation
::method evidenceBookMismatch; expose evidenceBookMismatch; return evidenceBookMismatch
::method detail; expose detail; return detail


::class MBCFDNeutralisationResult public
::method init
  expose resultId originalTradeId offsetTrade sizingFxEvidenceRef realisedPnL signedSettlementAmount marketEvidenceRef authorityRef
  use strict arg resultId,originalTradeId,offsetTrade,sizingFxEvidenceRef,realisedPnL,signedSettlementAmount,marketEvidenceRef,authorityRef
  if resultId="" | originalTradeId="" | marketEvidenceRef="" | authorityRef="" then raise syntax 88.900 array("invalid CFD neutralisation result")
  if \offsetTrade~isA(.MBDerivativeTrade) | offsetTrade~productType<>"CFD" then raise syntax 88.900 array("CFD neutralisation requires reversing CFD trade")
::method resultId; expose resultId; return resultId
::method originalTradeId; expose originalTradeId; return originalTradeId
::method offsetTrade; expose offsetTrade; return offsetTrade
::method sizingFxEvidenceRef; expose sizingFxEvidenceRef; return sizingFxEvidenceRef
::method realisedPnL; expose realisedPnL; return realisedPnL
::method signedSettlementAmount; expose signedSettlementAmount; return signedSettlementAmount
::method marketEvidenceRef; expose marketEvidenceRef; return marketEvidenceRef
::method authorityRef; expose authorityRef; return authorityRef


::class MBRiskNeutralisationExecution public
::method init
  expose executionId instructionId portfolioId currency executedAt authorityRef tradeCount signedNetSettlement state
  use strict arg executionId,instructionId,portfolioId,currency,executedAt,authorityRef,tradeCount,signedNetSettlement
  if executionId="" | instructionId="" | portfolioId="" | currency="" | executedAt="" | authorityRef="" then raise syntax 88.900 array("invalid risk neutralisation execution")
  state="COMPLETE"
::method executionId; expose executionId; return executionId
::method instructionId; expose instructionId; return instructionId
::method portfolioId; expose portfolioId; return portfolioId
::method currency; expose currency; return currency
::method executedAt; expose executedAt; return executedAt
::method authorityRef; expose authorityRef; return authorityRef
::method tradeCount; expose tradeCount; return tradeCount
::method signedNetSettlement; expose signedNetSettlement; return signedNetSettlement
::method state; expose state; return state


::class MBMerchantPositionSummary public
::method init
  expose relationshipId currency valuationTime netMarketValue unrealisedPnL realisedPnL collateral marginRequired availableMargin positionCount valuationStatus sourceAuthority
  use strict arg relationshipId,currency,valuationTime,netMarketValue,unrealisedPnL,realisedPnL,collateral,marginRequired,availableMargin,positionCount,valuationStatus,sourceAuthority
::method relationshipId; expose relationshipId; return relationshipId
::method currency; expose currency; return currency
::method valuationTime; expose valuationTime; return valuationTime
::method netMarketValue; expose netMarketValue; return netMarketValue
::method unrealisedPnL; expose unrealisedPnL; return unrealisedPnL
::method realisedPnL; expose realisedPnL; return realisedPnL
::method collateral; expose collateral; return collateral
::method marginRequired; expose marginRequired; return marginRequired
::method availableMargin; expose availableMargin; return availableMargin
::method positionCount; expose positionCount; return positionCount
::method valuationStatus; expose valuationStatus; return valuationStatus
::method sourceAuthority; expose sourceAuthority; return sourceAuthority


::class FederationBankMerchantBank public
::method init
  expose merchantEntity portfolios agreements assets controls valuations assessments marginCalls closeOuts obligations journal relationships products marketEvidence tradeMarks latestMarkByTrade latestValuationByPortfolio latestAssessmentByPortfolio lifecycle realisedPnlByPortfolio liquidityEvidence cureRecords closeOutExecutions fxEvidence counterpartyRiskEvidence basisEvidence fungibilityEvidence latestFungibilityByHedge hedgeEquivalenceEvidence latestEquivalenceByHedge offsetIntents hedgeRelationships hedgeRiskAssessments latestHedgeRiskByHedge neutralisationExecutions referenceDocuments instrumentResolutionEvidence hedgeRemediations currentRemediationByHedge hedgeRemediationActions hedgeBookAssessments latestHedgeBookByRoot latestCounterpartyByTrade latestFxByPair instrumentResolutionAttestations latestInstrumentAttestationByProduct marketStructureEvents marketStructureApplications hedgeRemediationPlans currentPlanByRemediation remediationPlanApprovals remediationPlanStepExecutionEvidence remediationPlanStepEvidenceByPlanStep remediationPlanExecutionSequence remediationPlanExecutionVerifications latestPlanExecutionVerification
  use strict arg merchantEntity="FEDERATIONBANK_MERCHANT_BANK"
  portfolios=.directory~new
  agreements=.directory~new
  assets=.directory~new
  controls=.directory~new
  valuations=.directory~new
  assessments=.directory~new
  marginCalls=.directory~new
  closeOuts=.directory~new
  obligations=.directory~new
  relationships=.directory~new
  products=.directory~new
  marketEvidence=.directory~new
  tradeMarks=.directory~new
  latestMarkByTrade=.directory~new
  latestValuationByPortfolio=.directory~new
  latestAssessmentByPortfolio=.directory~new
  lifecycle=.directory~new
  realisedPnlByPortfolio=.directory~new
  liquidityEvidence=.directory~new
  cureRecords=.directory~new
  closeOutExecutions=.directory~new
  fxEvidence=.directory~new
  counterpartyRiskEvidence=.directory~new
  basisEvidence=.directory~new
  fungibilityEvidence=.directory~new
  latestFungibilityByHedge=.directory~new
  hedgeEquivalenceEvidence=.directory~new
  latestEquivalenceByHedge=.directory~new
  offsetIntents=.directory~new
  hedgeRelationships=.directory~new
  hedgeRiskAssessments=.directory~new
  latestHedgeRiskByHedge=.directory~new
  neutralisationExecutions=.directory~new
  referenceDocuments=.directory~new
  instrumentResolutionEvidence=.directory~new
  instrumentResolutionAttestations=.directory~new
  latestInstrumentAttestationByProduct=.directory~new
  marketStructureEvents=.directory~new
  marketStructureApplications=.directory~new
  hedgeRemediations=.directory~new
  currentRemediationByHedge=.directory~new
  hedgeRemediationActions=.directory~new
  hedgeBookAssessments=.directory~new
  latestHedgeBookByRoot=.directory~new
  latestCounterpartyByTrade=.directory~new
  latestFxByPair=.directory~new
  hedgeRemediationPlans=.directory~new
  currentPlanByRemediation=.directory~new
  remediationPlanApprovals=.directory~new
  remediationPlanStepExecutionEvidence=.directory~new
  remediationPlanStepEvidenceByPlanStep=.directory~new
  remediationPlanExecutionSequence=.directory~new
  remediationPlanExecutionVerifications=.directory~new
  latestPlanExecutionVerification=.directory~new
  initial=.directory~new
  initial["merchantEntity"]=merchantEntity
  journal=.JournalPointedState~new(initial,"FB-MERCHANT-" || merchantEntity)

::method merchantEntity; expose merchantEntity; return merchantEntity
::method journalPoint; expose journal; return journal~journalPoint
::method journal; expose journal; return journal


::method registerRelationship
  expose relationships journal
  use strict arg relationship
  if \relationship~isA(.MBMerchantRelationship) then raise syntax 88.900 array("MBMerchantRelationship required")
  if relationships~hasIndex(relationship~relationshipId) then raise syntax 88.900 array("duplicate merchant relationship")
  relationships[relationship~relationshipId]=relationship
  journal~put("relationship:"||relationship~relationshipId,relationship,"MERCHANT_RELATIONSHIP_OPEN",self~eventMeta("clientEntity",relationship~clientEntity))
  return relationship

::method relationship
  expose relationships
  use strict arg relationshipId
  return relationships[relationshipId]

::method recordReferenceDocumentEvidence
  expose referenceDocuments journal
  use strict arg evidence
  if \evidence~isA(.MBReferenceDocumentEvidence) then raise syntax 88.900 array("MBReferenceDocumentEvidence required")
  if referenceDocuments~hasIndex(evidence~documentEvidenceId) then raise syntax 88.900 array("duplicate reference document evidence")
  referenceDocuments[evidence~documentEvidenceId]=evidence
  journal~put("referenceDocument:"||evidence~documentEvidenceId,evidence,"REFERENCE_DOCUMENT_EVIDENCE_RECORDED",self~eventMeta("sourceAuthority",evidence~sourceAuthority))
  return evidence

::method referenceDocumentEvidence
  expose referenceDocuments
  use strict arg documentEvidenceId
  return referenceDocuments[documentEvidenceId]

::method recordInstrumentResolutionEvidence
  expose referenceDocuments instrumentResolutionEvidence journal
  use strict arg evidence
  if \evidence~isA(.MBInstrumentResolutionEvidence) then raise syntax 88.900 array("MBInstrumentResolutionEvidence required")
  if referenceDocuments[evidence~documentEvidenceId]==.nil then raise syntax 88.900 array("instrument resolution evidence requires known source document")
  if instrumentResolutionEvidence~hasIndex(evidence~evidenceId) then raise syntax 88.900 array("duplicate instrument resolution evidence")
  instrumentResolutionEvidence[evidence~evidenceId]=evidence
  journal~put("instrumentResolution:"||evidence~evidenceId,evidence,"INSTRUMENT_RESOLUTION_EVIDENCE_RECORDED",self~eventMeta("venueMic",evidence~venueMic))
  return evidence

::method instrumentResolutionEvidence
  expose instrumentResolutionEvidence
  use strict arg evidenceId
  return instrumentResolutionEvidence[evidenceId]

::method instrumentIdentityFromEvidence
  expose instrumentResolutionEvidence
  use strict arg evidenceId,contractCurrency,conversionRatio=1,issuerRef=""
  e=instrumentResolutionEvidence[evidenceId]
  if e==.nil then raise syntax 88.900 array("unknown instrument resolution evidence",evidenceId)
  return .MBInstrumentIdentity~new(e~economicUnderlyingId,e~isin,e~venueMic,e~representationType,e~quoteCurrency,e~settlementCurrency,contractCurrency,conversionRatio,issuerRef,e~denominationCurrency,e~securityLineRef,e~placeOfSafekeeping,e~evidenceId)


::method attestProductInstrumentResolution
  expose products instrumentResolutionEvidence instrumentResolutionAttestations latestInstrumentAttestationByProduct journal
  use arg productOrAttestation,attestationArg=.nil
  if productOrAttestation~isA(.MBInstrumentResolutionAttestation) then attestation=productOrAttestation
  else do
    if attestationArg==.nil | \attestationArg~isA(.MBInstrumentResolutionAttestation) then raise syntax 88.900 array("MBInstrumentResolutionAttestation required")
    attestation=attestationArg
    if productOrAttestation<>attestation~productId then raise syntax 88.900 array("attestation product identifier mismatch")
  end
  if instrumentResolutionAttestations~hasIndex(attestation~attestationId) then raise syntax 88.900 array("duplicate instrument resolution attestation")
  product=products[attestation~productId]
  if product==.nil then raise syntax 88.900 array("attestation references unknown derivative product")
  if product~productVersion<>attestation~productVersion then raise syntax 88.900 array("attestation product version mismatch",product~productVersion,attestation~productVersion)
  identity=product~instrumentIdentity
  if identity==.nil then raise syntax 88.900 array("product has no instrument identity to attest")
  if identity~resolutionEvidenceRef="" then raise syntax 88.900 array("product instrument is not bound to resolution evidence")
  if identity~resolutionEvidenceRef<>attestation~resolutionEvidenceRef then raise syntax 88.900 array("attestation resolution evidence mismatch",identity~resolutionEvidenceRef,attestation~resolutionEvidenceRef)
  evidence=instrumentResolutionEvidence[attestation~resolutionEvidenceRef]
  if evidence==.nil | \evidence~matchesIdentity(identity) then raise syntax 88.900 array("attestation resolution evidence unavailable or inconsistent")
  if identity~settlementLineKey<>attestation~settlementLineKey then raise syntax 88.900 array("attestation settlement-line identity mismatch",identity~settlementLineKey,attestation~settlementLineKey)
  instrumentResolutionAttestations[attestation~attestationId]=attestation
  latestInstrumentAttestationByProduct[attestation~productId]=attestation
  journal~put("instrumentResolutionAttestation:"||attestation~attestationId,attestation,"INSTRUMENT_RESOLUTION_ATTESTED",self~eventMeta("productId",attestation~productId))
  return attestation

::method instrumentResolutionAttestation
  expose instrumentResolutionAttestations
  use strict arg attestationId
  return instrumentResolutionAttestations[attestationId]

::method productInstrumentResolutionAttestation
  expose latestInstrumentAttestationByProduct
  use strict arg productId
  return latestInstrumentAttestationByProduct[productId]

::method registerProduct
  expose products journal instrumentResolutionEvidence
  use strict arg product
  if \product~isA(.MBDerivativeProductDefinition) then raise syntax 88.900 array("MBDerivativeProductDefinition required")
  if products~hasIndex(product~productId) then raise syntax 88.900 array("duplicate derivative product")
  identity=product~instrumentIdentity
  if identity<>.nil then do
    if identity~resolutionEvidenceRef<>"" then do
      evidence=instrumentResolutionEvidence[identity~resolutionEvidenceRef]
      if evidence==.nil then raise syntax 88.900 array("product instrument references unknown resolution evidence")
      if \evidence~matchesIdentity(identity) then raise syntax 88.900 array("product instrument does not match resolution evidence")
    end
  end
  products[product~productId]=product
  journal~put("product:"||product~productId,product,"DERIVATIVE_PRODUCT_APPROVED",self~eventMeta("productVersion",product~productVersion))
  return product

::method product
  expose products
  use strict arg productId
  return products[productId]

::method recordFXEvidence
  expose fxEvidence latestFxByPair journal
  use strict arg evidence
  if \evidence~isA(.MBFXEvidence) then raise syntax 88.900 array("MBFXEvidence required")
  if fxEvidence~hasIndex(evidence~evidenceId) then raise syntax 88.900 array("duplicate FX evidence")
  fxEvidence[evidence~evidenceId]=evidence
  latestFxByPair[evidence~baseCurrency||">"||evidence~quoteCurrency]=evidence
  latestFxByPair[evidence~quoteCurrency||">"||evidence~baseCurrency]=evidence
  journal~put("fxEvidence:"||evidence~evidenceId,evidence,"FX_EVIDENCE_RECORDED",self~eventMeta("sourceAuthority",evidence~sourceAuthority))
  return evidence

::method fxEvidence
  expose fxEvidence
  use strict arg evidenceId
  return fxEvidence[evidenceId]

::method recordCounterpartyRiskEvidence
  expose counterpartyRiskEvidence latestCounterpartyByTrade journal
  use strict arg evidence
  if \evidence~isA(.MBCounterpartyRiskEvidence) then raise syntax 88.900 array("MBCounterpartyRiskEvidence required")
  if counterpartyRiskEvidence~hasIndex(evidence~evidenceId) then raise syntax 88.900 array("duplicate counterparty risk evidence")
  t=self~tradeById(evidence~tradeId)
  if t==.nil then raise syntax 88.900 array("counterparty risk references unknown trade")
  if t~counterpartyEntity<>"" & t~counterpartyEntity<>evidence~counterpartyEntity then raise syntax 88.900 array("counterparty risk legal entity mismatch")
  counterpartyRiskEvidence[evidence~evidenceId]=evidence
  latestCounterpartyByTrade[evidence~tradeId]=evidence
  journal~put("counterpartyRisk:"||evidence~evidenceId,evidence,"COUNTERPARTY_RISK_RECORDED",self~eventMeta("counterparty",evidence~counterpartyEntity))
  return evidence

::method recordBasisRiskEvidence
  expose basisEvidence hedgeRelationships journal
  use strict arg evidence
  if \evidence~isA(.MBBasisRiskEvidence) then raise syntax 88.900 array("MBBasisRiskEvidence required")
  if hedgeRelationships[evidence~hedgeId]==.nil then raise syntax 88.900 array("basis evidence references unknown hedge")
  if basisEvidence~hasIndex(evidence~evidenceId) then raise syntax 88.900 array("duplicate basis risk evidence")
  basisEvidence[evidence~evidenceId]=evidence
  journal~put("basisRisk:"||evidence~evidenceId,evidence,"HEDGE_BASIS_RISK_RECORDED",self~eventMeta("hedgeId",evidence~hedgeId))
  return evidence

::method recordHedgeFungibilityEvidence
  expose fungibilityEvidence latestFungibilityByHedge hedgeRelationships journal
  use strict arg evidence
  if \evidence~isA(.MBHedgeFungibilityEvidence) then raise syntax 88.900 array("MBHedgeFungibilityEvidence required")
  h=hedgeRelationships[evidence~hedgeId]
  if h==.nil then raise syntax 88.900 array("fungibility evidence references unknown hedge")
  if fungibilityEvidence~hasIndex(evidence~evidenceId) then raise syntax 88.900 array("duplicate fungibility evidence")
  prior=latestFungibilityByHedge[evidence~hedgeId]
  fungibilityEvidence[evidence~evidenceId]=evidence
  latestFungibilityByHedge[evidence~hedgeId]=evidence
  if evidence~healthy then do
    h~markEquivalence("EQUIVALENT",evidence~evidenceId)
    eventType="HEDGE_EQUIVALENCE_CONFIRMED"
    if prior<>.nil then if \prior~healthy then eventType="HEDGE_EQUIVALENCE_RESTORED"
  end
  else do
    h~markEquivalence("IMPAIRED",evidence~evidenceId)
    h~markEconomicState("HEDGE_IMPAIRED")
    eventType="HEDGE_EQUIVALENCE_IMPAIRED"
  end
  edit=journal~beginEdit(eventType,self~eventMeta("hedgeId",evidence~hedgeId))
  edit~put("fungibility:"||evidence~evidenceId,evidence)
  edit~put("hedge:"||evidence~hedgeId,h)
  edit~commit
  return evidence


::method recordMarketStructureEvent
  expose marketStructureEvents instrumentResolutionEvidence journal
  use strict arg event
  if \event~isA(.MBMarketStructureEvent) then raise syntax 88.900 array("MBMarketStructureEvent required")
  if marketStructureEvents~hasIndex(event~eventId) then raise syntax 88.900 array("duplicate market structure event")
  if instrumentResolutionEvidence[event~affectedInstrumentEvidenceRef]==.nil then raise syntax 88.900 array("market structure event references unknown instrument resolution evidence",event~affectedInstrumentEvidenceRef)
  marketStructureEvents[event~eventId]=event
  journal~put("marketStructureEvent:"||event~eventId,event,"MARKET_STRUCTURE_EVENT_RECORDED",self~eventMeta("eventType",event~eventType))
  return event

::method marketStructureEvent
  expose marketStructureEvents
  use strict arg eventId
  return marketStructureEvents[eventId]

::method applyMarketStructureEventToHedge
  expose marketStructureEvents marketStructureApplications hedgeRelationships latestEquivalenceByHedge products instrumentResolutionEvidence journal
  use arg eventOrId,hedgeId,equivalenceEvidenceId=""
  if eventOrId~isA(.MBMarketStructureEvent) then do
    event=eventOrId
    if marketStructureEvents[event~eventId]==.nil then self~recordMarketStructureEvent(event)
    else if marketStructureEvents[event~eventId] \== event then raise syntax 88.900 array("market structure event id already bound to another event")
  end
  else do
    event=marketStructureEvents[eventOrId]
    if event==.nil then raise syntax 88.900 array("unknown market structure event",eventOrId)
  end
  h=hedgeRelationships[hedgeId]
  if h==.nil then raise syntax 88.900 array("unknown hedge",hedgeId)
  appKey=event~eventId||"|"||hedgeId
  if marketStructureApplications~hasIndex(appKey) then raise syntax 88.900 array("market structure event already applied to hedge")
  original=self~tradeById(h~originalTradeId); offset=self~tradeById(h~offsetTradeId)
  op=self~productForTrade(original); xp=self~productForTrade(offset)
  if op==.nil | xp==.nil | op~instrumentIdentity==.nil | xp~instrumentIdentity==.nil then raise syntax 88.900 array("market structure event requires instrument-resolved hedge legs")
  oi=op~instrumentIdentity; xi=xp~instrumentIdentity
  if oi~resolutionEvidenceRef="" | xi~resolutionEvidenceRef="" then raise syntax 88.900 array("market structure event requires evidence-bound hedge legs")
  affected=event~affectedInstrumentEvidenceRef
  if affected<>oi~resolutionEvidenceRef & affected<>xi~resolutionEvidenceRef then raise syntax 88.900 array("market structure event does not affect either exact hedge settlement line",affected)
  if instrumentResolutionEvidence[oi~resolutionEvidenceRef]==.nil | instrumentResolutionEvidence[xi~resolutionEvidenceRef]==.nil then raise syntax 88.900 array("hedge instrument resolution evidence unavailable")
  prior=latestEquivalenceByHedge[hedgeId]
  version=1; supersedes=""
  if prior<>.nil then do
    version=prior~version+1
    supersedes=prior~evidenceId
  end
  if equivalenceEvidenceId="" then equivalenceEvidenceId="EQE-MS-"||event~eventId||"-"||hedgeId
  eq=.MBHedgeEquivalenceEvidence~new(equivalenceEvidenceId,hedgeId,version,supersedes,event~effectiveAt,event~jurisdiction,event~sourceAuthority,event~eventId,event~legalEffectRef,oi~resolutionEvidenceRef,xi~resolutionEvidenceRef,event~conversionAvailable,event~settlementAvailable,event~custodyTransferAvailable,event~legalTransferPermitted,event~marketLiquidityAvailable,event~reasonCode)
  self~recordHedgeEquivalenceEvidence(eq)
  marketStructureApplications[appKey]=equivalenceEvidenceId
  journal~put("marketStructureApplication:"||appKey,equivalenceEvidenceId,"MARKET_STRUCTURE_EVENT_APPLIED_TO_HEDGE",self~eventMeta("hedgeId",hedgeId))
  return eq

::method marketStructureApplicationEvidenceRef
  expose marketStructureApplications
  use strict arg eventId,hedgeId
  return marketStructureApplications[eventId||"|"||hedgeId]

::method recordHedgeEquivalenceEvidence
  expose hedgeEquivalenceEvidence latestEquivalenceByHedge hedgeRelationships products instrumentResolutionEvidence journal
  use strict arg evidence
  if \evidence~isA(.MBHedgeEquivalenceEvidence) then raise syntax 88.900 array("MBHedgeEquivalenceEvidence required")
  h=hedgeRelationships[evidence~hedgeId]
  if h==.nil then raise syntax 88.900 array("hedge equivalence evidence references unknown hedge")
  if hedgeEquivalenceEvidence~hasIndex(evidence~evidenceId) then raise syntax 88.900 array("duplicate hedge equivalence evidence")
  prior=latestEquivalenceByHedge[evidence~hedgeId]
  if prior==.nil then do
    if evidence~version<>1 | evidence~supersedesEvidenceRef<>"" then raise syntax 88.900 array("first hedge equivalence evidence must be version 1")
  end
  else do
    if evidence~version<>prior~version+1 then raise syntax 88.900 array("hedge equivalence evidence version must advance exactly once",prior~version,evidence~version)
    if evidence~supersedesEvidenceRef<>prior~evidenceId then raise syntax 88.900 array("hedge equivalence evidence must supersede current evidence",prior~evidenceId)
  end
  original=self~tradeById(h~originalTradeId)
  offset=self~tradeById(h~offsetTradeId)
  if original==.nil | offset==.nil then raise syntax 88.900 array("hedge equivalence evidence references missing trade")
  op=self~productForTrade(original); xp=self~productForTrade(offset)
  if op<>.nil then do
    oi=op~instrumentIdentity
    if oi<>.nil then if oi~resolutionEvidenceRef<>"" then do
      if evidence~originalInstrumentEvidenceRef<>oi~resolutionEvidenceRef then raise syntax 88.900 array("original instrument equivalence evidence mismatch",oi~resolutionEvidenceRef,evidence~originalInstrumentEvidenceRef)
      if instrumentResolutionEvidence[oi~resolutionEvidenceRef]==.nil then raise syntax 88.900 array("original instrument resolution evidence unavailable")
    end
  end
  if xp<>.nil then do
    xi=xp~instrumentIdentity
    if xi<>.nil then if xi~resolutionEvidenceRef<>"" then do
      if evidence~offsetInstrumentEvidenceRef<>xi~resolutionEvidenceRef then raise syntax 88.900 array("offset instrument equivalence evidence mismatch",xi~resolutionEvidenceRef,evidence~offsetInstrumentEvidenceRef)
      if instrumentResolutionEvidence[xi~resolutionEvidenceRef]==.nil then raise syntax 88.900 array("offset instrument resolution evidence unavailable")
    end
  end
  hedgeEquivalenceEvidence[evidence~evidenceId]=evidence
  latestEquivalenceByHedge[evidence~hedgeId]=evidence
  state=evidence~equivalenceState
  h~markEquivalence(state,evidence~evidenceId)
  eventType="HEDGE_EQUIVALENCE_CONFIRMED"
  if state="IMPAIRED" then do
    eventType="HEDGE_EQUIVALENCE_IMPAIRED"
    h~markEconomicState("HEDGE_IMPAIRED")
  end
  else if prior<>.nil then if \prior~healthy then eventType="HEDGE_EQUIVALENCE_RESTORED"
  edit=journal~beginEdit(eventType,self~eventMeta("hedgeId",evidence~hedgeId))
  edit~put("hedgeEquivalence:"||evidence~evidenceId,evidence)
  edit~put("hedgeEquivalenceLatest:"||evidence~hedgeId,evidence~evidenceId)
  edit~put("hedge:"||evidence~hedgeId,h)
  edit~commit
  return evidence

::method hedgeEquivalenceEvidence
  expose hedgeEquivalenceEvidence
  use strict arg evidenceId
  return hedgeEquivalenceEvidence[evidenceId]

::method latestHedgeEquivalenceEvidence
  expose latestEquivalenceByHedge
  use strict arg hedgeId
  return latestEquivalenceByHedge[hedgeId]

::method hedgeRelationship
  expose hedgeRelationships
  use strict arg hedgeId
  return hedgeRelationships[hedgeId]

::method hedgeIds
  expose hedgeRelationships
  ids=.array~new
  do hedgeId over hedgeRelationships~allIndexes
    ids~append(hedgeId)
  end
  ids~sort
  return ids

::method hedgesAffectedByInstrumentEvidence
  expose hedgeRelationships
  use strict arg evidenceRef
  if evidenceRef="" then raise syntax 88.900 array("instrument evidence reference required")
  found=.array~new
  do hedgeId over hedgeRelationships~allIndexes
    h=hedgeRelationships[hedgeId]
    original=self~tradeById(h~originalTradeId)
    offset=self~tradeById(h~offsetTradeId)
    if original==.nil | offset==.nil then iterate
    op=self~productForTrade(original); xp=self~productForTrade(offset)
    oi=.nil; xi=.nil
    if op<>.nil then oi=op~instrumentIdentity
    if xp<>.nil then xi=xp~instrumentIdentity
    affected=.false
    if oi<>.nil then if oi~resolutionEvidenceRef=evidenceRef then affected=.true
    if xi<>.nil then if xi~resolutionEvidenceRef=evidenceRef then affected=.true
    if affected then found~append(hedgeId)
  end
  found~sort
  return found

::method rootCFDTradeIdForHedge
  expose hedgeRelationships
  use strict arg hedgeId
  h=hedgeRelationships[hedgeId]
  if h==.nil then raise syntax 88.900 array("unknown hedge",hedgeId)
  current=h~originalTradeId
  seen=.directory~new
  do forever
    if seen~hasIndex(current) then raise syntax 88.900 array("cyclic CFD hedge graph",hedgeId,current)
    seen[current]=.true
    parent=""
    do candidateId over hedgeRelationships~allIndexes
      candidate=hedgeRelationships[candidateId]
      if candidate~offsetTradeId=current then do
        if parent<>"" & parent<>candidate~originalTradeId then raise syntax 88.900 array("ambiguous CFD hedge-book root",hedgeId,current)
        parent=candidate~originalTradeId
      end
    end
    if parent="" then leave
    current=parent
  end
  root=self~tradeById(current)
  if root==.nil | root~productType<>"CFD" | \root~contractualActive then raise syntax 88.900 array("invalid CFD hedge-book root",current)
  return current

::method rootsAffectedByInstrumentEvidence
  use strict arg evidenceRef
  roots=.directory~new
  impacted=self~hedgesAffectedByInstrumentEvidence(evidenceRef)
  do hedgeId over impacted
    rootId=self~rootCFDTradeIdForHedge(hedgeId)
    roots[rootId]=.true
  end
  found=.array~new
  do rootId over roots~allIndexes
    found~append(rootId)
  end
  found~sort
  return found

::method hedgeRiskAssessment
  expose hedgeRiskAssessments
  use strict arg assessmentId
  return hedgeRiskAssessments[assessmentId]

::method latestHedgeRiskAssessment
  expose latestHedgeRiskByHedge
  use strict arg hedgeId
  return latestHedgeRiskByHedge[hedgeId]

::method reassessHedgeRiskFromLatestKnown
  expose hedgeRelationships latestHedgeRiskByHedge
  use strict arg assessmentId,hedgeId,equivalenceEvidenceRef="",asAt=""
  h=hedgeRelationships[hedgeId]
  if h==.nil then raise syntax 88.900 array("unknown hedge",hedgeId)
  prior=latestHedgeRiskByHedge[hedgeId]
  fxRef=h~sizingFxEvidenceRef
  basisRef=""; cpRef=""
  if prior<>.nil then do
    if prior~fxEvidenceRef<>"" then fxRef=prior~fxEvidenceRef
    basisRef=prior~basisEvidenceRef
    cpRef=prior~counterpartyEvidenceRef
  end
  return self~assessHedgeRisk(assessmentId,hedgeId,fxRef,basisRef,cpRef,"",asAt,equivalenceEvidenceRef)

::method assessCFDHedgeBook
  expose hedgeRelationships hedgeBookAssessments latestHedgeBookByRoot latestCounterpartyByTrade latestFxByPair currentRemediationByHedge journal
  use strict arg assessmentId,rootTradeId,asAt=""
  if hedgeBookAssessments~hasIndex(assessmentId) then raise syntax 88.900 array("duplicate CFD hedge-book assessment")
  root=self~tradeById(rootTradeId)
  if root==.nil | root~productType<>"CFD" | \root~contractualActive then raise syntax 88.900 array("CFD hedge-book assessment requires active root CFD")
  included=.directory~new
  included[rootTradeId]=.true
  changed=.true
  do while changed
    changed=.false
    do hid over hedgeRelationships~allIndexes
      h=hedgeRelationships[hid]
      if included~hasIndex(h~originalTradeId) then do
        if \included~hasIndex(h~offsetTradeId) then do
          included[h~offsetTradeId]=.true
          changed=.true
        end
      end
    end
  end
  tradeIds=.array~new
  hedgeIds=.array~new
  gross=0; net=0; cp=0; replacement=0; hedgeCount=0; impaired=0; unproved=0; openRemediation=0
  do tid over included~allIndexes
    t=self~tradeById(tid)
    if t==.nil | t~productType<>"CFD" | \t~contractualActive then raise syntax 88.900 array("hedge-book graph references invalid CFD",tid)
    tradeIds~append(tid)
    amount=t~notional
    if t~currency<>root~currency then do
      fx=latestFxByPair[t~currency||">"||root~currency]
      if fx==.nil | \fx~supports(t~currency,root~currency) then raise syntax 88.900 array("latest FX evidence required for hedge-book currency",t~currency,root~currency)
      amount=fx~convert(amount,t~currency,root~currency)
      if asAt="" then asAt=fx~observedAt
    end
    gross=gross+abs(amount)
    net=net+self~signedNotional(amount,t~side)
    ce=latestCounterpartyByTrade[tid]
    if ce<>.nil then do
      cp=cp+ce~currentExposure
      replacement=replacement+ce~replacementCost
      if asAt="" then asAt=ce~asAt
    end
  end
  do hid over hedgeRelationships~allIndexes
    h=hedgeRelationships[hid]
    if included~hasIndex(h~originalTradeId) & included~hasIndex(h~offsetTradeId) then do
      hedgeIds~append(hid); hedgeCount=hedgeCount+1
      if h~equivalenceState="IMPAIRED" then impaired=impaired+1
      if h~equivalenceState="EQUIVALENCE_UNPROVED" then unproved=unproved+1
      rr=currentRemediationByHedge[hid]
      if rr<>.nil then if rr~state<>"RESOLVED" then openRemediation=openRemediation+1
    end
  end
  if asAt="" then asAt=root~executedAt
  if net<>0 then state="DIRECTIONAL_RESIDUAL"
  else if impaired>0 then state="NET_ZERO_WITH_IMPAIRED_CONTRACTS"
  else if unproved>0 then state="NET_ZERO_WITH_UNPROVED_EQUIVALENCE"
  else if cp>0 | replacement>0 then state="NET_ZERO_WITH_COUNTERPARTY_RISK"
  else state="NET_ZERO_WITH_MONITORING"
  a=.MBCFDHedgeBookAssessment~new(assessmentId,rootTradeId,asAt,root~currency,tradeIds~items,hedgeCount,gross,net,impaired,unproved,openRemediation,cp,replacement,state,tradeIds,hedgeIds)
  hedgeBookAssessments[assessmentId]=a
  latestHedgeBookByRoot[rootTradeId]=a
  journal~put("hedgeBookRisk:"||assessmentId,a,"CFD_HEDGE_BOOK_ASSESSED",self~eventMeta("state",state))
  return a

::method hedgeBookAssessment
  expose hedgeBookAssessments
  use strict arg assessmentId
  return hedgeBookAssessments[assessmentId]

::method latestCFDHedgeBookAssessment
  expose latestHedgeBookByRoot
  use strict arg rootTradeId
  return latestHedgeBookByRoot[rootTradeId]


::method proposeHedgeRemediationPlan
  expose hedgeRemediationPlans currentPlanByRemediation hedgeRemediations hedgeBookAssessments latestHedgeBookByRoot hedgeRelationships instrumentResolutionEvidence journal
  use strict arg plan
  if \plan~isA(.MBHedgeRemediationPlan) then raise syntax 88.900 array("MBHedgeRemediationPlan required")
  if hedgeRemediationPlans~hasIndex(plan~planId) then raise syntax 88.900 array("duplicate hedge remediation plan",plan~planId)
  r=hedgeRemediations[plan~remediationId]
  if r==.nil then raise syntax 88.900 array("unknown hedge remediation",plan~remediationId)
  if r~state="RESOLVED" then raise syntax 88.900 array("resolved hedge remediation cannot accept a plan")
  if r~policyRef<>plan~policyRef then raise syntax 88.900 array("remediation plan policy mismatch")
  h=hedgeRelationships[r~hedgeId]
  if h==.nil then raise syntax 88.900 array("remediation hedge unavailable")
  root=self~rootCFDTradeIdForHedge(r~hedgeId)
  if root<>plan~rootTradeId then raise syntax 88.900 array("remediation plan root trade mismatch",root,plan~rootTradeId)
  baseline=hedgeBookAssessments[plan~baselineBookAssessmentId]
  if baseline==.nil | baseline~rootTradeId<>root then raise syntax 88.900 array("remediation plan requires matching whole-book baseline")
  latest=latestHedgeBookByRoot[root]
  if latest==.nil | latest~assessmentId<>baseline~assessmentId then raise syntax 88.900 array("stale whole-book baseline cannot seed remediation plan")
  if \baseline~hasHedge(r~hedgeId) then raise syntax 88.900 array("remediation hedge absent from baseline book")
  prior=currentPlanByRemediation[r~remediationId]
  if prior<>.nil then if prior~state="PROPOSED" | prior~state="APPROVED" then raise syntax 88.900 array("remediation already has current plan",prior~planId)
  net=baseline~netBaseExposure; startNet=net; peak=abs(net); expected=1; ids=.directory~new; hasReplacement=.false; hasNeutralise=.false
  steps=plan~steps
  do i=1 to steps~items
    st=steps[i]
    if \st~isA(.MBHedgeRemediationPlanStep) then raise syntax 88.900 array("MBHedgeRemediationPlanStep required")
    if st~sequence<>expected then raise syntax 88.900 array("remediation plan step sequence must be contiguous",expected,st~sequence)
    expected+=1
    if ids~hasIndex(st~stepId) then raise syntax 88.900 array("duplicate remediation plan step",st~stepId)
    ids[st~stepId]=.true
    if st~targetRef<>"" then do
      if st~actionType="NEUTRALISE_EXISTING_HEDGE" | st~actionType="REHOME_CUSTODY" | st~actionType="RESTORE_FUNGIBILITY" | st~actionType="TRANSFER_HEDGE" then do
        if hedgeRelationships[st~targetRef]==.nil then raise syntax 88.900 array("remediation plan references unknown hedge",st~targetRef)
      end
    end
    if st~actionType="NEUTRALISE_EXISTING_HEDGE" then do
      if st~targetRef<>r~hedgeId then raise syntax 88.900 array("neutralisation step must target impaired remediation hedge",r~hedgeId)
      hasNeutralise=.true
    end
    if st~actionType="ADD_REPLACEMENT_HEDGE" then do
      if instrumentResolutionEvidence[st~instrumentEvidenceRef]==.nil then raise syntax 88.900 array("replacement plan references unknown instrument evidence",st~instrumentEvidenceRef)
      hasReplacement=.true
    end
    net=net+st~signedBaseExposureDelta
    if abs(net)>peak then peak=abs(net)
  end
  if startNet=0 then do
    if net<>0 then raise syntax 88.900 array("net-zero book remediation plan may not introduce directional exposure",net)
    if hasReplacement & \hasNeutralise then raise syntax 88.900 array("replacement of a netted impaired hedge must also neutralise the existing hedge leg")
  end
  else do
    if abs(net)>=abs(startNet) then raise syntax 88.900 array("directional remediation plan must reduce absolute whole-book exposure",startNet,net)
  end
  plan~acceptProjection(startNet,net,peak)
  hedgeRemediationPlans[plan~planId]=plan; currentPlanByRemediation[r~remediationId]=plan
  journal~put("hedgeRemediationPlan:"||plan~planId,plan,"HEDGE_REMEDIATION_PLAN_PROPOSED",self~eventMeta("remediationId",r~remediationId))
  return plan

::method approveHedgeRemediationPlan
  expose hedgeRemediationPlans remediationPlanApprovals hedgeRemediations latestHedgeBookByRoot journal
  use strict arg approval
  if \approval~isA(.MBHedgeRemediationPlanApproval) then raise syntax 88.900 array("MBHedgeRemediationPlanApproval required")
  if remediationPlanApprovals~hasIndex(approval~approvalId) then raise syntax 88.900 array("duplicate remediation plan approval",approval~approvalId)
  p=hedgeRemediationPlans[approval~planId]
  if p==.nil then raise syntax 88.900 array("unknown hedge remediation plan",approval~planId)
  if p~state<>"PROPOSED" then raise syntax 88.900 array("remediation plan not awaiting approval",p~state)
  if p~proposer=approval~approver then raise syntax 88.900 array("remediation plan requires independent maker/checker approval")
  if p~policyRef<>approval~policyRef then raise syntax 88.900 array("remediation plan approval policy mismatch")
  r=hedgeRemediations[p~remediationId]
  if r==.nil | r~state="RESOLVED" then raise syntax 88.900 array("remediation plan no longer actionable")
  latest=latestHedgeBookByRoot[p~rootTradeId]
  if latest==.nil | latest~assessmentId<>p~baselineBookAssessmentId then raise syntax 88.900 array("stale remediation plan requires fresh whole-book assessment")
  p~markApproved(approval~approvalId,approval~approver,approval~approvedAt,approval~approvalAuthorityRef)
  remediationPlanApprovals[approval~approvalId]=approval
  journal~put("hedgeRemediationPlan:"||p~planId,p,"HEDGE_REMEDIATION_PLAN_APPROVED",self~eventMeta("approvalId",approval~approvalId))
  return p

::method hedgeRemediationPlan
  expose hedgeRemediationPlans
  use strict arg planId
  return hedgeRemediationPlans[planId]

::method currentHedgeRemediationPlan
  expose currentPlanByRemediation
  use strict arg remediationId
  return currentPlanByRemediation[remediationId]

::method hedgeRemediationPlansFor
  expose hedgeRemediationPlans
  use arg remediationId=""
  rows=.array~new
  do id over hedgeRemediationPlans~allIndexes
    p=hedgeRemediationPlans[id]
    if remediationId="" | p~remediationId=remediationId then rows~append(p)
  end
  return rows

::method recordHedgeRemediationPlanStepExecutionEvidence
  expose hedgeRemediationPlans remediationPlanStepExecutionEvidence remediationPlanStepEvidenceByPlanStep remediationPlanExecutionSequence hedgeRelationships journal
  use strict arg evidence
  if \evidence~isA(.MBHedgeRemediationPlanStepExecutionEvidence) then raise syntax 88.900 array("MBHedgeRemediationPlanStepExecutionEvidence required")
  if remediationPlanStepExecutionEvidence~hasIndex(evidence~evidenceId) then raise syntax 88.900 array("duplicate remediation plan execution evidence",evidence~evidenceId)
  p=hedgeRemediationPlans[evidence~planId]
  if p==.nil then raise syntax 88.900 array("unknown hedge remediation plan",evidence~planId)
  if p~state<>"APPROVED" & p~state<>"EXECUTING" then raise syntax 88.900 array("remediation plan is not accepting execution evidence",p~state)
  if p~policyRef<>evidence~policyRef then raise syntax 88.900 array("remediation execution evidence policy mismatch")
  st=self~remediationPlanStep(p,evidence~stepId)
  if st==.nil then raise syntax 88.900 array("execution evidence references unknown plan step",evidence~stepId)
  key=p~planId||"|"||st~stepId
  if remediationPlanStepEvidenceByPlanStep~hasIndex(key) then raise syntax 88.900 array("remediation plan step already has terminal execution evidence",st~stepId)
  seqKey=p~planId||"|"||evidence~executionSequence
  if remediationPlanExecutionSequence~hasIndex(seqKey) then raise syntax 88.900 array("duplicate remediation execution sequence",evidence~executionSequence)
  nonDirectional=(st~actionType="RESTORE_FUNGIBILITY" | st~actionType="REHOME_CUSTODY" | st~actionType="TRANSFER_HEDGE")
  if nonDirectional & evidence~observedSignedBaseExposureDelta<>0 then raise syntax 88.900 array("non-directional execution evidence cannot claim exposure delta",st~actionType)
  if evidence~executionState="NOT_EXECUTED" & evidence~observedSignedBaseExposureDelta<>0 then raise syntax 88.900 array("not-executed step cannot claim exposure delta")
  if (evidence~executionState="COMPLETED" | evidence~executionState="PARTIAL") then do
    if st~actionType="NEUTRALISE_EXISTING_HEDGE" | st~actionType="ADD_REPLACEMENT_HEDGE" | st~actionType="REDUCE_CLIENT_EXPOSURE" then do
      actualHedge=hedgeRelationships[evidence~actualObjectRef]
      if actualHedge==.nil then raise syntax 88.900 array("directional remediation execution evidence must reference an actual hedge",evidence~actualObjectRef)
      if self~rootCFDTradeIdForHedge(actualHedge~hedgeId)<>p~rootTradeId then raise syntax 88.900 array("remediation execution hedge belongs to different CFD book")
    end
  end
  remediationPlanStepExecutionEvidence[evidence~evidenceId]=evidence
  remediationPlanStepEvidenceByPlanStep[key]=evidence
  remediationPlanExecutionSequence[seqKey]=evidence~evidenceId
  p~markExecutionStarted(evidence~effectiveAt)
  complete=.true
  do i=1 to p~steps~items
    k=p~planId||"|"||p~steps[i]~stepId
    if \remediationPlanStepEvidenceByPlanStep~hasIndex(k) then do; complete=.false; leave; end
  end
  if complete then p~markExecutionEvidenceComplete(evidence~effectiveAt)
  edit=journal~beginEdit("HEDGE_REMEDIATION_PLAN_EXECUTION_EVIDENCE_RECORDED",self~eventMeta("planId",p~planId))
  edit~put("hedgeRemediationPlanExecution:"||evidence~evidenceId,evidence)
  edit~put("hedgeRemediationPlan:"||p~planId,p)
  edit~commit
  return evidence

::method hedgeRemediationPlanStepExecutionEvidence
  expose remediationPlanStepExecutionEvidence
  use strict arg evidenceId
  return remediationPlanStepExecutionEvidence[evidenceId]

::method hedgeRemediationPlanExecutionEvidenceFor
  expose hedgeRemediationPlans remediationPlanStepEvidenceByPlanStep
  use strict arg planId
  p=hedgeRemediationPlans[planId]
  if p==.nil then return .array~new
  rows=.array~new
  do i=1 to p~steps~items
    e=remediationPlanStepEvidenceByPlanStep[planId||"|"||p~steps[i]~stepId]
    if e<>.nil then rows~append(e)
  end
  return rows

::method verifyHedgeRemediationPlanExecution
  expose hedgeRemediationPlans remediationPlanStepEvidenceByPlanStep remediationPlanExecutionVerifications latestPlanExecutionVerification hedgeBookAssessments latestHedgeBookByRoot hedgeRelationships journal
  use strict arg verificationId,planId,bookAssessmentId,verifiedAt
  if remediationPlanExecutionVerifications~hasIndex(verificationId) then raise syntax 88.900 array("duplicate remediation plan execution verification",verificationId)
  p=hedgeRemediationPlans[planId]
  if p==.nil then raise syntax 88.900 array("unknown hedge remediation plan",planId)
  if p~state<>"EVIDENCE_COMPLETE" then raise syntax 88.900 array("remediation plan execution evidence is not complete",p~state)
  a=hedgeBookAssessments[bookAssessmentId]
  if a==.nil | a~rootTradeId<>p~rootTradeId then raise syntax 88.900 array("execution verification requires matching whole-book assessment")
  latest=latestHedgeBookByRoot[p~rootTradeId]
  if latest==.nil | latest~assessmentId<>bookAssessmentId then raise syntax 88.900 array("stale whole-book assessment cannot verify remediation execution")
  observed=0; failed=0; partial=0; notExecuted=0; stepDeltaDeviation=0; objectDeviation=0; orderDeviation=.false; evidenceDelta=0; omittedExecutedObject=.false
  do i=1 to p~steps~items
    st=p~steps[i]
    e=remediationPlanStepEvidenceByPlanStep[planId||"|"||st~stepId]
    if e==.nil then raise syntax 88.900 array("execution verification missing plan step evidence",st~stepId)
    observed+=1
    if e~executionState="FAILED" then failed+=1
    if e~executionState="PARTIAL" then partial+=1
    if e~executionState="NOT_EXECUTED" then notExecuted+=1
    if e~executionSequence<>st~sequence then orderDeviation=.true
    if e~observedSignedBaseExposureDelta<>st~signedBaseExposureDelta then stepDeltaDeviation+=1
    evidenceDelta=evidenceDelta+e~observedSignedBaseExposureDelta
    if e~executionState="COMPLETED" | e~executionState="PARTIAL" then do
      if st~actionType="NEUTRALISE_EXISTING_HEDGE" | st~actionType="ADD_REPLACEMENT_HEDGE" | st~actionType="REDUCE_CLIENT_EXPOSURE" then do
        actualHedge=hedgeRelationships[e~actualObjectRef]
        if actualHedge==.nil then objectDeviation+=1
        else do
          if \a~hasHedge(e~actualObjectRef) then omittedExecutedObject=.true
          if st~actionType="NEUTRALISE_EXISTING_HEDGE" then do
            old=hedgeRelationships[st~targetRef]
            if old==.nil | actualHedge~originalTradeId<>old~offsetTradeId then objectDeviation+=1
          end
          else if self~rootCFDTradeIdForHedge(actualHedge~hedgeId)<>p~rootTradeId then objectDeviation+=1
          if st~actionType="ADD_REPLACEMENT_HEDGE" & st~instrumentEvidenceRef<>"" then do
            actualOffset=self~tradeById(actualHedge~offsetTradeId)
            actualProduct=self~productForTrade(actualOffset)
            if actualProduct==.nil | actualProduct~instrumentIdentity==.nil then objectDeviation+=1
            else if actualProduct~instrumentIdentity~resolutionEvidenceRef<>st~instrumentEvidenceRef then objectDeviation+=1
          end
        end
      end
    end
  end
  evidenceExpectedNet=p~startingNetBaseExposure+evidenceDelta
  evidenceBookMismatch=(evidenceExpectedNet<>a~netBaseExposure | omittedExecutedObject)
  deviation=a~netBaseExposure-p~projectedNetBaseExposure
  verificationResult="MATCHED_PROJECTED_BOOK"
  detail=""
  if failed>0 then do; verificationResult="EXECUTION_FAILED"; detail="failed steps="||failed; end
  else if notExecuted>0 then do; verificationResult="EXECUTION_NOT_COMPLETED"; detail="not executed steps="||notExecuted; end
  else if partial>0 then do; verificationResult="EXECUTION_PARTIAL"; detail="partial steps="||partial; end
  else if orderDeviation then do; verificationResult="EXECUTION_ORDER_DEVIATION"; detail="actual execution order differs from approved plan"; end
  else if objectDeviation>0 then do; verificationResult="STEP_OBJECT_DEVIATION"; detail="step object semantic deviations="||objectDeviation; end
  else if stepDeltaDeviation>0 then do; verificationResult="STEP_DELTA_DEVIATION"; detail="step delta deviations="||stepDeltaDeviation; end
  else if evidenceBookMismatch then do; verificationResult="EVIDENCE_BOOK_MISMATCH"; detail="execution evidence net does not match current book"; end
  else if deviation<>0 then do; verificationResult="PROJECTED_BOOK_DEVIATION"; detail="projected="||p~projectedNetBaseExposure||" actual="||a~netBaseExposure; end
  v=.MBHedgeRemediationPlanExecutionVerification~new(verificationId,planId,bookAssessmentId,verifiedAt,verificationResult,p~projectedNetBaseExposure,a~netBaseExposure,deviation,p~steps~items,observed,failed,partial,notExecuted,stepDeltaDeviation,objectDeviation,orderDeviation,evidenceBookMismatch,detail)
  remediationPlanExecutionVerifications[verificationId]=v
  latestPlanExecutionVerification[planId]=v
  p~markExecutionVerified(verificationId,bookAssessmentId,verificationResult,verifiedAt,a~netBaseExposure,deviation)
  edit=journal~beginEdit("HEDGE_REMEDIATION_PLAN_EXECUTION_VERIFIED",self~eventMeta("resultState",verificationResult))
  edit~put("hedgeRemediationPlanVerification:"||verificationId,v)
  edit~put("hedgeRemediationPlan:"||planId,p)
  edit~commit
  return v

::method hedgeRemediationPlanExecutionVerification
  expose remediationPlanExecutionVerifications
  use strict arg verificationId
  return remediationPlanExecutionVerifications[verificationId]

::method latestHedgeRemediationPlanExecutionVerification
  expose latestPlanExecutionVerification
  use strict arg planId
  return latestPlanExecutionVerification[planId]

::method remediationPlanStep private
  use strict arg plan,stepId
  do i=1 to plan~steps~items
    if plan~steps[i]~stepId=stepId then return plan~steps[i]
  end
  return .nil

::method mitigateHedgeRemediation
  expose hedgeRemediations hedgeRemediationActions hedgeBookAssessments latestHedgeBookByRoot hedgeRelationships journal
  use strict arg remediationId,actionEvidenceId,bookAssessmentId,mitigatedAt
  r=hedgeRemediations[remediationId]
  if r==.nil then raise syntax 88.900 array("unknown hedge remediation",remediationId)
  if r~state="RESOLVED" then raise syntax 88.900 array("resolved hedge remediation cannot be mitigated")
  action=hedgeRemediationActions[actionEvidenceId]
  if action==.nil | action~remediationId<>remediationId then raise syntax 88.900 array("invalid remediation action evidence")
  if action~actionType<>"REPLACE_HEDGE" & action~actionType<>"TRANSFER_HEDGE" then raise syntax 88.900 array("aggregate mitigation requires replacement/transfer action")
  old=hedgeRelationships[r~hedgeId]
  replacement=hedgeRelationships[action~replacementHedgeId]
  if old==.nil | replacement==.nil then raise syntax 88.900 array("remediation hedge relationship unavailable")
  if replacement~originalTradeId<>old~originalTradeId then raise syntax 88.900 array("replacement hedge must protect same original CFD")
  proof=hedgeBookAssessments[bookAssessmentId]
  if proof==.nil | proof~rootTradeId<>old~originalTradeId then raise syntax 88.900 array("whole-book proof does not cover original CFD")
  latest=latestHedgeBookByRoot[old~originalTradeId]
  if latest==.nil | latest~assessmentId<>bookAssessmentId then raise syntax 88.900 array("stale whole-book proof cannot mitigate remediation")
  if \proof~hasHedge(action~replacementHedgeId) then raise syntax 88.900 array("whole-book proof does not include replacement hedge")
  if replacement~equivalenceState<>"EQUIVALENT" then raise syntax 88.900 array("replacement hedge equivalence is not proved")
  if proof~unprovedHedgeCount>0 then raise syntax 88.900 array("whole-book proof contains unproved hedge equivalence",proof~unprovedHedgeCount)
  if proof~impairedHedgeCount<>1 then raise syntax 88.900 array("whole-book proof contains unexpected impaired hedges",proof~impairedHedgeCount)
  if \proof~directionallyNetted then raise syntax 88.900 array("replacement activity has not neutralised aggregate directional exposure",proof~netBaseExposure)
  r~markMitigated(actionEvidenceId,bookAssessmentId,mitigatedAt,"REPLACEMENT_BOOK_NETTED_WITH_CONTINUING_CONTRACT_MONITORING")
  journal~put("hedgeRemediation:"||remediationId,r,"HEDGE_REMEDIATION_MITIGATED",self~eventMeta("bookAssessmentId",bookAssessmentId))
  return r

::method openHedgeRemediation
  expose hedgeRemediations currentRemediationByHedge hedgeRelationships hedgeRiskAssessments journal
  use strict arg remediationId,hedgeId,triggerAssessmentId,policyRef,openedAt,dueBy=""
  if hedgeRemediations~hasIndex(remediationId) then raise syntax 88.900 array("duplicate hedge remediation",remediationId)
  h=hedgeRelationships[hedgeId]
  if h==.nil then raise syntax 88.900 array("unknown hedge",hedgeId)
  trigger=hedgeRiskAssessments[triggerAssessmentId]
  if trigger==.nil | trigger~hedgeId<>hedgeId then raise syntax 88.900 array("hedge remediation requires matching trigger assessment")
  if trigger~riskState<>"HEDGE_IMPAIRED" & trigger~riskState<>"EQUIVALENCE_UNPROVED" then raise syntax 88.900 array("hedge remediation requires impaired/unproved hedge risk",trigger~riskState)
  prior=currentRemediationByHedge[hedgeId]
  if prior<>.nil then if prior~state<>"RESOLVED" then raise syntax 88.900 array("hedge already has open remediation",prior~remediationId)
  r=.MBHedgeRemediationObligation~new(remediationId,hedgeId,triggerAssessmentId,trigger~equivalenceEvidenceRef,policyRef,openedAt,dueBy)
  hedgeRemediations[remediationId]=r
  currentRemediationByHedge[hedgeId]=r
  journal~put("hedgeRemediation:"||remediationId,r,"HEDGE_REMEDIATION_REQUIRED",self~eventMeta("hedgeId",hedgeId))
  return r

::method hedgeRemediation
  expose hedgeRemediations
  use strict arg remediationId
  return hedgeRemediations[remediationId]

::method currentHedgeRemediation
  expose currentRemediationByHedge
  use strict arg hedgeId
  return currentRemediationByHedge[hedgeId]

::method recordHedgeRemediationAction
  expose hedgeRemediations hedgeRemediationActions journal
  use strict arg evidence
  if \evidence~isA(.MBHedgeRemediationActionEvidence) then raise syntax 88.900 array("MBHedgeRemediationActionEvidence required")
  if hedgeRemediationActions~hasIndex(evidence~evidenceId) then raise syntax 88.900 array("duplicate hedge remediation action evidence")
  r=hedgeRemediations[evidence~remediationId]
  if r==.nil then raise syntax 88.900 array("remediation action references unknown obligation")
  if r~state="RESOLVED" then raise syntax 88.900 array("resolved remediation cannot accept action evidence")
  hedgeRemediationActions[evidence~evidenceId]=evidence
  r~markAction(evidence~evidenceId)
  edit=journal~beginEdit("HEDGE_REMEDIATION_ACTION_RECORDED",self~eventMeta("actionType",evidence~actionType))
  edit~put("hedgeRemediationAction:"||evidence~evidenceId,evidence)
  edit~put("hedgeRemediation:"||r~remediationId,r)
  edit~commit
  return evidence

::method hedgeRemediationAction
  expose hedgeRemediationActions
  use strict arg evidenceId
  return hedgeRemediationActions[evidenceId]

::method resolveHedgeRemediation
  expose hedgeRemediations hedgeRemediationActions hedgeRiskAssessments latestHedgeRiskByHedge hedgeRelationships latestEquivalenceByHedge journal
  use strict arg remediationId,actionEvidenceId,proofAssessmentId,resolvedAt
  r=hedgeRemediations[remediationId]
  if r==.nil then raise syntax 88.900 array("unknown hedge remediation",remediationId)
  if r~state="RESOLVED" then raise syntax 88.900 array("hedge remediation already resolved")
  action=hedgeRemediationActions[actionEvidenceId]
  if action==.nil | action~remediationId<>remediationId then raise syntax 88.900 array("invalid remediation action evidence")
  proof=hedgeRiskAssessments[proofAssessmentId]
  if proof==.nil then raise syntax 88.900 array("unknown hedge remediation proof assessment")
  if proof~riskState="HEDGE_IMPAIRED" | proof~riskState="EQUIVALENCE_UNPROVED" then raise syntax 88.900 array("remediation proof remains impaired/unproved",proof~riskState)
  disposition=""
  if action~actionType="RESTORE_FUNGIBILITY" | action~actionType="REHOME_CUSTODY" then do
    if proof~hedgeId<>r~hedgeId then raise syntax 88.900 array("restoration proof must assess original hedge")
    latest=latestHedgeRiskByHedge[r~hedgeId]
    if latest==.nil | latest~assessmentId<>proofAssessmentId then raise syntax 88.900 array("stale hedge risk assessment cannot resolve remediation")
    eq=latestEquivalenceByHedge[r~hedgeId]
    if eq==.nil | \eq~healthy then raise syntax 88.900 array("current hedge equivalence is not restored")
    if proof~equivalenceEvidenceRef<>eq~evidenceId then raise syntax 88.900 array("proof assessment does not bind current equivalence evidence")
    disposition="ORIGINAL_HEDGE_RESTORED"
  end
  else if action~actionType="REPLACE_HEDGE" | action~actionType="TRANSFER_HEDGE" then do
    replacement=hedgeRelationships[action~replacementHedgeId]
    if replacement==.nil then raise syntax 88.900 array("unknown replacement hedge")
    raise syntax 88.900 array("replacement/transfer requires aggregate book proof before remediation can resolve")
  end
  else do
    raise syntax 88.900 array("risk reduction alone cannot resolve hedge equivalence impairment")
  end
  r~resolve(actionEvidenceId,proofAssessmentId,resolvedAt,disposition)
  journal~put("hedgeRemediation:"||remediationId,r,"HEDGE_REMEDIATION_RESOLVED",self~eventMeta("disposition",disposition))
  return r

::method escalateHedgeRemediation
  expose hedgeRemediations journal
  use strict arg remediationId,escalatedAt,authorityRef,reasonCode
  r=hedgeRemediations[remediationId]
  if r==.nil then raise syntax 88.900 array("unknown hedge remediation",remediationId)
  r~markEscalated(escalatedAt,authorityRef,reasonCode)
  journal~put("hedgeRemediation:"||remediationId,r,"HEDGE_REMEDIATION_ESCALATED",self~eventMeta("reasonCode",reasonCode))
  return r

::method bookCFDOffset
  expose portfolios products fxEvidence offsetIntents hedgeRelationships journal
  use strict arg intentId,hedgeId,originalTradeId,offsetTrade,sizingFxEvidenceRef,authorityRef,executedAt
  if offsetIntents~hasIndex(intentId) | hedgeRelationships~hasIndex(hedgeId) then raise syntax 88.900 array("duplicate offset intent/hedge")
  original=self~tradeById(originalTradeId)
  if original==.nil | original~productType<>"CFD" | \original~contractualActive then raise syntax 88.900 array("CFD offset requires active original CFD")
  if \offsetTrade~isA(.MBDerivativeTrade) | offsetTrade~productType<>"CFD" then raise syntax 88.900 array("offsetting CFD trade required")
  if original~side=offsetTrade~side then raise syntax 88.900 array("CLOSE_INTENT_DIRECTION_MISMATCH",original~side,offsetTrade~side)
  if \offsetTrade~contractualActive then raise syntax 88.900 array("offset trade must be active")
  relationshipType=self~classifyHedge(original,offsetTrade)
  sizingFx=.nil
  if original~currency<>offsetTrade~currency then do
    sizingFx=fxEvidence[sizingFxEvidenceRef]
    if sizingFx==.nil | \sizingFx~supports(offsetTrade~currency,original~currency) then raise syntax 88.900 array("cross-currency offset requires matching FX evidence")
    offsetBase=sizingFx~convert(offsetTrade~notional,offsetTrade~currency,original~currency)
  end
  else do
    offsetBase=offsetTrade~notional
    if sizingFxEvidenceRef<>"" then do
      sizingFx=fxEvidence[sizingFxEvidenceRef]
      if sizingFx==.nil then raise syntax 88.900 array("unknown sizing FX evidence")
    end
  end
  before=self~signedNotional(original~notional,original~side)
  after=before+self~signedNotional(offsetBase,offsetTrade~side)
  if abs(after)>=abs(before) then raise syntax 88.900 array("CLOSE_INTENT_DID_NOT_REDUCE_EXPOSURE",before,after)
  p=portfolios[offsetTrade~portfolioId]
  if p==.nil then raise syntax 88.900 array("unknown offset portfolio",offsetTrade~portfolioId)
  if p~clientEntity<>offsetTrade~obligor | p~currency<>offsetTrade~currency then raise syntax 88.900 array("offset trade/portfolio identity mismatch")
  if offsetTrade~productId<>"" then do
    product=products[offsetTrade~productId]
    if product==.nil | product~status<>"ACTIVE" then raise syntax 88.900 array("unknown/inactive offset derivative product")
    if product~productType<>"CFD" | product~currency<>offsetTrade~currency then raise syntax 88.900 array("offset trade/product mismatch")
  end
  intent=.MBOffsetIntent~new(intentId,originalTradeId,executedAt,authorityRef)
  economicState="PARTIALLY_OFFSET"
  if after=0 then economicState="NET_ZERO"
  h=.MBHedgeRelationship~new(hedgeId,intentId,originalTradeId,offsetTrade~tradeId,relationshipType,sizingFxEvidenceRef,executedAt,original~currency,after,economicState)
  self~bookTrade(offsetTrade)
  if after=0 then original~markClientView("CLOSED")
  else original~markClientView("PARTIAL")
  original~markRiskState(economicState)
  offsetTrade~markClientView("HEDGE")
  offsetTrade~markRiskState(economicState)
  intent~markExecuted(hedgeId)
  offsetIntents[intentId]=intent
  hedgeRelationships[hedgeId]=h
  edit=journal~beginEdit("CFD_OFFSET_BOOKED",self~eventMeta("relationshipType",relationshipType))
  edit~put("trade:"||original~tradeId,original)
  edit~put("trade:"||offsetTrade~tradeId,offsetTrade)
  edit~put("offsetIntent:"||intentId,intent)
  edit~put("hedge:"||hedgeId,h)
  edit~commit
  return h

::method assessHedgeRisk
  expose hedgeRelationships hedgeRiskAssessments latestHedgeRiskByHedge fxEvidence counterpartyRiskEvidence basisEvidence fungibilityEvidence latestFungibilityByHedge hedgeEquivalenceEvidence latestEquivalenceByHedge journal
  use strict arg assessmentId,hedgeId,currentFxEvidenceRef="",basisEvidenceRef="",counterpartyEvidenceRef="",fungibilityEvidenceRef="",asAt="",equivalenceEvidenceRef=""
  if hedgeRiskAssessments~hasIndex(assessmentId) then raise syntax 88.900 array("duplicate hedge risk assessment")
  h=hedgeRelationships[hedgeId]
  if h==.nil then raise syntax 88.900 array("unknown hedge",hedgeId)
  original=self~tradeById(h~originalTradeId)
  offset=self~tradeById(h~offsetTradeId)
  if original==.nil | offset==.nil then raise syntax 88.900 array("hedge references missing trade")
  fx=.nil
  if original~currency<>offset~currency then do
    fx=fxEvidence[currentFxEvidenceRef]
    if fx==.nil | \fx~supports(offset~currency,original~currency) then raise syntax 88.900 array("current FX evidence required for cross-currency hedge")
    offsetBase=fx~convert(offset~notional,offset~currency,original~currency)
  end
  else offsetBase=offset~notional
  currentNet=self~signedNotional(original~notional,original~side)+self~signedNotional(offsetBase,offset~side)
  fxDrift=abs(currentNet-h~sizingNetExposure)
  basis=0
  if basisEvidenceRef<>"" then do
    be=basisEvidence[basisEvidenceRef]
    if be==.nil | be~hedgeId<>hedgeId then raise syntax 88.900 array("invalid basis evidence")
    basis=be~amountBaseCurrency
  end
  cp=0; replacement=0
  if counterpartyEvidenceRef<>"" then do
    ce=counterpartyRiskEvidence[counterpartyEvidenceRef]
    if ce==.nil | ce~tradeId<>offset~tradeId then raise syntax 88.900 array("counterparty evidence must reference offset leg")
    cp=ce~currentExposure; replacement=ce~replacementCost
  end
  fe=.nil
  ee=.nil
  if equivalenceEvidenceRef<>"" then do
    ee=hedgeEquivalenceEvidence[equivalenceEvidenceRef]
    if ee==.nil | ee~hedgeId<>hedgeId then raise syntax 88.900 array("invalid hedge equivalence evidence")
  end
  else ee=latestEquivalenceByHedge[hedgeId]
  if ee==.nil then do
    if fungibilityEvidenceRef<>"" then do
      fe=fungibilityEvidence[fungibilityEvidenceRef]
      if fe==.nil | fe~hedgeId<>hedgeId then raise syntax 88.900 array("invalid fungibility evidence")
    end
    else fe=latestFungibilityByHedge[hedgeId]
  end
  equivalence=h~equivalenceState
  if ee<>.nil then equivalence=ee~equivalenceState
  else if h~relationshipType<>"EXACT_OFFSET" & fe==.nil then equivalence="EQUIVALENCE_UNPROVED"
  else if fe<>.nil then do
    if fe~healthy then equivalence="EQUIVALENT"
    else equivalence="IMPAIRED"
  end
  if equivalence="IMPAIRED" then riskState="HEDGE_IMPAIRED"
  else if equivalence="EQUIVALENCE_UNPROVED" then riskState="EQUIVALENCE_UNPROVED"
  else if abs(currentNet)>0 | basis>0 | cp>0 | replacement>0 then riskState="RESIDUAL_RISK"
  else riskState="NET_ZERO_MARKET_RISK_WITH_MONITORING"
  if asAt="" then do
    if fx<>.nil then asAt=fx~observedAt
    else if ee<>.nil then asAt=ee~effectiveAt
    else if fe<>.nil then asAt=fe~asAt
    else asAt=h~sizingAt
  end
  feRef=""; eeRef=""
  if fe<>.nil then feRef=fe~evidenceId
  if ee<>.nil then eeRef=ee~evidenceId
  a=.MBHedgeRiskAssessment~new(assessmentId,hedgeId,asAt,h~baseCurrency,currentNet,fxDrift,basis,cp,replacement,equivalence,riskState,.true,currentFxEvidenceRef,basisEvidenceRef,counterpartyEvidenceRef,feRef,eeRef)
  hedgeRiskAssessments[assessmentId]=a
  latestHedgeRiskByHedge[hedgeId]=a
  if eeRef<>"" then h~markEquivalence(equivalence,eeRef)
  else if feRef<>"" then h~markEquivalence(equivalence,feRef)
  else h~markEquivalence(equivalence)
  if riskState="NET_ZERO_MARKET_RISK_WITH_MONITORING" then h~markEconomicState("NET_ZERO")
  else if riskState="HEDGE_IMPAIRED" then h~markEconomicState("HEDGE_IMPAIRED")
  else h~markEconomicState("RESIDUAL_RISK")
  edit=journal~beginEdit("HEDGE_RISK_ASSESSED",self~eventMeta("riskState",riskState))
  edit~put("hedgeRisk:"||assessmentId,a)
  edit~put("hedge:"||hedgeId,h)
  edit~commit
  return a

::method recordMarketEvidence
  expose marketEvidence journal
  use strict arg evidence
  if \evidence~isA(.MBMarketEvidence) then raise syntax 88.900 array("MBMarketEvidence required")
  if marketEvidence~hasIndex(evidence~evidenceId) then raise syntax 88.900 array("duplicate market evidence")
  marketEvidence[evidence~evidenceId]=evidence
  journal~put("marketEvidence:"||evidence~evidenceId,evidence,"MARKET_EVIDENCE_RECORDED",self~eventMeta("sourceAuthority",evidence~sourceAuthority))
  return evidence

::method marketEvidence
  expose marketEvidence
  use strict arg evidenceId
  return marketEvidence[evidenceId]

::method recordTradeMark
  expose portfolios marketEvidence tradeMarks latestMarkByTrade journal
  use strict arg mark
  if \mark~isA(.MBTradeMark) then raise syntax 88.900 array("MBTradeMark required")
  evidence=marketEvidence[mark~marketEvidenceRef]
  if evidence==.nil then raise syntax 88.900 array("unknown market evidence",mark~marketEvidenceRef)
  found=.nil
  do pid over portfolios~allIndexes while found==.nil
    t=portfolios[pid]~trade(mark~tradeId)
    if t<>.nil then found=t
  end
  if found==.nil then raise syntax 88.900 array("unknown trade",mark~tradeId)
  if found~currency<>mark~currency | evidence~currency<>mark~currency then raise syntax 88.900 array("trade mark currency mismatch")
  instrument=found~underlyingRef
  if instrument="" then instrument=found~marketRef
  if instrument<>"" & evidence~instrumentRef<>instrument then raise syntax 88.900 array("market evidence instrument mismatch")
  if tradeMarks~hasIndex(mark~markId) then raise syntax 88.900 array("duplicate trade mark")
  tradeMarks[mark~markId]=mark
  latestMarkByTrade[mark~tradeId]=mark
  journal~put("tradeMark:"||mark~markId,mark,"TRADE_MARK_RECORDED",self~eventMeta("marketEvidenceRef",mark~marketEvidenceRef))
  return mark

::method createPortfolioValuation
  expose portfolios latestMarkByTrade realisedPnlByPortfolio marketEvidence
  use strict arg valuationId,portfolioId,asAt
  p=portfolios[portfolioId]
  if p==.nil then raise syntax 88.900 array("unknown portfolio")
  marketValue=0; unrealised=0; grossExposure=0; positions=0; status="CURRENT"
  do tid over p~tradeIds
    t=p~trade(tid)
    if t~status="OPEN" then do
      mark=latestMarkByTrade[tid]
      if mark==.nil then raise syntax 88.900 array("open trade lacks market mark",tid)
      marketValue=marketValue+mark~marketValue
      unrealised=unrealised+mark~unrealisedPnL
      grossExposure=grossExposure+mark~grossExposure
      positions=positions+1
      ev=marketEvidence[mark~marketEvidenceRef]
      if ev~valuationStatus<>"CURRENT" then status=ev~valuationStatus
    end
  end
  realised=realisedPnlByPortfolio[portfolioId]
  if realised==.nil then realised=0
  v=.MBValuationSnapshot~new(valuationId,portfolioId,asAt,p~currency,marketValue,unrealised,grossExposure,"TRADE_MARK_SET:"||valuationId,realised,status,positions)
  return self~recordValuation(v)

::method closeTrade
  expose portfolios marketEvidence lifecycle realisedPnlByPortfolio journal
  use strict arg eventId,tradeId,eventType,effectiveAt,realisedPnL,marketEvidenceRef,authorityRef
  evidence=marketEvidence[marketEvidenceRef]
  if evidence==.nil then raise syntax 88.900 array("unknown market evidence")
  found=.nil; portfolio=.nil
  do pid over portfolios~allIndexes while found==.nil
    t=portfolios[pid]~trade(tradeId)
    if t<>.nil then do; found=t; portfolio=portfolios[pid]; end
  end
  if found==.nil then raise syntax 88.900 array("unknown trade",tradeId)
  if found~productType="CFD" then raise syntax 88.900 array("CFD close intent must create an offsetting/reversing position")
  if eventType="EXERCISED" | eventType="EXPIRED" then if found~productType<>"OPTION" then raise syntax 88.900 array("option lifecycle event on non-option")
  if evidence~currency<>found~currency then raise syntax 88.900 array("trade lifecycle currency mismatch")
  instrument=found~underlyingRef; if instrument="" then instrument=found~marketRef
  if instrument<>"" & evidence~instrumentRef<>instrument then raise syntax 88.900 array("trade lifecycle evidence mismatch")
  evt=.MBTradeLifecycleEvent~new(eventId,tradeId,eventType,effectiveAt,realisedPnL,marketEvidenceRef,authorityRef)
  found~close
  lifecycle[eventId]=evt
  total=realisedPnlByPortfolio[portfolio~portfolioId]; if total==.nil then total=0
  realisedPnlByPortfolio[portfolio~portfolioId]=total+realisedPnL
  edit=journal~beginEdit("TRADE_LIFECYCLE",self~eventMeta("eventType",eventType))
  edit~put("trade:"||tradeId,found)
  edit~put("tradeLifecycle:"||eventId,evt)
  edit~put("realisedPnl:"||portfolio~portfolioId,realisedPnlByPortfolio[portfolio~portfolioId])
  edit~commit
  return evt

::method portfolioConcentrationBps
  expose portfolios
  use strict arg portfolioId
  p=portfolios[portfolioId]
  if p==.nil then raise syntax 88.900 array("unknown portfolio")
  totals=.directory~new; gross=0; largest=0
  do tid over p~tradeIds
    t=p~trade(tid)
    if t~status="OPEN" then do
      ref=t~underlyingRef; if ref="" then ref=t~marketRef; if ref="" then ref="UNSPECIFIED"
      n=t~notional; gross=gross+n
      cur=totals[ref]; if cur==.nil then cur=0
      totals[ref]=cur+n
      if totals[ref]>largest then largest=totals[ref]
    end
  end
  if gross<=0 then return 0
  return largest*10000/gross

::method positionSummaryForRelationship
  expose relationships portfolios latestValuationByPortfolio latestAssessmentByPortfolio realisedPnlByPortfolio
  use strict arg relationshipId,sourceAuthority="FEDERATION_BROKERAGE_POSITION_AUTHORITY"
  r=relationships[relationshipId]
  if r==.nil | r~status<>"ACTIVE" then return .nil
  currency=""; valuationTime=""; marketValue=0; unrealised=0; realised=0; collateral=0; requiredMargin=0; availableMargin=0; positions=0; valuationStatus="CURRENT"; matched=0
  do pid over portfolios~allIndexes
    p=portfolios[pid]
    if p~relationshipId=relationshipId & p~status="OPEN" then do
      matched=matched+1
      if currency="" then currency=p~currency
      if p~currency<>currency then raise syntax 88.900 array("multi-currency relationship summary requires scoped projection")
      v=latestValuationByPortfolio[pid]
      a=latestAssessmentByPortfolio[pid]
      if v==.nil | a==.nil then raise syntax 88.900 array("position summary not current",pid)
      marketValue=marketValue+v~marketValue
      unrealised=unrealised+v~unrealisedPnL
      rp=realisedPnlByPortfolio[pid]; if rp==.nil then rp=0
      realised=realised+rp
      collateral=collateral+a~adjustedCollateral
      requiredMargin=requiredMargin+a~requiredMargin
      availableMargin=availableMargin+a~availableMargin
      positions=positions+p~clientPositionCount
      if valuationTime="" | v~asAt>valuationTime then valuationTime=v~asAt
      if v~valuationStatus<>"CURRENT" then valuationStatus=v~valuationStatus
    end
  end
  if matched=0 then return .nil
  return .MBMerchantPositionSummary~new(relationshipId,currency,valuationTime,marketValue,unrealised,realised,collateral,requiredMargin,availableMargin,positions,valuationStatus,sourceAuthority)

::method createPortfolio
  expose portfolios journal merchantEntity relationships realisedPnlByPortfolio
  use strict arg portfolioId,clientEntity,currency,relationshipId=""
  if portfolios~hasIndex(portfolioId) then raise syntax 88.900 array("duplicate portfolio",portfolioId)
  if relationshipId<>"" then do
    r=relationships[relationshipId]
    if r==.nil then raise syntax 88.900 array("unknown merchant relationship",relationshipId)
    if r~clientEntity<>clientEntity | r~status<>"ACTIVE" then raise syntax 88.900 array("portfolio/relationship identity mismatch")
  end
  p=.MBPortfolio~new(portfolioId,clientEntity,currency,relationshipId)
  portfolios[portfolioId]=p
  realisedPnlByPortfolio[portfolioId]=0
  journal~put("portfolio:"||portfolioId,p,"PORTFOLIO_OPEN",self~eventMeta("clientEntity",clientEntity))
  return p


::method portfolio
  expose portfolios
  use strict arg portfolioId
  return portfolios[portfolioId]

::method bookTrade
  expose portfolios journal products
  use strict arg trade
  p=portfolios[trade~portfolioId]
  if p==.nil then raise syntax 88.900 array("unknown portfolio",trade~portfolioId)
  if trade~productId<>"" then do
    product=products[trade~productId]
    if product==.nil then raise syntax 88.900 array("unknown derivative product",trade~productId)
    if product~status<>"ACTIVE" then raise syntax 88.900 array("derivative product inactive")
    if product~productType<>trade~productType | product~currency<>trade~currency then raise syntax 88.900 array("trade/product mismatch")
    if trade~underlyingRef<>"" & trade~underlyingRef<>product~underlyingRef then raise syntax 88.900 array("trade/product underlying mismatch")
  end
  p~addTrade(trade)
  journal~put("trade:"||trade~tradeId,trade,"TRADE_BOOKED",self~eventMeta("portfolioId",trade~portfolioId))
  return trade


::method registerCollateralAgreement
  expose agreements journal merchantEntity
  use strict arg agreement
  if \agreement~isA(.MBCollateralAgreement) then raise syntax 88.900 array("MBCollateralAgreement required")
  if agreement~securedParty<>merchantEntity then raise syntax 88.900 array("agreement secured party is not this Merchant Bank")
  if agreements~hasIndex(agreement~agreementId) then raise syntax 88.900 array("duplicate agreement")
  agreements[agreement~agreementId]=agreement
  journal~put("agreement:"||agreement~agreementId,agreement,"COLLATERAL_AGREEMENT_ACCEPTED",self~eventMeta("obligor",agreement~obligor))
  return agreement

::method collateralAgreement
  expose agreements
  use strict arg agreementId
  return agreements[agreementId]

::method collateralAsset
  expose assets
  use strict arg assetId
  return assets[assetId]

::method registerCollateralAsset
  expose assets journal
  use strict arg asset
  if \asset~isA(.MBCollateralAsset) then raise syntax 88.900 array("MBCollateralAsset required")
  if assets~hasIndex(asset~assetId) then raise syntax 88.900 array("duplicate collateral asset")
  assets[asset~assetId]=asset
  journal~put("asset:"||asset~assetId,asset,"COLLATERAL_ASSET_PROPOSED",self~eventMeta("owner",asset~owner))
  return asset

::method acknowledgeCoreControl
  expose agreements assets controls journal
  use strict arg receipt
  if \receipt~isA(.MBCollateralControlReceipt) then raise syntax 88.900 array("MBCollateralControlReceipt required")
  a=agreements[receipt~agreementId]
  asset=assets[receipt~assetId]
  if a==.nil | asset==.nil then raise syntax 88.900 array("unknown agreement/asset")
  if receipt~owner<>asset~owner | asset~owner<>a~collateralProvider then raise syntax 88.900 array("collateral legal entity mismatch")
  if receipt~currency<>asset~currency | receipt~currency<>a~currency then raise syntax 88.900 array("collateral currency mismatch")
  if \receipt~usable then raise syntax 88.900 array("Core Banking did not acknowledge enforceable control")
  if receipt~controlledAmount > asset~grossValue then raise syntax 88.900 array("control exceeds asset value")
  if receipt~controlledAmount > a~maximumSecuredAmount then raise syntax 88.900 array("control exceeds agreement secured amount")
  if controls~hasIndex(receipt~controlId) then raise syntax 88.900 array("duplicate control")
  assetControlled=0; agreementControlled=0
  do cid over controls~allIndexes
    existing=controls[cid]
    if existing~usable then do
      if existing~assetId=receipt~assetId then assetControlled=assetControlled+existing~controlledAmount
      if existing~agreementId=receipt~agreementId then agreementControlled=agreementControlled+existing~controlledAmount
      if existing~assetId=receipt~assetId & existing~agreementId=receipt~agreementId then raise syntax 88.900 array("collateral asset already controlled under agreement")
    end
  end
  if assetControlled+receipt~controlledAmount > asset~grossValue then raise syntax 88.900 array("aggregate control exceeds asset value")
  if agreementControlled+receipt~controlledAmount > a~maximumSecuredAmount then raise syntax 88.900 array("aggregate control exceeds agreement secured amount")
  controls[receipt~controlId]=receipt
  journal~put("control:"||receipt~controlId,receipt,"CORE_COLLATERAL_CONTROL_ACKNOWLEDGED",self~eventMeta("coreAuthorityRef",receipt~coreAuthorityRef))
  return receipt

::method controlledCollateral
  expose agreements assets controls
  use strict arg portfolioId,currency
  gross=0
  adjusted=0
  do cid over controls~allIndexes
    r=controls[cid]
    a=agreements[r~agreementId]
    asset=assets[r~assetId]
    if a~securedObligations=portfolioId & r~currency=currency & r~usable then do
      eligible=r~controlledAmount
      if eligible > asset~grossValue then eligible=asset~grossValue
      gross=gross+eligible
      adjusted=adjusted + eligible * (10000-asset~haircutBps) / 10000
    end
  end
  d=.directory~new
  d["gross"]=gross
  d["adjusted"]=adjusted
  return d

::method recordValuation
  expose portfolios valuations journal latestValuationByPortfolio
  use strict arg valuation
  if portfolios[valuation~portfolioId]==.nil then raise syntax 88.900 array("unknown portfolio")
  valuations[valuation~valuationId]=valuation
  latestValuationByPortfolio[valuation~portfolioId]=valuation
  journal~put("valuation:"||valuation~valuationId,valuation,"VALUATION_RECORDED",self~eventMeta("marketEvidenceRef",valuation~marketEvidenceRef))
  return valuation

::method recordLiquidityEvidence
  expose liquidityEvidence portfolios journal
  use strict arg evidence
  if \evidence~isA(.MBLiquidityEvidence) then raise syntax 88.900 array("MBLiquidityEvidence required")
  p=portfolios[evidence~portfolioId]
  if p==.nil then raise syntax 88.900 array("unknown portfolio",evidence~portfolioId)
  if p~currency<>evidence~currency then raise syntax 88.900 array("liquidity evidence currency mismatch")
  if liquidityEvidence~hasIndex(evidence~evidenceId) then raise syntax 88.900 array("duplicate liquidity evidence")
  liquidityEvidence[evidence~evidenceId]=evidence
  journal~put("liquidity:"||evidence~evidenceId,evidence,"MERCHANT_LIQUIDITY_EVIDENCE_RECORDED",self~eventMeta("sourceAuthority",evidence~sourceAuthority))
  return evidence

::method liquidityEvidence
  expose liquidityEvidence
  use strict arg evidenceId
  return liquidityEvidence[evidenceId]

::method assessMarginWithLiquidityEvidence
  expose liquidityEvidence portfolios
  use strict arg assessmentId,portfolioId,valuation,policy,liquidityEvidenceId,assessedAt
  e=liquidityEvidence[liquidityEvidenceId]
  if e==.nil then raise syntax 88.900 array("unknown liquidity evidence",liquidityEvidenceId)
  p=portfolios[portfolioId]
  if p==.nil | e~portfolioId<>portfolioId | e~currency<>p~currency then raise syntax 88.900 array("liquidity evidence portfolio mismatch")
  return self~assessMargin(assessmentId,portfolioId,valuation,policy,e~availableAmount,assessedAt)


::method assessMargin
  expose portfolios assessments journal latestAssessmentByPortfolio
  use strict arg assessmentId,portfolioId,valuation,policy,availableLiquidity,assessedAt
  p=portfolios[portfolioId]
  if p==.nil then raise syntax 88.900 array("unknown portfolio")
  if valuation~portfolioId<>portfolioId | valuation~currency<>p~currency then raise syntax 88.900 array("valuation mismatch")
  if \policy~isA(.MBRiskPolicy) then raise syntax 88.900 array("MBRiskPolicy required")
  c=self~controlledCollateral(portfolioId,p~currency)
  adjusted=c["adjusted"]
  gross=c["gross"]
  denominator=adjusted
  if valuation~marketValue>0 then denominator=denominator+valuation~marketValue
  if denominator<=0 then effectiveLeverage=999999
  else effectiveLeverage=valuation~riskExposure / denominator
  liquidityDeficit=policy~liquidityBufferRequired-availableLiquidity
  if liquidityDeficit<0 then liquidityDeficit=0
  requiredMargin=valuation~riskExposure/policy~maximumLeverage
  wholeRequired=trunc(requiredMargin)
  if requiredMargin>wholeRequired then requiredMargin=wholeRequired+1
  else requiredMargin=wholeRequired
  leverageDeficit=requiredMargin-denominator
  if leverageDeficit<0 then leverageDeficit=0
  availableMargin=denominator-requiredMargin
  if availableMargin<0 then availableMargin=0
  concentrationBps=self~portfolioConcentrationBps(portfolioId)
  concentrationDeficit=0
  if concentrationBps>policy~concentrationLimitBps then concentrationDeficit=1
  deficit=liquidityDeficit
  if leverageDeficit>deficit then deficit=leverageDeficit
  if concentrationDeficit>0 then state="CONCENTRATION_BREACH"
  else if deficit>0 then state="MARGIN_DEFICIT"
  else state="COMPLIANT"
  a=.MBMarginAssessment~new(assessmentId,portfolioId,policy~policyRef,valuation~riskExposure,gross,adjusted,availableLiquidity,policy~liquidityBufferRequired,effectiveLeverage,deficit,state,assessedAt,requiredMargin,availableMargin,concentrationBps)
  assessments[assessmentId]=a
  latestAssessmentByPortfolio[portfolioId]=a
  journal~put("assessment:"||assessmentId,a,"MARGIN_ASSESSED",self~eventMeta("state",state))
  return a


::method issueMarginCall
  expose assessments marginCalls journal portfolios
  use strict arg callId,assessmentId,issuedAt,cureBy
  a=assessments[assessmentId]
  if a==.nil | a~state<>"MARGIN_DEFICIT" then raise syntax 88.900 array("margin call requires deficit assessment")
  if marginCalls~hasIndex(callId) then raise syntax 88.900 array("duplicate margin call")
  do existingId over marginCalls~allIndexes
    existing=marginCalls[existingId]
    if existing~portfolioId=a~portfolioId & existing~state="OPEN" then raise syntax 88.900 array("portfolio already has open margin call")
  end
  p=portfolios[a~portfolioId]
  c=.MBMarginCall~new(callId,a~portfolioId,assessmentId,a~deficit,p~currency,issuedAt,cureBy)
  marginCalls[callId]=c
  journal~put("marginCall:"||callId,c,"MARGIN_CALL_ISSUED",self~eventMeta("assessmentId",assessmentId))
  return c

::method marginCall
  expose marginCalls
  use strict arg callId
  return marginCalls[callId]

::method cureMarginCall
  expose marginCalls assessments cureRecords liquidityEvidence controls agreements lifecycle portfolios journal hedgeRiskAssessments
  use strict arg callId,cureId,mechanism,evidenceRef,authorityRef,assessmentId,curedAt
  c=marginCalls[callId]
  if c==.nil | c~state<>"OPEN" then raise syntax 88.900 array("margin call not open")
  if cureRecords~hasIndex(cureId) then raise syntax 88.900 array("duplicate cure record")
  a=assessments[assessmentId]
  if a==.nil | a~portfolioId<>c~portfolioId then raise syntax 88.900 array("cure assessment mismatch")
  if assessmentId=c~assessmentId then raise syntax 88.900 array("cure requires a new assessment")
  if a~state<>"COMPLIANT" then raise syntax 88.900 array("margin call cannot be cured without compliant reassessment")
  p=portfolios[c~portfolioId]
  if mechanism="LIQUIDITY" then do
    e=liquidityEvidence[evidenceRef]
    if e==.nil | e~portfolioId<>c~portfolioId | e~currency<>p~currency then raise syntax 88.900 array("invalid liquidity cure evidence")
    if e~sourceAuthority<>authorityRef then raise syntax 88.900 array("liquidity cure authority mismatch")
  end
  else if mechanism="COLLATERAL" then do
    ctrl=controls[evidenceRef]
    if ctrl==.nil | \ctrl~usable then raise syntax 88.900 array("invalid collateral cure evidence")
    ag=agreements[ctrl~agreementId]
    if ag==.nil | ag~securedObligations<>c~portfolioId then raise syntax 88.900 array("collateral cure portfolio mismatch")
    if ctrl~coreAuthorityRef<>authorityRef then raise syntax 88.900 array("collateral cure authority mismatch")
  end
  else if mechanism="POSITION_REDUCTION" then do
    ev=lifecycle[evidenceRef]
    if ev==.nil then raise syntax 88.900 array("invalid position-reduction cure evidence")
    found=.false
    do tid over p~tradeIds while \found
      if tid=ev~tradeId then found=.true
    end
    if \found then raise syntax 88.900 array("position-reduction evidence portfolio mismatch")
    if ev~authorityRef<>authorityRef then raise syntax 88.900 array("position-reduction cure authority mismatch")
  end
  else if mechanism="RISK_REDUCTION" then do
    hra=hedgeRiskAssessments[evidenceRef]
    if hra==.nil then raise syntax 88.900 array("invalid hedge-risk cure evidence")
    if hra~riskState="HEDGE_IMPAIRED" | hra~riskState="EQUIVALENCE_UNPROVED" then raise syntax 88.900 array("impaired/unproved hedge cannot prove risk reduction")
    if authorityRef="" then raise syntax 88.900 array("risk-reduction cure authority required")
  end
  else raise syntax 88.900 array("invalid margin cure mechanism",mechanism)
  r=.MBMarginCureRecord~new(cureId,callId,c~portfolioId,mechanism,evidenceRef,authorityRef,assessmentId,curedAt)
  c~cureWithEvidence(cureId)
  cureRecords[cureId]=r
  edit=journal~beginEdit("MARGIN_CALL_CURED",self~eventMeta("mechanism",mechanism))
  edit~put("marginCall:"||callId,c)
  edit~put("marginCure:"||cureId,r)
  edit~commit
  return r

::method cureRecord
  expose cureRecords
  use strict arg cureId
  return cureRecords[cureId]

::method defaultMarginCall
  expose marginCalls closeOuts journal latestAssessmentByPortfolio
  use strict arg callId,instructionId,authorityRef,defaultAt
  c=marginCalls[callId]
  if c==.nil then raise syntax 88.900 array("unknown margin call")
  if c~state<>"OPEN" then raise syntax 88.900 array("margin call not open")
  if defaultAt<c~cureBy then raise syntax 88.900 array("margin cure deadline has not expired")
  latest=latestAssessmentByPortfolio[c~portfolioId]
  if latest<>.nil & latest~assessmentId<>c~assessmentId & latest~state="COMPLIANT" then raise syntax 88.900 array("latest risk assessment is compliant; cure must be recorded")
  if closeOuts~hasIndex(instructionId) then raise syntax 88.900 array("duplicate close-out instruction")
  c~defaultAt(defaultAt)
  i=.MBCloseOutInstruction~new(instructionId,c~portfolioId,"MARGIN_DEFAULT:"||callId,authorityRef,defaultAt)
  closeOuts[instructionId]=i
  edit=journal~beginEdit("MARGIN_DEFAULT_CLOSE_OUT",self~eventMeta("callId",callId))
  edit~put("marginCall:"||callId,c)
  edit~put("closeOut:"||instructionId,i)
  edit~commit
  return i

::method closeOutInstruction
  expose closeOuts
  use strict arg instructionId
  return closeOuts[instructionId]

::method executeCloseOut
  expose closeOuts closeOutExecutions portfolios marketEvidence lifecycle realisedPnlByPortfolio journal
  use strict arg instructionId,executionId,results,executedAt,authorityRef
  i=closeOuts[instructionId]
  if i==.nil | i~state<>"REQUIRED" then raise syntax 88.900 array("close-out instruction not executable")
  if closeOutExecutions~hasIndex(executionId) then raise syntax 88.900 array("duplicate close-out execution")
  if authorityRef="" then raise syntax 88.900 array("close-out execution authority required")
  if \results~isA(.Directory) then raise syntax 88.900 array("close-out results directory required")
  p=portfolios[i~portfolioId]
  if p==.nil then raise syntax 88.900 array("unknown close-out portfolio")
  openCount=0; signedNet=0; realisedDelta=0
  do tid over p~tradeIds
    t=p~trade(tid)
    if t~status="OPEN" then do
      if t~productType="CFD" then raise syntax 88.900 array("CFD default handling requires reversing positions via executeRiskNeutralisation",tid)
      openCount=openCount+1
      r=results[tid]
      if r==.nil | \r~isA(.MBCloseOutTradeResult) | r~tradeId<>tid then raise syntax 88.900 array("missing close-out result",tid)
      ev=marketEvidence[r~marketEvidenceRef]
      if ev==.nil | ev~currency<>t~currency then raise syntax 88.900 array("invalid close-out market evidence",tid)
      instrument=t~underlyingRef; if instrument="" then instrument=t~marketRef
      if instrument<>"" & ev~instrumentRef<>instrument then raise syntax 88.900 array("close-out evidence instrument mismatch",tid)
      signedNet=signedNet+r~signedSettlementAmount
      realisedDelta=realisedDelta+r~realisedPnL
    end
  end
  if openCount=0 then raise syntax 88.900 array("no open positions to close")
  if results~items<>openCount then raise syntax 88.900 array("close-out results must match every open position exactly")
  edit=journal~beginEdit("PORTFOLIO_CLOSE_OUT_EXECUTED",self~eventMeta("instructionId",instructionId))
  do tid over p~tradeIds
    t=p~trade(tid)
    if t~status="OPEN" then do
      r=results[tid]
      evtId=executionId||":"||tid
      evt=.MBTradeLifecycleEvent~new(evtId,tid,"CLOSED",executedAt,r~realisedPnL,r~marketEvidenceRef,r~authorityRef)
      t~close
      lifecycle[evtId]=evt
      edit~put("trade:"||tid,t)
      edit~put("tradeLifecycle:"||evtId,evt)
    end
  end
  current=realisedPnlByPortfolio[p~portfolioId]; if current==.nil then current=0
  realisedPnlByPortfolio[p~portfolioId]=current+realisedDelta
  e=.MBCloseOutExecution~new(executionId,instructionId,p~portfolioId,p~currency,executedAt,authorityRef,openCount,signedNet)
  closeOutExecutions[executionId]=e
  i~markExecuted(executionId)
  edit~put("realisedPnl:"||p~portfolioId,realisedPnlByPortfolio[p~portfolioId])
  edit~put("closeOut:"||instructionId,i)
  edit~put("closeOutExecution:"||executionId,e)
  edit~commit
  return e

::method executeRiskNeutralisation
  expose closeOuts neutralisationExecutions portfolios marketEvidence realisedPnlByPortfolio journal
  use strict arg instructionId,executionId,results,executedAt,authorityRef
  i=closeOuts[instructionId]
  if i==.nil | i~state<>"REQUIRED" then raise syntax 88.900 array("risk neutralisation instruction not executable")
  if neutralisationExecutions~hasIndex(executionId) then raise syntax 88.900 array("duplicate risk neutralisation execution")
  if \results~isA(.Directory) then raise syntax 88.900 array("risk neutralisation results directory required")
  p=portfolios[i~portfolioId]
  if p==.nil then raise syntax 88.900 array("unknown neutralisation portfolio")
  required=0; signedNet=0; realisedDelta=0
  do tid over p~tradeIds
    t=p~trade(tid)
    if t~productType="CFD" & t~contractualActive & t~clientViewState<>"CLOSED" & t~clientViewState<>"HEDGE" then do
      required=required+1
      r=results[tid]
      if r==.nil | \r~isA(.MBCFDNeutralisationResult) | r~originalTradeId<>tid then raise syntax 88.900 array("missing CFD neutralisation result",tid)
      off=r~offsetTrade
      if off~side=t~side then raise syntax 88.900 array("CLOSE_INTENT_DIRECTION_MISMATCH",tid)
      ev=marketEvidence[r~marketEvidenceRef]
      if ev==.nil | ev~currency<>t~currency then raise syntax 88.900 array("invalid neutralisation market evidence",tid)
      signedNet=signedNet+r~signedSettlementAmount
      realisedDelta=realisedDelta+r~realisedPnL
    end
  end
  if required=0 then raise syntax 88.900 array("no exposed CFD positions to neutralise")
  if results~items<>required then raise syntax 88.900 array("neutralisation results must match every exposed CFD position exactly")
  do tid over p~tradeIds
    t=p~trade(tid)
    if t~productType="CFD" & t~contractualActive & t~clientViewState<>"CLOSED" & t~clientViewState<>"HEDGE" then do
      r=results[tid]
      self~bookCFDOffset(executionId||":"||tid||":INTENT",executionId||":"||tid||":HEDGE",tid,r~offsetTrade,r~sizingFxEvidenceRef,r~authorityRef,executedAt)
    end
  end
  current=realisedPnlByPortfolio[p~portfolioId]; if current==.nil then current=0
  realisedPnlByPortfolio[p~portfolioId]=current+realisedDelta
  e=.MBRiskNeutralisationExecution~new(executionId,instructionId,p~portfolioId,p~currency,executedAt,authorityRef,required,signedNet)
  neutralisationExecutions[executionId]=e
  i~markExecuted(executionId)
  edit=journal~beginEdit("PORTFOLIO_RISK_NEUTRALISED",self~eventMeta("instructionId",instructionId))
  edit~put("realisedPnl:"||p~portfolioId,realisedPnlByPortfolio[p~portfolioId])
  edit~put("closeOut:"||instructionId,i)
  edit~put("riskNeutralisation:"||executionId,e)
  edit~commit
  return e

::method riskNeutralisationExecution
  expose neutralisationExecutions
  use strict arg executionId
  return neutralisationExecutions[executionId]

::method createNeutralisationSettlementObligation
  expose neutralisationExecutions portfolios merchantEntity
  use strict arg obligationId,executionId
  e=neutralisationExecutions[executionId]
  if e==.nil | e~state<>"COMPLETE" then raise syntax 88.900 array("risk neutralisation execution required")
  signed=e~signedNetSettlement
  if signed=0 then return .nil
  p=portfolios[e~portfolioId]
  if signed>0 then return self~createSettlementObligation(obligationId,p~clientEntity,merchantEntity,e~currency,signed,"DERIVATIVE_RISK_NEUTRALISATION",executionId)
  return self~createSettlementObligation(obligationId,merchantEntity,p~clientEntity,e~currency,-signed,"DERIVATIVE_RISK_NEUTRALISATION",executionId)

::method closeOutExecution
  expose closeOutExecutions
  use strict arg executionId
  return closeOutExecutions[executionId]

::method createCloseOutSettlementObligation
  expose closeOutExecutions portfolios merchantEntity
  use strict arg obligationId,executionId
  e=closeOutExecutions[executionId]
  if e==.nil | e~state<>"COMPLETE" then raise syntax 88.900 array("close-out execution required")
  signed=e~signedNetSettlement
  if signed=0 then return .nil
  p=portfolios[e~portfolioId]
  if signed>0 then return self~createSettlementObligation(obligationId,p~clientEntity,merchantEntity,e~currency,signed,"DERIVATIVE_CLOSE_OUT",executionId)
  return self~createSettlementObligation(obligationId,merchantEntity,p~clientEntity,e~currency,-signed,"DERIVATIVE_CLOSE_OUT",executionId)

::method createSettlementObligation
  expose obligations journal
  use strict arg obligationId,debtor,creditor,currency,amount,reason,sourceRef
  if obligations~hasIndex(obligationId) then raise syntax 88.900 array("duplicate settlement obligation")
  o=.MBSettlementObligation~new(obligationId,debtor,creditor,currency,amount,reason,sourceRef)
  obligations[obligationId]=o
  journal~put("obligation:"||obligationId,o,"SETTLEMENT_OBLIGATION_CREATED",self~eventMeta("reason",reason))
  return o

::method settlementObligation
  expose obligations
  use strict arg obligationId
  return obligations[obligationId]

::method tradeById private
  expose portfolios
  use strict arg tradeId
  do pid over portfolios~allIndexes
    t=portfolios[pid]~trade(tradeId)
    if t<>.nil then return t
  end
  return .nil

::method productForTrade private
  expose products
  use strict arg trade
  if trade~productId="" then return .nil
  return products[trade~productId]

::method classifyHedge private
  use strict arg original,offset
  op=self~productForTrade(original)
  xp=self~productForTrade(offset)
  oi=.nil; xi=.nil
  if op<>.nil then oi=op~instrumentIdentity
  if xp<>.nil then xi=xp~instrumentIdentity
  if oi<>.nil & xi<>.nil then do
    if oi~exactContractIdentity(xi) then return "EXACT_OFFSET"
    if oi~sameSettlementLineIdentity(xi) then return "SETTLEMENT_LINE_HEDGE"
    if \oi~sameEconomicUnderlying(xi) then raise syntax 88.900 array("offset does not reference same economic underlying")
    if oi~representationType="DLC_ORDINARY" & xi~representationType="DLC_ORDINARY" then return "DLC_EQUIVALENCE"
    if oi~representationType="ADR" | xi~representationType="ADR" | oi~representationType="CDI" | xi~representationType="CDI" | oi~representationType="DEPOSITARY_RECEIPT" | xi~representationType="DEPOSITARY_RECEIPT" then return "DEPOSITARY_HEDGE"
    return "CROSS_LISTED_HEDGE"
  end
  if original~underlyingRef<>"" & original~underlyingRef=offset~underlyingRef then do
    if original~currency=offset~currency then return "UNDERLYING_HEDGE"
    return "CROSS_LISTED_HEDGE"
  end
  raise syntax 88.900 array("offset economic underlying cannot be proved")

::method signedNotional private
  use strict arg amount,side
  if side="LONG" then return amount
  if side="SHORT" then return -amount
  raise syntax 88.900 array("invalid side",side)

::method eventMeta private
  use strict arg key,value
  d=.directory~new
  d[key]=value
  return d

::requires "JournalPointedState.cls"
