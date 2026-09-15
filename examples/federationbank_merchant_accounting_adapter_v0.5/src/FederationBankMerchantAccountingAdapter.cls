/*
 * FederationBank Merchant Accounting Adapter v0.5
 *
 * Merchant-domain facts remain authoritative for trading/risk semantics.
 * Accounting Core remains authoritative only for native posting mechanics.
 * This adapter accepts bounded scalar Merchant accounting evidence and maps
 * only the accounting consequence into FederationBank Merchant's own book.
 */

::options digits 50

::class FederationBankMerchantAccountingBuild public
::constant VERSION "0.5"
::constant API "federationbank.merchant.accounting/0.5"
::constant PROJECTION_API "federationbank.merchant.accounting.projection/0.2"
::constant EVENT_PROJECTION_API "federationbank.merchant.accounting.event_projection/0.2"
::constant SETTLEMENT_AMOUNT_API "federationbank.merchant.accounting.settlement_amount/0.1"
::constant FAIR_VALUE_POLICY "federationbank.merchant.accounting.derivative_fair_value/0.2"
::constant FAIR_VALUE_TRANSITION_POLICY "federationbank.merchant.accounting.derivative_fair_value_transition/0.2"
::constant LIFECYCLE_PROJECTION_POLICY "federationbank.merchant.accounting.lifecycle_projection/0.1"
::constant SETTLEMENT_OBLIGATION_POLICY "federationbank.merchant.accounting.settlement_obligation/0.1"
::constant SETTLEMENT_OBSERVATION_POLICY "federationbank.merchant.accounting.settlement_observation/0.1"
::constant FAIR_VALUE_EVENT_TYPE "MERCHANT_DERIVATIVE_FAIR_VALUE_MOVEMENT"
::constant FAIR_VALUE_TRANSITION_EVENT_TYPE "MERCHANT_DERIVATIVE_FAIR_VALUE_TRANSITION"
::constant SETTLEMENT_OBLIGATION_EVENT_TYPE "MERCHANT_DERIVATIVE_SETTLEMENT_OBLIGATION"
::constant SETTLEMENT_OBSERVATION_EVENT_TYPE "MERCHANT_DERIVATIVE_SETTLEMENT_OBSERVED"
::constant POLICY_EFFECTIVE_FROM "2026-01-01"
/* Release-scoped executable artifact identity. The sealed package manifest binds
 * this unique identity to the exact source bytes delivered in v0.5. */
::constant POLICY_ARTIFACT_IDENTITY "FBMAA-0.5-20260828-AC07-7F93D184"

::class MBAccountingBridgeUtil public
::method requireSignedWhole class
  use arg value,label
  text=value~string~strip
  if text="" then raise syntax 93.900 additional(label || " must be an exact whole-number minor-unit amount")
  sign=""
  first=text~substr(1,1)
  if first="+" | first="-" then do
    sign=first
    text=text~substr(2)
  end
  if text="" | verify(text,"0123456789")<>0 then raise syntax 93.900 additional(label || " must be an exact whole-number minor-unit amount")
  do while text~length>1 & text~substr(1,1)="0"
    text=text~substr(2)
  end
  if text~length>50 then raise syntax 93.900 additional(label || " exceeds accounting numeric digits 50")
  if text="0" then return "0"
  if sign="-" then return "-" || text
  return text

::class MBAccountingCurrencyScaleEvidence public
::attribute evidenceId get
::attribute currency get
::attribute minorUnitsPerUnit get
::attribute sourceAuthority get
::attribute sourceRef get
::attribute effectiveFrom get

::method init
  expose evidenceId currency minorUnitsPerUnit sourceAuthority sourceRef effectiveFrom
  use strict arg evidenceIdArg,currencyArg,minorUnitsPerUnitArg,sourceAuthorityArg,sourceRefArg,effectiveFromArg=""
  evidenceId=.AccountingUtil~requireText(evidenceIdArg,"scale evidenceId")
  currency=.AccountingUtil~requireText(currencyArg,"scale currency")~upper
  minorUnitsPerUnit=.AccountingUtil~requireWholeNonNegative(minorUnitsPerUnitArg,"minorUnitsPerUnit")
  if minorUnitsPerUnit<=0 then raise syntax 93.900 additional("minorUnitsPerUnit must be positive")
  sourceAuthority=.AccountingUtil~requireText(sourceAuthorityArg,"scale sourceAuthority")
  sourceRef=.AccountingUtil~requireText(sourceRefArg,"scale sourceRef")
  effectiveFrom=effectiveFromArg~string~strip

::method toMinor
  expose currency minorUnitsPerUnit
  use strict arg amount,currencyArg,label="amount"
  if currencyArg~string~strip~upper<>currency then raise syntax 93.900 additional("currency scale mismatch: " || currencyArg || " != " || currency)
  text=amount~string~strip
  if \datatype(text,"N") then raise syntax 93.900 additional(label || " must be numeric")
  numeric digits 50
  scaled=(text+0)*minorUnitsPerUnit
  whole=trunc(scaled,0)
  if scaled<>whole then raise syntax 93.900 additional("ACCOUNTING_SCALE_NON_EXACT: " || label || "=" || text || " scale=" || minorUnitsPerUnit)
  return .MBAccountingBridgeUtil~requireSignedWhole(whole,label || " minor-unit result")

::class MBAccountingDerivativeFairValueMovementEvidence public
::attribute evidenceId get
::attribute legalEntityId get
::attribute sourceEventRef get
::attribute postingDate get
::attribute periodId get
::attribute tradeId get
::attribute portfolioId get
::attribute economicRootTradeId get
::attribute closeIntentRef get
::attribute counterpartyEntity get
::attribute contractRole get
::attribute currency get
::attribute amountMinor get
::attribute carryingSide get
::attribute movementDirection get
::attribute sourceAuthority get

::method init
  expose evidenceId legalEntityId sourceEventRef postingDate periodId tradeId portfolioId economicRootTradeId closeIntentRef counterpartyEntity contractRole currency amountMinor carryingSide movementDirection sourceAuthority evidenceRefs metadata
  use strict arg evidenceIdArg,legalEntityIdArg,sourceEventRefArg,postingDateArg,periodIdArg,tradeIdArg,portfolioIdArg,economicRootTradeIdArg,currencyArg,amountMinorArg,carryingSideArg,movementDirectionArg,sourceAuthorityArg,closeIntentRefArg="",counterpartyEntityArg="",contractRoleArg="CLIENT_CONTRACT",evidenceRefsArg=.nil,metadataArg=.nil
  evidenceId=.AccountingUtil~requireText(evidenceIdArg,"evidenceId")
  legalEntityId=.AccountingUtil~requireText(legalEntityIdArg,"legalEntityId")
  sourceEventRef=.AccountingUtil~requireText(sourceEventRefArg,"sourceEventRef")
  postingDate=.AccountingUtil~requireDate(postingDateArg,"postingDate")
  periodId=.AccountingUtil~requireText(periodIdArg,"periodId")
  tradeId=.AccountingUtil~requireText(tradeIdArg,"tradeId")
  portfolioId=.AccountingUtil~requireText(portfolioIdArg,"portfolioId")
  economicRootTradeId=.AccountingUtil~requireText(economicRootTradeIdArg,"economicRootTradeId")
  closeIntentRef=closeIntentRefArg~string~strip
  counterpartyEntity=counterpartyEntityArg~string~strip
  contractRole=contractRoleArg~string~strip~upper
  if wordpos(contractRole,"CLIENT_CONTRACT REVERSING_CONTRACT EXTERNAL_HEDGE")=0 then -
    raise syntax 93.900 additional("unsupported contractRole: " || contractRole)
  currency=.AccountingUtil~requireText(currencyArg,"currency")~upper
  amountMinor=.AccountingUtil~requireWholeNonNegative(amountMinorArg,"amountMinor")
  if amountMinor=0 then raise syntax 93.900 additional("amountMinor must be positive")
  carryingSide=carryingSideArg~string~strip~upper
  if wordpos(carryingSide,"ASSET LIABILITY")=0 then raise syntax 93.900 additional("carryingSide must be ASSET or LIABILITY")
  movementDirection=movementDirectionArg~string~strip~upper
  if wordpos(movementDirection,"INCREASE DECREASE")=0 then raise syntax 93.900 additional("movementDirection must be INCREASE or DECREASE")
  sourceAuthority=.AccountingUtil~requireText(sourceAuthorityArg,"sourceAuthority")
  evidenceRefs=.AccountingUtil~copyArray(evidenceRefsArg)
  metadata=.AccountingUtil~copyDirectory(metadataArg)

::method evidenceRefs
  expose evidenceRefs
  return .AccountingUtil~copyArray(evidenceRefs)

::method metadata
  expose metadata
  return .AccountingUtil~copyDirectory(metadata)

::class MBAccountingDerivativeFairValueTransitionEvidence public
::attribute evidenceId get
::attribute legalEntityId get
::attribute sourceEventRef get
::attribute postingDate get
::attribute periodId get
::attribute tradeId get
::attribute portfolioId get
::attribute economicRootTradeId get
::attribute closeIntentRef get
::attribute counterpartyEntity get
::attribute contractRole get
::attribute currency get
::attribute previousMarketValueMinor get
::attribute currentMarketValueMinor get
::attribute previousMarkRef get
::attribute currentMarkRef get
::attribute valuationRef get
::attribute marketEvidenceRef get
::attribute scaleEvidenceRef get
::attribute sourceAuthority get

