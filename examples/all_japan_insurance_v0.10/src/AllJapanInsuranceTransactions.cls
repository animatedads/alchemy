/* AllJapanInsuranceTransactions.cls - AJI billing / policy financial transactions v0.10.
 *
 * Policy/rating/claims remain authoritative in AllJapanInsurance. This module
 * owns immutable billing schedules, collection attempts, calculation-backed
 * premium adjustments, cancellation calculations, producer settlements and
 * policyholder refunds. Accounting remains a downstream projection.
 */

::options digits 50

::class AllJapanInsuranceTransactionBuild public
::constant API_VERSION "all.japan.insurance.transactions/0.3"
::constant COLLECTION_COLLECTED "COLLECTED"
::constant COLLECTION_FAILED "FAILED"
::constant ADJUSTMENT_ENDORSEMENT "ENDORSEMENT"
::constant ADJUSTMENT_CANCELLATION "CANCELLATION"
::constant ADJUSTMENT_REINSTATEMENT "REINSTATEMENT"
::constant SALES_PREMIUM_CONTROL "PREMIUM_CONTROL"
::constant SALES_COMMISSION_PAYABLE "COMMISSION_PAYABLE"
::constant CANCELLATION_FUNCTION "AJI.CANCELLATION.COMPONENT_PRORATA_SHORT_RATE/1"
::constant MIDTERM_RERATING_FUNCTION "AJI.MIDTERM.RERATE.PINNED_PROGRAM/1"
::constant REINSTATEMENT_FUNCTION "AJI.REINSTATEMENT.RESTORE_CANCELLATION_RETURN/1"
::constant NON_PAYMENT_REASON "NON_PAYMENT"
::constant BILLING_DEBIT "DEBIT"
::constant BILLING_CREDIT "CREDIT"
::constant BILLING_SOURCE_INITIAL "INITIAL_INSTALMENT"
::constant BILLING_SOURCE_ADJUSTMENT "PREMIUM_ADJUSTMENT"
::constant BILLING_SOURCE_REVISION "SCHEDULE_REVISION"
::constant BILLING_SOURCE_REVERSAL "SCHEDULE_REVERSAL"
::constant BILLING_ALLOCATION_FUNCTION "AJI.BILLING.ALLOCATE.OLDEST_DUE/1"
::constant BILLING_REVISION_FUNCTION "AJI.BILLING.REVISION.REPLACE_OPEN_FUTURE/1"

::class AllJapanInsuranceTransactionMath public
::method signedWhole class
  use arg value
  numeric digits 50
  if value==.nil then return .nil
  signal on syntax name bad
  n=value+0
  signal off syntax
  if n\=n~trunc then return .nil
  return n
bad:
  signal off syntax
  return .nil
::method roundFraction class
  use arg numerator, denominator
  numeric digits 50
  if denominator<=0 | numerator<0 then return .nil
  return (2*numerator+denominator) % (2*denominator)

::class AllJapanInsurancePremiumInstalment public
::attribute instalmentId get
::attribute sequence get
::attribute dueDate get
::attribute amountMinor get
::attribute currency get
::method init
  expose instalmentId sequence dueDate amountMinor currency
  use arg instalmentIdArg,sequenceArg,dueDateArg,amountMinorArg,currencyArg
  instalmentId=instalmentIdArg~string
  sequence=sequenceArg+0
  dueDate=dueDateArg~string
  amountMinor=amountMinorArg+0
  currency=.AllJapanInsuranceCanonical~token(currencyArg)
::method canonicalText
  expose instalmentId sequence dueDate amountMinor currency
  return "AJI-PREMIUM-INSTALMENT/0.1" || '0a'x || -
         "INSTALMENT_ID=" || instalmentId || '0a'x || -
         "SEQUENCE=" || sequence || '0a'x || -
         "DUE_DATE=" || dueDate || '0a'x || -
         "AMOUNT_MINOR=" || amountMinor || '0a'x || -
         "CURRENCY=" || currency || '0a'x

::class AllJapanInsurancePremiumSchedule public
::attribute scheduleId get
::attribute policyId get
::attribute createdAt get
::method init
  expose scheduleId policyId createdAt instalments
  use arg scheduleIdArg,policyIdArg,createdAtArg,instalmentsArg
  scheduleId=scheduleIdArg~string
  policyId=policyIdArg~string
  createdAt=createdAtArg~string
  instalments=.array~new
  if instalmentsArg\==.nil then do item over instalmentsArg; instalments~append(item); end
::method instalments
  expose instalments
  out=.array~new
  do item over instalments; out~append(item); end
  return out
::method totalMinor
  expose instalments
  numeric digits 50
  total=0
  do item over instalments; total+=item~amountMinor; end
  return total
::method canonicalText
  expose scheduleId policyId createdAt instalments
  text="AJI-PREMIUM-SCHEDULE/0.1" || '0a'x || "SCHEDULE_ID=" || scheduleId || '0a'x || "POLICY_ID=" || policyId || '0a'x || "CREATED_AT=" || createdAt || '0a'x
  do item over instalments; text=text || item~canonicalText; end
  return text

::class AllJapanInsurancePremiumCollectionAttempt public
::attribute attemptId get
::attribute policyId get
::attribute instalmentId get
::attribute amountMinor get
::attribute currency get
::attribute attemptedAt get
::attribute outcome get
::attribute paymentRef get
::attribute bankEvidenceRef get
::attribute failureCode get
::method init
  expose attemptId policyId instalmentId amountMinor currency attemptedAt outcome paymentRef bankEvidenceRef failureCode
  use arg attemptIdArg,policyIdArg,instalmentIdArg,amountMinorArg,currencyArg,attemptedAtArg,outcomeArg,paymentRefArg="",bankEvidenceRefArg="",failureCodeArg=""
  attemptId=attemptIdArg~string
  policyId=policyIdArg~string
  instalmentId=instalmentIdArg~string
  amountMinor=amountMinorArg+0
  currency=.AllJapanInsuranceCanonical~token(currencyArg)
  attemptedAt=attemptedAtArg~string
  outcome=.AllJapanInsuranceCanonical~token(outcomeArg)
  paymentRef=paymentRefArg~string
  bankEvidenceRef=bankEvidenceRefArg~string
  failureCode=.AllJapanInsuranceCanonical~token(failureCodeArg)
::method canonicalText
  expose attemptId policyId instalmentId amountMinor currency attemptedAt outcome paymentRef bankEvidenceRef failureCode
  return "AJI-PREMIUM-COLLECTION-ATTEMPT/0.1" || '0a'x || -
         "ATTEMPT_ID=" || attemptId || '0a'x || "POLICY_ID=" || policyId || '0a'x || -
         "INSTALMENT_ID=" || instalmentId || '0a'x || "AMOUNT_MINOR=" || amountMinor || '0a'x || -
         "CURRENCY=" || currency || '0a'x || "ATTEMPTED_AT=" || attemptedAt || '0a'x || -
         "OUTCOME=" || outcome || '0a'x || "PAYMENT_REF=" || paymentRef || '0a'x || -
         "BANK_EVIDENCE_REF=" || bankEvidenceRef || '0a'x || "FAILURE_CODE=" || failureCode || '0a'x


::class AllJapanInsurancePremiumAdjustmentCalculation public
::attribute calculationId get
::attribute policyId get
::attribute transactionType get
::attribute effectiveDate get
::attribute riskDeltaMinor get
::attribute salesDeltaMinor get
::attribute taxDeltaMinor get
::attribute totalDeltaMinor get
::attribute currency get
::attribute ratingFunctionRef get
::attribute calculatedAt get
::attribute evidenceRef get
::method init
  expose calculationId policyId transactionType effectiveDate riskDeltaMinor salesDeltaMinor taxDeltaMinor totalDeltaMinor currency ratingFunctionRef calculatedAt evidenceRef
  use arg calculationIdArg,policyIdArg,transactionTypeArg,effectiveDateArg,riskDeltaArg,salesDeltaArg,taxDeltaArg,totalDeltaArg,currencyArg,ratingFunctionRefArg,calculatedAtArg,evidenceRefArg=""
  calculationId=calculationIdArg~string
  policyId=policyIdArg~string
  transactionType=.AllJapanInsuranceCanonical~token(transactionTypeArg)
  effectiveDate=effectiveDateArg~string
  riskDeltaMinor=riskDeltaArg+0
  salesDeltaMinor=salesDeltaArg+0
  taxDeltaMinor=taxDeltaArg+0
  totalDeltaMinor=totalDeltaArg+0
  currency=.AllJapanInsuranceCanonical~token(currencyArg)
  ratingFunctionRef=ratingFunctionRefArg~string
  calculatedAt=calculatedAtArg~string
  evidenceRef=evidenceRefArg~string
::method canonicalText
  expose calculationId policyId transactionType effectiveDate riskDeltaMinor salesDeltaMinor taxDeltaMinor totalDeltaMinor currency ratingFunctionRef calculatedAt evidenceRef
  return "AJI-PREMIUM-ADJUSTMENT-CALCULATION/0.1|" || calculationId || "|POLICY=" || policyId || "|TYPE=" || transactionType || -
         "|EFFECTIVE=" || effectiveDate || "|RISK_DELTA=" || riskDeltaMinor || "|SALES_DELTA=" || salesDeltaMinor || "|TAX_DELTA=" || taxDeltaMinor || -
         "|TOTAL_DELTA=" || totalDeltaMinor || "|CCY=" || currency || "|FUNCTION=" || ratingFunctionRef || "|CALCULATED_AT=" || calculatedAt || "|EVIDENCE=" || evidenceRef

::class AllJapanInsurancePremiumAdjustment public
::attribute adjustmentId get
::attribute policyId get
::attribute transactionType get
::attribute effectiveDate get
::attribute calculationRef get
::attribute riskDeltaMinor get
::attribute salesDeltaMinor get
::attribute taxDeltaMinor get
::attribute totalDeltaMinor get
::attribute currency get
::attribute salesCostTreatment get
::attribute reasonCode get
::attribute authorizedBy get
::attribute authorizedAt get
::attribute evidenceRef get
::method init
  expose adjustmentId policyId transactionType effectiveDate calculationRef riskDeltaMinor salesDeltaMinor taxDeltaMinor totalDeltaMinor currency salesCostTreatment reasonCode authorizedBy authorizedAt evidenceRef
  use arg adjustmentIdArg,policyIdArg,transactionTypeArg,effectiveDateArg,calculationRefArg,riskDeltaArg,salesDeltaArg,taxDeltaArg,totalDeltaArg,currencyArg,salesTreatmentArg,reasonCodeArg,authorizedByArg,authorizedAtArg,evidenceRefArg=""
  adjustmentId=adjustmentIdArg~string
  policyId=policyIdArg~string
  transactionType=.AllJapanInsuranceCanonical~token(transactionTypeArg)
  effectiveDate=effectiveDateArg~string
  calculationRef=calculationRefArg~string
  riskDeltaMinor=riskDeltaArg+0
  salesDeltaMinor=salesDeltaArg+0
  taxDeltaMinor=taxDeltaArg+0
  totalDeltaMinor=totalDeltaArg+0
  currency=.AllJapanInsuranceCanonical~token(currencyArg)
  salesCostTreatment=.AllJapanInsuranceCanonical~token(salesTreatmentArg)
  reasonCode=.AllJapanInsuranceCanonical~token(reasonCodeArg)
  authorizedBy=authorizedByArg~string
  authorizedAt=authorizedAtArg~string
  evidenceRef=evidenceRefArg~string
::method canonicalText
  expose adjustmentId policyId transactionType effectiveDate calculationRef riskDeltaMinor salesDeltaMinor taxDeltaMinor totalDeltaMinor currency salesCostTreatment reasonCode authorizedBy authorizedAt evidenceRef
  return "AJI-PREMIUM-ADJUSTMENT/0.1" || '0a'x || -
         "ADJUSTMENT_ID=" || adjustmentId || '0a'x || "POLICY_ID=" || policyId || '0a'x || -
         "TRANSACTION_TYPE=" || transactionType || '0a'x || "EFFECTIVE_DATE=" || effectiveDate || '0a'x || -
         "CALCULATION_REF=" || calculationRef || '0a'x || "RISK_DELTA_MINOR=" || riskDeltaMinor || '0a'x || -
         "SALES_DELTA_MINOR=" || salesDeltaMinor || '0a'x || "TAX_DELTA_MINOR=" || taxDeltaMinor || '0a'x || -
         "TOTAL_DELTA_MINOR=" || totalDeltaMinor || '0a'x || "CURRENCY=" || currency || '0a'x || -
         "SALES_COST_TREATMENT=" || salesCostTreatment || '0a'x || "REASON_CODE=" || reasonCode || '0a'x || -
         "AUTHORIZED_BY=" || authorizedBy || '0a'x || "AUTHORIZED_AT=" || authorizedAt || '0a'x || -
         "EVIDENCE_REF=" || evidenceRef || '0a'x

::class AllJapanInsuranceCancellationComponentRule public
::attribute componentCode get
::attribute proratable get
::attribute shortRateNumerator get
::attribute shortRateDenominator get
::method init
  expose componentCode proratable shortRateNumerator shortRateDenominator
  use arg componentCodeArg,proratableArg=.true,shortNumArg=0,shortDenArg=1
  componentCode=.AllJapanInsuranceCanonical~token(componentCodeArg)
  proratable=proratableArg
  shortRateNumerator=shortNumArg+0
  shortRateDenominator=shortDenArg+0
::method calculateReturn
  expose proratable shortRateNumerator shortRateDenominator
  use arg writtenMinor,unearnedNumerator,unearnedDenominator
  numeric digits 50
  if writtenMinor<0 | unearnedNumerator<0 | unearnedDenominator<=0 | unearnedNumerator>unearnedDenominator then return .nil
  if shortRateNumerator<0 | shortRateDenominator<=0 | shortRateNumerator>shortRateDenominator then return .nil
  if \proratable then gross=0
  else gross=.AllJapanInsuranceTransactionMath~roundFraction(writtenMinor*unearnedNumerator,unearnedDenominator)
  retained=.AllJapanInsuranceTransactionMath~roundFraction(gross*shortRateNumerator,shortRateDenominator)
  if gross==.nil | retained==.nil | retained>gross then return .nil
  out=.directory~new
  out["grossReturnMinor"]=gross
  out["shortRateRetainedMinor"]=retained
  out["netReturnMinor"]=gross-retained
  return out
::method canonicalText
  expose componentCode proratable shortRateNumerator shortRateDenominator
  return "AJI-CANCELLATION-COMPONENT-RULE/0.1|" || componentCode || "|PRORATABLE=" || proratable || "|SHORT_RATE=" || shortRateNumerator || "/" || shortRateDenominator

