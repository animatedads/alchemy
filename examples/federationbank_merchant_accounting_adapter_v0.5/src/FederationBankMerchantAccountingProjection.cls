/*
 * Merchant v0.15 -> Merchant Accounting scalar projection v0.2.
 *
 * This is the only package component that consumes live Merchant-domain
 * objects. It emits bounded scalar accounting evidence. Accounting posting
 * never calls back into Merchant to mutate contractual/risk state.
 */

::options digits 50

::class FederationBankMerchantAccountingProjectionV1 public

::method api
  return .FederationBankMerchantAccountingBuild~PROJECTION_API

::method projectTradeMarkTransition
  use strict arg merchantBank,trade,currentMark,valuation,scaleEvidence,postingDate,periodId,previousMark=.nil
  self~requireTradeBinding(merchantBank,trade)
  if currentMark==.nil | \currentMark~isA(.MBTradeMark) then raise syntax 93.900 additional("MBTradeMark required")
  if valuation==.nil | \valuation~isA(.MBValuationSnapshot) then raise syntax 93.900 additional("MBValuationSnapshot required")
  if scaleEvidence==.nil | \scaleEvidence~isA(.MBAccountingCurrencyScaleEvidence) then raise syntax 93.900 additional("MBAccountingCurrencyScaleEvidence required")
  if currentMark~tradeId<>trade~tradeId then raise syntax 93.900 additional("trade/current mark identity mismatch")
  if currentMark~currency<>trade~currency then raise syntax 93.900 additional("trade/current mark currency mismatch")
  if valuation~portfolioId<>trade~portfolioId | valuation~currency<>trade~currency then raise syntax 93.900 additional("trade/valuation identity mismatch")
  marketEvidence=merchantBank~marketEvidence(currentMark~marketEvidenceRef)
  if marketEvidence==.nil then raise syntax 93.900 additional("current Merchant mark lacks registered market evidence: " || currentMark~marketEvidenceRef)
  if marketEvidence~currency<>currentMark~currency then raise syntax 93.900 additional("current mark/market evidence currency mismatch")

  previousMinor=0
  previousRef="OPENING_ZERO"
  if previousMark<>.nil then do
    if \previousMark~isA(.MBTradeMark) then raise syntax 93.900 additional("previous MBTradeMark required")
    if previousMark~tradeId<>trade~tradeId | previousMark~currency<>trade~currency then raise syntax 93.900 additional("trade/previous mark identity mismatch")
    previousMinor=scaleEvidence~toMinor(previousMark~marketValue,trade~currency,"previous marketValue")
    previousRef=previousMark~markId
  end
  currentMinor=scaleEvidence~toMinor(currentMark~marketValue,trade~currency,"current marketValue")
  identity=self~deriveAccountingIdentity(merchantBank,trade)

  refs=.array~new
  refs~append("MERCHANT_TRADE:" || trade~tradeId)
  if previousMark<>.nil then refs~append("MERCHANT_MARK:" || previousMark~markId)
  refs~append("MERCHANT_MARK:" || currentMark~markId)
  refs~append("MERCHANT_MARKET_EVIDENCE:" || currentMark~marketEvidenceRef)
  refs~append("MERCHANT_VALUATION:" || valuation~valuationId)
  refs~append("ACCOUNTING_SCALE:" || scaleEvidence~evidenceId)

  metadata=.directory~new
  metadata["projectionApi"]=self~api
  metadata["merchantValuationStatus"]=valuation~valuationStatus
  metadata["merchantValuationAsAt"]=valuation~asAt
  metadata["merchantMarkAsAt"]=currentMark~asAt
  metadata["marketEvidenceSourceAuthority"]=marketEvidence~sourceAuthority
  metadata["marketEvidenceObservedAt"]=marketEvidence~observedAt
  metadata["scaleSourceAuthority"]=scaleEvidence~sourceAuthority
  metadata["scaleSourceRef"]=scaleEvidence~sourceRef

  return .MBAccountingDerivativeFairValueTransitionEvidence~new( -
    "MBACC-FV-" || currentMark~markId,merchantBank~merchantEntity,"MB:ACCOUNTING:FV_TRANSITION:" || currentMark~markId, -
    postingDate,periodId,trade~tradeId,trade~portfolioId,identity["economicRootTradeId"],trade~currency, -
    previousMinor,currentMinor,previousRef,currentMark~markId,valuation~valuationId,currentMark~marketEvidenceRef,scaleEvidence~evidenceId, -
    "FEDERATIONBANK_MERCHANT_BANK:VALUATION_PROJECTION/0.1",identity["closeIntentRef"],trade~counterpartyEntity,identity["contractRole"],refs,metadata)