::method init
  expose evidenceId legalEntityId sourceEventRef postingDate periodId tradeId portfolioId economicRootTradeId closeIntentRef counterpartyEntity contractRole currency previousMarketValueMinor currentMarketValueMinor previousMarkRef currentMarkRef valuationRef marketEvidenceRef scaleEvidenceRef sourceAuthority evidenceRefs metadata
  use strict arg evidenceIdArg,legalEntityIdArg,sourceEventRefArg,postingDateArg,periodIdArg,tradeIdArg,portfolioIdArg,economicRootTradeIdArg,currencyArg,previousMarketValueMinorArg,currentMarketValueMinorArg,previousMarkRefArg,currentMarkRefArg,valuationRefArg,marketEvidenceRefArg,scaleEvidenceRefArg,sourceAuthorityArg,closeIntentRefArg="",counterpartyEntityArg="",contractRoleArg="CLIENT_CONTRACT",evidenceRefsArg=.nil,metadataArg=.nil
  evidenceId=.AccountingUtil~requireText(evidenceIdArg,"transition evidenceId")
  legalEntityId=.AccountingUtil~requireText(legalEntityIdArg,"legalEntityId")
  sourceEventRef=.AccountingUtil~requireText(sourceEventRefArg,"sourceEventRef")
  postingDate=.AccountingUtil~requireDate(postingDateArg,"postingDate")
  periodId=.AccountingUtil~requireText(periodIdArg,"periodId")
  tradeId=.AccountingUtil~requireText(tradeIdArg,"tradeId")
  portfolioId=.AccountingUtil~requireText(portfolioIdArg,"portfolioId")
  economicRootTradeId=.AccountingUtil~requireText(economicRootTradeIdArg,"economicRootTradeId")
  currency=.AccountingUtil~requireText(currencyArg,"currency")~upper
  previousMarketValueMinor=.MBAccountingBridgeUtil~requireSignedWhole(previousMarketValueMinorArg,"previousMarketValueMinor")
  currentMarketValueMinor=.MBAccountingBridgeUtil~requireSignedWhole(currentMarketValueMinorArg,"currentMarketValueMinor")
  previousMarkRef=.AccountingUtil~requireText(previousMarkRefArg,"previousMarkRef")
  currentMarkRef=.AccountingUtil~requireText(currentMarkRefArg,"currentMarkRef")
  valuationRef=.AccountingUtil~requireText(valuationRefArg,"valuationRef")
  marketEvidenceRef=.AccountingUtil~requireText(marketEvidenceRefArg,"marketEvidenceRef")
  scaleEvidenceRef=.AccountingUtil~requireText(scaleEvidenceRefArg,"scaleEvidenceRef")
  sourceAuthority=.AccountingUtil~requireText(sourceAuthorityArg,"sourceAuthority")
  closeIntentRef=closeIntentRefArg~string~strip
  counterpartyEntity=counterpartyEntityArg~string~strip
  contractRole=contractRoleArg~string~strip~upper
  if wordpos(contractRole,"CLIENT_CONTRACT REVERSING_CONTRACT EXTERNAL_HEDGE")=0 then -
    raise syntax 93.900 additional("unsupported transition contractRole: " || contractRole)
  evidenceRefs=.AccountingUtil~copyArray(evidenceRefsArg)
  metadata=.AccountingUtil~copyDirectory(metadataArg)

::method evidenceRefs
  expose evidenceRefs
  return .AccountingUtil~copyArray(evidenceRefs)

::method metadata
  expose metadata
  return .AccountingUtil~copyDirectory(metadata)

::class MBAccountingTradeLifecycleObservation public
::attribute projectionId get
::attribute legalEntityId get
::attribute sourceEventRef get
::attribute postingDate get
::attribute periodId get
::attribute eventId get
::attribute tradeId get
::attribute portfolioId get
::attribute economicRootTradeId get
::attribute closeIntentRef get
::attribute counterpartyEntity get
::attribute contractRole get
::attribute currency get
::attribute eventType get
::attribute effectiveAt get
::attribute realisedPnLMinor get
::attribute marketEvidenceRef get
::attribute authorityRef get
::attribute scaleEvidenceRef get
::attribute sourceAuthority get
::attribute postingState get

::method init
  expose projectionId legalEntityId sourceEventRef postingDate periodId eventId tradeId portfolioId economicRootTradeId closeIntentRef counterpartyEntity contractRole currency eventType effectiveAt realisedPnLMinor marketEvidenceRef authorityRef scaleEvidenceRef sourceAuthority postingState evidenceRefs metadata
  use strict arg projectionIdArg,legalEntityIdArg,sourceEventRefArg,postingDateArg,periodIdArg,eventIdArg,tradeIdArg,portfolioIdArg,economicRootTradeIdArg,currencyArg,eventTypeArg,effectiveAtArg,realisedPnLMinorArg,marketEvidenceRefArg,authorityRefArg,scaleEvidenceRefArg,sourceAuthorityArg,closeIntentRefArg="",counterpartyEntityArg="",contractRoleArg="CLIENT_CONTRACT",evidenceRefsArg=.nil,metadataArg=.nil
  projectionId=.AccountingUtil~requireText(projectionIdArg,"lifecycle projectionId")
  legalEntityId=.AccountingUtil~requireText(legalEntityIdArg,"legalEntityId")
  sourceEventRef=.AccountingUtil~requireText(sourceEventRefArg,"sourceEventRef")
  postingDate=.AccountingUtil~requireDate(postingDateArg,"postingDate")
  periodId=.AccountingUtil~requireText(periodIdArg,"periodId")
  eventId=.AccountingUtil~requireText(eventIdArg,"eventId")
  tradeId=.AccountingUtil~requireText(tradeIdArg,"tradeId")
  portfolioId=.AccountingUtil~requireText(portfolioIdArg,"portfolioId")
  economicRootTradeId=.AccountingUtil~requireText(economicRootTradeIdArg,"economicRootTradeId")
  currency=.AccountingUtil~requireText(currencyArg,"currency")~upper
  eventType=.AccountingUtil~requireText(eventTypeArg,"eventType")~upper
  effectiveAt=.AccountingUtil~requireText(effectiveAtArg,"effectiveAt")
  realisedPnLMinor=.MBAccountingBridgeUtil~requireSignedWhole(realisedPnLMinorArg,"realisedPnLMinor")
  marketEvidenceRef=.AccountingUtil~requireText(marketEvidenceRefArg,"marketEvidenceRef")
  authorityRef=.AccountingUtil~requireText(authorityRefArg,"authorityRef")
  scaleEvidenceRef=.AccountingUtil~requireText(scaleEvidenceRefArg,"scaleEvidenceRef")
  sourceAuthority=.AccountingUtil~requireText(sourceAuthorityArg,"sourceAuthority")
  closeIntentRef=closeIntentRefArg~string~strip
  counterpartyEntity=counterpartyEntityArg~string~strip
  contractRole=contractRoleArg~string~strip~upper
  if wordpos(contractRole,"CLIENT_CONTRACT REVERSING_CONTRACT EXTERNAL_HEDGE")=0 then -
    raise syntax 93.900 additional("unsupported lifecycle contractRole: " || contractRole)
  postingState="SETTLEMENT_EVIDENCE_REQUIRED"
  evidenceRefs=.AccountingUtil~copyArray(evidenceRefsArg)
  metadata=.AccountingUtil~copyDirectory(metadataArg)

::method evidenceRefs
  expose evidenceRefs
  return .AccountingUtil~copyArray(evidenceRefs)

::method metadata
  expose metadata
  return .AccountingUtil~copyDirectory(metadata)

::class MBAccountingSettlementObligationEvidence public
::attribute evidenceId get
::attribute legalEntityId get
::attribute sourceEventRef get
::attribute postingDate get
::attribute periodId get
::attribute obligationId get
::attribute executionId get
::attribute executionType get
::attribute portfolioId get
::attribute debtor get
::attribute creditor get
::attribute counterpartyEntity get
::attribute currency get
::attribute amountMinor get
::attribute settlementSide get
::attribute reason get
::attribute sourceAuthority get
::method init
  expose evidenceId legalEntityId sourceEventRef postingDate periodId obligationId executionId executionType portfolioId debtor creditor counterpartyEntity currency amountMinor settlementSide reason sourceAuthority evidenceRefs metadata
  use strict arg evidenceIdArg,legalEntityIdArg,sourceEventRefArg,postingDateArg,periodIdArg,obligationIdArg,executionIdArg,executionTypeArg,portfolioIdArg,debtorArg,creditorArg,counterpartyArg,currencyArg,amountMinorArg,settlementSideArg,reasonArg,sourceAuthorityArg,evidenceRefsArg=.nil,metadataArg=.nil
  evidenceId=.AccountingUtil~requireText(evidenceIdArg,"settlement obligation evidenceId")
  legalEntityId=.AccountingUtil~requireText(legalEntityIdArg,"legalEntityId")
  sourceEventRef=.AccountingUtil~requireText(sourceEventRefArg,"sourceEventRef")
  postingDate=.AccountingUtil~requireDate(postingDateArg,"postingDate")
  periodId=.AccountingUtil~requireText(periodIdArg,"periodId")
  obligationId=.AccountingUtil~requireText(obligationIdArg,"obligationId")
  executionId=.AccountingUtil~requireText(executionIdArg,"executionId")
  executionType=executionTypeArg~string~strip~upper
  if wordpos(executionType,"CLOSE_OUT RISK_NEUTRALISATION")=0 then raise syntax 93.900 additional("unsupported settlement executionType: " || executionType)
  portfolioId=.AccountingUtil~requireText(portfolioIdArg,"portfolioId")
  debtor=.AccountingUtil~requireText(debtorArg,"debtor")
  creditor=.AccountingUtil~requireText(creditorArg,"creditor")
  counterpartyEntity=.AccountingUtil~requireText(counterpartyArg,"counterpartyEntity")
  currency=.AccountingUtil~requireText(currencyArg,"currency")~upper
  amountMinor=.AccountingUtil~requireWholeNonNegative(amountMinorArg,"amountMinor")
  if amountMinor<=0 then raise syntax 93.900 additional("settlement obligation amountMinor must be positive")
  settlementSide=settlementSideArg~string~strip~upper
  if wordpos(settlementSide,"RECEIVABLE PAYABLE")=0 then raise syntax 93.900 additional("settlementSide must be RECEIVABLE or PAYABLE")
  reason=.AccountingUtil~requireText(reasonArg,"reason")~upper
  sourceAuthority=.AccountingUtil~requireText(sourceAuthorityArg,"sourceAuthority")
  evidenceRefs=.AccountingUtil~copyArray(evidenceRefsArg)
  metadata=.AccountingUtil~copyDirectory(metadataArg)