::class AllJapanInsuranceCancellationPlan public
::attribute planRef get
::attribute riskRule get
::attribute salesRule get
::attribute taxRule get
::method init
  expose planRef riskRule salesRule taxRule
  use arg planRefArg,riskRuleArg,salesRuleArg,taxRuleArg
  planRef=planRefArg~string
  riskRule=riskRuleArg
  salesRule=salesRuleArg
  taxRule=taxRuleArg
::method canonicalText
  expose planRef riskRule salesRule taxRule
  return "AJI-CANCELLATION-PLAN/0.1|" || planRef || '0a'x || riskRule~canonicalText || '0a'x || salesRule~canonicalText || '0a'x || taxRule~canonicalText

::class AllJapanInsuranceCancellationCalculation public
::attribute calculationId get
::attribute policyId get
::attribute planRef get
::attribute effectiveDate get
::attribute currency get
::attribute unearnedNumerator get
::attribute unearnedDenominator get
::attribute riskReturnMinor get
::attribute salesReturnMinor get
::attribute taxReturnMinor get
::attribute shortRateRetainedMinor get
::attribute totalReturnMinor get
::attribute calculatedAt get
::attribute functionRef get
::method init
  expose calculationId policyId planRef effectiveDate currency unearnedNumerator unearnedDenominator riskReturnMinor salesReturnMinor taxReturnMinor shortRateRetainedMinor totalReturnMinor calculatedAt functionRef
  use arg calculationIdArg,policyIdArg,planRefArg,effectiveDateArg,currencyArg,unearnedNumArg,unearnedDenArg,riskReturnArg,salesReturnArg,taxReturnArg,retainedArg,totalReturnArg,calculatedAtArg,functionRefArg
  calculationId=calculationIdArg~string
  policyId=policyIdArg~string
  planRef=planRefArg~string
  effectiveDate=effectiveDateArg~string
  currency=.AllJapanInsuranceCanonical~token(currencyArg)
  unearnedNumerator=unearnedNumArg+0
  unearnedDenominator=unearnedDenArg+0
  riskReturnMinor=riskReturnArg+0
  salesReturnMinor=salesReturnArg+0
  taxReturnMinor=taxReturnArg+0
  shortRateRetainedMinor=retainedArg+0
  totalReturnMinor=totalReturnArg+0
  calculatedAt=calculatedAtArg~string
  functionRef=functionRefArg~string
::method canonicalText
  expose calculationId policyId planRef effectiveDate currency unearnedNumerator unearnedDenominator riskReturnMinor salesReturnMinor taxReturnMinor shortRateRetainedMinor totalReturnMinor calculatedAt functionRef
  return "AJI-CANCELLATION-CALCULATION/0.1|" || calculationId || "|POLICY=" || policyId || "|PLAN=" || planRef || -
         "|EFFECTIVE=" || effectiveDate || "|CCY=" || currency || "|UNEARNED=" || unearnedNumerator || "/" || unearnedDenominator || -
         "|RISK_RETURN=" || riskReturnMinor || "|SALES_RETURN=" || salesReturnMinor || "|TAX_RETURN=" || taxReturnMinor || -
         "|SHORT_RATE_RETAINED=" || shortRateRetainedMinor || "|TOTAL_RETURN=" || totalReturnMinor || "|CALCULATED_AT=" || calculatedAt || "|FUNCTION=" || functionRef

::class AllJapanInsuranceCommissionSettlement public
::attribute settlementId get
::attribute policyId get
::attribute producerRef get
::attribute amountMinor get
::attribute currency get
::attribute settledAt get
::attribute paymentRef get
::attribute bankEvidenceRef get
::method init
  expose settlementId policyId producerRef amountMinor currency settledAt paymentRef bankEvidenceRef
  use arg settlementIdArg,policyIdArg,producerRefArg,amountMinorArg,currencyArg,settledAtArg,paymentRefArg,bankEvidenceRefArg
  settlementId=settlementIdArg~string
  policyId=policyIdArg~string
  producerRef=producerRefArg~string
  amountMinor=amountMinorArg+0
  currency=.AllJapanInsuranceCanonical~token(currencyArg)
  settledAt=settledAtArg~string
  paymentRef=paymentRefArg~string
  bankEvidenceRef=bankEvidenceRefArg~string

::class AllJapanInsurancePolicyholderRefund public
::attribute refundId get
::attribute policyId get
::attribute payeeRef get
::attribute amountMinor get
::attribute currency get
::attribute paidAt get
::attribute paymentRef get
::attribute bankEvidenceRef get
::method init
  expose refundId policyId payeeRef amountMinor currency paidAt paymentRef bankEvidenceRef
  use arg refundIdArg,policyIdArg,payeeRefArg,amountMinorArg,currencyArg,paidAtArg,paymentRefArg,bankEvidenceRefArg
  refundId=refundIdArg~string
  policyId=policyIdArg~string
  payeeRef=payeeRefArg~string
  amountMinor=amountMinorArg+0
  currency=.AllJapanInsuranceCanonical~token(currencyArg)
  paidAt=paidAtArg~string
  paymentRef=paymentRefArg~string
  bankEvidenceRef=bankEvidenceRefArg~string

::class AllJapanInsuranceExposureSnapshot public
::attribute snapshotId get
::attribute policyId get
::attribute effectiveFrom get
::attribute programRef get
::attribute ratingFunctionRef get
::attribute totalPremiumMinor get
::attribute currency get
::attribute capturedAt get
::attribute evidenceRef get
::method init
  expose snapshotId policyId effectiveFrom programRef ratingFunctionRef risks totalPremiumMinor currency capturedAt evidenceRef
  use arg snapshotIdArg,policyIdArg,effectiveFromArg,programRefArg,ratingFunctionRefArg,risksArg,totalPremiumMinorArg,currencyArg,capturedAtArg,evidenceRefArg=""
  snapshotId=snapshotIdArg~string
  policyId=policyIdArg~string
  effectiveFrom=effectiveFromArg~string
  programRef=programRefArg~string
  ratingFunctionRef=ratingFunctionRefArg~string
  risks=.array~new
  if risksArg\==.nil then do item over risksArg; risks~append(item); end
  totalPremiumMinor=totalPremiumMinorArg+0
  currency=.AllJapanInsuranceCanonical~token(currencyArg)
  capturedAt=capturedAtArg~string
  evidenceRef=evidenceRefArg~string
::method risks
  expose risks
  out=.array~new
  do item over risks; out~append(item); end
  return out
::method canonicalText
  expose snapshotId policyId effectiveFrom programRef ratingFunctionRef risks totalPremiumMinor currency capturedAt evidenceRef
  out="AJI-EXPOSURE-SNAPSHOT/0.9|" || snapshotId || "|POLICY=" || policyId || "|EFFECTIVE=" || effectiveFrom || "|PROGRAM=" || programRef || "|FUNCTION=" || ratingFunctionRef || "|TOTAL=" || totalPremiumMinor || "|CCY=" || currency || "|CAPTURED=" || capturedAt || "|EVIDENCE=" || evidenceRef
  do risk over risks; out||="|RISK=" || risk~riskRef || risk~canonicalFacts; end
  return out

::class AllJapanInsuranceExposureChange public
::attribute changeId get
::attribute policyId get
::attribute priorSnapshotId get
::attribute effectiveDate get
::attribute remainingNumerator get
::attribute remainingDenominator get
::attribute requestedAt get
::attribute evidenceRef get
::method init
  expose changeId policyId priorSnapshotId effectiveDate newRisks remainingNumerator remainingDenominator requestedAt evidenceRef
  use arg changeIdArg,policyIdArg,priorSnapshotIdArg,effectiveDateArg,newRisksArg,remainingNumeratorArg,remainingDenominatorArg,requestedAtArg,evidenceRefArg=""
  changeId=changeIdArg~string
  policyId=policyIdArg~string
  priorSnapshotId=priorSnapshotIdArg~string
  effectiveDate=effectiveDateArg~string
  newRisks=.array~new
  if newRisksArg\==.nil then do item over newRisksArg; newRisks~append(item); end
  remainingNumerator=remainingNumeratorArg+0
  remainingDenominator=remainingDenominatorArg+0
  requestedAt=requestedAtArg~string
  evidenceRef=evidenceRefArg~string
::method newRisks
  expose newRisks
  out=.array~new
  do item over newRisks; out~append(item); end
  return out

::class AllJapanInsuranceNonPaymentNotice public
::attribute noticeId get
::attribute policyId get
::attribute arrearsAsOfDate get
::attribute cureDeadline get
::attribute arrearsMinor get
::attribute currency get
::attribute issuedAt get
::attribute authorizedBy get
::attribute evidenceRef get
::method init
  expose noticeId policyId arrearsAsOfDate cureDeadline arrearsMinor currency issuedAt authorizedBy evidenceRef
  use arg noticeIdArg,policyIdArg,arrearsAsOfDateArg,cureDeadlineArg,arrearsMinorArg,currencyArg,issuedAtArg,authorizedByArg,evidenceRefArg=""
  noticeId=noticeIdArg~string; policyId=policyIdArg~string; arrearsAsOfDate=arrearsAsOfDateArg~string; cureDeadline=cureDeadlineArg~string
  arrearsMinor=arrearsMinorArg+0; currency=.AllJapanInsuranceCanonical~token(currencyArg); issuedAt=issuedAtArg~string; authorizedBy=authorizedByArg~string; evidenceRef=evidenceRefArg~string

::class AllJapanInsuranceCommissionRecoveryAuthorization public
::attribute recoveryId get
::attribute policyId get
::attribute adjustmentId get
::attribute producerRef get
::attribute amountMinor get
::attribute currency get
::attribute authorizedBy get
::attribute authorizedAt get
::attribute evidenceRef get
::method init
  expose recoveryId policyId adjustmentId producerRef amountMinor currency authorizedBy authorizedAt evidenceRef
  use arg recoveryIdArg,policyIdArg,adjustmentIdArg,producerRefArg,amountMinorArg,currencyArg,authorizedByArg,authorizedAtArg,evidenceRefArg=""
  recoveryId=recoveryIdArg~string; policyId=policyIdArg~string; adjustmentId=adjustmentIdArg~string; producerRef=producerRefArg~string; amountMinor=amountMinorArg+0; currency=.AllJapanInsuranceCanonical~token(currencyArg); authorizedBy=authorizedByArg~string; authorizedAt=authorizedAtArg~string; evidenceRef=evidenceRefArg~string

::class AllJapanInsuranceCommissionRecoveryReceipt public
::attribute receiptId get
::attribute recoveryId get
::attribute policyId get
::attribute producerRef get
::attribute amountMinor get
::attribute currency get
::attribute receivedAt get
::attribute paymentRef get
::attribute bankEvidenceRef get
::method init
  expose receiptId recoveryId policyId producerRef amountMinor currency receivedAt paymentRef bankEvidenceRef
  use arg receiptIdArg,recoveryIdArg,policyIdArg,producerRefArg,amountMinorArg,currencyArg,receivedAtArg,paymentRefArg,bankEvidenceRefArg
  receiptId=receiptIdArg~string; recoveryId=recoveryIdArg~string; policyId=policyIdArg~string; producerRef=producerRefArg~string; amountMinor=amountMinorArg+0; currency=.AllJapanInsuranceCanonical~token(currencyArg); receivedAt=receivedAtArg~string; paymentRef=paymentRefArg~string; bankEvidenceRef=bankEvidenceRefArg~string

::class AllJapanInsuranceTaxRemittance public
::attribute remittanceId get
::attribute policyId get
::attribute taxAuthorityRef get
::attribute amountMinor get
::attribute currency get
::attribute remittedAt get
::attribute paymentRef get
::attribute bankEvidenceRef get
::method init
  expose remittanceId policyId taxAuthorityRef amountMinor currency remittedAt paymentRef bankEvidenceRef
  use arg remittanceIdArg,policyIdArg,taxAuthorityRefArg,amountMinorArg,currencyArg,remittedAtArg,paymentRefArg,bankEvidenceRefArg
  remittanceId=remittanceIdArg~string; policyId=policyIdArg~string; taxAuthorityRef=taxAuthorityRefArg~string; amountMinor=amountMinorArg+0; currency=.AllJapanInsuranceCanonical~token(currencyArg); remittedAt=remittedAtArg~string; paymentRef=paymentRefArg~string; bankEvidenceRef=bankEvidenceRefArg~string

::class AllJapanInsuranceTaxRecoveryAuthorization public
::attribute recoveryId get
::attribute policyId get
::attribute adjustmentId get
::attribute taxAuthorityRef get
::attribute amountMinor get
::attribute currency get
::attribute authorizedBy get
::attribute authorizedAt get
::attribute evidenceRef get
::method init
  expose recoveryId policyId adjustmentId taxAuthorityRef amountMinor currency authorizedBy authorizedAt evidenceRef
  use arg recoveryIdArg,policyIdArg,adjustmentIdArg,taxAuthorityRefArg,amountMinorArg,currencyArg,authorizedByArg,authorizedAtArg,evidenceRefArg=""
  recoveryId=recoveryIdArg~string; policyId=policyIdArg~string; adjustmentId=adjustmentIdArg~string; taxAuthorityRef=taxAuthorityRefArg~string; amountMinor=amountMinorArg+0; currency=.AllJapanInsuranceCanonical~token(currencyArg); authorizedBy=authorizedByArg~string; authorizedAt=authorizedAtArg~string; evidenceRef=evidenceRefArg~string

::class AllJapanInsuranceTaxRecoveryReceipt public
::attribute receiptId get
::attribute recoveryId get
::attribute policyId get
::attribute taxAuthorityRef get
::attribute amountMinor get
::attribute currency get
::attribute receivedAt get
::attribute paymentRef get
::attribute bankEvidenceRef get
::method init
  expose receiptId recoveryId policyId taxAuthorityRef amountMinor currency receivedAt paymentRef bankEvidenceRef
  use arg receiptIdArg,recoveryIdArg,policyIdArg,taxAuthorityRefArg,amountMinorArg,currencyArg,receivedAtArg,paymentRefArg,bankEvidenceRefArg
  receiptId=receiptIdArg~string; recoveryId=recoveryIdArg~string; policyId=policyIdArg~string; taxAuthorityRef=taxAuthorityRefArg~string; amountMinor=amountMinorArg+0; currency=.AllJapanInsuranceCanonical~token(currencyArg); receivedAt=receivedAtArg~string; paymentRef=paymentRefArg~string; bankEvidenceRef=bankEvidenceRefArg~string