::method projectTradeLifecycleObservation
  use strict arg merchantBank,trade,lifecycleEvent,scaleEvidence,postingDate,periodId
  self~requireTradeBinding(merchantBank,trade)
  if lifecycleEvent==.nil | \lifecycleEvent~isA(.MBTradeLifecycleEvent) then raise syntax 93.900 additional("MBTradeLifecycleEvent required")
  if scaleEvidence==.nil | \scaleEvidence~isA(.MBAccountingCurrencyScaleEvidence) then raise syntax 93.900 additional("MBAccountingCurrencyScaleEvidence required")
  if lifecycleEvent~tradeId<>trade~tradeId then raise syntax 93.900 additional("trade/lifecycle identity mismatch")
  marketEvidence=merchantBank~marketEvidence(lifecycleEvent~marketEvidenceRef)
  if marketEvidence==.nil then raise syntax 93.900 additional("lifecycle event lacks registered market evidence: " || lifecycleEvent~marketEvidenceRef)
  if marketEvidence~currency<>trade~currency then raise syntax 93.900 additional("trade/lifecycle market evidence currency mismatch")
  realisedMinor=scaleEvidence~toMinor(lifecycleEvent~realisedPnL,trade~currency,"lifecycle realisedPnL")
  identity=self~deriveAccountingIdentity(merchantBank,trade)

  refs=.array~of("MERCHANT_TRADE:" || trade~tradeId,"MERCHANT_LIFECYCLE:" || lifecycleEvent~eventId,"MERCHANT_MARKET_EVIDENCE:" || lifecycleEvent~marketEvidenceRef,"ACCOUNTING_SCALE:" || scaleEvidence~evidenceId)
  metadata=.directory~new
  metadata["projectionApi"]=self~api
  metadata["marketEvidenceSourceAuthority"]=marketEvidence~sourceAuthority
  metadata["marketEvidenceObservedAt"]=marketEvidence~observedAt
  metadata["scaleSourceAuthority"]=scaleEvidence~sourceAuthority
  metadata["scaleSourceRef"]=scaleEvidence~sourceRef

  return .MBAccountingTradeLifecycleObservation~new( -
    "MBACC-LIFE-" || lifecycleEvent~eventId,merchantBank~merchantEntity,"MB:ACCOUNTING:LIFECYCLE:" || lifecycleEvent~eventId,postingDate,periodId, -
    lifecycleEvent~eventId,trade~tradeId,trade~portfolioId,identity["economicRootTradeId"],trade~currency,lifecycleEvent~eventType,lifecycleEvent~effectiveAt, -
    realisedMinor,lifecycleEvent~marketEvidenceRef,lifecycleEvent~authorityRef,scaleEvidence~evidenceId,"FEDERATIONBANK_MERCHANT_BANK:LIFECYCLE_PROJECTION/0.1", -
    identity["closeIntentRef"],trade~counterpartyEntity,identity["contractRole"],refs,metadata)