::method evidenceRefs; expose evidenceRefs; return .AccountingUtil~copyArray(evidenceRefs)
::method metadata; expose metadata; return .AccountingUtil~copyDirectory(metadata)

::class MBAccountingSettlementInstructionObservation public
::attribute projectionId get
::attribute legalEntityId get
::attribute obligationId get
::attribute instructionId get
::attribute debtor get
::attribute creditor get
::attribute currency get
::attribute amountMinor get
::attribute settlementChannelRef get
::attribute authorityRef get
::attribute instructedAt get
::attribute postingState get
::method init
  expose projectionId legalEntityId obligationId instructionId debtor creditor currency amountMinor settlementChannelRef authorityRef instructedAt postingState evidenceRefs metadata
  use strict arg projectionIdArg,legalEntityIdArg,obligationIdArg,instructionIdArg,debtorArg,creditorArg,currencyArg,amountMinorArg,channelArg,authorityArg,instructedAtArg,evidenceRefsArg=.nil,metadataArg=.nil
  projectionId=.AccountingUtil~requireText(projectionIdArg,"instruction projectionId")
  legalEntityId=.AccountingUtil~requireText(legalEntityIdArg,"legalEntityId")
  obligationId=.AccountingUtil~requireText(obligationIdArg,"obligationId")
  instructionId=.AccountingUtil~requireText(instructionIdArg,"instructionId")
  debtor=.AccountingUtil~requireText(debtorArg,"debtor")
  creditor=.AccountingUtil~requireText(creditorArg,"creditor")
  currency=.AccountingUtil~requireText(currencyArg,"currency")~upper
  amountMinor=.AccountingUtil~requireWholeNonNegative(amountMinorArg,"amountMinor")
  settlementChannelRef=.AccountingUtil~requireText(channelArg,"settlementChannelRef")
  authorityRef=.AccountingUtil~requireText(authorityArg,"authorityRef")
  instructedAt=.AccountingUtil~requireText(instructedAtArg,"instructedAt")
  postingState="SETTLEMENT_COMPLETION_EVIDENCE_REQUIRED"
  evidenceRefs=.AccountingUtil~copyArray(evidenceRefsArg)
  metadata=.AccountingUtil~copyDirectory(metadataArg)
::method evidenceRefs; expose evidenceRefs; return .AccountingUtil~copyArray(evidenceRefs)
::method metadata; expose metadata; return .AccountingUtil~copyDirectory(metadata)

::class MBAccountingSettlementObservationEvidence public
::attribute evidenceId get
::attribute legalEntityId get
::attribute sourceEventRef get
::attribute postingDate get
::attribute periodId get
::attribute settlementEvidenceId get
::attribute obligationId get
::attribute instructionId get
::attribute externalSettlementRef get
::attribute debtor get
::attribute creditor get
::attribute counterpartyEntity get
::attribute currency get
::attribute amountMinor get
::attribute settlementSide get
::attribute outcome get
::attribute sourceAuthority get
::method init
  expose evidenceId legalEntityId sourceEventRef postingDate periodId settlementEvidenceId obligationId instructionId externalSettlementRef debtor creditor counterpartyEntity currency amountMinor settlementSide outcome sourceAuthority evidenceRefs metadata
  use strict arg evidenceIdArg,legalEntityIdArg,sourceEventRefArg,postingDateArg,periodIdArg,settlementEvidenceIdArg,obligationIdArg,instructionIdArg,externalSettlementRefArg,debtorArg,creditorArg,counterpartyArg,currencyArg,amountMinorArg,settlementSideArg,outcomeArg,sourceAuthorityArg,evidenceRefsArg=.nil,metadataArg=.nil
  evidenceId=.AccountingUtil~requireText(evidenceIdArg,"settlement observation evidenceId")
  legalEntityId=.AccountingUtil~requireText(legalEntityIdArg,"legalEntityId")
  sourceEventRef=.AccountingUtil~requireText(sourceEventRefArg,"sourceEventRef")
  postingDate=.AccountingUtil~requireDate(postingDateArg,"postingDate")
  periodId=.AccountingUtil~requireText(periodIdArg,"periodId")
  settlementEvidenceId=.AccountingUtil~requireText(settlementEvidenceIdArg,"settlementEvidenceId")
  obligationId=.AccountingUtil~requireText(obligationIdArg,"obligationId")
  instructionId=.AccountingUtil~requireText(instructionIdArg,"instructionId")
  externalSettlementRef=.AccountingUtil~requireText(externalSettlementRefArg,"externalSettlementRef")
  debtor=.AccountingUtil~requireText(debtorArg,"debtor")
  creditor=.AccountingUtil~requireText(creditorArg,"creditor")
  counterpartyEntity=.AccountingUtil~requireText(counterpartyArg,"counterpartyEntity")
  currency=.AccountingUtil~requireText(currencyArg,"currency")~upper
  amountMinor=.AccountingUtil~requireWholeNonNegative(amountMinorArg,"amountMinor")
  settlementSide=settlementSideArg~string~strip~upper
  if wordpos(settlementSide,"RECEIVABLE PAYABLE")=0 then raise syntax 93.900 additional("settlementSide must be RECEIVABLE or PAYABLE")
  outcome=outcomeArg~string~strip~upper
  if wordpos(outcome,"PARTIAL COMPLETE FAILED")=0 then raise syntax 93.900 additional("unsupported settlement outcome: " || outcome)
  if outcome="FAILED" then do; if amountMinor<>0 then raise syntax 93.900 additional("failed settlement observation must have zero amountMinor"); end
  else if amountMinor<=0 then raise syntax 93.900 additional("settled amountMinor must be positive")
  sourceAuthority=.AccountingUtil~requireText(sourceAuthorityArg,"sourceAuthority")
  evidenceRefs=.AccountingUtil~copyArray(evidenceRefsArg)
  metadata=.AccountingUtil~copyDirectory(metadataArg)
::method evidenceRefs; expose evidenceRefs; return .AccountingUtil~copyArray(evidenceRefs)
::method metadata; expose metadata; return .AccountingUtil~copyDirectory(metadata)



::class MBAccountingSettlementAmountRequestEvidence public
::attribute requestId get
::attribute legalEntityId get
::attribute obligationId get
::attribute settlementDate get
::attribute currencyMinorExponent get
::attribute settlementElectionRef get
::attribute tenderClass get
::attribute sourceAuthority get
::method init
  expose requestId legalEntityId obligationId settlementDate currencyMinorExponent settlementElectionRef tenderClass sourceAuthority evidenceRefs metadata
  use strict arg requestIdArg,legalEntityIdArg,obligationIdArg,settlementDateArg,currencyMinorExponentArg,electionArg,tenderArg,sourceAuthorityArg,evidenceArg=.nil,metadataArg=.nil
  requestId=.AccountingUtil~requireText(requestIdArg,"settlement amount requestId")
  legalEntityId=.AccountingUtil~requireText(legalEntityIdArg,"settlement amount legalEntityId")
  obligationId=.AccountingUtil~requireText(obligationIdArg,"settlement amount obligationId")
  settlementDate=.AccountingUtil~requireDate(settlementDateArg,"settlementDate")
  currencyMinorExponent=.AccountingUtil~requireWholeNonNegative(currencyMinorExponentArg,"currencyMinorExponent")
  if currencyMinorExponent>50 then raise syntax 93.900 additional("currencyMinorExponent exceeds accounting numeric digits")
  settlementElectionRef=.AccountingUtil~requireText(electionArg,"settlementElectionRef")
  tenderClass=.AccountingUtil~requireText(tenderArg,"tenderClass")~upper
  sourceAuthority=.AccountingUtil~requireText(sourceAuthorityArg,"settlement amount sourceAuthority")
  evidenceRefs=.AccountingUtil~copyArray(evidenceArg)
  metadata=.AccountingUtil~copyDirectory(metadataArg)
::method evidenceRefs; expose evidenceRefs; return .AccountingUtil~copyArray(evidenceRefs)
::method metadata; expose metadata; return .AccountingUtil~copyDirectory(metadata)