::class AllJapanInsuranceBillingItem public
::attribute itemId get
::attribute policyId get
::attribute scheduleVersionRef get
::attribute sourceRef get
::attribute sourceType get
::attribute sequence get
::attribute dueDate get
::attribute direction get
::attribute amountMinor get
::attribute currency get
::attribute createdAt get
::method init
  expose itemId policyId scheduleVersionRef sourceRef sourceType sequence dueDate direction amountMinor currency createdAt
  use arg itemIdArg,policyIdArg,scheduleVersionRefArg,sourceRefArg,sourceTypeArg,sequenceArg,dueDateArg,directionArg,amountMinorArg,currencyArg,createdAtArg
  itemId=itemIdArg~string
  policyId=policyIdArg~string
  scheduleVersionRef=scheduleVersionRefArg~string
  sourceRef=sourceRefArg~string
  sourceType=.AllJapanInsuranceCanonical~token(sourceTypeArg)
  sequence=sequenceArg+0
  dueDate=dueDateArg~string
  direction=.AllJapanInsuranceCanonical~token(directionArg)
  amountMinor=amountMinorArg+0
  currency=.AllJapanInsuranceCanonical~token(currencyArg)
  createdAt=createdAtArg~string
::method canonicalText
  expose itemId policyId scheduleVersionRef sourceRef sourceType sequence dueDate direction amountMinor currency createdAt
  return "AJI-BILLING-ITEM/0.1" || '0a'x || -
         "ITEM_ID=" || itemId || '0a'x || "POLICY_ID=" || policyId || '0a'x || -
         "SCHEDULE_VERSION_REF=" || scheduleVersionRef || '0a'x || "SOURCE_REF=" || sourceRef || '0a'x || -
         "SOURCE_TYPE=" || sourceType || '0a'x || "SEQUENCE=" || sequence || '0a'x || -
         "DUE_DATE=" || dueDate || '0a'x || "DIRECTION=" || direction || '0a'x || -
         "AMOUNT_MINOR=" || amountMinor || '0a'x || "CURRENCY=" || currency || '0a'x || -
         "CREATED_AT=" || createdAt || '0a'x

::class AllJapanInsuranceBillingScheduleRevision public
::attribute revisionId get
::attribute policyId get
::attribute predecessorRef get
::attribute effectiveDate get
::attribute createdAt get
::attribute reasonRef get
::method init
  expose revisionId policyId predecessorRef effectiveDate createdAt reasonRef replaceItemIds replacementItems
  use arg revisionIdArg,policyIdArg,predecessorRefArg,effectiveDateArg,createdAtArg,reasonRefArg,replaceItemIdsArg,replacementItemsArg
  revisionId=revisionIdArg~string
  policyId=policyIdArg~string
  predecessorRef=predecessorRefArg~string
  effectiveDate=effectiveDateArg~string
  createdAt=createdAtArg~string
  reasonRef=reasonRefArg~string
  replaceItemIds=.array~new
  if replaceItemIdsArg\==.nil then do x over replaceItemIdsArg; replaceItemIds~append(x~string); end
  replacementItems=.array~new
  if replacementItemsArg\==.nil then do x over replacementItemsArg; replacementItems~append(x); end
::method replaceItemIds
  expose replaceItemIds
  out=.array~new; do x over replaceItemIds; out~append(x); end; return out
::method replacementItems
  expose replacementItems
  out=.array~new; do x over replacementItems; out~append(x); end; return out
::method canonicalText
  expose revisionId policyId predecessorRef effectiveDate createdAt reasonRef replaceItemIds replacementItems
  text="AJI-BILLING-SCHEDULE-REVISION/0.1" || '0a'x || "REVISION_ID=" || revisionId || '0a'x || "POLICY_ID=" || policyId || '0a'x || -
       "PREDECESSOR_REF=" || predecessorRef || '0a'x || "EFFECTIVE_DATE=" || effectiveDate || '0a'x || "CREATED_AT=" || createdAt || '0a'x || "REASON_REF=" || reasonRef || '0a'x
  do x over replaceItemIds; text=text || "REPLACE=" || x || '0a'x; end
  do x over replacementItems; text=text || x~canonicalText; end
  return text

::class AllJapanInsuranceBillingReceipt public
::attribute receiptId get
::attribute policyId get
::attribute payerRef get
::attribute amountMinor get
::attribute currency get
::attribute receivedAt get
::attribute paymentRef get
::attribute bankEvidenceRef get
::method init
  expose receiptId policyId payerRef amountMinor currency receivedAt paymentRef bankEvidenceRef
  use arg receiptIdArg,policyIdArg,payerRefArg,amountMinorArg,currencyArg,receivedAtArg,paymentRefArg,bankEvidenceRefArg
  receiptId=receiptIdArg~string
  policyId=policyIdArg~string
  payerRef=payerRefArg~string
  amountMinor=amountMinorArg+0
  currency=.AllJapanInsuranceCanonical~token(currencyArg)
  receivedAt=receivedAtArg~string
  paymentRef=paymentRefArg~string
  bankEvidenceRef=bankEvidenceRefArg~string
::method canonicalText
  expose receiptId policyId payerRef amountMinor currency receivedAt paymentRef bankEvidenceRef
  return "AJI-BILLING-RECEIPT/0.1|" || receiptId || "|POLICY=" || policyId || "|PAYER=" || payerRef || "|AMOUNT=" || amountMinor || "|CCY=" || currency || -
         "|RECEIVED_AT=" || receivedAt || "|PAYMENT_REF=" || paymentRef || "|BANK_EVIDENCE=" || bankEvidenceRef

::class AllJapanInsuranceBillingAllocation public
::attribute allocationId get
::attribute policyId get
::attribute sourceKind get
::attribute sourceRef get
::attribute targetItemId get
::attribute amountMinor get
::attribute allocatedAt get
::attribute functionRef get
::method init
  expose allocationId policyId sourceKind sourceRef targetItemId amountMinor allocatedAt functionRef
  use arg allocationIdArg,policyIdArg,sourceKindArg,sourceRefArg,targetItemIdArg,amountMinorArg,allocatedAtArg,functionRefArg
  allocationId=allocationIdArg~string
  policyId=policyIdArg~string
  sourceKind=.AllJapanInsuranceCanonical~token(sourceKindArg)
  sourceRef=sourceRefArg~string
  targetItemId=targetItemIdArg~string
  amountMinor=amountMinorArg+0
  allocatedAt=allocatedAtArg~string
  functionRef=functionRefArg~string
::method canonicalText
  expose allocationId policyId sourceKind sourceRef targetItemId amountMinor allocatedAt functionRef
  return "AJI-BILLING-ALLOCATION/0.1|" || allocationId || "|POLICY=" || policyId || "|SOURCE_KIND=" || sourceKind || "|SOURCE_REF=" || sourceRef || -
         "|TARGET=" || targetItemId || "|AMOUNT=" || amountMinor || "|ALLOCATED_AT=" || allocatedAt || "|FUNCTION=" || functionRef

::class AllJapanInsuranceTransactionAuthority public
::attribute authority get
::method init
  expose authority productRatingBook schedules instalments attempts adjustmentCalculations adjustments cancellationPlans cancellationCalculations commissionSettlements refunds exposureSnapshots currentExposure exposureChanges reratingEvidence nonPaymentNotices commissionRecoveries commissionRecoveryByAdjustment commissionRecoveryReceipts taxRemittances taxRecoveries taxRecoveryByAdjustment taxRecoveryReceipts billingItems billingItemByInstalment billingScheduleRevisions currentBillingSchedule billingReceipts billingAllocations billingReceiptInitialApplied
  use arg authorityArg,productRatingBookArg=.nil
  authority=authorityArg
  productRatingBook=productRatingBookArg
  schedules=.table~new
  instalments=.table~new
  attempts=.table~new
  adjustmentCalculations=.table~new
  adjustments=.table~new
  cancellationPlans=.table~new
  cancellationCalculations=.table~new
  commissionSettlements=.table~new
  refunds=.table~new
  exposureSnapshots=.table~new
  currentExposure=.table~new
  exposureChanges=.table~new
  reratingEvidence=.table~new
  nonPaymentNotices=.table~new
  commissionRecoveries=.table~new
  commissionRecoveryByAdjustment=.table~new
  commissionRecoveryReceipts=.table~new
  taxRemittances=.table~new
  taxRecoveries=.table~new
  taxRecoveryByAdjustment=.table~new
  taxRecoveryReceipts=.table~new
  billingItems=.table~new
  billingItemByInstalment=.table~new
  billingScheduleRevisions=.table~new
  currentBillingSchedule=.table~new
  billingReceipts=.table~new
  billingAllocations=.table~new
  billingReceiptInitialApplied=.table~new
::method requireRole private
  use arg actor,role
  if actor==.nil then return .AllJapanInsuranceResult~failure("AUTHORITY_REQUIRED",role)
  if \actor~hasRole(role) then return .AllJapanInsuranceResult~failure("AUTHORITY_DENIED",role)
  return .AllJapanInsuranceResult~success
::method schedule
  expose schedules
  use arg policyIdArg
  return schedules[policyIdArg~string]
::method instalment
  expose instalments
  use arg instalmentIdArg
  return instalments[instalmentIdArg~string]
::method collectionAttempt
  expose attempts
  use arg attemptIdArg
  return attempts[attemptIdArg~string]
::method adjustmentCalculation
  expose adjustmentCalculations
  use arg calculationIdArg
  return adjustmentCalculations[calculationIdArg~string]
::method premiumAdjustment
  expose adjustments
  use arg adjustmentIdArg
  return adjustments[adjustmentIdArg~string]
::method cancellationPlan
  expose cancellationPlans
  use arg planRefArg
  return cancellationPlans[planRefArg~string]
::method registerCancellationPlan
  expose cancellationPlans
  use arg actor,plan
  auth=self~requireRole(actor,.AllJapanInsuranceBuild~ROLE_POLICY_TRANSACTION)
  if \auth~ok then return auth
  if plan==.nil | plan~planRef="" then return .AllJapanInsuranceResult~failure("CANCELLATION_PLAN_REQUIRED")
  existing=cancellationPlans[plan~planRef]
  if existing\==.nil then do
    if existing~canonicalText=plan~canonicalText then return .AllJapanInsuranceResult~failure("CANCELLATION_PLAN_DUPLICATE",plan~planRef)
    return .AllJapanInsuranceResult~failure("CANCELLATION_PLAN_IDENTITY_CONFLICT",plan~planRef)
  end
  cancellationPlans[plan~planRef]=plan
  return .AllJapanInsuranceResult~success(plan)
::method cancellationCalculation
  expose cancellationCalculations
  use arg calculationIdArg
  return cancellationCalculations[calculationIdArg~string]
::method commissionSettlement
  expose commissionSettlements
  use arg settlementIdArg
  return commissionSettlements[settlementIdArg~string]
::method policyholderRefund
  expose refunds
  use arg refundIdArg
  return refunds[refundIdArg~string]
::method registerInitialSchedule
  expose authority schedules instalments billingItems billingItemByInstalment currentBillingSchedule
  use arg actor,schedule
  auth=self~requireRole(actor,.AllJapanInsuranceBuild~ROLE_PREMIUM_BILLING)
  if \auth~ok then return auth
  if authority==.nil then return .AllJapanInsuranceResult~failure("INSURANCE_AUTHORITY_REQUIRED")
  if schedule==.nil | schedule~scheduleId="" | schedule~policyId="" | schedule~createdAt="" then return .AllJapanInsuranceResult~failure("PREMIUM_SCHEDULE_IDENTITY_REQUIRED")
  if schedules~hasIndex(schedule~policyId) then return .AllJapanInsuranceResult~failure("PREMIUM_SCHEDULE_ALREADY_EXISTS",schedule~policyId)
  policy=authority~policy(schedule~policyId)
  if policy==.nil then return .AllJapanInsuranceResult~failure("POLICY_NOT_FOUND",schedule~policyId)
  quote=authority~quote(policy~quoteId)
  if quote==.nil then return .AllJapanInsuranceResult~failure("QUOTE_NOT_FOUND",policy~quoteId)
  if schedule~instalments~items=0 then return .AllJapanInsuranceResult~failure("PREMIUM_SCHEDULE_EMPTY")
  seenSequence=.set~new
  total=0
  do item over schedule~instalments
    if item==.nil | item~instalmentId="" | item~dueDate="" then return .AllJapanInsuranceResult~failure("PREMIUM_INSTALMENT_IDENTITY_REQUIRED")
    if instalments~hasIndex(item~instalmentId) then return .AllJapanInsuranceResult~failure("PREMIUM_INSTALMENT_DUPLICATE",item~instalmentId)
    if item~sequence<1 | item~sequence\=item~sequence~trunc | seenSequence~hasIndex(item~sequence) then return .AllJapanInsuranceResult~failure("PREMIUM_INSTALMENT_SEQUENCE_INVALID",item~sequence)
    seenSequence~put(item~sequence)
    if item~currency\=quote~currency then return .AllJapanInsuranceResult~failure("PREMIUM_INSTALMENT_CURRENCY_MISMATCH",item~currency)
    money=.AllJapanInsuranceCurrency~validateMinorAmount(item~currency,item~amountMinor)
    if \money~ok | item~amountMinor=0 then return .AllJapanInsuranceResult~failure("PREMIUM_INSTALMENT_AMOUNT_INVALID",item~instalmentId)
    if item~dueDate<policy~inceptionDate | item~dueDate>policy~expiryDate then return .AllJapanInsuranceResult~failure("PREMIUM_INSTALMENT_DUE_DATE_INVALID",item~dueDate)
    total+=item~amountMinor
  end
  if total\=quote~premiumMinor then return .AllJapanInsuranceResult~failure("PREMIUM_SCHEDULE_TOTAL_MISMATCH",total)
  schedules[schedule~policyId]=schedule
  versionRef="INITIAL:" || schedule~scheduleId
  currentBillingSchedule[schedule~policyId]=versionRef
  do item over schedule~instalments
    instalments[item~instalmentId]=item
    billingId="INSTALMENT:" || item~instalmentId
    b=.AllJapanInsuranceBillingItem~new(billingId,schedule~policyId,versionRef,item~instalmentId,.AllJapanInsuranceTransactionBuild~BILLING_SOURCE_INITIAL,item~sequence,item~dueDate,.AllJapanInsuranceTransactionBuild~BILLING_DEBIT,item~amountMinor,item~currency,schedule~createdAt)
    billingItems[billingId]=b
    billingItemByInstalment[item~instalmentId]=billingId
  end
  return .AllJapanInsuranceResult~success(schedule)