::method projectSettlementObligation
  use strict arg merchantBank,obligation,scaleEvidence,postingDate,periodId
  self~requireMerchantBank(merchantBank)
  if obligation==.nil | \obligation~isA(.MBSettlementObligation) then raise syntax 93.900 additional("MBSettlementObligation required")
  if merchantBank~settlementObligation(obligation~obligationId)\==obligation then raise syntax 93.900 additional("settlement obligation is not the registered Merchant obligation")
  if scaleEvidence==.nil | \scaleEvidence~isA(.MBAccountingCurrencyScaleEvidence) then raise syntax 93.900 additional("MBAccountingCurrencyScaleEvidence required")
  if obligation~amount<=0 then raise syntax 93.900 additional("zero settlement obligation is not accountable")
  merchant=merchantBank~merchantEntity
  if obligation~debtor=merchant & obligation~creditor=merchant then raise syntax 93.900 additional("Merchant cannot be both settlement debtor and creditor")
  if obligation~debtor<>merchant & obligation~creditor<>merchant then raise syntax 93.900 additional("settlement obligation does not bind Merchant legal entity")

  reason=obligation~reason~string~strip~upper
  execution=.nil; executionType=""
  if reason="DERIVATIVE_CLOSE_OUT" then do
    execution=merchantBank~closeOutExecution(obligation~sourceRef); executionType="CLOSE_OUT"
  end
  else if reason="DERIVATIVE_RISK_NEUTRALISATION" then do
    execution=merchantBank~riskNeutralisationExecution(obligation~sourceRef); executionType="RISK_NEUTRALISATION"
  end
  else raise syntax 93.900 additional("UNSUPPORTED_SETTLEMENT_REASON: " || reason)
  if execution==.nil | execution~state<>"COMPLETE" then raise syntax 93.900 additional("completed Merchant source execution required")
  if execution~currency<>obligation~currency then raise syntax 93.900 additional("execution/obligation currency mismatch")
  signedMinor=scaleEvidence~toMinor(execution~signedNetSettlement,obligation~currency,"execution signedNetSettlement")
  amountMinor=scaleEvidence~toMinor(obligation~amount,obligation~currency,"settlement obligation amount")
  if signedMinor=0 then raise syntax 93.900 additional("zero execution settlement cannot have a settlement obligation")
  if abs(signedMinor)<>amountMinor then raise syntax 93.900 additional("execution/obligation settlement amount mismatch")
  if signedMinor>0 then do
    side="RECEIVABLE"; counterparty=obligation~debtor
    if obligation~creditor<>merchant then raise syntax 93.900 additional("positive execution settlement must make Merchant creditor")
  end
  else do
    side="PAYABLE"; counterparty=obligation~creditor
    if obligation~debtor<>merchant then raise syntax 93.900 additional("negative execution settlement must make Merchant debtor")
  end
  refs=.array~of("MERCHANT_SETTLEMENT_OBLIGATION:"||obligation~obligationId,"MERCHANT_EXECUTION:"||execution~executionId,"ACCOUNTING_SCALE:"||scaleEvidence~evidenceId)
  metadata=.directory~new
  metadata["projectionApi"]=self~api
  metadata["merchantExecutionType"]=executionType
  metadata["merchantExecutionAt"]=execution~executedAt
  metadata["merchantObligationStatus"]=obligation~status
  metadata["scaleSourceAuthority"]=scaleEvidence~sourceAuthority
  metadata["scaleSourceRef"]=scaleEvidence~sourceRef
  return .MBAccountingSettlementObligationEvidence~new( -
    "MBACC-SETTLE-OBL-"||obligation~obligationId,merchant,"MB:ACCOUNTING:SETTLEMENT_OBLIGATION:"||obligation~obligationId,postingDate,periodId, -
    obligation~obligationId,execution~executionId,executionType,execution~portfolioId,obligation~debtor,obligation~creditor,counterparty,obligation~currency,amountMinor,side,reason,execution~authorityRef,refs,metadata)

::method projectSettlementInstructionObservation
  use strict arg merchantBank,instruction,scaleEvidence
  self~requireMerchantBank(merchantBank)
  if instruction==.nil | \instruction~isA(.MBSettlementInstructionEvidence) then raise syntax 93.900 additional("MBSettlementInstructionEvidence required")
  if merchantBank~settlementInstruction(instruction~instructionId)\==instruction then raise syntax 93.900 additional("settlement instruction is not registered Merchant evidence")
  obligation=merchantBank~settlementObligation(instruction~obligationId)
  if obligation==.nil then raise syntax 93.900 additional("instruction lacks registered settlement obligation")
  if scaleEvidence==.nil | \scaleEvidence~isA(.MBAccountingCurrencyScaleEvidence) then raise syntax 93.900 additional("MBAccountingCurrencyScaleEvidence required")
  amountMinor=scaleEvidence~toMinor(instruction~amount,instruction~currency,"settlement instruction amount")
  refs=.array~of("MERCHANT_SETTLEMENT_OBLIGATION:"||obligation~obligationId,"MERCHANT_SETTLEMENT_INSTRUCTION:"||instruction~instructionId,"ACCOUNTING_SCALE:"||scaleEvidence~evidenceId)
  metadata=.directory~new; metadata["projectionApi"]=self~api; metadata["scaleSourceRef"]=scaleEvidence~sourceRef
  return .MBAccountingSettlementInstructionObservation~new("MBACC-SETTLE-INS-"||instruction~instructionId,merchantBank~merchantEntity,obligation~obligationId,instruction~instructionId,instruction~debtor,instruction~creditor,instruction~currency,amountMinor,instruction~settlementChannelRef,instruction~authorityRef,instruction~instructedAt,refs,metadata)