::class MBAccountingSettlementAmountDetermination public
::attribute contractGeneration get
::attribute requestId get
::attribute legalEntityId get
::attribute obligationId get
::attribute settlementDate get
::attribute currency get
::attribute accountedAmountMinor get
::attribute settledAmountMinor get
::attribute roundingDifferenceMinor get
::attribute tenderClass get
::attribute settlementElectionRef get
::attribute settlementElectionIdentity get
::attribute settlementPolicyRef get
::attribute settlementPolicyIdentity get
::attribute rulesetRef get
::attribute rulesetIdentity get
::attribute roundingAlgorithmRef get
::attribute roundingQuantumMinor get
::attribute jurisdiction get
::attribute requestFingerprint get
::attribute sourceAuthority get
::attribute postingState get
::method init
  expose contractGeneration requestId legalEntityId obligationId settlementDate currency accountedAmountMinor settledAmountMinor roundingDifferenceMinor tenderClass settlementElectionRef settlementElectionIdentity settlementPolicyRef settlementPolicyIdentity rulesetRef rulesetIdentity roundingAlgorithmRef roundingQuantumMinor jurisdiction requestFingerprint sourceAuthority postingState evidenceRefs metadata
  use strict arg requestIdArg,legalEntityIdArg,obligationIdArg,settlementDateArg,currencyArg,accountedArg,settledArg,differenceArg,tenderArg,electionRefArg,electionIdentityArg,policyRefArg,policyIdentityArg,rulesetRefArg,rulesetIdentityArg,roundingAlgorithmArg,quantumArg,jurisdictionArg,requestFingerprintArg,sourceAuthorityArg,evidenceArg=.nil,metadataArg=.nil
  contractGeneration=.FederationBankMerchantAccountingBuild~SETTLEMENT_AMOUNT_API
  requestId=.AccountingUtil~requireText(requestIdArg,"settlement amount determination requestId")
  legalEntityId=.AccountingUtil~requireText(legalEntityIdArg,"settlement amount determination legalEntityId")
  obligationId=.AccountingUtil~requireText(obligationIdArg,"settlement amount determination obligationId")
  settlementDate=.AccountingUtil~requireDate(settlementDateArg,"settlement amount determination date")
  currency=.AccountingUtil~requireText(currencyArg,"settlement amount determination currency")~upper
  accountedAmountMinor=.MBAccountingBridgeUtil~requireSignedWhole(accountedArg,"accountedAmountMinor")
  settledAmountMinor=.MBAccountingBridgeUtil~requireSignedWhole(settledArg,"settledAmountMinor")
  roundingDifferenceMinor=.MBAccountingBridgeUtil~requireSignedWhole(differenceArg,"roundingDifferenceMinor")
  numeric digits 50
  if settledAmountMinor-accountedAmountMinor<>roundingDifferenceMinor then raise syntax 93.900 additional("settlement amount determination difference mismatch")
  tenderClass=.AccountingUtil~requireText(tenderArg,"settlement amount determination tenderClass")~upper
  settlementElectionRef=.AccountingUtil~requireText(electionRefArg,"settlementElectionRef")
  settlementElectionIdentity=.AccountingUtil~requireText(electionIdentityArg,"settlementElectionIdentity")
  settlementPolicyRef=.AccountingUtil~requireText(policyRefArg,"settlementPolicyRef")
  settlementPolicyIdentity=.AccountingUtil~requireText(policyIdentityArg,"settlementPolicyIdentity")
  rulesetRef=.AccountingUtil~requireText(rulesetRefArg,"rulesetRef")
  rulesetIdentity=.AccountingUtil~requireText(rulesetIdentityArg,"rulesetIdentity")
  roundingAlgorithmRef=.AccountingUtil~requireText(roundingAlgorithmArg,"roundingAlgorithmRef")
  roundingQuantumMinor=.AccountingUtil~requireWholeNonNegative(quantumArg,"roundingQuantumMinor")
  if roundingQuantumMinor=0 then raise syntax 93.900 additional("roundingQuantumMinor must be positive")
  jurisdiction=.AccountingUtil~requireText(jurisdictionArg,"jurisdiction")~upper
  requestFingerprint=.AccountingUtil~requireText(requestFingerprintArg,"requestFingerprint")
  sourceAuthority=.AccountingUtil~requireText(sourceAuthorityArg,"sourceAuthority")
  if roundingDifferenceMinor=0 then postingState="MERCHANT_SETTLEMENT_OBSERVATION_REQUIRED"
  else postingState="MERCHANT_SETTLEMENT_AMOUNT_AUTHORITY_REQUIRED"
  evidenceRefs=.AccountingUtil~copyArray(evidenceArg)
  metadata=.AccountingUtil~copyDirectory(metadataArg)
::method evidenceRefs; expose evidenceRefs; return .AccountingUtil~copyArray(evidenceRefs)
::method metadata; expose metadata; return .AccountingUtil~copyDirectory(metadata)
::method projection
  expose contractGeneration requestId legalEntityId obligationId settlementDate currency accountedAmountMinor settledAmountMinor roundingDifferenceMinor tenderClass settlementElectionRef settlementElectionIdentity settlementPolicyRef settlementPolicyIdentity rulesetRef rulesetIdentity roundingAlgorithmRef roundingQuantumMinor jurisdiction requestFingerprint sourceAuthority postingState evidenceRefs metadata
  p=.directory~new
  p["contract_generation"]=contractGeneration; p["request_id"]=requestId; p["legal_entity_id"]=legalEntityId; p["obligation_id"]=obligationId
  p["settlement_date"]=settlementDate; p["currency"]=currency; p["accounted_amount_minor"]=accountedAmountMinor; p["settled_amount_minor"]=settledAmountMinor; p["rounding_difference_minor"]=roundingDifferenceMinor
  p["tender_class"]=tenderClass; p["settlement_election_ref"]=settlementElectionRef; p["settlement_election_identity"]=settlementElectionIdentity
  p["settlement_policy_ref"]=settlementPolicyRef; p["settlement_policy_identity"]=settlementPolicyIdentity; p["ruleset_ref"]=rulesetRef; p["ruleset_identity"]=rulesetIdentity
  p["rounding_algorithm_ref"]=roundingAlgorithmRef; p["rounding_quantum_minor"]=roundingQuantumMinor; p["jurisdiction"]=jurisdiction; p["request_fingerprint"]=requestFingerprint
  p["source_authority"]=sourceAuthority; p["posting_state"]=postingState; p["evidence_refs"]=.AccountingUtil~copyArray(evidenceRefs); p["metadata"]=.AccountingUtil~copyDirectory(metadata)
  return p

::class MBAccountingSettlementAmountResult public
::attribute ok get
::attribute status get
::attribute determination get
::attribute errorCode get
::attribute message get
::method success class
  use strict arg determinationArg
  return self~new(.true,"DETERMINED",determinationArg,"","")
::method failure class
  use strict arg codeArg,messageArg=""
  return self~new(.false,"REJECTED",.nil,codeArg,messageArg)
::method init
  expose ok status determination errorCode message
  use strict arg okArg,statusArg,determinationArg,codeArg,messageArg
  ok=okArg; status=statusArg~string; determination=determinationArg; errorCode=codeArg~string; message=messageArg~string

::class MBAccountingSettlementObligationPolicy public subclass AccountingPolicy
::method init
  use strict arg identityArg,entityArg="FEDERATIONBANK_MERCHANT_BANK"
  self~init:super(.FederationBankMerchantAccountingBuild~SETTLEMENT_OBLIGATION_POLICY,identityArg || "#MBAccountingSettlementObligationPolicy",entityArg,.FederationBankMerchantAccountingBuild~SETTLEMENT_OBLIGATION_EVENT_TYPE,.FederationBankMerchantAccountingBuild~POLICY_EFFECTIVE_FROM)
::method propose
  use strict arg event,book
  numeric digits 50
  amount=.AccountingUtil~requireWholeNonNegative(event~value("amountMinor"),"amountMinor")
  if amount<=0 then return .AccountingPolicyDecision~reject("ZERO_NOT_ACCOUNTABLE",event~sourceEventRef)
  side=.AccountingUtil~requireText(event~value("settlementSide"),"settlementSide")~upper
  if wordpos(side,"RECEIVABLE PAYABLE")=0 then return .AccountingPolicyDecision~reject("UNSUPPORTED_SETTLEMENT_SIDE",side)
  expected=.AccountingUtil~requireText(event~value("periodId"),"periodId")
  period=book~periodForDate(event~eventDate,.false)
  if period==.nil | period~periodId<>expected then return .AccountingPolicyDecision~reject("ACCOUNTING_PERIOD_BINDING_MISMATCH",expected)
  dims=event~metadata
  dims["merchantObligationId"]=event~value("obligationId")
  dims["merchantExecutionId"]=event~value("executionId")
  dims["merchantPortfolioId"]=event~value("portfolioId")
  dims["settlementSide"]=side
  dims["settlementReason"]=event~value("reason")
  dims["sourceAuthority"]=event~sourceAuthorityRef
  draft=self~newDraft(event,book,event~eventDate,"Recognise Merchant derivative settlement obligation",.nil,dims)
  ccy=.AccountingUtil~requireText(event~value("currency"),"currency")~upper
  if side="RECEIVABLE" then do
    draft~addLine(.AccountingJournalLine~new("1315",ccy,amount,0,"Recognise derivative settlement receivable",dims))
    draft~addLine(.AccountingJournalLine~new("2395",ccy,0,amount,"Pending derivative derecognition control",dims))
  end
  else do
    draft~addLine(.AccountingJournalLine~new("1395",ccy,amount,0,"Pending derivative derecognition control",dims))
    draft~addLine(.AccountingJournalLine~new("2315",ccy,0,amount,"Recognise derivative settlement payable",dims))
  end
  return .AccountingPolicyDecision~accept(draft,"Attributable Merchant obligation becomes settlement receivable/payable; derivative carrying-value derecognition remains separately unproved")