::method collectedForInstalment
  expose attempts
  use arg instalmentIdArg
  numeric digits 50
  total=0
  do attempt over attempts~allItems
    if attempt~instalmentId=instalmentIdArg~string & attempt~outcome=.AllJapanInsuranceTransactionBuild~COLLECTION_COLLECTED then total+=attempt~amountMinor
  end
  return total
::method outstandingForInstalment
  expose instalments billingItemByInstalment
  use arg instalmentIdArg
  item=instalments[instalmentIdArg~string]
  if item==.nil then return .nil
  billingId=billingItemByInstalment[item~instalmentId]
  if billingId\==.nil then return self~billingOpenDebitMinor(billingId)
  return item~amountMinor-self~collectedForInstalment(item~instalmentId)
::method recordCollectionAttempt
  expose authority schedules instalments attempts billingReceipts billingItemByInstalment billingReceiptInitialApplied
  use arg actor,attempt
  auth=self~requireRole(actor,.AllJapanInsuranceBuild~ROLE_PREMIUM_BILLING)
  if \auth~ok then return auth
  if attempt==.nil then return .AllJapanInsuranceResult~failure("PREMIUM_COLLECTION_ATTEMPT_REQUIRED")
  if attempt~attemptId="" | attempt~policyId="" | attempt~instalmentId="" | attempt~attemptedAt="" then return .AllJapanInsuranceResult~failure("PREMIUM_COLLECTION_ATTEMPT_IDENTITY_REQUIRED")
  if attempts~hasIndex(attempt~attemptId) then return .AllJapanInsuranceResult~failure("PREMIUM_COLLECTION_ATTEMPT_DUPLICATE",attempt~attemptId)
  policy=authority~policy(attempt~policyId)
  if policy==.nil then return .AllJapanInsuranceResult~failure("POLICY_NOT_FOUND",attempt~policyId)
  schedule=schedules[attempt~policyId]
  if schedule==.nil then return .AllJapanInsuranceResult~failure("PREMIUM_SCHEDULE_NOT_FOUND",attempt~policyId)
  item=instalments[attempt~instalmentId]
  if item==.nil then return .AllJapanInsuranceResult~failure("PREMIUM_INSTALMENT_NOT_FOUND",attempt~instalmentId)
  if attempt~currency\=item~currency then return .AllJapanInsuranceResult~failure("PREMIUM_COLLECTION_CURRENCY_MISMATCH",attempt~currency)
  money=.AllJapanInsuranceCurrency~validateMinorAmount(attempt~currency,attempt~amountMinor)
  if \money~ok | attempt~amountMinor=0 then return .AllJapanInsuranceResult~failure("PREMIUM_COLLECTION_AMOUNT_INVALID")
  outstanding=self~outstandingForInstalment(item~instalmentId)
  if attempt~amountMinor>outstanding then return .AllJapanInsuranceResult~failure("PREMIUM_COLLECTION_EXCEEDS_INSTALMENT",outstanding)
  if attempt~outcome=.AllJapanInsuranceTransactionBuild~COLLECTION_COLLECTED then do
    if attempt~paymentRef="" | attempt~bankEvidenceRef="" then return .AllJapanInsuranceResult~failure("PREMIUM_COLLECTION_BANK_EVIDENCE_REQUIRED")
    if attempt~failureCode\="" then return .AllJapanInsuranceResult~failure("PREMIUM_COLLECTION_SUCCESS_FAILURE_CODE_INVALID")
  end
  else if attempt~outcome=.AllJapanInsuranceTransactionBuild~COLLECTION_FAILED then do
    if attempt~failureCode="" | attempt~bankEvidenceRef="" then return .AllJapanInsuranceResult~failure("PREMIUM_COLLECTION_FAILURE_EVIDENCE_REQUIRED")
    if attempt~paymentRef\="" then return .AllJapanInsuranceResult~failure("PREMIUM_COLLECTION_FAILED_PAYMENT_REF_INVALID")
  end
  else return .AllJapanInsuranceResult~failure("PREMIUM_COLLECTION_OUTCOME_INVALID",attempt~outcome)
  attempts[attempt~attemptId]=attempt
  if attempt~outcome=.AllJapanInsuranceTransactionBuild~COLLECTION_COLLECTED then do
    receiptId="ATTEMPT:" || attempt~attemptId
    receipt=.AllJapanInsuranceBillingReceipt~new(receiptId,attempt~policyId,policy~partyRef,attempt~amountMinor,attempt~currency,attempt~attemptedAt,attempt~paymentRef,attempt~bankEvidenceRef)
    billingReceipts[receiptId]=receipt
    target=billingItemByInstalment[attempt~instalmentId]
    ignored=self~allocateBillingSourceToTarget("RECEIPT",receiptId,target,attempt~amountMinor,attempt~attemptedAt)
    billingReceiptInitialApplied[receiptId]=attempt~amountMinor
  end
  return .AllJapanInsuranceResult~success(attempt)
::method arrearsAsOf
  use arg policyIdArg,asOfDateArg
  return self~billingArrearsAsOf(policyIdArg,asOfDateArg)

::method recordAdjustmentCalculation
  expose authority adjustmentCalculations
  use arg actor,calculation
  auth=self~requireRole(actor,.AllJapanInsuranceBuild~ROLE_RATING_ENGINE)
  if \auth~ok then return auth
  if calculation==.nil | calculation~calculationId="" | calculation~policyId="" | calculation~effectiveDate="" | calculation~calculatedAt="" then return .AllJapanInsuranceResult~failure("PREMIUM_ADJUSTMENT_CALCULATION_IDENTITY_REQUIRED")
  if calculation~ratingFunctionRef="" | calculation~evidenceRef="" then return .AllJapanInsuranceResult~failure("PREMIUM_ADJUSTMENT_CALCULATION_EVIDENCE_REQUIRED")
  if adjustmentCalculations~hasIndex(calculation~calculationId) then return .AllJapanInsuranceResult~failure("PREMIUM_ADJUSTMENT_CALCULATION_DUPLICATE",calculation~calculationId)
  if calculation~transactionType\=.AllJapanInsuranceTransactionBuild~ADJUSTMENT_ENDORSEMENT & calculation~transactionType\=.AllJapanInsuranceTransactionBuild~ADJUSTMENT_REINSTATEMENT then return .AllJapanInsuranceResult~failure("PREMIUM_ADJUSTMENT_CALCULATION_TYPE_INVALID",calculation~transactionType)
  r=.AllJapanInsuranceTransactionMath~signedWhole(calculation~riskDeltaMinor)
  s=.AllJapanInsuranceTransactionMath~signedWhole(calculation~salesDeltaMinor)
  t=.AllJapanInsuranceTransactionMath~signedWhole(calculation~taxDeltaMinor)
  total=.AllJapanInsuranceTransactionMath~signedWhole(calculation~totalDeltaMinor)
  if r==.nil | s==.nil | t==.nil | total==.nil | total=0 | r+s+t\=total then return .AllJapanInsuranceResult~failure("PREMIUM_ADJUSTMENT_CALCULATION_AMOUNT_INVALID")
  policy=authority~policy(calculation~policyId)
  if policy==.nil then return .AllJapanInsuranceResult~failure("POLICY_NOT_FOUND",calculation~policyId)
  quote=authority~quote(policy~quoteId)
  if quote==.nil | calculation~currency\=quote~currency then return .AllJapanInsuranceResult~failure("PREMIUM_ADJUSTMENT_CALCULATION_CURRENCY_MISMATCH",calculation~currency)
  if calculation~effectiveDate<policy~inceptionDate | calculation~effectiveDate>=policy~expiryDate then return .AllJapanInsuranceResult~failure("PREMIUM_ADJUSTMENT_CALCULATION_EFFECTIVE_DATE_INVALID",calculation~effectiveDate)
  if calculation~transactionType=.AllJapanInsuranceTransactionBuild~ADJUSTMENT_ENDORSEMENT then do
    if calculation~ratingFunctionRef\=quote~ratingFunctionRef then return .AllJapanInsuranceResult~failure("PREMIUM_ADJUSTMENT_CALCULATION_FUNCTION_MISMATCH",calculation~ratingFunctionRef)
  end
  else if calculation~ratingFunctionRef\=.AllJapanInsuranceTransactionBuild~REINSTATEMENT_FUNCTION then return .AllJapanInsuranceResult~failure("PREMIUM_REINSTATEMENT_CALCULATION_FUNCTION_MISMATCH",calculation~ratingFunctionRef)
  adjustmentCalculations[calculation~calculationId]=calculation
  return .AllJapanInsuranceResult~success(calculation)
::method validateAdjustment private
  expose authority adjustmentCalculations adjustments cancellationCalculations
  use arg actor,adjustment,allowCancellation=.false,allowReinstatement=.false
  if adjustment==.nil then return .AllJapanInsuranceResult~failure("PREMIUM_ADJUSTMENT_REQUIRED")
  if adjustment~adjustmentId="" | adjustment~policyId="" | adjustment~effectiveDate="" | adjustment~calculationRef="" then return .AllJapanInsuranceResult~failure("PREMIUM_ADJUSTMENT_IDENTITY_REQUIRED")
  if adjustment~reasonCode="" | adjustment~authorizedBy="" | adjustment~authorizedAt="" | adjustment~evidenceRef="" then return .AllJapanInsuranceResult~failure("PREMIUM_ADJUSTMENT_EVIDENCE_REQUIRED")
  if adjustment~authorizedBy\=actor~principalId then return .AllJapanInsuranceResult~failure("PREMIUM_ADJUSTMENT_AUTHORITY_MISMATCH",adjustment~authorizedBy)
  if adjustments~hasIndex(adjustment~adjustmentId) then return .AllJapanInsuranceResult~failure("PREMIUM_ADJUSTMENT_DUPLICATE",adjustment~adjustmentId)
  if adjustment~transactionType=.AllJapanInsuranceTransactionBuild~ADJUSTMENT_CANCELLATION & \allowCancellation then return .AllJapanInsuranceResult~failure("PREMIUM_CANCELLATION_REQUIRES_CANCELLATION_RECORD")
  if adjustment~transactionType=.AllJapanInsuranceTransactionBuild~ADJUSTMENT_REINSTATEMENT & \allowReinstatement then return .AllJapanInsuranceResult~failure("PREMIUM_REINSTATEMENT_REQUIRES_REINSTATEMENT_RECORD")
  if adjustment~transactionType\=.AllJapanInsuranceTransactionBuild~ADJUSTMENT_ENDORSEMENT & adjustment~transactionType\=.AllJapanInsuranceTransactionBuild~ADJUSTMENT_CANCELLATION & adjustment~transactionType\=.AllJapanInsuranceTransactionBuild~ADJUSTMENT_REINSTATEMENT then return .AllJapanInsuranceResult~failure("PREMIUM_ADJUSTMENT_TYPE_INVALID",adjustment~transactionType)
  if adjustment~transactionType=.AllJapanInsuranceTransactionBuild~ADJUSTMENT_ENDORSEMENT | adjustment~transactionType=.AllJapanInsuranceTransactionBuild~ADJUSTMENT_REINSTATEMENT then do
    calc=adjustmentCalculations[adjustment~calculationRef]
    if calc==.nil then return .AllJapanInsuranceResult~failure("PREMIUM_ADJUSTMENT_CALCULATION_NOT_FOUND",adjustment~calculationRef)
    if calc~policyId\=adjustment~policyId | calc~effectiveDate\=adjustment~effectiveDate | calc~currency\=adjustment~currency then return .AllJapanInsuranceResult~failure("PREMIUM_ADJUSTMENT_CALCULATION_MISMATCH",calc~calculationId)
    if calc~riskDeltaMinor\=adjustment~riskDeltaMinor | calc~salesDeltaMinor\=adjustment~salesDeltaMinor | calc~taxDeltaMinor\=adjustment~taxDeltaMinor | calc~totalDeltaMinor\=adjustment~totalDeltaMinor then return .AllJapanInsuranceResult~failure("PREMIUM_ADJUSTMENT_CALCULATION_AMOUNT_MISMATCH",calc~calculationId)
  end
  r=.AllJapanInsuranceTransactionMath~signedWhole(adjustment~riskDeltaMinor)
  s=.AllJapanInsuranceTransactionMath~signedWhole(adjustment~salesDeltaMinor)
  t=.AllJapanInsuranceTransactionMath~signedWhole(adjustment~taxDeltaMinor)
  total=.AllJapanInsuranceTransactionMath~signedWhole(adjustment~totalDeltaMinor)
  if r==.nil | s==.nil | t==.nil | total==.nil | total=0 then return .AllJapanInsuranceResult~failure("PREMIUM_ADJUSTMENT_AMOUNT_INVALID")
  if r+s+t\=total then return .AllJapanInsuranceResult~failure("PREMIUM_ADJUSTMENT_COMPONENTS_UNBALANCED")
  treatment=adjustment~salesCostTreatment
  if treatment\=.AllJapanInsuranceTransactionBuild~SALES_PREMIUM_CONTROL & treatment\=.AllJapanInsuranceTransactionBuild~SALES_COMMISSION_PAYABLE then return .AllJapanInsuranceResult~failure("PREMIUM_ADJUSTMENT_SALES_TREATMENT_INVALID",treatment)
  policy=authority~policy(adjustment~policyId)
  if policy==.nil then return .AllJapanInsuranceResult~failure("POLICY_NOT_FOUND",adjustment~policyId)
  quote=authority~quote(policy~quoteId)
  if quote==.nil then return .AllJapanInsuranceResult~failure("QUOTE_NOT_FOUND",policy~quoteId)
  if adjustment~currency\=quote~currency then return .AllJapanInsuranceResult~failure("PREMIUM_ADJUSTMENT_CURRENCY_MISMATCH",adjustment~currency)
  if adjustment~effectiveDate<policy~inceptionDate | adjustment~effectiveDate>=policy~expiryDate then return .AllJapanInsuranceResult~failure("PREMIUM_ADJUSTMENT_EFFECTIVE_DATE_INVALID",adjustment~effectiveDate)
  cancellation=authority~policyCancellation(policy~policyId)
  if cancellation\==.nil then do
    if adjustment~effectiveDate>=cancellation~effectiveDate & adjustment~transactionType\=.AllJapanInsuranceTransactionBuild~ADJUSTMENT_CANCELLATION & adjustment~transactionType\=.AllJapanInsuranceTransactionBuild~ADJUSTMENT_REINSTATEMENT then return .AllJapanInsuranceResult~failure("PREMIUM_ADJUSTMENT_AFTER_CANCELLATION",cancellation~effectiveDate)
  end
  return .AllJapanInsuranceResult~success(adjustment)