::method projectSettlementObservation
  use strict arg merchantBank,observation,scaleEvidence,postingDate,periodId
  self~requireMerchantBank(merchantBank)
  if observation==.nil | \observation~isA(.MBSettlementObservationEvidence) then raise syntax 93.900 additional("MBSettlementObservationEvidence required")
  if merchantBank~settlementObservation(observation~evidenceId)\==observation then raise syntax 93.900 additional("settlement observation is not registered Merchant evidence")
  obligation=merchantBank~settlementObligation(observation~obligationId)
  instruction=merchantBank~settlementInstruction(observation~instructionId)
  if obligation==.nil | instruction==.nil then raise syntax 93.900 additional("settlement observation lacks Merchant obligation/instruction binding")
  if scaleEvidence==.nil | \scaleEvidence~isA(.MBAccountingCurrencyScaleEvidence) then raise syntax 93.900 additional("MBAccountingCurrencyScaleEvidence required")
  merchant=merchantBank~merchantEntity
  if obligation~creditor=merchant then do; side="RECEIVABLE"; counterparty=obligation~debtor; end
  else if obligation~debtor=merchant then do; side="PAYABLE"; counterparty=obligation~creditor; end
  else raise syntax 93.900 additional("settlement observation obligation does not bind Merchant legal entity")
  amountMinor=scaleEvidence~toMinor(observation~amount,observation~currency,"observed settlement amount")
  refs=.array~of("MERCHANT_SETTLEMENT_OBLIGATION:"||obligation~obligationId,"MERCHANT_SETTLEMENT_INSTRUCTION:"||instruction~instructionId,"MERCHANT_SETTLEMENT_OBSERVATION:"||observation~evidenceId,"EXTERNAL_SETTLEMENT:"||observation~externalSettlementRef,"ACCOUNTING_SCALE:"||scaleEvidence~evidenceId)
  do ref over observation~evidenceRefs; refs~append(ref); end
  metadata=.directory~new
  metadata["projectionApi"]=self~api
  metadata["merchantSettlementObservedAt"]=observation~observedAt
  metadata["merchantObligationStatus"]=obligation~status
  metadata["scaleSourceAuthority"]=scaleEvidence~sourceAuthority
  metadata["scaleSourceRef"]=scaleEvidence~sourceRef
  return .MBAccountingSettlementObservationEvidence~new( -
    "MBACC-SETTLE-OBS-"||observation~evidenceId,merchant,"MB:ACCOUNTING:SETTLEMENT_OBSERVATION:"||observation~evidenceId,postingDate,periodId,observation~evidenceId,obligation~obligationId,instruction~instructionId,observation~externalSettlementRef,observation~debtor,observation~creditor,counterparty,observation~currency,amountMinor,side,observation~outcome,observation~sourceAuthority,refs,metadata)

::method requireMerchantBank private
  use strict arg merchantBank
  if merchantBank==.nil | \merchantBank~isA(.FederationBankMerchantBank) then raise syntax 93.900 additional("FederationBankMerchantBank required")
  return .true

::method requireTradeBinding private
  use strict arg merchantBank,trade
  self~requireMerchantBank(merchantBank)
  if trade==.nil | \trade~isA(.MBDerivativeTrade) then raise syntax 93.900 additional("MBDerivativeTrade required")
  portfolio=merchantBank~portfolio(trade~portfolioId)
  if portfolio==.nil then raise syntax 93.900 additional("trade portfolio is not registered with Merchant Bank")
  registered=portfolio~trade(trade~tradeId)
  if registered==.nil | registered\==trade then raise syntax 93.900 additional("trade object is not the registered Merchant contract")
  return .true

::method deriveAccountingIdentity private
  use strict arg merchantBank,trade
  d=.directory~new
  d["economicRootTradeId"]=trade~tradeId
  d["closeIntentRef"]=""
  if trade~sourceType="CLIENT" then d["contractRole"]="CLIENT_CONTRACT"
  else if trade~sourceType="EXTERNAL_HEDGE" then d["contractRole"]="EXTERNAL_HEDGE"
  else raise syntax 93.900 additional("INTERNAL_HEDGE_ACCOUNTING_POLICY_UNDEFINED: an intra-entity hedge designation is not automatically an externally recognised derivative contract")

  do hedgeId over merchantBank~hedgeIds
    hedge=merchantBank~hedgeRelationship(hedgeId)
    if hedge~offsetTradeId=trade~tradeId then do
      d["economicRootTradeId"]=hedge~originalTradeId
      d["closeIntentRef"]=hedge~intentId
      d["contractRole"]="REVERSING_CONTRACT"
      leave
    end
  end
  return d

::requires "FederationBankMerchantAccountingAdapter.cls"
::requires "FederationBankMerchantBank.cls"