::class MBAccountingSettlementObservationPolicy public subclass AccountingPolicy
::method init
  use strict arg identityArg,entityArg="FEDERATIONBANK_MERCHANT_BANK"
  self~init:super(.FederationBankMerchantAccountingBuild~SETTLEMENT_OBSERVATION_POLICY,identityArg || "#MBAccountingSettlementObservationPolicy",entityArg,.FederationBankMerchantAccountingBuild~SETTLEMENT_OBSERVATION_EVENT_TYPE,.FederationBankMerchantAccountingBuild~POLICY_EFFECTIVE_FROM)
::method propose
  use strict arg event,book
  numeric digits 50
  amount=.AccountingUtil~requireWholeNonNegative(event~value("amountMinor"),"amountMinor")
  outcome=.AccountingUtil~requireText(event~value("outcome"),"outcome")~upper
  if outcome="FAILED" then return .AccountingPolicyDecision~reject("FAILED_SETTLEMENT_NOT_ACCOUNTABLE",event~sourceEventRef)
  if amount<=0 then return .AccountingPolicyDecision~reject("ZERO_NOT_ACCOUNTABLE",event~sourceEventRef)
  side=.AccountingUtil~requireText(event~value("settlementSide"),"settlementSide")~upper
  expected=.AccountingUtil~requireText(event~value("periodId"),"periodId")
  period=book~periodForDate(event~eventDate,.false)
  if period==.nil | period~periodId<>expected then return .AccountingPolicyDecision~reject("ACCOUNTING_PERIOD_BINDING_MISMATCH",expected)
  dims=event~metadata
  dims["merchantObligationId"]=event~value("obligationId")
  dims["merchantInstructionId"]=event~value("instructionId")
  dims["merchantSettlementEvidenceId"]=event~value("settlementEvidenceId")
  dims["externalSettlementRef"]=event~value("externalSettlementRef")
  dims["settlementSide"]=side
  dims["settlementOutcome"]=outcome
  dims["sourceAuthority"]=event~sourceAuthorityRef
  draft=self~newDraft(event,book,event~eventDate,"Recognise externally observed Merchant settlement",.nil,dims)
  ccy=.AccountingUtil~requireText(event~value("currency"),"currency")~upper
  if side="RECEIVABLE" then do
    draft~addLine(.AccountingJournalLine~new("1105",ccy,amount,0,"Cash observed at settlement agent",dims))
    draft~addLine(.AccountingJournalLine~new("1315",ccy,0,amount,"Clear derivative settlement receivable",dims))
  end
  else do
    draft~addLine(.AccountingJournalLine~new("2315",ccy,amount,0,"Clear derivative settlement payable",dims))
    draft~addLine(.AccountingJournalLine~new("1105",ccy,0,amount,"Cash observed at settlement agent",dims))
  end
  return .AccountingPolicyDecision~accept(draft,"Only externally attributable partial/complete settlement evidence moves settlement receivable/payable to cash-at-settlement-agent")

::class MBAccountingDerivativeFairValueMovementPolicy public subclass AccountingPolicy
::method init
  use strict arg identityArg,entityArg="FEDERATIONBANK_MERCHANT_BANK"
  self~init:super(.FederationBankMerchantAccountingBuild~FAIR_VALUE_POLICY,identityArg || "#MBAccountingDerivativeFairValueMovementPolicy",entityArg,.FederationBankMerchantAccountingBuild~FAIR_VALUE_EVENT_TYPE,.FederationBankMerchantAccountingBuild~POLICY_EFFECTIVE_FROM)

::method propose
  use strict arg event,book
  numeric digits 50
  amount=.AccountingUtil~requireWholeNonNegative(event~value("amountMinor"),"amountMinor")
  if amount=0 then return .AccountingPolicyDecision~reject("ZERO_NOT_ACCOUNTABLE",event~sourceEventRef)
  side=.AccountingUtil~requireText(event~value("carryingSide"),"carryingSide")~upper
  direction=.AccountingUtil~requireText(event~value("movementDirection"),"movementDirection")~upper
  if wordpos(side,"ASSET LIABILITY")=0 then return .AccountingPolicyDecision~reject("UNSUPPORTED_CARRYING_SIDE",side)
  if wordpos(direction,"INCREASE DECREASE")=0 then return .AccountingPolicyDecision~reject("UNSUPPORTED_MOVEMENT_DIRECTION",direction)
  if \self~periodBindingValid(event,book) then return .AccountingPolicyDecision~reject("ACCOUNTING_PERIOD_BINDING_MISMATCH",event~value("periodId"))

  dims=self~dimensions(event)
  draft=self~newDraft(event,book,event~eventDate,"Merchant derivative fair-value movement",.nil,dims)
  ccy=.AccountingUtil~requireText(event~value("currency"),"currency")~upper
  if side="ASSET" & direction="INCREASE" then do
    draft~addLine(.AccountingJournalLine~new("1300",ccy,amount,0,"Increase derivative asset",dims))
    draft~addLine(.AccountingJournalLine~new("4100",ccy,0,amount,"Derivative fair-value gain",dims))
  end
  else if side="ASSET" & direction="DECREASE" then do
    draft~addLine(.AccountingJournalLine~new("5100",ccy,amount,0,"Derivative fair-value loss",dims))
    draft~addLine(.AccountingJournalLine~new("1300",ccy,0,amount,"Decrease derivative asset",dims))
  end
  else if side="LIABILITY" & direction="INCREASE" then do
    draft~addLine(.AccountingJournalLine~new("5100",ccy,amount,0,"Derivative fair-value loss",dims))
    draft~addLine(.AccountingJournalLine~new("2300",ccy,0,amount,"Increase derivative liability",dims))
  end
  else do
    draft~addLine(.AccountingJournalLine~new("2300",ccy,amount,0,"Decrease derivative liability",dims))
    draft~addLine(.AccountingJournalLine~new("4100",ccy,0,amount,"Derivative fair-value gain",dims))
  end
  return .AccountingPolicyDecision~accept(draft,"Merchant entity policy maps attributable derivative fair-value movement")

::method periodBindingValid private
  use strict arg event,book
  expected=.AccountingUtil~requireText(event~value("periodId"),"periodId")
  period=book~periodForDate(event~eventDate,.false)
  if period==.nil then return .false
  return period~periodId=expected

::method dimensions private
  use strict arg event
  dims=event~metadata
  dims["merchantTradeId"]=event~value("tradeId")
  dims["merchantPortfolioId"]=event~value("portfolioId")
  dims["economicRootTradeId"]=event~correlationRef
  dims["contractRole"]=event~value("contractRole")
  dims["sourceAuthority"]=event~sourceAuthorityRef
  if event~value("closeIntentRef","")~string<>"" then dims["closeIntentRef"]=event~value("closeIntentRef")
  if event~counterpartyEntityId<>"" then dims["counterpartyEntity"]=event~counterpartyEntityId
  return dims

::class MBAccountingDerivativeFairValueTransitionPolicy public subclass AccountingPolicy
::method init
  use strict arg identityArg,entityArg="FEDERATIONBANK_MERCHANT_BANK"
  self~init:super(.FederationBankMerchantAccountingBuild~FAIR_VALUE_TRANSITION_POLICY,identityArg || "#MBAccountingDerivativeFairValueTransitionPolicy",entityArg,.FederationBankMerchantAccountingBuild~FAIR_VALUE_TRANSITION_EVENT_TYPE,.FederationBankMerchantAccountingBuild~POLICY_EFFECTIVE_FROM)

::method propose
  use strict arg event,book
  numeric digits 50
  previous=.MBAccountingBridgeUtil~requireSignedWhole(event~value("previousMarketValueMinor"),"previousMarketValueMinor")
  current=.MBAccountingBridgeUtil~requireSignedWhole(event~value("currentMarketValueMinor"),"currentMarketValueMinor")
  if previous=current then return .AccountingPolicyDecision~reject("NO_CHANGE",event~sourceEventRef)
  expected=.AccountingUtil~requireText(event~value("periodId"),"periodId")
  period=book~periodForDate(event~eventDate,.false)
  if period==.nil then return .AccountingPolicyDecision~reject("ACCOUNTING_PERIOD_BINDING_MISMATCH",expected)
  if period~periodId<>expected then return .AccountingPolicyDecision~reject("ACCOUNTING_PERIOD_BINDING_MISMATCH",expected)

  dims=event~metadata
  dims["merchantTradeId"]=event~value("tradeId")
  dims["merchantPortfolioId"]=event~value("portfolioId")
  dims["economicRootTradeId"]=event~correlationRef
  dims["contractRole"]=event~value("contractRole")
  dims["sourceAuthority"]=event~sourceAuthorityRef
  dims["previousMarkRef"]=event~value("previousMarkRef")
  dims["currentMarkRef"]=event~value("currentMarkRef")
  dims["valuationRef"]=event~value("valuationRef")
  dims["marketEvidenceRef"]=event~value("marketEvidenceRef")
  dims["scaleEvidenceRef"]=event~value("scaleEvidenceRef")
  if event~value("closeIntentRef","")~string<>"" then dims["closeIntentRef"]=event~value("closeIntentRef")
  if event~counterpartyEntityId<>"" then dims["counterpartyEntity"]=event~counterpartyEntityId

  draft=self~newDraft(event,book,event~eventDate,"Merchant derivative fair-value transition",.nil,dims)
  ccy=.AccountingUtil~requireText(event~value("currency"),"currency")~upper
  if previous>0 then draft~addLine(.AccountingJournalLine~new("1300",ccy,0,previous,"Derecognise prior derivative asset carrying amount",dims))
  else if previous<0 then draft~addLine(.AccountingJournalLine~new("2300",ccy,-previous,0,"Derecognise prior derivative liability carrying amount",dims))
  if current>0 then draft~addLine(.AccountingJournalLine~new("1300",ccy,current,0,"Recognise current derivative asset carrying amount",dims))
  else if current<0 then draft~addLine(.AccountingJournalLine~new("2300",ccy,0,-current,"Recognise current derivative liability carrying amount",dims))
  delta=current-previous
  if delta>0 then draft~addLine(.AccountingJournalLine~new("4100",ccy,0,delta,"Derivative fair-value gain",dims))
  else if delta<0 then draft~addLine(.AccountingJournalLine~new("5100",ccy,-delta,0,"Derivative fair-value loss",dims))
  return .AccountingPolicyDecision~accept(draft,"Merchant entity policy maps attributable derivative fair-value transition")