::method recordPremiumAdjustment
  expose adjustments reratingEvidence exposureSnapshots currentExposure
  use arg actor,adjustment
  auth=self~requireRole(actor,.AllJapanInsuranceBuild~ROLE_POLICY_TRANSACTION)
  if \auth~ok then return auth
  if adjustment\==.nil then do
    if adjustment~transactionType=.AllJapanInsuranceTransactionBuild~ADJUSTMENT_REINSTATEMENT then return .AllJapanInsuranceResult~failure("PREMIUM_REINSTATEMENT_REQUIRES_REINSTATEMENT_RECORD")
  end
  valid=self~validateAdjustment(actor,adjustment,.false,.false)
  if \valid~ok then return valid
  adjustments[adjustment~adjustmentId]=adjustment
  if reratingEvidence~hasIndex(adjustment~calculationRef) then do
    ev=reratingEvidence[adjustment~calculationRef]
    after=ev["afterRating"]
    change=ev["change"]
    prior=currentExposure[adjustment~policyId]
    writtenAfter=after~totalPremiumMinor
    if prior\==.nil then writtenAfter=prior~totalPremiumMinor+adjustment~totalDeltaMinor
    snap=.AllJapanInsuranceExposureSnapshot~new("EXPOSURE:" || adjustment~adjustmentId,adjustment~policyId,adjustment~effectiveDate,after~planRef,after~ratingFunctionRef,change~newRisks,writtenAfter,after~currency,adjustment~authorizedAt,adjustment~evidenceRef)
    exposureSnapshots[snap~snapshotId]=snap
    currentExposure[adjustment~policyId]=snap
  end
  return .AllJapanInsuranceResult~success(adjustment)
::method currentWrittenComponents
  expose authority adjustments
  use arg policyIdArg
  numeric digits 50
  policy=authority~policy(policyIdArg)
  if policy==.nil then return .AllJapanInsuranceResult~failure("POLICY_NOT_FOUND",policyIdArg)
  quote=authority~quote(policy~quoteId)
  if quote==.nil then return .AllJapanInsuranceResult~failure("QUOTE_NOT_FOUND",policy~quoteId)
  rating=authority~rating(quote~ratingId)
  if rating==.nil then return .AllJapanInsuranceResult~failure("RATING_NOT_FOUND",quote~ratingId)
  sales=0; tax=0
  do cost over rating~costs
    if cost~code=.AllJapanInsuranceRatingBuild~COST_SALES then sales+=cost~amountMinor
    else if cost~code~length>=4 & cost~code~substr(1,4)="TAX_" then tax+=cost~amountMinor
  end
  risk=rating~totalPremiumMinor-sales-tax
  do adj over adjustments~allItems
    if adj~policyId\=policy~policyId then iterate
    risk+=adj~riskDeltaMinor
    sales+=adj~salesDeltaMinor
    tax+=adj~taxDeltaMinor
  end
  if risk<0 | sales<0 | tax<0 then return .AllJapanInsuranceResult~failure("WRITTEN_PREMIUM_COMPONENT_NEGATIVE",policy~policyId)
  out=.directory~new
  out["riskPremiumMinor"]=risk
  out["salesCostMinor"]=sales
  out["taxMinor"]=tax
  out["totalPremiumMinor"]=risk+sales+tax
  out["currency"]=quote~currency
  return .AllJapanInsuranceResult~success(out)
::method calculateCancellation
  expose cancellationPlans cancellationCalculations
  use arg calculationIdArg,policyIdArg,effectiveDateArg,unearnedNumeratorArg,unearnedDenominatorArg,planRefArg,calculatedAtArg
  if calculationIdArg~string="" | calculatedAtArg~string="" | planRefArg~string="" then return .AllJapanInsuranceResult~failure("CANCELLATION_CALCULATION_CONTEXT_REQUIRED")
  if cancellationCalculations~hasIndex(calculationIdArg~string) then return .AllJapanInsuranceResult~failure("CANCELLATION_CALCULATION_DUPLICATE",calculationIdArg)
  plan=cancellationPlans[planRefArg~string]
  if plan==.nil then return .AllJapanInsuranceResult~failure("CANCELLATION_PLAN_NOT_FOUND",planRefArg)
  position=self~currentWrittenComponents(policyIdArg)
  if \position~ok then return position
  parts=position~value
  rr=plan~riskRule~calculateReturn(parts["riskPremiumMinor"],unearnedNumeratorArg,unearnedDenominatorArg)
  sr=plan~salesRule~calculateReturn(parts["salesCostMinor"],unearnedNumeratorArg,unearnedDenominatorArg)
  tr=plan~taxRule~calculateReturn(parts["taxMinor"],unearnedNumeratorArg,unearnedDenominatorArg)
  if rr==.nil | sr==.nil | tr==.nil then return .AllJapanInsuranceResult~failure("CANCELLATION_RULE_INVALID",plan~planRef)
  retained=rr["shortRateRetainedMinor"]+sr["shortRateRetainedMinor"]+tr["shortRateRetainedMinor"]
  total=rr["netReturnMinor"]+sr["netReturnMinor"]+tr["netReturnMinor"]
  calc=.AllJapanInsuranceCancellationCalculation~new(calculationIdArg,policyIdArg,plan~planRef,effectiveDateArg,parts["currency"],unearnedNumeratorArg,unearnedDenominatorArg,rr["netReturnMinor"],sr["netReturnMinor"],tr["netReturnMinor"],retained,total,calculatedAtArg,.AllJapanInsuranceTransactionBuild~CANCELLATION_FUNCTION)
  cancellationCalculations[calc~calculationId]=calc
  return .AllJapanInsuranceResult~success(calc)
::method recordCancellation
  expose authority adjustments cancellationCalculations
  use arg actor,cancellation,salesTreatmentArg=.nil
  if salesTreatmentArg==.nil then salesTreatmentArg=.AllJapanInsuranceTransactionBuild~SALES_PREMIUM_CONTROL
  auth=self~requireRole(actor,.AllJapanInsuranceBuild~ROLE_POLICY_TRANSACTION)
  if \auth~ok then return auth
  if cancellation==.nil then return .AllJapanInsuranceResult~failure("POLICY_CANCELLATION_REQUIRED")
  calc=cancellationCalculations[cancellation~calculationRef]
  if calc==.nil then return .AllJapanInsuranceResult~failure("CANCELLATION_CALCULATION_NOT_FOUND",cancellation~calculationRef)
  if calc~policyId\=cancellation~policyId | calc~effectiveDate\=cancellation~effectiveDate then return .AllJapanInsuranceResult~failure("CANCELLATION_CALCULATION_MISMATCH",calc~calculationId)
  adj=.AllJapanInsurancePremiumAdjustment~new("ADJ:CANCEL:" || cancellation~cancellationId,cancellation~policyId,.AllJapanInsuranceTransactionBuild~ADJUSTMENT_CANCELLATION,cancellation~effectiveDate,calc~calculationId,-calc~riskReturnMinor,-calc~salesReturnMinor,-calc~taxReturnMinor,-calc~totalReturnMinor,calc~currency,salesTreatmentArg,cancellation~reasonCode,cancellation~authorizedBy,cancellation~authorizedAt,cancellation~evidenceRef)
  valid=self~validateAdjustment(actor,adj,.true)
  if \valid~ok then return valid
  cov=authority~recordCancellation(actor,cancellation)
  if \cov~ok then return cov
  adjustments[adj~adjustmentId]=adj
  return .AllJapanInsuranceResult~success(adj,calc~totalReturnMinor~string)
::method recordCommissionSettlement
  expose authority commissionSettlements
  use arg actor,settlement
  auth=self~requireRole(actor,.AllJapanInsuranceBuild~ROLE_COMMISSION_SETTLEMENT)
  if \auth~ok then return auth
  if settlement==.nil | settlement~settlementId="" | settlement~policyId="" | settlement~producerRef="" | settlement~settledAt="" then return .AllJapanInsuranceResult~failure("COMMISSION_SETTLEMENT_IDENTITY_REQUIRED")
  if commissionSettlements~hasIndex(settlement~settlementId) then return .AllJapanInsuranceResult~failure("COMMISSION_SETTLEMENT_DUPLICATE",settlement~settlementId)
  if settlement~paymentRef="" | settlement~bankEvidenceRef="" then return .AllJapanInsuranceResult~failure("COMMISSION_SETTLEMENT_BANK_EVIDENCE_REQUIRED")
  policy=authority~policy(settlement~policyId)
  if policy==.nil then return .AllJapanInsuranceResult~failure("POLICY_NOT_FOUND",settlement~policyId)
  quote=authority~quote(policy~quoteId)
  if quote==.nil | settlement~currency\=quote~currency then return .AllJapanInsuranceResult~failure("COMMISSION_SETTLEMENT_CURRENCY_MISMATCH",settlement~currency)
  money=.AllJapanInsuranceCurrency~validateMinorAmount(settlement~currency,settlement~amountMinor)
  if \money~ok | settlement~amountMinor=0 then return .AllJapanInsuranceResult~failure("COMMISSION_SETTLEMENT_AMOUNT_INVALID")
  commissionSettlements[settlement~settlementId]=settlement
  return .AllJapanInsuranceResult~success(settlement)
::method recordPolicyholderRefund
  expose authority refunds
  use arg actor,refund
  auth=self~requireRole(actor,.AllJapanInsuranceBuild~ROLE_PREMIUM_BILLING)
  if \auth~ok then return auth
  if refund==.nil | refund~refundId="" | refund~policyId="" | refund~payeeRef="" | refund~paidAt="" then return .AllJapanInsuranceResult~failure("POLICYHOLDER_REFUND_IDENTITY_REQUIRED")
  if refunds~hasIndex(refund~refundId) then return .AllJapanInsuranceResult~failure("POLICYHOLDER_REFUND_DUPLICATE",refund~refundId)
  if refund~paymentRef="" | refund~bankEvidenceRef="" then return .AllJapanInsuranceResult~failure("POLICYHOLDER_REFUND_BANK_EVIDENCE_REQUIRED")
  policy=authority~policy(refund~policyId)
  if policy==.nil then return .AllJapanInsuranceResult~failure("POLICY_NOT_FOUND",refund~policyId)
  quote=authority~quote(policy~quoteId)
  if quote==.nil | refund~currency\=quote~currency then return .AllJapanInsuranceResult~failure("POLICYHOLDER_REFUND_CURRENCY_MISMATCH",refund~currency)
  money=.AllJapanInsuranceCurrency~validateMinorAmount(refund~currency,refund~amountMinor)
  if \money~ok | refund~amountMinor=0 then return .AllJapanInsuranceResult~failure("POLICYHOLDER_REFUND_AMOUNT_INVALID")
  refunds[refund~refundId]=refund
  return .AllJapanInsuranceResult~success(refund)

::method currentExposureSnapshot
  expose currentExposure
  use arg policyIdArg
  return currentExposure[policyIdArg~string]
::method exposureSnapshot
  expose exposureSnapshots
  use arg snapshotIdArg
  return exposureSnapshots[snapshotIdArg~string]
::method exposureChange
  expose exposureChanges
  use arg changeIdArg
  return exposureChanges[changeIdArg~string]
::method reratingEvidence
  expose reratingEvidence
  use arg calculationIdArg
  return reratingEvidence[calculationIdArg~string]
::method registerBoundExposureSnapshot
  expose authority productRatingBook exposureSnapshots currentExposure
  use arg actor,snapshot
  auth=self~requireRole(actor,.AllJapanInsuranceBuild~ROLE_RATING_ENGINE)
  if \auth~ok then return auth
  if productRatingBook==.nil then return .AllJapanInsuranceResult~failure("PRODUCT_RATING_BOOK_REQUIRED")
  if snapshot==.nil | snapshot~snapshotId="" | snapshot~policyId="" | snapshot~capturedAt="" | snapshot~evidenceRef="" then return .AllJapanInsuranceResult~failure("EXPOSURE_SNAPSHOT_IDENTITY_REQUIRED")
  if exposureSnapshots~hasIndex(snapshot~snapshotId) | currentExposure~hasIndex(snapshot~policyId) then return .AllJapanInsuranceResult~failure("EXPOSURE_SNAPSHOT_ALREADY_EXISTS",snapshot~policyId)
  policy=authority~policy(snapshot~policyId)
  if policy==.nil then return .AllJapanInsuranceResult~failure("POLICY_NOT_FOUND",snapshot~policyId)
  quote=authority~quote(policy~quoteId)
  if quote==.nil then return .AllJapanInsuranceResult~failure("QUOTE_NOT_FOUND",policy~quoteId)
  if snapshot~effectiveFrom\=policy~inceptionDate | snapshot~programRef\=quote~ratingPlanRef | snapshot~ratingFunctionRef\=quote~ratingFunctionRef | snapshot~currency\=quote~currency then return .AllJapanInsuranceResult~failure("EXPOSURE_SNAPSHOT_BOUND_IDENTITY_MISMATCH",snapshot~snapshotId)
  rr=productRatingBook~ratePinnedProgram("VERIFY:" || snapshot~snapshotId,quote~submissionId,snapshot~programRef,policy~inceptionDate,snapshot~risks,snapshot~capturedAt)
  if \rr~ok then return rr
  if rr~value~totalPremiumMinor\=quote~premiumMinor | snapshot~totalPremiumMinor\=quote~premiumMinor then return .AllJapanInsuranceResult~failure("EXPOSURE_SNAPSHOT_PREMIUM_MISMATCH",rr~value~totalPremiumMinor)
  exposureSnapshots[snapshot~snapshotId]=snapshot
  currentExposure[policy~policyId]=snapshot
  return .AllJapanInsuranceResult~success(snapshot)
::method recordExposureChange
  expose authority currentExposure exposureChanges
  use arg actor,change
  auth=self~requireRole(actor,.AllJapanInsuranceBuild~ROLE_POLICY_TRANSACTION)
  if \auth~ok then return auth
  if change==.nil | change~changeId="" | change~policyId="" | change~priorSnapshotId="" | change~effectiveDate="" | change~requestedAt="" | change~evidenceRef="" then return .AllJapanInsuranceResult~failure("EXPOSURE_CHANGE_IDENTITY_REQUIRED")
  if exposureChanges~hasIndex(change~changeId) then return .AllJapanInsuranceResult~failure("EXPOSURE_CHANGE_DUPLICATE",change~changeId)
  current=currentExposure[change~policyId]
  if current==.nil then return .AllJapanInsuranceResult~failure("EXPOSURE_SNAPSHOT_REQUIRED",change~policyId)
  if current~snapshotId\=change~priorSnapshotId then return .AllJapanInsuranceResult~failure("EXPOSURE_CHANGE_STALE_SNAPSHOT",current~snapshotId)
  policy=authority~policy(change~policyId)
  if policy==.nil then return .AllJapanInsuranceResult~failure("POLICY_NOT_FOUND",change~policyId)
  if change~effectiveDate<policy~inceptionDate | change~effectiveDate>=policy~expiryDate then return .AllJapanInsuranceResult~failure("EXPOSURE_CHANGE_EFFECTIVE_DATE_INVALID",change~effectiveDate)
  cancellation=authority~policyCancellation(policy~policyId)
  reinstatement=authority~policyReinstatement(policy~policyId)
  if cancellation\==.nil then do
    if reinstatement==.nil & change~effectiveDate>=cancellation~effectiveDate then return .AllJapanInsuranceResult~failure("EXPOSURE_CHANGE_AFTER_CANCELLATION",cancellation~effectiveDate)
  end
  pr=.AllJapanInsuranceProration~new(change~remainingNumerator,change~remainingDenominator,"MIDTERM:" || change~changeId)
  v=pr~validate
  if \v~ok | pr~isFullTerm then return .AllJapanInsuranceResult~failure("EXPOSURE_CHANGE_PRORATION_INVALID",change~changeId)
  if change~newRisks~items=0 then return .AllJapanInsuranceResult~failure("EXPOSURE_CHANGE_RISK_REQUIRED",change~changeId)
  exposureChanges[change~changeId]=change
  return .AllJapanInsuranceResult~success(change)
::method transactionRisks private
  use arg risksArg,numeratorArg,denominatorArg,basisRefArg
  out=.array~new
  do risk over risksArg
    coverages=.array~new
    do selection over risk~coverages
      pr=.AllJapanInsuranceProration~new(numeratorArg,denominatorArg,basisRefArg)
      coverages~append(.AllJapanInsuranceCoverageSelection~new(selection~coverageCode,selection~selectedModifiers,pr))
    end
    out~append(.AllJapanInsuranceRiskObject~new(risk~riskRef,risk~productCode,risk~riskType,risk~facts,coverages))
  end
  return out
::method splitProductRating private
  use arg rating
  numeric digits 50
  sales=0; tax=0
  do cost over rating~costs
    if cost~code=.AllJapanInsuranceRatingBuild~COST_SALES then sales+=cost~amountMinor
    else if cost~code~length>=4 & cost~code~substr(1,4)="TAX_" then tax+=cost~amountMinor
  end
  risk=rating~totalPremiumMinor-sales-tax
  out=.directory~new
  out["risk"]=risk; out["sales"]=sales; out["tax"]=tax; out["total"]=rating~totalPremiumMinor
  return out
::method calculateExposureChange
  expose authority productRatingBook currentExposure exposureChanges reratingEvidence
  use arg actor,calculationIdArg,changeIdArg,ratedAtArg
  auth=self~requireRole(actor,.AllJapanInsuranceBuild~ROLE_RATING_ENGINE)
  if \auth~ok then return auth
  if productRatingBook==.nil then return .AllJapanInsuranceResult~failure("PRODUCT_RATING_BOOK_REQUIRED")
  change=exposureChanges[changeIdArg~string]
  if change==.nil then return .AllJapanInsuranceResult~failure("EXPOSURE_CHANGE_NOT_FOUND",changeIdArg)
  prior=currentExposure[change~policyId]
  if prior==.nil then return .AllJapanInsuranceResult~failure("EXPOSURE_CHANGE_STALE_SNAPSHOT",change~priorSnapshotId)
  if prior~snapshotId\=change~priorSnapshotId then return .AllJapanInsuranceResult~failure("EXPOSURE_CHANGE_STALE_SNAPSHOT",change~priorSnapshotId)
  policy=authority~policy(change~policyId); quote=authority~quote(policy~quoteId)
  if policy==.nil | quote==.nil then return .AllJapanInsuranceResult~failure("EXPOSURE_CHANGE_POLICY_CONTEXT_MISSING",change~policyId)
  beforeRisks=self~transactionRisks(prior~risks,change~remainingNumerator,change~remainingDenominator,"MIDTERM:" || change~changeId)
  afterRisks=self~transactionRisks(change~newRisks,change~remainingNumerator,change~remainingDenominator,"MIDTERM:" || change~changeId)
  before=productRatingBook~ratePinnedProgram("MIDTERM:BEFORE:" || calculationIdArg,quote~submissionId,prior~programRef,policy~inceptionDate,beforeRisks,ratedAtArg)
  if \before~ok then return before
  after=productRatingBook~ratePinnedProgram("MIDTERM:AFTER:" || calculationIdArg,quote~submissionId,prior~programRef,policy~inceptionDate,afterRisks,ratedAtArg)
  if \after~ok then return after
  b=self~splitProductRating(before~value); a=self~splitProductRating(after~value)
  riskDelta=a["risk"]-b["risk"]; salesDelta=a["sales"]-b["sales"]; taxDelta=a["tax"]-b["tax"]; totalDelta=a["total"]-b["total"]
  if totalDelta=0 then return .AllJapanInsuranceResult~failure("MIDTERM_RERATING_NO_PREMIUM_CHANGE",change~changeId)
  calc=.AllJapanInsurancePremiumAdjustmentCalculation~new(calculationIdArg,policy~policyId,.AllJapanInsuranceTransactionBuild~ADJUSTMENT_ENDORSEMENT,change~effectiveDate,riskDelta,salesDelta,taxDelta,totalDelta,quote~currency,quote~ratingFunctionRef,ratedAtArg,change~evidenceRef || "|PINNED_PROGRAM=" || prior~programRef || "|BEFORE=" || before~value~ratingId || "|AFTER=" || after~value~ratingId)
  stored=self~recordAdjustmentCalculation(actor,calc)
  if \stored~ok then return stored
  ev=.directory~new; ev["change"]=change; ev["beforeRating"]=before~value; ev["afterRating"]=after~value
  reratingEvidence[calc~calculationId]=ev
  return .AllJapanInsuranceResult~success(calc,.AllJapanInsuranceTransactionBuild~MIDTERM_RERATING_FUNCTION)
::method nonPaymentNotice
  expose nonPaymentNotices
  use arg noticeIdArg
  return nonPaymentNotices[noticeIdArg~string]
::method issueNonPaymentNotice
  expose authority nonPaymentNotices
  use arg actor,noticeIdArg,policyIdArg,arrearsAsOfDateArg,cureDeadlineArg,issuedAtArg,evidenceRefArg
  auth=self~requireRole(actor,.AllJapanInsuranceBuild~ROLE_CREDIT_CONTROL)
  if \auth~ok then return auth
  if noticeIdArg~string="" | policyIdArg~string="" | issuedAtArg~string="" | evidenceRefArg~string="" then return .AllJapanInsuranceResult~failure("NON_PAYMENT_NOTICE_IDENTITY_REQUIRED")
  if nonPaymentNotices~hasIndex(noticeIdArg~string) then return .AllJapanInsuranceResult~failure("NON_PAYMENT_NOTICE_DUPLICATE",noticeIdArg)
  if cureDeadlineArg~string<=arrearsAsOfDateArg~string then return .AllJapanInsuranceResult~failure("NON_PAYMENT_CURE_DEADLINE_INVALID",cureDeadlineArg)
  policy=authority~policy(policyIdArg); if policy==.nil then return .AllJapanInsuranceResult~failure("POLICY_NOT_FOUND",policyIdArg)
  rows=self~arrearsAsOf(policyIdArg,arrearsAsOfDateArg); total=0; ccy=""
  do row over rows; total+=row["outstandingMinor"]; if ccy="" then ccy=row["currency"]; else if ccy\=row["currency"] then return .AllJapanInsuranceResult~failure("NON_PAYMENT_ARREARS_CURRENCY_AMBIGUOUS"); end
  if total<=0 then return .AllJapanInsuranceResult~failure("NON_PAYMENT_ARREARS_REQUIRED",policyIdArg)
  notice=.AllJapanInsuranceNonPaymentNotice~new(noticeIdArg,policyIdArg,arrearsAsOfDateArg,cureDeadlineArg,total,ccy,issuedAtArg,actor~principalId,evidenceRefArg)
  nonPaymentNotices[notice~noticeId]=notice
  return .AllJapanInsuranceResult~success(notice)
::method recordNonPaymentCancellation
  expose nonPaymentNotices
  use arg actor,cancellation,noticeIdArg,salesTreatmentArg=.nil
  notice=nonPaymentNotices[noticeIdArg~string]
  if notice==.nil then return .AllJapanInsuranceResult~failure("NON_PAYMENT_NOTICE_NOT_FOUND",noticeIdArg)
  if cancellation==.nil | cancellation~policyId\=notice~policyId | cancellation~reasonCode\=.AllJapanInsuranceTransactionBuild~NON_PAYMENT_REASON then return .AllJapanInsuranceResult~failure("NON_PAYMENT_CANCELLATION_NOTICE_MISMATCH",noticeIdArg)
  if cancellation~effectiveDate<notice~cureDeadline then return .AllJapanInsuranceResult~failure("NON_PAYMENT_CURE_PERIOD_NOT_EXPIRED",notice~cureDeadline)
  rows=self~arrearsAsOf(cancellation~policyId,cancellation~effectiveDate); total=0
  do row over rows; total+=row["outstandingMinor"]; end
  if total<=0 then return .AllJapanInsuranceResult~failure("NON_PAYMENT_ARREARS_CURED",cancellation~policyId)
  return self~recordCancellation(actor,cancellation,salesTreatmentArg)
::method calculateReinstatement
  expose authority cancellationCalculations
  use arg actor,calculationIdArg,policyIdArg,cancellationCalculationIdArg,effectiveDateArg,calculatedAtArg,evidenceRefArg
  auth=self~requireRole(actor,.AllJapanInsuranceBuild~ROLE_RATING_ENGINE)
  if \auth~ok then return auth
  cc=cancellationCalculations[cancellationCalculationIdArg~string]
  if cc==.nil then return .AllJapanInsuranceResult~failure("REINSTATEMENT_CANCELLATION_CALCULATION_NOT_FOUND",cancellationCalculationIdArg)
  if cc~policyId\=policyIdArg~string then return .AllJapanInsuranceResult~failure("REINSTATEMENT_CANCELLATION_CALCULATION_NOT_FOUND",cancellationCalculationIdArg)
  calc=.AllJapanInsurancePremiumAdjustmentCalculation~new(calculationIdArg,policyIdArg,.AllJapanInsuranceTransactionBuild~ADJUSTMENT_REINSTATEMENT,effectiveDateArg,cc~riskReturnMinor,cc~salesReturnMinor,cc~taxReturnMinor,cc~totalReturnMinor,cc~currency,.AllJapanInsuranceTransactionBuild~REINSTATEMENT_FUNCTION,calculatedAtArg,evidenceRefArg)
  return self~recordAdjustmentCalculation(actor,calc)
::method recordReinstatement
  expose authority adjustments adjustmentCalculations cancellationCalculations
  use arg actor,reinstatement,calculationIdArg,salesTreatmentArg=.nil
  if salesTreatmentArg==.nil then salesTreatmentArg=.AllJapanInsuranceTransactionBuild~SALES_PREMIUM_CONTROL
  auth=self~requireRole(actor,.AllJapanInsuranceBuild~ROLE_POLICY_TRANSACTION)
  if \auth~ok then return auth
  if reinstatement==.nil then return .AllJapanInsuranceResult~failure("POLICY_REINSTATEMENT_REQUIRED")
  if self~arrearsAsOf(reinstatement~policyId,reinstatement~effectiveDate)~items>0 then return .AllJapanInsuranceResult~failure("POLICY_REINSTATEMENT_ARREARS_OUTSTANDING",reinstatement~policyId)
  calc=adjustmentCalculations[calculationIdArg~string]
  if calc==.nil then return .AllJapanInsuranceResult~failure("POLICY_REINSTATEMENT_CALCULATION_REQUIRED",calculationIdArg)
  if calc~transactionType\=.AllJapanInsuranceTransactionBuild~ADJUSTMENT_REINSTATEMENT then return .AllJapanInsuranceResult~failure("POLICY_REINSTATEMENT_CALCULATION_REQUIRED",calculationIdArg)
  if reinstatement~premiumAdjustmentRef="" then return .AllJapanInsuranceResult~failure("POLICY_REINSTATEMENT_PREMIUM_ADJUSTMENT_REQUIRED")
  adj=.AllJapanInsurancePremiumAdjustment~new(reinstatement~premiumAdjustmentRef,reinstatement~policyId,.AllJapanInsuranceTransactionBuild~ADJUSTMENT_REINSTATEMENT,reinstatement~coverageRestoredFromDate,calc~calculationId,calc~riskDeltaMinor,calc~salesDeltaMinor,calc~taxDeltaMinor,calc~totalDeltaMinor,calc~currency,salesTreatmentArg,"REINSTATEMENT",reinstatement~authorizedBy,reinstatement~authorizedAt,reinstatement~evidenceRef)
  valid=self~validateAdjustment(actor,adj,.false,.true)
  if \valid~ok then return valid
  cov=authority~recordReinstatement(actor,reinstatement)
  if \cov~ok then return cov
  adjustments[adj~adjustmentId]=adj
  return .AllJapanInsuranceResult~success(adj)
::method commissionRecoveryForAdjustment
  expose commissionRecoveryByAdjustment commissionRecoveries
  use arg adjustmentIdArg
  id=commissionRecoveryByAdjustment[adjustmentIdArg~string]
  if id==.nil then return .nil
  return commissionRecoveries[id]