::class FederationBankMerchantAccountingAdapter public
::attribute merchantEntity get
::attribute bookId get
::attribute reportingBasis get
::attribute policyArtifactIdentity get

::method init
  expose merchantEntity bookId reportingBasis engine fairValuePolicyRef fairValueTransitionPolicyRef lifecycleProjectionPolicyRef settlementObligationPolicyRef settlementObservationPolicyRef settlementChartReady policyArtifactIdentity
  use strict arg merchantEntityArg="FEDERATIONBANK_MERCHANT_BANK",bookIdArg="FB-MERCHANT-STAT",reportingBasisArg="IFRS",nativeBookArg=.nil,policyArtifactIdentityArg=""
  numeric digits 50
  merchantEntity=.AccountingUtil~requireText(merchantEntityArg,"merchantEntity")
  bookId=.AccountingUtil~requireText(bookIdArg,"bookId")
  reportingBasis=.AccountingUtil~requireText(reportingBasisArg,"reportingBasis")
  if policyArtifactIdentityArg~string~strip="" then policyArtifactIdentity=.FederationBankMerchantAccountingBuild~POLICY_ARTIFACT_IDENTITY
  else policyArtifactIdentity=.AccountingUtil~requireText(policyArtifactIdentityArg,"policyArtifactIdentity")
  fairValuePolicyRef=.FederationBankMerchantAccountingBuild~FAIR_VALUE_POLICY
  fairValueTransitionPolicyRef=.FederationBankMerchantAccountingBuild~FAIR_VALUE_TRANSITION_POLICY
  lifecycleProjectionPolicyRef=.FederationBankMerchantAccountingBuild~LIFECYCLE_PROJECTION_POLICY
  settlementObligationPolicyRef=.FederationBankMerchantAccountingBuild~SETTLEMENT_OBLIGATION_POLICY
  settlementObservationPolicyRef=.FederationBankMerchantAccountingBuild~SETTLEMENT_OBSERVATION_POLICY
  if nativeBookArg==.nil then engine=.AccountingEngine~new(merchantEntity,bookId,reportingBasis)
  else do
    if \nativeBookArg~isA(.AccountingBook) then raise syntax 93.900 additional("AccountingBook required")
    if nativeBookArg~legalEntityId<>merchantEntity then raise syntax 93.900 additional("Recovered Merchant accounting book legal entity mismatch")
    if nativeBookArg~bookId<>bookId then raise syntax 93.900 additional("Recovered Merchant accounting book id mismatch")
    if nativeBookArg~reportingBasis<>reportingBasis then raise syntax 93.900 additional("Recovered Merchant accounting reporting basis mismatch")
    engine=.AccountingEngine~new(merchantEntity,bookId,reportingBasis,nativeBookArg)
  end
  settlementChartReady=self~ensureChart
  engine~registerPolicy(.MBAccountingDerivativeFairValueMovementPolicy~new(policyArtifactIdentity,merchantEntity))
  engine~registerPolicy(.MBAccountingDerivativeFairValueTransitionPolicy~new(policyArtifactIdentity,merchantEntity))
  engine~registerPolicy(.MBAccountingSettlementObligationPolicy~new(policyArtifactIdentity,merchantEntity))
  engine~registerPolicy(.MBAccountingSettlementObservationPolicy~new(policyArtifactIdentity,merchantEntity))

::method createDurable class
  use strict arg storePath,merchantEntityArg="FEDERATIONBANK_MERCHANT_BANK",bookIdArg="FB-MERCHANT-STAT",reportingBasisArg="IFRS",policyArtifactIdentityArg=""
  store=.AccountingFileStore~new(storePath)
  book=store~createBook(merchantEntityArg,bookIdArg,reportingBasisArg)
  return self~new(merchantEntityArg,bookIdArg,reportingBasisArg,book,policyArtifactIdentityArg)

::method recoverDurable class
  use strict arg storePath,policyArtifactIdentityArg=""
  store=.AccountingFileStore~new(storePath)
  book=store~recoverBook
  return self~new(book~legalEntityId,book~bookId,book~reportingBasis,book,policyArtifactIdentityArg)

::method api
  return .FederationBankMerchantAccountingBuild~API

::method projectionApi
  return .FederationBankMerchantAccountingBuild~PROJECTION_API

::method eventProjectionApi
  return .FederationBankMerchantAccountingBuild~EVENT_PROJECTION_API

::method engine
  expose engine
  return engine

::method book
  expose engine
  return engine~book

::method fairValuePolicyRef
  expose fairValuePolicyRef
  return fairValuePolicyRef

::method fairValueTransitionPolicyRef
  expose fairValueTransitionPolicyRef
  return fairValueTransitionPolicyRef

::method lifecycleProjectionPolicyRef
  expose lifecycleProjectionPolicyRef
  return lifecycleProjectionPolicyRef

::method settlementObligationPolicyRef
  expose settlementObligationPolicyRef
  return settlementObligationPolicyRef

::method settlementObservationPolicyRef
  expose settlementObservationPolicyRef
  return settlementObservationPolicyRef

::method settlementPostingAvailable
  expose settlementChartReady
  return settlementChartReady


::method settlementAmountApi
  return .FederationBankMerchantAccountingBuild~SETTLEMENT_AMOUNT_API

::method registerSettlementRoundingElection
  expose merchantEntity engine
  use strict arg election
  if election==.nil | \election~isA(.AccountingSettlementRoundingElection) then raise syntax 93.900 additional("AccountingSettlementRoundingElection required")
  if election~legalEntityId<>merchantEntity then raise syntax 93.900 additional("Merchant settlement election legal entity mismatch")
  return engine~scopes~registerSettlementElection(election)

::method registerSettlementRoundingPolicy
  expose engine
  use strict arg policy
  if policy==.nil | \policy~isA(.AccountingSettlementPolicy) then raise syntax 93.900 additional("AccountingSettlementPolicy required")
  return engine~registerSettlementPolicy(policy)

::method determineSettlementAmount
  expose merchantEntity engine
  use strict arg request,scaleEvidence
  if request==.nil | \request~isA(.MBAccountingSettlementAmountRequestEvidence) then return .MBAccountingSettlementAmountResult~failure("MERCHANT_SETTLEMENT_AMOUNT_REQUEST_REQUIRED","MBAccountingSettlementAmountRequestEvidence required")
  if request~legalEntityId<>merchantEntity then return .MBAccountingSettlementAmountResult~failure("MERCHANT_ENTITY_MISMATCH",request~legalEntityId||" != "||merchantEntity)
  if scaleEvidence==.nil | \scaleEvidence~isA(.MBAccountingCurrencyScaleEvidence) then return .MBAccountingSettlementAmountResult~failure("ACCOUNTING_SCALE_EVIDENCE_REQUIRED","MBAccountingCurrencyScaleEvidence required")
  facts=self~settlementObligationAccountingFacts(request~obligationId)
  if facts==.nil then return .MBAccountingSettlementAmountResult~failure("SETTLEMENT_OBLIGATION_NOT_ACCOUNTED",request~obligationId)
  if scaleEvidence~currency<>facts["currency"] then return .MBAccountingSettlementAmountResult~failure("ACCOUNTING_SCALE_CURRENCY_MISMATCH",scaleEvidence~currency||" != "||facts["currency"])
  numeric digits 50
  expectedScale=10**request~currencyMinorExponent
  if scaleEvidence~minorUnitsPerUnit<>expectedScale then return .MBAccountingSettlementAmountResult~failure("ACCOUNTING_SCALE_EXPONENT_MISMATCH",scaleEvidence~minorUnitsPerUnit||" != 10**"||request~currencyMinorExponent)
  refs=request~evidenceRefs
  refs~append("MERCHANT_SETTLEMENT_OBLIGATION:"||request~obligationId)
  refs~append("ACCOUNTING_SCALE:"||scaleEvidence~evidenceId)
  metadata=request~metadata
  metadata["merchantSettlementSide"]=facts["side"]
  metadata["merchantSettlementAmountAuthority"]="DETERMINATION_ONLY"
  dims=.directory~new
  dims["merchantObligationId"]=request~obligationId
  dims["settlementSide"]=facts["side"]
  coreRequest=.AccountingSettlementRequest~new("MB:SETTLEMENT:AMOUNT:"||request~requestId,merchantEntity,request~settlementDate,facts["currency"],request~currencyMinorExponent,facts["amountMinor"],request~settlementElectionRef,request~tenderClass,request~obligationId,facts["counterparty"],request~sourceAuthority,refs,dims,metadata)
  coreResult=engine~determineSettlement(coreRequest)
  if \coreResult~ok then return .MBAccountingSettlementAmountResult~failure(coreResult~errorCode,coreResult~message)
  d=coreResult~determination
  out=.MBAccountingSettlementAmountDetermination~new(request~requestId,merchantEntity,request~obligationId,request~settlementDate,d~currency,d~accountedAmountMinor,d~settledAmountMinor,d~roundingDifferenceMinor,d~tenderClass,d~settlementElectionRef,d~settlementElectionIdentity,d~settlementPolicyRef,d~settlementPolicyIdentity,d~rulesetRef,d~rulesetIdentity,d~roundingAlgorithmRef,d~roundingQuantumMinor,d~jurisdiction,d~requestFingerprint,request~sourceAuthority,d~evidenceRefs,d~metadata)
  return .MBAccountingSettlementAmountResult~success(out)