::method authorizeCommissionRecovery
  expose adjustments commissionRecoveries commissionRecoveryByAdjustment
  use arg actor,recovery
  auth=self~requireRole(actor,.AllJapanInsuranceBuild~ROLE_COMMISSION_SETTLEMENT)
  if \auth~ok then return auth
  if recovery==.nil then return .AllJapanInsuranceResult~failure("COMMISSION_RECOVERY_IDENTITY_REQUIRED")
  if recovery~recoveryId="" | recovery~adjustmentId="" | recovery~policyId="" | recovery~producerRef="" | recovery~authorizedAt="" | recovery~evidenceRef="" then return .AllJapanInsuranceResult~failure("COMMISSION_RECOVERY_IDENTITY_REQUIRED")
  if recovery~authorizedBy\=actor~principalId then return .AllJapanInsuranceResult~failure("COMMISSION_RECOVERY_AUTHORITY_MISMATCH",recovery~authorizedBy)
  if commissionRecoveries~hasIndex(recovery~recoveryId) | commissionRecoveryByAdjustment~hasIndex(recovery~adjustmentId) then return .AllJapanInsuranceResult~failure("COMMISSION_RECOVERY_DUPLICATE",recovery~adjustmentId)
  adj=adjustments[recovery~adjustmentId]
  if adj==.nil then return .AllJapanInsuranceResult~failure("COMMISSION_RECOVERY_ADJUSTMENT_INVALID",recovery~adjustmentId)
  if adj~policyId\=recovery~policyId | adj~salesCostTreatment\=.AllJapanInsuranceTransactionBuild~SALES_COMMISSION_PAYABLE | adj~salesDeltaMinor>=0 then return .AllJapanInsuranceResult~failure("COMMISSION_RECOVERY_ADJUSTMENT_INVALID",recovery~adjustmentId)
  if recovery~currency\=adj~currency | recovery~amountMinor<=0 | recovery~amountMinor> -adj~salesDeltaMinor then return .AllJapanInsuranceResult~failure("COMMISSION_RECOVERY_AMOUNT_INVALID",recovery~amountMinor)
  commissionRecoveries[recovery~recoveryId]=recovery; commissionRecoveryByAdjustment[recovery~adjustmentId]=recovery~recoveryId
  return .AllJapanInsuranceResult~success(recovery)
::method commissionRecoveryReceipt
  expose commissionRecoveryReceipts
  use arg receiptIdArg
  return commissionRecoveryReceipts[receiptIdArg~string]
::method recordCommissionRecoveryReceipt
  expose commissionRecoveries commissionRecoveryReceipts
  use arg actor,receipt
  auth=self~requireRole(actor,.AllJapanInsuranceBuild~ROLE_COMMISSION_SETTLEMENT)
  if \auth~ok then return auth
  if receipt==.nil then return .AllJapanInsuranceResult~failure("COMMISSION_RECOVERY_RECEIPT_EVIDENCE_REQUIRED")
  if receipt~receiptId="" | receipt~paymentRef="" | receipt~bankEvidenceRef="" then return .AllJapanInsuranceResult~failure("COMMISSION_RECOVERY_RECEIPT_EVIDENCE_REQUIRED")
  if commissionRecoveryReceipts~hasIndex(receipt~receiptId) then return .AllJapanInsuranceResult~failure("COMMISSION_RECOVERY_RECEIPT_DUPLICATE",receipt~receiptId)
  recovery=commissionRecoveries[receipt~recoveryId]
  if recovery==.nil then return .AllJapanInsuranceResult~failure("COMMISSION_RECOVERY_RECEIPT_MISMATCH",receipt~recoveryId)
  if recovery~policyId\=receipt~policyId | recovery~producerRef\=receipt~producerRef | recovery~currency\=receipt~currency then return .AllJapanInsuranceResult~failure("COMMISSION_RECOVERY_RECEIPT_MISMATCH",receipt~recoveryId)
  total=0; do prior over commissionRecoveryReceipts~allItems; if prior~recoveryId=receipt~recoveryId then total+=prior~amountMinor; end
  if receipt~amountMinor<=0 | total+receipt~amountMinor>recovery~amountMinor then return .AllJapanInsuranceResult~failure("COMMISSION_RECOVERY_RECEIPT_EXCEEDS_AUTHORIZATION",recovery~amountMinor-total)
  commissionRecoveryReceipts[receipt~receiptId]=receipt
  return .AllJapanInsuranceResult~success(receipt)
::method taxRemittance
  expose taxRemittances
  use arg remittanceIdArg
  return taxRemittances[remittanceIdArg~string]
::method recordTaxRemittance
  expose authority taxRemittances
  use arg actor,remittance
  auth=self~requireRole(actor,.AllJapanInsuranceBuild~ROLE_TAX_SETTLEMENT)
  if \auth~ok then return auth
  if remittance==.nil | remittance~remittanceId="" | remittance~policyId="" | remittance~taxAuthorityRef="" | remittance~remittedAt="" | remittance~paymentRef="" | remittance~bankEvidenceRef="" then return .AllJapanInsuranceResult~failure("TAX_REMITTANCE_IDENTITY_REQUIRED")
  if taxRemittances~hasIndex(remittance~remittanceId) then return .AllJapanInsuranceResult~failure("TAX_REMITTANCE_DUPLICATE",remittance~remittanceId)
  policy=authority~policy(remittance~policyId); if policy==.nil then return .AllJapanInsuranceResult~failure("POLICY_NOT_FOUND",remittance~policyId)
  quote=authority~quote(policy~quoteId)
  if quote==.nil | remittance~currency\=quote~currency | remittance~amountMinor<=0 then return .AllJapanInsuranceResult~failure("TAX_REMITTANCE_AMOUNT_INVALID",remittance~policyId)
  taxRemittances[remittance~remittanceId]=remittance
  return .AllJapanInsuranceResult~success(remittance)
::method taxRecoveryForAdjustment
  expose taxRecoveryByAdjustment taxRecoveries
  use arg adjustmentIdArg
  id=taxRecoveryByAdjustment[adjustmentIdArg~string]
  if id==.nil then return .nil
  return taxRecoveries[id]
::method authorizeTaxRecovery
  expose adjustments taxRecoveries taxRecoveryByAdjustment
  use arg actor,recovery
  auth=self~requireRole(actor,.AllJapanInsuranceBuild~ROLE_TAX_SETTLEMENT)
  if \auth~ok then return auth
  if recovery==.nil then return .AllJapanInsuranceResult~failure("TAX_RECOVERY_IDENTITY_REQUIRED")
  if recovery~recoveryId="" | recovery~adjustmentId="" | recovery~policyId="" | recovery~taxAuthorityRef="" | recovery~authorizedAt="" | recovery~evidenceRef="" then return .AllJapanInsuranceResult~failure("TAX_RECOVERY_IDENTITY_REQUIRED")
  if recovery~authorizedBy\=actor~principalId then return .AllJapanInsuranceResult~failure("TAX_RECOVERY_AUTHORITY_MISMATCH",recovery~authorizedBy)
  if taxRecoveries~hasIndex(recovery~recoveryId) | taxRecoveryByAdjustment~hasIndex(recovery~adjustmentId) then return .AllJapanInsuranceResult~failure("TAX_RECOVERY_DUPLICATE",recovery~adjustmentId)
  adj=adjustments[recovery~adjustmentId]
  if adj==.nil then return .AllJapanInsuranceResult~failure("TAX_RECOVERY_ADJUSTMENT_INVALID",recovery~adjustmentId)
  if adj~policyId\=recovery~policyId | adj~taxDeltaMinor>=0 then return .AllJapanInsuranceResult~failure("TAX_RECOVERY_ADJUSTMENT_INVALID",recovery~adjustmentId)
  if recovery~currency\=adj~currency | recovery~amountMinor<=0 | recovery~amountMinor> -adj~taxDeltaMinor then return .AllJapanInsuranceResult~failure("TAX_RECOVERY_AMOUNT_INVALID",recovery~amountMinor)
  taxRecoveries[recovery~recoveryId]=recovery; taxRecoveryByAdjustment[recovery~adjustmentId]=recovery~recoveryId
  return .AllJapanInsuranceResult~success(recovery)
::method taxRecoveryReceipt
  expose taxRecoveryReceipts
  use arg receiptIdArg
  return taxRecoveryReceipts[receiptIdArg~string]
::method recordTaxRecoveryReceipt
  expose taxRecoveries taxRecoveryReceipts
  use arg actor,receipt
  auth=self~requireRole(actor,.AllJapanInsuranceBuild~ROLE_TAX_SETTLEMENT)
  if \auth~ok then return auth
  if receipt==.nil then return .AllJapanInsuranceResult~failure("TAX_RECOVERY_RECEIPT_EVIDENCE_REQUIRED")
  if receipt~receiptId="" | receipt~paymentRef="" | receipt~bankEvidenceRef="" then return .AllJapanInsuranceResult~failure("TAX_RECOVERY_RECEIPT_EVIDENCE_REQUIRED")
  if taxRecoveryReceipts~hasIndex(receipt~receiptId) then return .AllJapanInsuranceResult~failure("TAX_RECOVERY_RECEIPT_DUPLICATE",receipt~receiptId)
  recovery=taxRecoveries[receipt~recoveryId]
  if recovery==.nil then return .AllJapanInsuranceResult~failure("TAX_RECOVERY_RECEIPT_MISMATCH",receipt~recoveryId)
  if recovery~policyId\=receipt~policyId | recovery~taxAuthorityRef\=receipt~taxAuthorityRef | recovery~currency\=receipt~currency then return .AllJapanInsuranceResult~failure("TAX_RECOVERY_RECEIPT_MISMATCH",receipt~recoveryId)
  total=0; do prior over taxRecoveryReceipts~allItems; if prior~recoveryId=receipt~recoveryId then total+=prior~amountMinor; end
  if receipt~amountMinor<=0 | total+receipt~amountMinor>recovery~amountMinor then return .AllJapanInsuranceResult~failure("TAX_RECOVERY_RECEIPT_EXCEEDS_AUTHORIZATION",recovery~amountMinor-total)
  taxRecoveryReceipts[receipt~receiptId]=receipt
  return .AllJapanInsuranceResult~success(receipt)


::method billingItem
  expose billingItems
  use arg itemIdArg
  return billingItems[itemIdArg~string]
::method billingReceipt
  expose billingReceipts
  use arg receiptIdArg
  return billingReceipts[receiptIdArg~string]
::method billingReceiptAppliedAtRecord
  expose billingReceiptInitialApplied
  use arg receiptIdArg
  value=billingReceiptInitialApplied[receiptIdArg~string]
  if value==.nil then return .nil
  return value
::method billingAllocation
  expose billingAllocations
  use arg allocationIdArg
  return billingAllocations[allocationIdArg~string]
::method currentBillingScheduleRef
  expose currentBillingSchedule
  use arg policyIdArg
  ref=currentBillingSchedule[policyIdArg~string]
  if ref==.nil then return ""
  return ref
::method billingItemsForPolicy
  expose billingItems
  use arg policyIdArg
  out=.array~new
  do item over billingItems~allItems
    if item~policyId=policyIdArg~string then out~append(item)
  end
  return out
::method billingAllocatedToTarget private
  expose billingAllocations
  use arg targetItemIdArg
  numeric digits 50
  total=0
  do allocation over billingAllocations~allItems
    if allocation~targetItemId=targetItemIdArg~string then total+=allocation~amountMinor
  end
  return total
::method billingAllocatedFromSource private
  expose billingAllocations
  use arg sourceKindArg,sourceRefArg
  numeric digits 50
  total=0
  kind=.AllJapanInsuranceCanonical~token(sourceKindArg)
  do allocation over billingAllocations~allItems
    if allocation~sourceKind=kind & allocation~sourceRef=sourceRefArg~string then total+=allocation~amountMinor
  end
  return total
::method billingOpenDebitMinor
  expose billingItems
  use arg itemIdArg
  item=billingItems[itemIdArg~string]
  if item==.nil | item~direction\=.AllJapanInsuranceTransactionBuild~BILLING_DEBIT then return .nil
  remaining=item~amountMinor-self~billingAllocatedToTarget(item~itemId)
  if remaining<0 then return .nil
  return remaining
::method billingUnappliedCreditMinor
  expose billingItems
  use arg itemIdArg
  item=billingItems[itemIdArg~string]
  if item==.nil | item~direction\=.AllJapanInsuranceTransactionBuild~BILLING_CREDIT then return .nil
  remaining=item~amountMinor-self~billingAllocatedFromSource("CREDIT_ITEM",item~itemId)
  if remaining<0 then return .nil
  return remaining
::method billingUnappliedReceiptMinor
  expose billingReceipts
  use arg receiptIdArg
  receipt=billingReceipts[receiptIdArg~string]
  if receipt==.nil then return .nil
  remaining=receipt~amountMinor-self~billingAllocatedFromSource("RECEIPT",receipt~receiptId)
  if remaining<0 then return .nil
  return remaining
::method allocateBillingSourceToTarget private
  expose billingItems billingReceipts billingAllocations
  use arg sourceKindArg,sourceRefArg,targetItemIdArg,amountArg,allocatedAtArg
  numeric digits 50
  kind=.AllJapanInsuranceCanonical~token(sourceKindArg)
  target=billingItems[targetItemIdArg~string]
  if target==.nil | target~direction\=.AllJapanInsuranceTransactionBuild~BILLING_DEBIT then return .AllJapanInsuranceResult~failure("BILLING_ALLOCATION_TARGET_INVALID",targetItemIdArg)
  open=self~billingOpenDebitMinor(target~itemId)
  if open==.nil | open<=0 then return .AllJapanInsuranceResult~failure("BILLING_ALLOCATION_TARGET_SETTLED",target~itemId)
  if kind="RECEIPT" then available=self~billingUnappliedReceiptMinor(sourceRefArg)
  else if kind="CREDIT_ITEM" then available=self~billingUnappliedCreditMinor(sourceRefArg)
  else return .AllJapanInsuranceResult~failure("BILLING_ALLOCATION_SOURCE_INVALID",kind)
  amount=.AllJapanInsuranceTransactionMath~signedWhole(amountArg)
  if amount==.nil | amount<=0 | available==.nil | amount>available | amount>open then return .AllJapanInsuranceResult~failure("BILLING_ALLOCATION_AMOUNT_INVALID",amountArg)
  allocationId="ALLOC:" || (billingAllocations~items+1) || ":" || kind || ":" || sourceRefArg~string || ":" || target~itemId
  a=.AllJapanInsuranceBillingAllocation~new(allocationId,target~policyId,kind,sourceRefArg,target~itemId,amount,allocatedAtArg,.AllJapanInsuranceTransactionBuild~BILLING_ALLOCATION_FUNCTION)
  billingAllocations[allocationId]=a
  return .AllJapanInsuranceResult~success(a)
::method oldestOpenBillingDebit private
  expose billingItems
  use arg policyIdArg
  best=.nil; bestKey=""
  do item over billingItems~allItems
    if item~policyId\=policyIdArg~string | item~direction\=.AllJapanInsuranceTransactionBuild~BILLING_DEBIT then iterate
    open=self~billingOpenDebitMinor(item~itemId)
    if open==.nil | open<=0 then iterate
    key=item~dueDate || "|" || item~itemId
    if best==.nil | key<bestKey then do; best=item; bestKey=key; end
  end
  return best
::method oldestUnappliedBillingCredit private
  expose billingItems
  use arg policyIdArg
  best=.nil; bestKey=""
  do item over billingItems~allItems
    if item~policyId\=policyIdArg~string | item~direction\=.AllJapanInsuranceTransactionBuild~BILLING_CREDIT then iterate
    remaining=self~billingUnappliedCreditMinor(item~itemId)
    if remaining==.nil | remaining<=0 then iterate
    key=item~dueDate || "|" || item~createdAt || "|" || item~itemId
    if best==.nil | key<bestKey then do; best=item; bestKey=key; end
  end
  return best
::method oldestUnappliedBillingReceipt private
  expose billingReceipts
  use arg policyIdArg
  best=.nil; bestKey=""
  do receipt over billingReceipts~allItems
    if receipt~policyId\=policyIdArg~string then iterate
    remaining=self~billingUnappliedReceiptMinor(receipt~receiptId)
    if remaining==.nil | remaining<=0 then iterate
    key=receipt~receivedAt || "|" || receipt~receiptId
    if best==.nil | key<bestKey then do; best=receipt; bestKey=key; end
  end
  return best
::method autoAllocateBillingSource private
  use arg sourceKindArg,sourceRefArg,policyIdArg,allocatedAtArg
  numeric digits 50
  do forever
    if .AllJapanInsuranceCanonical~token(sourceKindArg)="RECEIPT" then available=self~billingUnappliedReceiptMinor(sourceRefArg)
    else available=self~billingUnappliedCreditMinor(sourceRefArg)
    if available==.nil | available<=0 then leave
    target=self~oldestOpenBillingDebit(policyIdArg)
    if target==.nil then leave
    open=self~billingOpenDebitMinor(target~itemId)
    amount=available
    if open<amount then amount=open
    r=self~allocateBillingSourceToTarget(sourceKindArg,sourceRefArg,target~itemId,amount,allocatedAtArg)
    if \r~ok then return r
  end
  return .AllJapanInsuranceResult~success
::method autoApplyExistingBillingSources private
  use arg policyIdArg,allocatedAtArg
  do forever
    target=self~oldestOpenBillingDebit(policyIdArg)
    if target==.nil then leave
    credit=self~oldestUnappliedBillingCredit(policyIdArg)
    if credit\==.nil then do
      available=self~billingUnappliedCreditMinor(credit~itemId); open=self~billingOpenDebitMinor(target~itemId); amount=available; if open<amount then amount=open
      r=self~allocateBillingSourceToTarget("CREDIT_ITEM",credit~itemId,target~itemId,amount,allocatedAtArg); if \r~ok then return r
      iterate
    end
    receipt=self~oldestUnappliedBillingReceipt(policyIdArg)
    if receipt\==.nil then do
      available=self~billingUnappliedReceiptMinor(receipt~receiptId); open=self~billingOpenDebitMinor(target~itemId); amount=available; if open<amount then amount=open
      r=self~allocateBillingSourceToTarget("RECEIPT",receipt~receiptId,target~itemId,amount,allocatedAtArg); if \r~ok then return r
      iterate
    end
    leave
  end
  return .AllJapanInsuranceResult~success
::method recordBillingReceipt
  expose authority billingReceipts billingReceiptInitialApplied
  use arg actor,receipt
  auth=self~requireRole(actor,.AllJapanInsuranceBuild~ROLE_PREMIUM_BILLING)
  if \auth~ok then return auth
  if receipt==.nil | receipt~receiptId="" | receipt~policyId="" | receipt~payerRef="" | receipt~receivedAt="" | receipt~paymentRef="" | receipt~bankEvidenceRef="" then return .AllJapanInsuranceResult~failure("BILLING_RECEIPT_EVIDENCE_REQUIRED")
  if billingReceipts~hasIndex(receipt~receiptId) then return .AllJapanInsuranceResult~failure("BILLING_RECEIPT_DUPLICATE",receipt~receiptId)
  policy=authority~policy(receipt~policyId)
  if policy==.nil then return .AllJapanInsuranceResult~failure("POLICY_NOT_FOUND",receipt~policyId)
  quote=authority~quote(policy~quoteId)
  if quote==.nil | receipt~currency\=quote~currency then return .AllJapanInsuranceResult~failure("BILLING_RECEIPT_CURRENCY_MISMATCH",receipt~currency)
  money=.AllJapanInsuranceCurrency~validateMinorAmount(receipt~currency,receipt~amountMinor)
  if \money~ok | receipt~amountMinor=0 then return .AllJapanInsuranceResult~failure("BILLING_RECEIPT_AMOUNT_INVALID",receipt~receiptId)
  billingReceipts[receipt~receiptId]=receipt
  r=self~autoAllocateBillingSource("RECEIPT",receipt~receiptId,receipt~policyId,receipt~receivedAt)
  if \r~ok then return r
  billingReceiptInitialApplied[receipt~receiptId]=receipt~amountMinor-self~billingUnappliedReceiptMinor(receipt~receiptId)
  return .AllJapanInsuranceResult~success(receipt)
::method billPremiumAdjustment
  expose authority adjustments billingItems currentBillingSchedule
  use arg actor,adjustmentIdArg,dueDateArg,createdAtArg
  auth=self~requireRole(actor,.AllJapanInsuranceBuild~ROLE_PREMIUM_BILLING)
  if \auth~ok then return auth
  adj=adjustments[adjustmentIdArg~string]
  if adj==.nil then return .AllJapanInsuranceResult~failure("BILLING_ADJUSTMENT_NOT_FOUND",adjustmentIdArg)
  policy=authority~policy(adj~policyId)
  if policy==.nil then return .AllJapanInsuranceResult~failure("POLICY_NOT_FOUND",adj~policyId)
  if dueDateArg~string="" | createdAtArg~string="" then return .AllJapanInsuranceResult~failure("BILLING_ADJUSTMENT_DUE_DATE_REQUIRED",adj~adjustmentId)
  if dueDateArg~string<policy~inceptionDate | dueDateArg~string>policy~expiryDate then return .AllJapanInsuranceResult~failure("BILLING_ADJUSTMENT_DUE_DATE_INVALID",dueDateArg)
  itemId="ADJUSTMENT:" || adj~adjustmentId
  if billingItems~hasIndex(itemId) then return .AllJapanInsuranceResult~failure("BILLING_ADJUSTMENT_ALREADY_BILLED",adj~adjustmentId)
  amount=adj~totalDeltaMinor
  if amount>0 then direction=.AllJapanInsuranceTransactionBuild~BILLING_DEBIT
  else direction=.AllJapanInsuranceTransactionBuild~BILLING_CREDIT
  if amount<0 then amount=-amount
  if amount=0 then return .AllJapanInsuranceResult~failure("BILLING_ADJUSTMENT_ZERO",adj~adjustmentId)
  versionRef=currentBillingSchedule[adj~policyId]
  if versionRef==.nil then versionRef="UNSCHEDULED:" || adj~policyId
  item=.AllJapanInsuranceBillingItem~new(itemId,adj~policyId,versionRef,adj~adjustmentId,.AllJapanInsuranceTransactionBuild~BILLING_SOURCE_ADJUSTMENT,0,dueDateArg,direction,amount,adj~currency,createdAtArg)
  billingItems[itemId]=item
  if direction=.AllJapanInsuranceTransactionBuild~BILLING_CREDIT then r=self~autoAllocateBillingSource("CREDIT_ITEM",itemId,adj~policyId,createdAtArg)
  else r=self~autoApplyExistingBillingSources(adj~policyId,createdAtArg)
  if \r~ok then return r
  return .AllJapanInsuranceResult~success(item)
::method recordBillingScheduleRevision
  expose authority billingItems billingScheduleRevisions currentBillingSchedule
  use arg actor,revision
  numeric digits 50
  auth=self~requireRole(actor,.AllJapanInsuranceBuild~ROLE_PREMIUM_BILLING)
  if \auth~ok then return auth
  if revision==.nil | revision~revisionId="" | revision~policyId="" | revision~predecessorRef="" | revision~effectiveDate="" | revision~createdAt="" | revision~reasonRef="" then return .AllJapanInsuranceResult~failure("BILLING_REVISION_IDENTITY_REQUIRED")
  if billingScheduleRevisions~hasIndex(revision~revisionId) then return .AllJapanInsuranceResult~failure("BILLING_REVISION_DUPLICATE",revision~revisionId)
  current=currentBillingSchedule[revision~policyId]
  if current==.nil | current\=revision~predecessorRef then return .AllJapanInsuranceResult~failure("BILLING_REVISION_PREDECESSOR_STALE",revision~predecessorRef)
  policy=authority~policy(revision~policyId); if policy==.nil then return .AllJapanInsuranceResult~failure("POLICY_NOT_FOUND",revision~policyId)
  quote=authority~quote(policy~quoteId); if quote==.nil then return .AllJapanInsuranceResult~failure("QUOTE_NOT_FOUND",policy~quoteId)
  replaceIds=revision~replaceItemIds; replacements=revision~replacementItems
  if replaceIds~items=0 | replacements~items=0 then return .AllJapanInsuranceResult~failure("BILLING_REVISION_ITEMS_REQUIRED",revision~revisionId)
  seen=.set~new; replacedTotal=0
  do id over replaceIds
    if seen~hasIndex(id) then return .AllJapanInsuranceResult~failure("BILLING_REVISION_REPLACE_DUPLICATE",id)
    seen~put(id)
    old=billingItems[id]
    if old==.nil | old~policyId\=revision~policyId | old~direction\=.AllJapanInsuranceTransactionBuild~BILLING_DEBIT then return .AllJapanInsuranceResult~failure("BILLING_REVISION_REPLACE_INVALID",id)
    if old~dueDate<revision~effectiveDate then return .AllJapanInsuranceResult~failure("BILLING_REVISION_REPLACE_ALREADY_DUE",id)
    open=self~billingOpenDebitMinor(id)
    if open==.nil | open<=0 then return .AllJapanInsuranceResult~failure("BILLING_REVISION_REPLACE_SETTLED",id)
    replacedTotal+=open
  end
  replacementTotal=0; seenNew=.set~new
  do item over replacements
    if item==.nil | item~itemId="" | item~policyId\=revision~policyId | item~scheduleVersionRef\=revision~revisionId | item~sourceRef\=revision~revisionId | item~sourceType\=.AllJapanInsuranceTransactionBuild~BILLING_SOURCE_REVISION then return .AllJapanInsuranceResult~failure("BILLING_REVISION_REPLACEMENT_INVALID",revision~revisionId)
    if item~direction\=.AllJapanInsuranceTransactionBuild~BILLING_DEBIT | item~amountMinor<=0 | item~currency\=quote~currency | item~dueDate<revision~effectiveDate then return .AllJapanInsuranceResult~failure("BILLING_REVISION_REPLACEMENT_INVALID",item~itemId)
    if seenNew~hasIndex(item~itemId) | billingItems~hasIndex(item~itemId) then return .AllJapanInsuranceResult~failure("BILLING_REVISION_REPLACEMENT_DUPLICATE",item~itemId)
    seenNew~put(item~itemId); replacementTotal+=item~amountMinor
  end
  if replacementTotal\=replacedTotal then return .AllJapanInsuranceResult~failure("BILLING_REVISION_TOTAL_MISMATCH",replacementTotal)
  /* Reversal credits are forced against the exact replaced debit, never floated. */
  do id over replaceIds
    old=billingItems[id]; open=self~billingOpenDebitMinor(id)
    reversalId="REVERSAL:" || revision~revisionId || ":" || id
    reversal=.AllJapanInsuranceBillingItem~new(reversalId,revision~policyId,revision~revisionId,revision~revisionId,.AllJapanInsuranceTransactionBuild~BILLING_SOURCE_REVERSAL,0,revision~effectiveDate,.AllJapanInsuranceTransactionBuild~BILLING_CREDIT,open,old~currency,revision~createdAt)
    billingItems[reversalId]=reversal
    r=self~allocateBillingSourceToTarget("CREDIT_ITEM",reversalId,id,open,revision~createdAt)
    if \r~ok then return r
  end
  do item over replacements; billingItems[item~itemId]=item; end
  billingScheduleRevisions[revision~revisionId]=revision
  currentBillingSchedule[revision~policyId]=revision~revisionId
  r=self~autoApplyExistingBillingSources(revision~policyId,revision~createdAt)
  if \r~ok then return r
  return .AllJapanInsuranceResult~success(revision,.AllJapanInsuranceTransactionBuild~BILLING_REVISION_FUNCTION)
::method billingArrearsAsOf
  expose authority billingItems
  use arg policyIdArg,asOfDateArg
  out=.array~new
  cancellation=authority~policyCancellation(policyIdArg)
  reinstatement=authority~policyReinstatement(policyIdArg)
  do item over billingItems~allItems
    if item~policyId\=policyIdArg~string | item~direction\=.AllJapanInsuranceTransactionBuild~BILLING_DEBIT then iterate
    if item~dueDate>=asOfDateArg~string then iterate
    if cancellation\==.nil & reinstatement==.nil then do
      if item~dueDate>=cancellation~effectiveDate then iterate
    end
    outstanding=self~billingOpenDebitMinor(item~itemId)
    if outstanding==.nil | outstanding<=0 then iterate
    row=.directory~new
    row["billingItemId"]=item~itemId
    if item~sourceType=.AllJapanInsuranceTransactionBuild~BILLING_SOURCE_INITIAL then row["instalmentId"]=item~sourceRef
    else row["instalmentId"]=""
    row["dueDate"]=item~dueDate
    row["outstandingMinor"]=outstanding
    row["currency"]=item~currency
    row["sourceType"]=item~sourceType
    row["sourceRef"]=item~sourceRef
    out~append(row)
  end
  return out
::method billingPosition
  expose billingItems billingReceipts
  use arg policyIdArg
  numeric digits 50
  debit=0; credit=0; cash=0
  do item over billingItems~allItems
    if item~policyId\=policyIdArg~string then iterate
    if item~direction=.AllJapanInsuranceTransactionBuild~BILLING_DEBIT then do; x=self~billingOpenDebitMinor(item~itemId); if x\==.nil then debit+=x; end
    else if item~direction=.AllJapanInsuranceTransactionBuild~BILLING_CREDIT then do; x=self~billingUnappliedCreditMinor(item~itemId); if x\==.nil then credit+=x; end
  end
  do receipt over billingReceipts~allItems
    if receipt~policyId=policyIdArg~string then do; x=self~billingUnappliedReceiptMinor(receipt~receiptId); if x\==.nil then cash+=x; end
  end
  out=.directory~new; out["openDebitMinor"]=debit; out["unappliedCreditMinor"]=credit; out["unappliedCashMinor"]=cash; out["netDebitMinor"]=debit-credit-cash
  return out

::requires "AllJapanInsuranceProductRating.cls"
::requires "AllJapanInsuranceRating.cls"