::method postSettlementAmountDetermination
  expose merchantEntity
  use strict arg determination
  if determination==.nil | \determination~isA(.MBAccountingSettlementAmountDetermination) then return .AccountingTransactionResult~failure("MERCHANT_SETTLEMENT_AMOUNT_DETERMINATION_REQUIRED","MBAccountingSettlementAmountDetermination required")
  if determination~legalEntityId<>merchantEntity then return .AccountingTransactionResult~failure("MERCHANT_ENTITY_MISMATCH",determination~legalEntityId||" != "||merchantEntity)
  if determination~roundingDifferenceMinor<>0 then return .AccountingTransactionResult~failure("MERCHANT_SETTLEMENT_AMOUNT_AUTHORITY_REQUIRED","A settlement-rounding determination does not amend or discharge the Merchant contractual obligation; attributable Merchant settlement-amount authority is required before any accounting adjustment")
  return .AccountingTransactionResult~failure("SETTLEMENT_COMPLETION_EVIDENCE_REQUIRED","An exact settlement-amount determination still proves neither instruction nor external cash settlement")

::method settlementObligationAccountingFacts private
  expose engine
  use strict arg obligationId
  entry=engine~book~sourceEntry("MB:ACCOUNTING:SETTLEMENT_OBLIGATION:"||obligationId)
  if entry==.nil then return .nil
  if entry~eventType<>.FederationBankMerchantAccountingBuild~SETTLEMENT_OBLIGATION_EVENT_TYPE then return .nil
  facts=.directory~new; facts["amountMinor"]=0; facts["currency"]=""; facts["side"]=""; facts["counterparty"]=entry~counterpartyEntityId
  do line over entry~lines
    if line~accountId="1315" & line~debitMinor>0 then do
      if facts["side"]<>"" then return .nil
      facts["side"]="RECEIVABLE"; facts["amountMinor"]=line~debitMinor-line~creditMinor; facts["currency"]=line~currency
    end
    else if line~accountId="2315" & line~creditMinor>0 then do
      if facts["side"]<>"" then return .nil
      facts["side"]="PAYABLE"; facts["amountMinor"]=line~creditMinor-line~debitMinor; facts["currency"]=line~currency
    end
  end
  if facts["side"]="" | facts["amountMinor"]<=0 | facts["currency"]="" then return .nil
  return facts

::method addPeriod
  expose engine
  use strict arg periodId,startDate,endDate,state="OPEN"
  return engine~book~addPeriod(.AccountingPeriod~new(periodId,startDate,endDate,state))

::method accountingEventForDerivativeFairValueMovement
  expose merchantEntity
  use strict arg evidence
  if evidence==.nil | \evidence~isA(.MBAccountingDerivativeFairValueMovementEvidence) then return .nil
  if evidence~legalEntityId<>merchantEntity then return .nil
  payload=.directory~new
  payload["periodId"]=evidence~periodId
  payload["tradeId"]=evidence~tradeId
  payload["portfolioId"]=evidence~portfolioId
  payload["contractRole"]=evidence~contractRole
  payload["currency"]=evidence~currency
  payload["amountMinor"]=evidence~amountMinor
  payload["carryingSide"]=evidence~carryingSide
  payload["movementDirection"]=evidence~movementDirection
  payload["closeIntentRef"]=evidence~closeIntentRef
  refs=evidence~evidenceRefs
  refs~append(evidence~evidenceId)
  metadata=evidence~metadata
  metadata["merchantAccountingProjection"]=self~eventProjectionApi
  return .AccountingEvent~new(evidence~sourceEventRef,evidence~legalEntityId,.FederationBankMerchantAccountingBuild~FAIR_VALUE_EVENT_TYPE,evidence~postingDate,evidence~economicRootTradeId,evidence~counterpartyEntity,evidence~sourceAuthority,payload,refs,metadata)

::method accountingEventForDerivativeFairValueTransition
  expose merchantEntity
  use strict arg evidence
  if evidence==.nil | \evidence~isA(.MBAccountingDerivativeFairValueTransitionEvidence) then return .nil
  if evidence~legalEntityId<>merchantEntity then return .nil
  payload=.directory~new
  payload["periodId"]=evidence~periodId
  payload["tradeId"]=evidence~tradeId
  payload["portfolioId"]=evidence~portfolioId
  payload["contractRole"]=evidence~contractRole
  payload["currency"]=evidence~currency
  payload["previousMarketValueMinor"]=evidence~previousMarketValueMinor
  payload["currentMarketValueMinor"]=evidence~currentMarketValueMinor
  payload["previousMarkRef"]=evidence~previousMarkRef
  payload["currentMarkRef"]=evidence~currentMarkRef
  payload["valuationRef"]=evidence~valuationRef
  payload["marketEvidenceRef"]=evidence~marketEvidenceRef
  payload["scaleEvidenceRef"]=evidence~scaleEvidenceRef
  payload["closeIntentRef"]=evidence~closeIntentRef
  refs=evidence~evidenceRefs
  refs~append(evidence~evidenceId)
  metadata=evidence~metadata
  metadata["merchantAccountingProjection"]=self~eventProjectionApi
  return .AccountingEvent~new(evidence~sourceEventRef,evidence~legalEntityId,.FederationBankMerchantAccountingBuild~FAIR_VALUE_TRANSITION_EVENT_TYPE,evidence~postingDate,evidence~economicRootTradeId,evidence~counterpartyEntity,evidence~sourceAuthority,payload,refs,metadata)

::method accountingEventProjectionForDerivativeFairValueMovement
  use strict arg evidence
  event=self~accountingEventForDerivativeFairValueMovement(evidence)
  if event==.nil then return .nil
  return .AccountingEventCodec~toProjection(event)

::method accountingEventProjectionForDerivativeFairValueTransition
  use strict arg evidence
  event=self~accountingEventForDerivativeFairValueTransition(evidence)
  if event==.nil then return .nil
  return .AccountingEventCodec~toProjection(event)

::method postDerivativeFairValueMovement
  expose merchantEntity engine
  use strict arg evidence
  if evidence==.nil | \evidence~isA(.MBAccountingDerivativeFairValueMovementEvidence) then return .AccountingTransactionResult~failure("MERCHANT_ACCOUNTING_EVIDENCE_REQUIRED","MBAccountingDerivativeFairValueMovementEvidence required")
  if evidence~legalEntityId<>merchantEntity then return .AccountingTransactionResult~failure("MERCHANT_ENTITY_MISMATCH",evidence~legalEntityId || " != " || merchantEntity)
  return engine~transact(self~accountingEventForDerivativeFairValueMovement(evidence))

::method postDerivativeFairValueTransition
  expose merchantEntity engine fairValueTransitionPolicyRef policyArtifactIdentity
  use strict arg evidence
  if evidence==.nil | \evidence~isA(.MBAccountingDerivativeFairValueTransitionEvidence) then return .AccountingTransactionResult~failure("MERCHANT_ACCOUNTING_TRANSITION_EVIDENCE_REQUIRED","MBAccountingDerivativeFairValueTransitionEvidence required")
  if evidence~legalEntityId<>merchantEntity then return .AccountingTransactionResult~failure("MERCHANT_ENTITY_MISMATCH",evidence~legalEntityId || " != " || merchantEntity)
  if evidence~previousMarketValueMinor=evidence~currentMarketValueMinor then return .AccountingTransactionResult~success("NO_CHANGE",.nil,fairValueTransitionPolicyRef,policyArtifactIdentity || "#MBAccountingDerivativeFairValueTransitionPolicy")
  return engine~transact(self~accountingEventForDerivativeFairValueTransition(evidence))

::method accountingEventForSettlementObligation
  use strict arg evidence
  payload=.directory~new
  payload["periodId"]=evidence~periodId
  payload["obligationId"]=evidence~obligationId
  payload["executionId"]=evidence~executionId
  payload["executionType"]=evidence~executionType
  payload["portfolioId"]=evidence~portfolioId
  payload["debtor"]=evidence~debtor
  payload["creditor"]=evidence~creditor
  payload["currency"]=evidence~currency
  payload["amountMinor"]=evidence~amountMinor
  payload["settlementSide"]=evidence~settlementSide
  payload["reason"]=evidence~reason
  refs=evidence~evidenceRefs; refs~append("MERCHANT_SETTLEMENT_OBLIGATION:"||evidence~obligationId); refs~append("MERCHANT_EXECUTION:"||evidence~executionId)
  return .AccountingEvent~new(evidence~sourceEventRef,evidence~legalEntityId,.FederationBankMerchantAccountingBuild~SETTLEMENT_OBLIGATION_EVENT_TYPE,evidence~postingDate,evidence~obligationId,evidence~counterpartyEntity,evidence~sourceAuthority,payload,refs,evidence~metadata)

::method accountingEventForSettlementObservation
  use strict arg evidence
  payload=.directory~new
  payload["periodId"]=evidence~periodId
  payload["settlementEvidenceId"]=evidence~settlementEvidenceId
  payload["obligationId"]=evidence~obligationId
  payload["instructionId"]=evidence~instructionId
  payload["externalSettlementRef"]=evidence~externalSettlementRef
  payload["debtor"]=evidence~debtor
  payload["creditor"]=evidence~creditor
  payload["currency"]=evidence~currency
  payload["amountMinor"]=evidence~amountMinor
  payload["settlementSide"]=evidence~settlementSide
  payload["outcome"]=evidence~outcome
  refs=evidence~evidenceRefs; refs~append("MERCHANT_SETTLEMENT_OBLIGATION:"||evidence~obligationId); refs~append("MERCHANT_SETTLEMENT_OBSERVATION:"||evidence~settlementEvidenceId); refs~append("EXTERNAL_SETTLEMENT:"||evidence~externalSettlementRef)
  return .AccountingEvent~new(evidence~sourceEventRef,evidence~legalEntityId,.FederationBankMerchantAccountingBuild~SETTLEMENT_OBSERVATION_EVENT_TYPE,evidence~postingDate,evidence~obligationId,evidence~counterpartyEntity,evidence~sourceAuthority,payload,refs,evidence~metadata)

::method postSettlementObligation
  expose merchantEntity engine settlementChartReady
  use strict arg evidence
  if evidence==.nil | \evidence~isA(.MBAccountingSettlementObligationEvidence) then return .AccountingTransactionResult~failure("MERCHANT_SETTLEMENT_OBLIGATION_EVIDENCE_REQUIRED","MBAccountingSettlementObligationEvidence required")
  if evidence~legalEntityId<>merchantEntity then return .AccountingTransactionResult~failure("MERCHANT_ENTITY_MISMATCH",evidence~legalEntityId || " != " || merchantEntity)
  if \settlementChartReady then return .AccountingTransactionResult~failure("SETTLEMENT_CHART_UPGRADE_REQUIRED","Recovered pre-v0.4 Merchant accounting chart is sealed without settlement accounts; historical replay remains available but new settlement postings require an explicitly migrated/new book")
  return engine~transact(self~accountingEventForSettlementObligation(evidence))

::method postSettlementInstructionObservation
  expose merchantEntity
  use strict arg observation
  if observation==.nil | \observation~isA(.MBAccountingSettlementInstructionObservation) then return .AccountingTransactionResult~failure("MERCHANT_SETTLEMENT_INSTRUCTION_OBSERVATION_REQUIRED","MBAccountingSettlementInstructionObservation required")
  if observation~legalEntityId<>merchantEntity then return .AccountingTransactionResult~failure("MERCHANT_ENTITY_MISMATCH",observation~legalEntityId || " != " || merchantEntity)
  return .AccountingTransactionResult~failure("SETTLEMENT_COMPLETION_EVIDENCE_REQUIRED","A Merchant settlement instruction proves intent/dispatch only; it does not prove payment, receipt or cash movement")

::method postSettlementObservation
  expose merchantEntity engine settlementChartReady policyArtifactIdentity
  use strict arg evidence
  if evidence==.nil | \evidence~isA(.MBAccountingSettlementObservationEvidence) then return .AccountingTransactionResult~failure("MERCHANT_SETTLEMENT_OBSERVATION_EVIDENCE_REQUIRED","MBAccountingSettlementObservationEvidence required")
  if evidence~legalEntityId<>merchantEntity then return .AccountingTransactionResult~failure("MERCHANT_ENTITY_MISMATCH",evidence~legalEntityId || " != " || merchantEntity)
  if evidence~outcome="FAILED" then return .AccountingTransactionResult~success("NO_POSTING_SETTLEMENT_FAILED",.nil,.FederationBankMerchantAccountingBuild~SETTLEMENT_OBSERVATION_POLICY,policyArtifactIdentity || "#MBAccountingSettlementObservationPolicy")
  if \settlementChartReady then return .AccountingTransactionResult~failure("SETTLEMENT_CHART_UPGRADE_REQUIRED","Recovered pre-v0.4 Merchant accounting chart cannot post settlement events")
  obligationSource="MB:ACCOUNTING:SETTLEMENT_OBLIGATION:"||evidence~obligationId
  obligationEntry=engine~book~sourceEntry(obligationSource)
  if obligationEntry==.nil then return .AccountingTransactionResult~failure("SETTLEMENT_OBLIGATION_NOT_ACCOUNTED",evidence~obligationId)
  event=self~accountingEventForSettlementObservation(evidence)
  if engine~book~sourceEntry(evidence~sourceEventRef)<>.nil then return engine~transact(event)
  binding=self~validateSettlementObservationAgainstBook(evidence,obligationEntry)
  if binding<>"" then return .AccountingTransactionResult~failure("SETTLEMENT_ACCOUNTING_BINDING_MISMATCH",binding)
  return engine~transact(event)

::method validateSettlementObservationAgainstBook private
  expose engine
  use strict arg evidence,obligationEntry
  if obligationEntry~correlationRef<>evidence~obligationId then return "obligation correlation mismatch"
  if obligationEntry~counterpartyEntityId<>evidence~counterpartyEntity then return "obligation counterparty mismatch"
  expectedAccount="1315"; if evidence~settlementSide="PAYABLE" then expectedAccount="2315"
  original=0; found=.false
  do line over obligationEntry~lines
    if line~accountId=expectedAccount & line~currency=evidence~currency then do
      found=.true
      if evidence~settlementSide="RECEIVABLE" then original=original+line~debitMinor-line~creditMinor
      else original=original+line~creditMinor-line~debitMinor
    end
  end
  if \found | original<=0 then return "accounted obligation side/currency mismatch"
  already=0
  do entry over engine~book~entriesByCorrelation(evidence~obligationId)
    if entry~eventType<>.FederationBankMerchantAccountingBuild~SETTLEMENT_OBSERVATION_EVENT_TYPE then iterate
    do line over entry~lines
      if line~accountId<>"1105" | line~currency<>evidence~currency then iterate
      if evidence~settlementSide="RECEIVABLE" then already=already+line~debitMinor
      else already=already+line~creditMinor
    end
  end
  if already+evidence~amountMinor>original then return "observed settlement exceeds accounted obligation: original="||original||" already="||already||" new="||evidence~amountMinor
  return ""

::method postTradeLifecycleObservation
  expose merchantEntity
  use strict arg observation
  if observation==.nil | \observation~isA(.MBAccountingTradeLifecycleObservation) then return .AccountingTransactionResult~failure("MERCHANT_LIFECYCLE_OBSERVATION_REQUIRED","MBAccountingTradeLifecycleObservation required")
  if observation~legalEntityId<>merchantEntity then return .AccountingTransactionResult~failure("MERCHANT_ENTITY_MISMATCH",observation~legalEntityId || " != " || merchantEntity)
  return .AccountingTransactionResult~failure("SETTLEMENT_EVIDENCE_REQUIRED","Merchant lifecycle evidence proves contractual/lifecycle state and realised P&L evidence, but does not itself prove cash, settlement receivable/payable, custody movement or settlement completion")

::method ensureChart private
  expose engine
  chart=engine~book~chart
  base=.array~of("1300","2300","4100","5100")
  settlement=.array~of("1105","1315","1395","2315","2395")
  if chart~isSealed then do
    do id over base
      if \chart~contains(id) then raise syntax 93.900 additional("Recovered Merchant accounting chart missing required account: " || id)
    end
    do id over settlement
      if \chart~contains(id) then return .false
    end
    return .true
  end
  if \chart~contains("1300") then chart~add(.AccountingAccount~new("1300","Derivative assets","ASSET"))
  if \chart~contains("2300") then chart~add(.AccountingAccount~new("2300","Derivative liabilities","LIABILITY"))
  if \chart~contains("4100") then chart~add(.AccountingAccount~new("4100","Derivative fair-value gains","REVENUE"))
  if \chart~contains("5100") then chart~add(.AccountingAccount~new("5100","Derivative fair-value losses","EXPENSE"))
  if \chart~contains("1105") then chart~add(.AccountingAccount~new("1105","Cash at settlement agent","ASSET"))
  if \chart~contains("1315") then chart~add(.AccountingAccount~new("1315","Derivative settlement receivables","ASSET"))
  if \chart~contains("1395") then chart~add(.AccountingAccount~new("1395","Derivative settlement control assets","ASSET"))
  if \chart~contains("2315") then chart~add(.AccountingAccount~new("2315","Derivative settlement payables","LIABILITY"))
  if \chart~contains("2395") then chart~add(.AccountingAccount~new("2395","Derivative settlement control liabilities","LIABILITY"))
  chart~seal
  return .true

::requires "AccountingPersistence.cls"
::requires "AccountingEngine.cls"
