/* AllJapanInsuranceAccounting.cls - AJI -> Accounting Core v0.7 bridge (AJI v0.10).
 *
 * Insurance operational state remains authoritative in AllJapanInsurance.
 * Accounting Core owns posted accounting truth for the AJI legal entity.
 * This bridge emits accounting.event/0.1 evidence and uses the preferred
 * AccountingEngine~transact() path.
 *
 * AJI functional/statutory book currency is JPY. Foreign-currency policies are
 * not silently translated here; they require an explicit FX accounting policy.
 */

::options digits 50

::class AllJapanInsuranceAccountingBuild public
::constant API_VERSION "all.japan.insurance.accounting/0.5"
::constant LEGAL_ENTITY_ID "ALL_JAPAN_INSURANCE_CO_LTD"
::constant FUNCTIONAL_CURRENCY "JPY"
::constant BOOK_ID "AJI-STAT"
::constant POLICY_ARTIFACT_IDENTITY "AJIA-0.10-20260828-BILLING-SUBLEDGER"
::constant EVENT_POLICY_BOUND "POLICY_BOUND"
::constant EVENT_PREMIUM_COLLECTED "PREMIUM_COLLECTED"
::constant EVENT_BILLING_CASH_RECEIVED "BILLING_CASH_RECEIVED"
::constant EVENT_CLAIM_RESERVE_CHANGED "CLAIM_RESERVE_CHANGED"
::constant EVENT_CLAIM_PAID "CLAIM_PAID"
::constant EVENT_PREMIUM_ADJUSTED "POLICY_PREMIUM_ADJUSTED"
::constant EVENT_COMMISSION_PAID "COMMISSION_PAID"
::constant EVENT_POLICYHOLDER_REFUND_PAID "POLICYHOLDER_REFUND_PAID"
::constant EVENT_COMMISSION_RECOVERED "COMMISSION_RECOVERED"
::constant EVENT_TAX_REMITTED "PREMIUM_TAX_REMITTED"
::constant EVENT_TAX_RECOVERED "PREMIUM_TAX_RECOVERED"
::constant SALES_PREMIUM_CONTROL "PREMIUM_CONTROL"
::constant SALES_COMMISSION_PAYABLE "COMMISSION_PAYABLE"
::constant ACCOUNT_CASH "1000"
::constant ACCOUNT_PREMIUM_RECEIVABLE "1100"
::constant ACCOUNT_INSURANCE_PREMIUM_CONTROL "2200"
::constant ACCOUNT_COMMISSION_PAYABLE "2210"
::constant ACCOUNT_TAX_PAYABLE "2220"
::constant ACCOUNT_CLAIMS_OUTSTANDING "2230"
::constant ACCOUNT_CLAIMS_INCURRED_CONTROL "6100"
::constant POLICY_BOUND_REF "aji.accounting.policy-bound/0.2"
::constant POLICY_BOUND_IDENTITY "AJIA-0.7-20260828-6D4A0E5CBFB94383#AllJapanInsurancePolicyBoundAccountingPolicy"
::constant PREMIUM_COLLECTED_REF "aji.accounting.premium-collected/0.3"
::constant PREMIUM_COLLECTED_IDENTITY "AJIA-0.8-20260828-PREMIUMCOLLECTED#AllJapanInsurancePremiumCollectedAccountingPolicy"
::constant BILLING_CASH_RECEIVED_REF "aji.accounting.billing-cash-received/0.1"
::constant BILLING_CASH_RECEIVED_IDENTITY "AJIA-0.10-20260828-BILLINGCASH#AllJapanInsuranceBillingCashReceivedAccountingPolicy"
::constant CLAIM_RESERVE_REF "aji.accounting.claim-reserve-change/0.2"
::constant CLAIM_RESERVE_IDENTITY "AJIA-0.7-20260828-6D4A0E5CBFB94383#AllJapanInsuranceClaimReserveAccountingPolicy"
::constant CLAIM_PAID_REF "aji.accounting.claim-paid/0.1"
::constant CLAIM_PAID_IDENTITY "AJIA-0.7-20260828-6D4A0E5CBFB94383#AllJapanInsuranceClaimPaidAccountingPolicy"
::constant PREMIUM_ADJUSTED_REF "aji.accounting.premium-adjusted/0.2"
::constant PREMIUM_ADJUSTED_IDENTITY "AJIA-0.9-20260828-RECOVERY-AUTH#AllJapanInsurancePremiumAdjustedAccountingPolicy"
::constant COMMISSION_PAID_REF "aji.accounting.commission-paid/0.1"
::constant COMMISSION_PAID_IDENTITY "AJIA-0.8-20260828-COMMISSIONPAID#AllJapanInsuranceCommissionPaidAccountingPolicy"
::constant POLICYHOLDER_REFUND_REF "aji.accounting.policyholder-refund-paid/0.1"
::constant POLICYHOLDER_REFUND_IDENTITY "AJIA-0.8-20260828-REFUNDPAID#AllJapanInsurancePolicyholderRefundPaidAccountingPolicy"
::constant COMMISSION_RECOVERED_REF "aji.accounting.commission-recovered/0.1"
::constant COMMISSION_RECOVERED_IDENTITY "AJIA-0.9-20260828-COMMISSIONRECOVERED#AllJapanInsuranceCommissionRecoveredAccountingPolicy"
::constant TAX_REMITTED_REF "aji.accounting.premium-tax-remitted/0.1"
::constant TAX_REMITTED_IDENTITY "AJIA-0.9-20260828-TAXREMITTED#AllJapanInsuranceTaxRemittedAccountingPolicy"
::constant TAX_RECOVERED_REF "aji.accounting.premium-tax-recovered/0.1"
::constant TAX_RECOVERED_IDENTITY "AJIA-0.9-20260828-TAXRECOVERED#AllJapanInsuranceTaxRecoveredAccountingPolicy"

::class AllJapanInsuranceAccountingUtil public
::method nonNegativeWhole class
  use arg value
  numeric digits 50
  if value==.nil then return .false
  signal on syntax name bad
  n=value+0
  signal off syntax
  return n>=0 & n=n~trunc
bad:
  signal off syntax
  return .false
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
::method requireFunctionalCurrency class
  use arg event
  currency=.AllJapanInsuranceCanonical~token(event~value("currency",""))
  if currency="" then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_CURRENCY_REQUIRED",event~sourceEventRef)
  if currency\=.AllJapanInsuranceAccountingBuild~FUNCTIONAL_CURRENCY then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_FUNCTIONAL_CURRENCY_MISMATCH",currency)
  return .nil
::method dimensionsFor class
  use arg event
  d=.directory~new
  do key over .array~of("policyId","policyNumber","termNumber","quoteId","ratingId","claimId","assessmentId","paymentId","payeeRef","productCode","instalmentId","attemptId","adjustmentId","settlementId","producerRef","refundId","recoveryId","receiptId","taxAuthorityRef","remittanceId","billingReceiptId")
    value=event~value(key,.nil)
    if value\==.nil & value~string\="" then d[key]=value
  end
  return d
::method appendEvidence class
  use arg target, value
  if value==.nil | value~string="" then return .true
  text=value~string
  do existing over target
    if existing~string=text then return .true
  end
  target~append(text)
  return .true
::method claimOutstandingMinor class
  use arg book, claimIdArg
  numeric digits 50
  if book==.nil | \book~isA(.AccountingBook) then return .nil
  claimId=claimIdArg~string
  if claimId="" then return .nil
  total=0
  do entry over book~entries
    do line over entry~lines
      if line~accountId\=.AllJapanInsuranceAccountingBuild~ACCOUNT_CLAIMS_OUTSTANDING then iterate
      if line~currency\=.AllJapanInsuranceAccountingBuild~FUNCTIONAL_CURRENCY then iterate
      dims=line~dimensions
      if \dims~hasIndex("claimId") then iterate
      if dims["claimId"]~string\=claimId then iterate
      total += line~creditMinor - line~debitMinor
    end
  end
  return total

::method policyAccountNetDebitMinor class
  use arg book,accountIdArg,policyIdArg
  numeric digits 50
  if book==.nil | \book~isA(.AccountingBook) then return .nil
  policyId=policyIdArg~string
  accountId=accountIdArg~string
  if policyId="" | accountId="" then return .nil
  total=0
  do entry over book~entries
    do line over entry~lines
      if line~accountId\=accountId then iterate
      if line~currency\=.AllJapanInsuranceAccountingBuild~FUNCTIONAL_CURRENCY then iterate
      dims=line~dimensions
      if \dims~hasIndex("policyId") then iterate
      if dims["policyId"]~string\=policyId then iterate
      total += line~debitMinor-line~creditMinor
    end
  end
  return total
::method policyAccountNetCreditMinor class
  use arg book,accountIdArg,policyIdArg
  value=self~policyAccountNetDebitMinor(book,accountIdArg,policyIdArg)
  if value==.nil then return .nil
  return -value

::class AllJapanInsuranceAccountingFactory public
::method engine class
  use arg periodIdArg="2026", startDateArg="2026-01-01", endDateArg="2026-12-31", reportingBasisArg="ENTITY_GAAP"
  engine=.AccountingEngine~new(.AllJapanInsuranceAccountingBuild~LEGAL_ENTITY_ID,.AllJapanInsuranceAccountingBuild~BOOK_ID,reportingBasisArg)
  self~ensureChart(engine~book)
  if engine~book~period(periodIdArg)==.nil then engine~book~addPeriod(.AccountingPeriod~new(periodIdArg,startDateArg,endDateArg))
  self~registerPolicies(engine,startDateArg,endDateArg)
  return engine
::method createDurable class
  use arg storePathArg, periodIdArg="2026", startDateArg="2026-01-01", endDateArg="2026-12-31", reportingBasisArg="ENTITY_GAAP"
  store=.AccountingFileStore~new(storePathArg)
  book=store~createBook(.AllJapanInsuranceAccountingBuild~LEGAL_ENTITY_ID,.AllJapanInsuranceAccountingBuild~BOOK_ID,reportingBasisArg)
  self~ensureChart(book)
  book~addPeriod(.AccountingPeriod~new(periodIdArg,startDateArg,endDateArg))
  engine=.AccountingEngine~new(book~legalEntityId,book~bookId,book~reportingBasis,book)
  self~registerPolicies(engine,startDateArg,endDateArg)
  return engine
::method recoverDurable class
  use arg storePathArg, policyFromArg="2026-01-01", policyToArg=""
  store=.AccountingFileStore~new(storePathArg)
  book=store~recoverBook
  if book~legalEntityId\=.AllJapanInsuranceAccountingBuild~LEGAL_ENTITY_ID then raise syntax 93.900 additional("Recovered AJI book legal entity mismatch")
  if book~bookId\=.AllJapanInsuranceAccountingBuild~BOOK_ID then raise syntax 93.900 additional("Recovered AJI book id mismatch")
  self~ensureChart(book)
  engine=.AccountingEngine~new(book~legalEntityId,book~bookId,book~reportingBasis,book)
  self~registerPolicies(engine,policyFromArg,policyToArg)
  return engine
::method ensureChart private class
  use arg book
  chart=book~chart
  if chart~isSealed then do
    do id over .array~of("1000","1100","2200","2210","2220","2230","6100")
      if \chart~contains(id) then raise syntax 93.900 additional("Recovered AJI chart missing account: " || id)
    end
    return .true
  end
  ccy=.AllJapanInsuranceAccountingBuild~FUNCTIONAL_CURRENCY
  chart~add(.AccountingAccount~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_CASH,"Cash","ASSET","AUTO","SINGLE",.true,ccy))
  chart~add(.AccountingAccount~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_PREMIUM_RECEIVABLE,"Premium receivable","ASSET","AUTO","SINGLE",.true,ccy))
  chart~add(.AccountingAccount~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_INSURANCE_PREMIUM_CONTROL,"Insurance contract premium control","LIABILITY","AUTO","SINGLE",.true,ccy))
  chart~add(.AccountingAccount~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_COMMISSION_PAYABLE,"Commission payable","LIABILITY","AUTO","SINGLE",.true,ccy))
  chart~add(.AccountingAccount~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_TAX_PAYABLE,"Premium tax payable","LIABILITY","AUTO","SINGLE",.true,ccy))
  chart~add(.AccountingAccount~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_CLAIMS_OUTSTANDING,"Claims outstanding / reserve control","LIABILITY","AUTO","SINGLE",.true,ccy))
  chart~add(.AccountingAccount~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_CLAIMS_INCURRED_CONTROL,"Claims incurred control","EXPENSE","AUTO","SINGLE",.true,ccy))
  chart~seal
  return .true
::method registerPolicies private class
  use arg engine, fromArg, toArg=""
  entity=.AllJapanInsuranceAccountingBuild~LEGAL_ENTITY_ID
  engine~registerPolicy(.AllJapanInsurancePolicyBoundAccountingPolicy~new(.AllJapanInsuranceAccountingBuild~POLICY_BOUND_REF,.AllJapanInsuranceAccountingBuild~POLICY_BOUND_IDENTITY,entity,.AllJapanInsuranceAccountingBuild~EVENT_POLICY_BOUND,fromArg,toArg))
  engine~registerPolicy(.AllJapanInsurancePremiumCollectedAccountingPolicy~new(.AllJapanInsuranceAccountingBuild~PREMIUM_COLLECTED_REF,.AllJapanInsuranceAccountingBuild~PREMIUM_COLLECTED_IDENTITY,entity,.AllJapanInsuranceAccountingBuild~EVENT_PREMIUM_COLLECTED,fromArg,toArg))
  engine~registerPolicy(.AllJapanInsuranceBillingCashReceivedAccountingPolicy~new(.AllJapanInsuranceAccountingBuild~BILLING_CASH_RECEIVED_REF,.AllJapanInsuranceAccountingBuild~BILLING_CASH_RECEIVED_IDENTITY,entity,.AllJapanInsuranceAccountingBuild~EVENT_BILLING_CASH_RECEIVED,fromArg,toArg))
  engine~registerPolicy(.AllJapanInsuranceClaimReserveAccountingPolicy~new(.AllJapanInsuranceAccountingBuild~CLAIM_RESERVE_REF,.AllJapanInsuranceAccountingBuild~CLAIM_RESERVE_IDENTITY,entity,.AllJapanInsuranceAccountingBuild~EVENT_CLAIM_RESERVE_CHANGED,fromArg,toArg))
  engine~registerPolicy(.AllJapanInsuranceClaimPaidAccountingPolicy~new(.AllJapanInsuranceAccountingBuild~CLAIM_PAID_REF,.AllJapanInsuranceAccountingBuild~CLAIM_PAID_IDENTITY,entity,.AllJapanInsuranceAccountingBuild~EVENT_CLAIM_PAID,fromArg,toArg))
  engine~registerPolicy(.AllJapanInsurancePremiumAdjustedAccountingPolicy~new(.AllJapanInsuranceAccountingBuild~PREMIUM_ADJUSTED_REF,.AllJapanInsuranceAccountingBuild~PREMIUM_ADJUSTED_IDENTITY,entity,.AllJapanInsuranceAccountingBuild~EVENT_PREMIUM_ADJUSTED,fromArg,toArg))
  engine~registerPolicy(.AllJapanInsuranceCommissionPaidAccountingPolicy~new(.AllJapanInsuranceAccountingBuild~COMMISSION_PAID_REF,.AllJapanInsuranceAccountingBuild~COMMISSION_PAID_IDENTITY,entity,.AllJapanInsuranceAccountingBuild~EVENT_COMMISSION_PAID,fromArg,toArg))
  engine~registerPolicy(.AllJapanInsurancePolicyholderRefundPaidAccountingPolicy~new(.AllJapanInsuranceAccountingBuild~POLICYHOLDER_REFUND_REF,.AllJapanInsuranceAccountingBuild~POLICYHOLDER_REFUND_IDENTITY,entity,.AllJapanInsuranceAccountingBuild~EVENT_POLICYHOLDER_REFUND_PAID,fromArg,toArg))
  engine~registerPolicy(.AllJapanInsuranceCommissionRecoveredAccountingPolicy~new(.AllJapanInsuranceAccountingBuild~COMMISSION_RECOVERED_REF,.AllJapanInsuranceAccountingBuild~COMMISSION_RECOVERED_IDENTITY,entity,.AllJapanInsuranceAccountingBuild~EVENT_COMMISSION_RECOVERED,fromArg,toArg))
  engine~registerPolicy(.AllJapanInsuranceTaxRemittedAccountingPolicy~new(.AllJapanInsuranceAccountingBuild~TAX_REMITTED_REF,.AllJapanInsuranceAccountingBuild~TAX_REMITTED_IDENTITY,entity,.AllJapanInsuranceAccountingBuild~EVENT_TAX_REMITTED,fromArg,toArg))
  engine~registerPolicy(.AllJapanInsuranceTaxRecoveredAccountingPolicy~new(.AllJapanInsuranceAccountingBuild~TAX_RECOVERED_REF,.AllJapanInsuranceAccountingBuild~TAX_RECOVERED_IDENTITY,entity,.AllJapanInsuranceAccountingBuild~EVENT_TAX_RECOVERED,fromArg,toArg))
  return .true

::class AllJapanInsurancePolicyBoundAccountingPolicy subclass AccountingPolicy
::method init
  use arg refArg,identityArg,entityArg,typeArg,fromArg,toArg=""
  self~init:super(refArg,identityArg,entityArg,typeArg,fromArg,toArg)
::method propose
  use arg event,book
  rejection=.AllJapanInsuranceAccountingUtil~requireFunctionalCurrency(event)
  if rejection\==.nil then return rejection
  risk=event~value("riskPremiumMinor",.nil)
  sales=event~value("salesCostMinor",.nil)
  tax=event~value("taxMinor",.nil)
  total=event~value("totalPremiumMinor",.nil)
  if \.AllJapanInsuranceAccountingUtil~nonNegativeWhole(risk) | \.AllJapanInsuranceAccountingUtil~nonNegativeWhole(sales) | \.AllJapanInsuranceAccountingUtil~nonNegativeWhole(tax) | \.AllJapanInsuranceAccountingUtil~nonNegativeWhole(total) then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_PREMIUM_COMPONENT_INVALID",event~sourceEventRef)
  if risk+sales+tax\=total then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_PREMIUM_COMPONENTS_UNBALANCED",event~sourceEventRef)
  if total=0 then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_ZERO_PREMIUM",event~sourceEventRef)
  treatment=.AllJapanInsuranceCanonical~token(event~value("salesCostTreatment",.AllJapanInsuranceAccountingBuild~SALES_PREMIUM_CONTROL))
  if treatment\=.AllJapanInsuranceAccountingBuild~SALES_PREMIUM_CONTROL & treatment\=.AllJapanInsuranceAccountingBuild~SALES_COMMISSION_PAYABLE then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_SALES_TREATMENT_INVALID",treatment)
  ccy=.AllJapanInsuranceAccountingBuild~FUNCTIONAL_CURRENCY
  d=self~newDraft(event,book,event~eventDate,"AJI policy bound - premium control recognition")
  dims=.AllJapanInsuranceAccountingUtil~dimensionsFor(event)
  d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_PREMIUM_RECEIVABLE,ccy,total,0,"Premium receivable",dims))
  premiumControl=risk
  if treatment=.AllJapanInsuranceAccountingBuild~SALES_PREMIUM_CONTROL then premiumControl+=sales
  if premiumControl>0 then d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_INSURANCE_PREMIUM_CONTROL,ccy,0,premiumControl,"Insurance contract premium control",dims))
  if treatment=.AllJapanInsuranceAccountingBuild~SALES_COMMISSION_PAYABLE & sales>0 then d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_COMMISSION_PAYABLE,ccy,0,sales,"Commission payable",dims))
  if tax>0 then d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_TAX_PAYABLE,ccy,0,tax,"Premium tax payable",dims))
  return .AccountingPolicyDecision~accept(d,"Initial policy premium decomposition; revenue recognition remains separate accounting policy")

::class AllJapanInsurancePremiumCollectedAccountingPolicy subclass AccountingPolicy
::method init
  use arg refArg,identityArg,entityArg,typeArg,fromArg,toArg=""
  self~init:super(refArg,identityArg,entityArg,typeArg,fromArg,toArg)
::method propose
  use arg event,book
  rejection=.AllJapanInsuranceAccountingUtil~requireFunctionalCurrency(event)
  if rejection\==.nil then return rejection
  amount=event~value("amountMinor",.nil)
  if \.AllJapanInsuranceAccountingUtil~nonNegativeWhole(amount) | amount=0 then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_COLLECTION_AMOUNT_INVALID",event~sourceEventRef)
  policyId=event~value("policyId","")~string
  if policyId="" then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_POLICY_ID_REQUIRED",event~sourceEventRef)
  receivable=.AllJapanInsuranceAccountingUtil~policyAccountNetDebitMinor(book,.AllJapanInsuranceAccountingBuild~ACCOUNT_PREMIUM_RECEIVABLE,policyId)
  if receivable==.nil | receivable<amount then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_COLLECTION_EXCEEDS_RECEIVABLE",receivable)
  ccy=.AllJapanInsuranceAccountingBuild~FUNCTIONAL_CURRENCY
  dims=.AllJapanInsuranceAccountingUtil~dimensionsFor(event)
  d=self~newDraft(event,book,event~eventDate,"AJI premium collection")
  d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_CASH,ccy,amount,0,"Premium cash received",dims))
  d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_PREMIUM_RECEIVABLE,ccy,0,amount,"Premium receivable settled",dims))
  return .AccountingPolicyDecision~accept(d,"Collection clears the JPY premium receivable")


::class AllJapanInsuranceBillingCashReceivedAccountingPolicy subclass AccountingPolicy
::method init
  use arg refArg,identityArg,entityArg,typeArg,fromArg,toArg=""
  self~init:super(refArg,identityArg,entityArg,typeArg,fromArg,toArg)
::method propose
  use arg event,book
  rejection=.AllJapanInsuranceAccountingUtil~requireFunctionalCurrency(event)
  if rejection\==.nil then return rejection
  amount=event~value("amountMinor",.nil)
  applied=event~value("appliedAtReceiptMinor",.nil)
  unapplied=event~value("unappliedAtReceiptMinor",.nil)
  if \.AllJapanInsuranceAccountingUtil~nonNegativeWhole(amount) | amount=0 | \.AllJapanInsuranceAccountingUtil~nonNegativeWhole(applied) | \.AllJapanInsuranceAccountingUtil~nonNegativeWhole(unapplied) then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_BILLING_RECEIPT_AMOUNT_INVALID",event~sourceEventRef)
  if applied+unapplied\=amount then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_BILLING_RECEIPT_ALLOCATION_MISMATCH",event~sourceEventRef)
  if event~value("paymentRef","")~string="" | event~value("bankEvidenceRef","")~string="" then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_BILLING_RECEIPT_EVIDENCE_REQUIRED",event~sourceEventRef)
  policyId=event~value("policyId","")~string
  if policyId="" then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_POLICY_ID_REQUIRED",event~sourceEventRef)
  ccy=.AllJapanInsuranceAccountingBuild~FUNCTIONAL_CURRENCY
  dims=.AllJapanInsuranceAccountingUtil~dimensionsFor(event)
  d=self~newDraft(event,book,event~eventDate,"AJI billing cash receipt")
  d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_CASH,ccy,amount,0,"Billing cash received",dims))
  d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_PREMIUM_RECEIVABLE,ccy,0,amount,"Premium receivable / customer credit control",dims))
  return .AccountingPolicyDecision~accept(d,"Billing receipt may create an unapplied customer credit; billing allocation remains operational truth")

::class AllJapanInsuranceClaimReserveAccountingPolicy subclass AccountingPolicy
::method init
  use arg refArg,identityArg,entityArg,typeArg,fromArg,toArg=""
  self~init:super(refArg,identityArg,entityArg,typeArg,fromArg,toArg)
::method propose
  use arg event,book
  rejection=.AllJapanInsuranceAccountingUtil~requireFunctionalCurrency(event)
  if rejection\==.nil then return rejection
  before=event~value("reserveBeforeMinor",.nil)
  delta=.AllJapanInsuranceAccountingUtil~signedWhole(event~value("reserveDeltaMinor",.nil))
  after=event~value("reserveAfterMinor",.nil)
  if \.AllJapanInsuranceAccountingUtil~nonNegativeWhole(before) | delta==.nil | \.AllJapanInsuranceAccountingUtil~nonNegativeWhole(after) then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_CLAIM_RESERVE_INVALID",event~sourceEventRef)
  if delta=0 then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_CLAIM_RESERVE_NO_CHANGE",event~sourceEventRef)
  if before+delta\=after then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_CLAIM_RESERVE_DELTA_MISMATCH",event~sourceEventRef)
  claimId=event~value("claimId","")~string
  current=.AllJapanInsuranceAccountingUtil~claimOutstandingMinor(book,claimId)
  if current==.nil then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_CLAIM_ID_REQUIRED",event~sourceEventRef)
  if current\=before then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_CLAIM_OUTSTANDING_MISMATCH",current)
  ccy=.AllJapanInsuranceAccountingBuild~FUNCTIONAL_CURRENCY
  dims=.AllJapanInsuranceAccountingUtil~dimensionsFor(event)
  d=self~newDraft(event,book,event~eventDate,"AJI claim reserve change")
  if delta>0 then do
    d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_CLAIMS_INCURRED_CONTROL,ccy,delta,0,"Increase claims incurred control",dims))
    d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_CLAIMS_OUTSTANDING,ccy,0,delta,"Increase claims outstanding",dims))
  end
  else do
    amount=-delta
    d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_CLAIMS_OUTSTANDING,ccy,amount,0,"Release claims outstanding",dims))
    d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_CLAIMS_INCURRED_CONTROL,ccy,0,amount,"Release claims incurred control",dims))
  end
  return .AccountingPolicyDecision~accept(d,"Claim reserve movement follows authoritative AJI assessment and current claim-specific outstanding")

::class AllJapanInsuranceClaimPaidAccountingPolicy subclass AccountingPolicy
::method init
  use arg refArg,identityArg,entityArg,typeArg,fromArg,toArg=""
  self~init:super(refArg,identityArg,entityArg,typeArg,fromArg,toArg)
::method propose
  use arg event,book
  rejection=.AllJapanInsuranceAccountingUtil~requireFunctionalCurrency(event)
  if rejection\==.nil then return rejection
  amount=event~value("amountMinor",.nil)
  before=event~value("reserveBeforeMinor",.nil)
  after=event~value("reserveAfterMinor",.nil)
  paidBefore=event~value("paidToDateBeforeMinor",.nil)
  paidAfter=event~value("paidToDateAfterMinor",.nil)
  if \.AllJapanInsuranceAccountingUtil~nonNegativeWhole(amount) | amount=0 then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_CLAIM_PAYMENT_AMOUNT_INVALID",event~sourceEventRef)
  if \.AllJapanInsuranceAccountingUtil~nonNegativeWhole(before) | \.AllJapanInsuranceAccountingUtil~nonNegativeWhole(after) then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_CLAIM_PAYMENT_RESERVE_INVALID",event~sourceEventRef)
  if \.AllJapanInsuranceAccountingUtil~nonNegativeWhole(paidBefore) | \.AllJapanInsuranceAccountingUtil~nonNegativeWhole(paidAfter) then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_CLAIM_PAYMENT_CUMULATIVE_INVALID",event~sourceEventRef)
  if amount>before | before-amount\=after then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_CLAIM_PAYMENT_RESERVE_MISMATCH",event~sourceEventRef)
  if paidBefore+amount\=paidAfter then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_CLAIM_PAYMENT_CUMULATIVE_MISMATCH",event~sourceEventRef)
  if event~value("paymentRef","")~string="" then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_CLAIM_PAYMENT_EVIDENCE_REQUIRED",event~sourceEventRef)
  claimId=event~value("claimId","")~string
  current=.AllJapanInsuranceAccountingUtil~claimOutstandingMinor(book,claimId)
  if current==.nil then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_CLAIM_ID_REQUIRED",event~sourceEventRef)
  if current\=before then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_CLAIM_OUTSTANDING_MISMATCH",current)
  ccy=.AllJapanInsuranceAccountingBuild~FUNCTIONAL_CURRENCY
  dims=.AllJapanInsuranceAccountingUtil~dimensionsFor(event)
  d=self~newDraft(event,book,event~eventDate,"AJI claim cash settlement")
  d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_CLAIMS_OUTSTANDING,ccy,amount,0,"Settle claims outstanding",dims))
  d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_CASH,ccy,0,amount,"Claim cash paid",dims))
  return .AccountingPolicyDecision~accept(d,"Cash settlement consumes previously recognised claim outstanding; it does not rewrite incurred loss")

::class AllJapanInsurancePremiumAdjustedAccountingPolicy subclass AccountingPolicy
::method init
  use arg refArg,identityArg,entityArg,typeArg,fromArg,toArg=""
  self~init:super(refArg,identityArg,entityArg,typeArg,fromArg,toArg)
::method propose
  use arg event,book
  numeric digits 50
  rejection=.AllJapanInsuranceAccountingUtil~requireFunctionalCurrency(event)
  if rejection\==.nil then return rejection
  risk=.AllJapanInsuranceAccountingUtil~signedWhole(event~value("riskDeltaMinor",.nil))
  sales=.AllJapanInsuranceAccountingUtil~signedWhole(event~value("salesDeltaMinor",.nil))
  tax=.AllJapanInsuranceAccountingUtil~signedWhole(event~value("taxDeltaMinor",.nil))
  total=.AllJapanInsuranceAccountingUtil~signedWhole(event~value("totalDeltaMinor",.nil))
  if risk==.nil | sales==.nil | tax==.nil | total==.nil | total=0 then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_PREMIUM_ADJUSTMENT_INVALID",event~sourceEventRef)
  if risk+sales+tax\=total then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_PREMIUM_ADJUSTMENT_UNBALANCED",event~sourceEventRef)
  if event~value("calculationRef","")~string="" | event~value("calculationFunctionRef","")~string="" then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_PREMIUM_ADJUSTMENT_CALCULATION_REQUIRED",event~sourceEventRef)
  treatment=.AllJapanInsuranceCanonical~token(event~value("salesCostTreatment",""))
  if treatment\=.AllJapanInsuranceAccountingBuild~SALES_PREMIUM_CONTROL & treatment\=.AllJapanInsuranceAccountingBuild~SALES_COMMISSION_PAYABLE then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_SALES_TREATMENT_INVALID",treatment)
  policyId=event~value("policyId","")~string
  if policyId="" then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_POLICY_ID_REQUIRED",event~sourceEventRef)
  ccy=.AllJapanInsuranceAccountingBuild~FUNCTIONAL_CURRENCY
  dims=.AllJapanInsuranceAccountingUtil~dimensionsFor(event)
  d=self~newDraft(event,book,event~eventDate,"AJI policy premium adjustment")
  /* Apply component economics first. Positive delta credits the relevant
   * control/payable. Negative delta reverses it and must not manufacture a
   * debit liability; commission clawback remains a separate future event. */
  if risk>0 then d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_INSURANCE_PREMIUM_CONTROL,ccy,0,risk,"Increase insurance premium control",dims))
  else if risk<0 then do
    amount=-risk
    current=.AllJapanInsuranceAccountingUtil~policyAccountNetCreditMinor(book,.AllJapanInsuranceAccountingBuild~ACCOUNT_INSURANCE_PREMIUM_CONTROL,policyId)
    if current<amount then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_PREMIUM_CONTROL_REVERSAL_EXCEEDS_POSITION",current)
    d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_INSURANCE_PREMIUM_CONTROL,ccy,amount,0,"Reverse insurance premium control",dims))
  end
  if sales\=0 then do
    if treatment=.AllJapanInsuranceAccountingBuild~SALES_PREMIUM_CONTROL then do
      if sales>0 then d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_INSURANCE_PREMIUM_CONTROL,ccy,0,sales,"Increase sales premium control",dims))
      else do
        amount=-sales
        current=.AllJapanInsuranceAccountingUtil~policyAccountNetCreditMinor(book,.AllJapanInsuranceAccountingBuild~ACCOUNT_INSURANCE_PREMIUM_CONTROL,policyId)
        /* Risk reversal lines in this draft are not in book yet. Account for
         * the preceding risk reversal when testing aggregate availability. */
        if risk<0 then current+=risk
        if current<amount then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_SALES_CONTROL_REVERSAL_EXCEEDS_POSITION",current)
        d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_INSURANCE_PREMIUM_CONTROL,ccy,amount,0,"Reverse sales premium control",dims))
      end
    end
    else do
      if sales>0 then d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_COMMISSION_PAYABLE,ccy,0,sales,"Increase commission payable",dims))
      else do
        amount=-sales
        current=.AllJapanInsuranceAccountingUtil~policyAccountNetCreditMinor(book,.AllJapanInsuranceAccountingBuild~ACCOUNT_COMMISSION_PAYABLE,policyId)
        if current<amount then do
          requiredRecovery=amount-current
          recoveryRef=event~value("commissionRecoveryRef","")~string
          recoveryMinor=.AllJapanInsuranceAccountingUtil~signedWhole(event~value("commissionRecoveryMinor",.nil))
          producerRef=event~value("producerRef","")~string
          if recoveryRef="" | producerRef="" | recoveryMinor==.nil | recoveryMinor\=requiredRecovery then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_COMMISSION_CLAWBACK_REQUIRED",requiredRecovery)
          d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_COMMISSION_PAYABLE,ccy,amount,0,"Reverse commission and establish authorised producer recovery",dims))
        end
        else d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_COMMISSION_PAYABLE,ccy,amount,0,"Reverse unpaid commission payable",dims))
      end
    end
  end
  if tax>0 then d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_TAX_PAYABLE,ccy,0,tax,"Increase premium tax payable",dims))
  else if tax<0 then do
    amount=-tax
    current=.AllJapanInsuranceAccountingUtil~policyAccountNetCreditMinor(book,.AllJapanInsuranceAccountingBuild~ACCOUNT_TAX_PAYABLE,policyId)
    if current<amount then do
      requiredRecovery=amount-current
      recoveryRef=event~value("taxRecoveryRef","")~string
      recoveryMinor=.AllJapanInsuranceAccountingUtil~signedWhole(event~value("taxRecoveryMinor",.nil))
      taxAuthorityRef=event~value("taxAuthorityRef","")~string
      if recoveryRef="" | taxAuthorityRef="" | recoveryMinor==.nil | recoveryMinor\=requiredRecovery then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_TAX_RECOVERY_POLICY_REQUIRED",requiredRecovery)
      d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_TAX_PAYABLE,ccy,amount,0,"Reverse premium tax and establish authorised tax recovery",dims))
    end
    else d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_TAX_PAYABLE,ccy,amount,0,"Reverse unpaid premium tax",dims))
  end
  /* The policyholder control remains account 1100. A debit balance is premium
   * receivable; a credit balance is return premium due. This preserves the
   * durable v0.7 chart while making the sign explicit in policy behaviour. */
  if total>0 then d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_PREMIUM_RECEIVABLE,ccy,total,0,"Additional premium receivable",dims))
  else d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_PREMIUM_RECEIVABLE,ccy,0,-total,"Return premium / policyholder credit",dims))
  return .AccountingPolicyDecision~accept(d,"Calculation-backed endorsement/cancellation adjusts written premium controls without rerating historical bound term")

::class AllJapanInsuranceCommissionPaidAccountingPolicy subclass AccountingPolicy
::method init
  use arg refArg,identityArg,entityArg,typeArg,fromArg,toArg=""
  self~init:super(refArg,identityArg,entityArg,typeArg,fromArg,toArg)
::method propose
  use arg event,book
  rejection=.AllJapanInsuranceAccountingUtil~requireFunctionalCurrency(event)
  if rejection\==.nil then return rejection
  amount=event~value("amountMinor",.nil)
  if \.AllJapanInsuranceAccountingUtil~nonNegativeWhole(amount) | amount=0 then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_COMMISSION_PAYMENT_INVALID",event~sourceEventRef)
  if event~value("paymentRef","")~string="" | event~value("bankEvidenceRef","")~string="" then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_COMMISSION_BANK_EVIDENCE_REQUIRED",event~sourceEventRef)
  policyId=event~value("policyId","")~string
  current=.AllJapanInsuranceAccountingUtil~policyAccountNetCreditMinor(book,.AllJapanInsuranceAccountingBuild~ACCOUNT_COMMISSION_PAYABLE,policyId)
  if current==.nil | current<amount then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_COMMISSION_PAYMENT_EXCEEDS_PAYABLE",current)
  ccy=.AllJapanInsuranceAccountingBuild~FUNCTIONAL_CURRENCY
  dims=.AllJapanInsuranceAccountingUtil~dimensionsFor(event)
  d=self~newDraft(event,book,event~eventDate,"AJI producer commission settlement")
  d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_COMMISSION_PAYABLE,ccy,amount,0,"Commission payable settled",dims))
  d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_CASH,ccy,0,amount,"Commission cash paid",dims))
  return .AccountingPolicyDecision~accept(d,"Producer settlement consumes an existing policy-specific commission payable and requires bank evidence")

::class AllJapanInsurancePolicyholderRefundPaidAccountingPolicy subclass AccountingPolicy
::method init
  use arg refArg,identityArg,entityArg,typeArg,fromArg,toArg=""
  self~init:super(refArg,identityArg,entityArg,typeArg,fromArg,toArg)
::method propose
  use arg event,book
  rejection=.AllJapanInsuranceAccountingUtil~requireFunctionalCurrency(event)
  if rejection\==.nil then return rejection
  amount=event~value("amountMinor",.nil)
  if \.AllJapanInsuranceAccountingUtil~nonNegativeWhole(amount) | amount=0 then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_REFUND_PAYMENT_INVALID",event~sourceEventRef)
  if event~value("paymentRef","")~string="" | event~value("bankEvidenceRef","")~string="" then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_REFUND_BANK_EVIDENCE_REQUIRED",event~sourceEventRef)
  policyId=event~value("policyId","")~string
  receivable=.AllJapanInsuranceAccountingUtil~policyAccountNetDebitMinor(book,.AllJapanInsuranceAccountingBuild~ACCOUNT_PREMIUM_RECEIVABLE,policyId)
  if receivable==.nil | receivable>-amount then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_REFUND_EXCEEDS_POLICYHOLDER_CREDIT",receivable)
  ccy=.AllJapanInsuranceAccountingBuild~FUNCTIONAL_CURRENCY
  dims=.AllJapanInsuranceAccountingUtil~dimensionsFor(event)
  d=self~newDraft(event,book,event~eventDate,"AJI policyholder return premium payment")
  d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_PREMIUM_RECEIVABLE,ccy,amount,0,"Clear policyholder premium credit",dims))
  d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_CASH,ccy,0,amount,"Return premium cash paid",dims))
  return .AccountingPolicyDecision~accept(d,"Cash refund clears an existing credit balance in policy premium control")

::class AllJapanInsuranceCommissionRecoveredAccountingPolicy subclass AccountingPolicy
::method init
  use arg refArg,identityArg,entityArg,typeArg,fromArg,toArg=""
  self~init:super(refArg,identityArg,entityArg,typeArg,fromArg,toArg)
::method propose
  use arg event,book
  rejection=.AllJapanInsuranceAccountingUtil~requireFunctionalCurrency(event)
  if rejection\==.nil then return rejection
  amount=event~value("amountMinor",.nil)
  if \.AllJapanInsuranceAccountingUtil~nonNegativeWhole(amount) | amount=0 then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_COMMISSION_RECOVERY_INVALID",event~sourceEventRef)
  if event~value("recoveryId","")~string="" | event~value("producerRef","")~string="" | event~value("paymentRef","")~string="" | event~value("bankEvidenceRef","")~string="" then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_COMMISSION_RECOVERY_EVIDENCE_REQUIRED",event~sourceEventRef)
  policyId=event~value("policyId","")~string
  debit=.AllJapanInsuranceAccountingUtil~policyAccountNetDebitMinor(book,.AllJapanInsuranceAccountingBuild~ACCOUNT_COMMISSION_PAYABLE,policyId)
  if debit==.nil | debit<amount then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_COMMISSION_RECOVERY_EXCEEDS_RECEIVABLE",debit)
  ccy=.AllJapanInsuranceAccountingBuild~FUNCTIONAL_CURRENCY; dims=.AllJapanInsuranceAccountingUtil~dimensionsFor(event)
  d=self~newDraft(event,book,event~eventDate,"AJI producer commission recovery receipt")
  d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_CASH,ccy,amount,0,"Producer recovery cash received",dims))
  d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_COMMISSION_PAYABLE,ccy,0,amount,"Clear producer commission recovery control",dims))
  return .AccountingPolicyDecision~accept(d,"Explicit recovery receipt clears an authorised debit producer-settlement-control position")

::class AllJapanInsuranceTaxRemittedAccountingPolicy subclass AccountingPolicy
::method init
  use arg refArg,identityArg,entityArg,typeArg,fromArg,toArg=""
  self~init:super(refArg,identityArg,entityArg,typeArg,fromArg,toArg)
::method propose
  use arg event,book
  rejection=.AllJapanInsuranceAccountingUtil~requireFunctionalCurrency(event)
  if rejection\==.nil then return rejection
  amount=event~value("amountMinor",.nil)
  if \.AllJapanInsuranceAccountingUtil~nonNegativeWhole(amount) | amount=0 then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_TAX_REMITTANCE_INVALID",event~sourceEventRef)
  if event~value("taxAuthorityRef","")~string="" | event~value("paymentRef","")~string="" | event~value("bankEvidenceRef","")~string="" then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_TAX_REMITTANCE_EVIDENCE_REQUIRED",event~sourceEventRef)
  policyId=event~value("policyId","")~string
  current=.AllJapanInsuranceAccountingUtil~policyAccountNetCreditMinor(book,.AllJapanInsuranceAccountingBuild~ACCOUNT_TAX_PAYABLE,policyId)
  if current==.nil | current<amount then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_TAX_REMITTANCE_EXCEEDS_PAYABLE",current)
  ccy=.AllJapanInsuranceAccountingBuild~FUNCTIONAL_CURRENCY; dims=.AllJapanInsuranceAccountingUtil~dimensionsFor(event)
  d=self~newDraft(event,book,event~eventDate,"AJI premium tax remittance")
  d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_TAX_PAYABLE,ccy,amount,0,"Premium tax liability remitted",dims))
  d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_CASH,ccy,0,amount,"Premium tax cash remitted",dims))
  return .AccountingPolicyDecision~accept(d,"Tax remittance consumes only an existing policy-attributed tax payable")

::class AllJapanInsuranceTaxRecoveredAccountingPolicy subclass AccountingPolicy
::method init
  use arg refArg,identityArg,entityArg,typeArg,fromArg,toArg=""
  self~init:super(refArg,identityArg,entityArg,typeArg,fromArg,toArg)
::method propose
  use arg event,book
  rejection=.AllJapanInsuranceAccountingUtil~requireFunctionalCurrency(event)
  if rejection\==.nil then return rejection
  amount=event~value("amountMinor",.nil)
  if \.AllJapanInsuranceAccountingUtil~nonNegativeWhole(amount) | amount=0 then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_TAX_RECOVERY_INVALID",event~sourceEventRef)
  if event~value("recoveryId","")~string="" | event~value("taxAuthorityRef","")~string="" | event~value("paymentRef","")~string="" | event~value("bankEvidenceRef","")~string="" then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_TAX_RECOVERY_EVIDENCE_REQUIRED",event~sourceEventRef)
  policyId=event~value("policyId","")~string
  debit=.AllJapanInsuranceAccountingUtil~policyAccountNetDebitMinor(book,.AllJapanInsuranceAccountingBuild~ACCOUNT_TAX_PAYABLE,policyId)
  if debit==.nil | debit<amount then return .AccountingPolicyDecision~reject("AJI_ACCOUNTING_TAX_RECOVERY_EXCEEDS_RECEIVABLE",debit)
  ccy=.AllJapanInsuranceAccountingBuild~FUNCTIONAL_CURRENCY; dims=.AllJapanInsuranceAccountingUtil~dimensionsFor(event)
  d=self~newDraft(event,book,event~eventDate,"AJI premium tax recovery receipt")
  d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_CASH,ccy,amount,0,"Premium tax recovery cash received",dims))
  d~addLine(.AccountingJournalLine~new(.AllJapanInsuranceAccountingBuild~ACCOUNT_TAX_PAYABLE,ccy,0,amount,"Clear premium tax recovery control",dims))
  return .AccountingPolicyDecision~accept(d,"Explicit tax recovery receipt clears an authorised debit tax-settlement-control position")

::class AllJapanInsuranceAccountingAdapter public
::attribute authority get
::attribute transactionAuthority get
::method init
  expose authority transactionAuthority
  use arg authorityArg,transactionAuthorityArg=.nil
  authority=authorityArg
  transactionAuthority=transactionAuthorityArg
::method policyBoundEvent
  expose authority
  use arg policyIdArg,eventDateArg,correlationRefArg="",counterpartyEntityIdArg="",salesTreatmentArg="PREMIUM_CONTROL",evidenceArg=.nil
  if authority==.nil then return .AllJapanInsuranceResult~failure("ACCOUNTING_AUTHORITY_REQUIRED")
  policy=authority~policy(policyIdArg)
  if policy==.nil then return .AllJapanInsuranceResult~failure("POLICY_NOT_FOUND",policyIdArg)
  quote=authority~quote(policy~quoteId)
  if quote==.nil then return .AllJapanInsuranceResult~failure("QUOTE_NOT_FOUND",policy~quoteId)
  if quote~ratingId="" then return .AllJapanInsuranceResult~failure("ACCOUNTING_RATING_REQUIRED",quote~quoteId)
  rating=authority~rating(quote~ratingId)
  if rating==.nil then return .AllJapanInsuranceResult~failure("RATING_NOT_FOUND",quote~ratingId)
  if rating~currency\=quote~currency | rating~totalPremiumMinor\=quote~premiumMinor then return .AllJapanInsuranceResult~failure("ACCOUNTING_RATING_QUOTE_MISMATCH",quote~quoteId)
  if quote~currency\=.AllJapanInsuranceAccountingBuild~FUNCTIONAL_CURRENCY then return .AllJapanInsuranceResult~failure("ACCOUNTING_FX_POLICY_REQUIRED",quote~currency)
  split=self~premiumSplit(rating)
  if \split~ok then return split
  parts=split~value
  payload=.directory~new
  payload["currency"]=quote~currency
  payload["totalPremiumMinor"]=quote~premiumMinor
  payload["riskPremiumMinor"]=parts["riskPremiumMinor"]
  payload["salesCostMinor"]=parts["salesCostMinor"]
  payload["taxMinor"]=parts["taxMinor"]
  payload["salesCostTreatment"]=.AllJapanInsuranceCanonical~token(salesTreatmentArg)
  payload["policyId"]=policy~policyId
  payload["policyNumber"]=policy~policyNumber
  payload["termNumber"]=policy~termNumber
  payload["quoteId"]=quote~quoteId
  payload["ratingId"]=rating~ratingId
  payload["productCode"]=policy~productCode
  evidence=.array~new
  if evidenceArg\==.nil then do item over evidenceArg; ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,item); end
  ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,"AJI:POLICY:" || policy~policyId)
  ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,"AJI:QUOTE:" || quote~quoteId)
  ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,"AJI:RATING:" || rating~ratingId)
  lock=authority~policyContractLock(policy~policyId)
  if lock\==.nil then ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,"AJI:CONTRACT_LOCK:" || lock~semanticIdentity)
  event=.AccountingEvent~new("AJI:POLICY_BOUND:" || policy~policyId,.AllJapanInsuranceAccountingBuild~LEGAL_ENTITY_ID,.AllJapanInsuranceAccountingBuild~EVENT_POLICY_BOUND,eventDateArg,correlationRefArg,counterpartyEntityIdArg,"ALL_JAPAN.POLICY.AUTHORITY",payload,evidence)
  return .AllJapanInsuranceResult~success(event)
::method premiumCollectedEvent
  expose authority
  use arg collectionRefArg,policyIdArg,amountMinorArg,eventDateArg,correlationRefArg="",counterpartyEntityIdArg="",evidenceArg=.nil
  policy=authority~policy(policyIdArg)
  if policy==.nil then return .AllJapanInsuranceResult~failure("POLICY_NOT_FOUND",policyIdArg)
  quote=authority~quote(policy~quoteId)
  if quote==.nil then return .AllJapanInsuranceResult~failure("QUOTE_NOT_FOUND",policy~quoteId)
  if quote~currency\=.AllJapanInsuranceAccountingBuild~FUNCTIONAL_CURRENCY then return .AllJapanInsuranceResult~failure("ACCOUNTING_FX_POLICY_REQUIRED",quote~currency)
  if \.AllJapanInsuranceAccountingUtil~nonNegativeWhole(amountMinorArg) | amountMinorArg=0 then return .AllJapanInsuranceResult~failure("PREMIUM_COLLECTION_AMOUNT_INVALID")
  payload=.directory~new
  payload["currency"]=quote~currency
  payload["amountMinor"]=amountMinorArg
  payload["policyId"]=policy~policyId
  payload["policyNumber"]=policy~policyNumber
  payload["termNumber"]=policy~termNumber
  payload["quoteId"]=quote~quoteId
  payload["productCode"]=policy~productCode
  evidence=.array~new
  if evidenceArg\==.nil then do item over evidenceArg; ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,item); end
  ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,"AJI:POLICY:" || policy~policyId)
  event=.AccountingEvent~new("AJI:PREMIUM_COLLECTED:" || collectionRefArg~string,.AllJapanInsuranceAccountingBuild~LEGAL_ENTITY_ID,.AllJapanInsuranceAccountingBuild~EVENT_PREMIUM_COLLECTED,eventDateArg,correlationRefArg,counterpartyEntityIdArg,"ALL_JAPAN.COLLECTIONS",payload,evidence)
  return .AllJapanInsuranceResult~success(event)
::method claimReserveChangedEvent
  expose authority
  use arg assessmentIdArg,priorReserveMinorArg,eventDateArg,correlationRefArg="",counterpartyEntityIdArg="",evidenceArg=.nil
  numeric digits 50
  assessment=authority~assessment(assessmentIdArg)
  if assessment==.nil then return .AllJapanInsuranceResult~failure("CLAIM_ASSESSMENT_NOT_FOUND",assessmentIdArg)
  if \.AllJapanInsuranceAccountingUtil~nonNegativeWhole(priorReserveMinorArg) then return .AllJapanInsuranceResult~failure("PRIOR_CLAIM_RESERVE_INVALID")
  policy=authority~policy(assessment~policyId)
  if policy==.nil then return .AllJapanInsuranceResult~failure("POLICY_NOT_FOUND",assessment~policyId)
  quote=authority~quote(policy~quoteId)
  if quote==.nil then return .AllJapanInsuranceResult~failure("QUOTE_NOT_FOUND",policy~quoteId)
  if quote~currency\=.AllJapanInsuranceAccountingBuild~FUNCTIONAL_CURRENCY then return .AllJapanInsuranceResult~failure("ACCOUNTING_FX_POLICY_REQUIRED",quote~currency)
  paidToDate=authority~claimPaidTotal(assessment~claimId)
  target=assessment~payableMinor-paidToDate
  if target<0 then return .AllJapanInsuranceResult~failure("CLAIM_RESERVE_BELOW_PAID_AMOUNT",assessment~assessmentId)
  delta=target-priorReserveMinorArg
  if delta=0 then return .AllJapanInsuranceResult~failure("CLAIM_RESERVE_NO_CHANGE",assessment~assessmentId)
  payload=.directory~new
  payload["currency"]=quote~currency
  payload["reserveBeforeMinor"]=priorReserveMinorArg
  payload["reserveDeltaMinor"]=delta
  payload["reserveAfterMinor"]=target
  payload["paidToDateMinor"]=paidToDate
  payload["policyId"]=policy~policyId
  payload["policyNumber"]=policy~policyNumber
  payload["claimId"]=assessment~claimId
  payload["assessmentId"]=assessment~assessmentId
  payload["productCode"]=policy~productCode
  evidence=.array~new
  if evidenceArg\==.nil then do item over evidenceArg; ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,item); end
  ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,"AJI:CLAIM_ASSESSMENT:" || assessment~assessmentId)
  if assessment~evidenceRef\="" then ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,assessment~evidenceRef)
  event=.AccountingEvent~new("AJI:CLAIM_RESERVE:" || assessment~assessmentId,.AllJapanInsuranceAccountingBuild~LEGAL_ENTITY_ID,.AllJapanInsuranceAccountingBuild~EVENT_CLAIM_RESERVE_CHANGED,eventDateArg,correlationRefArg,counterpartyEntityIdArg,"ALL_JAPAN.CLAIMS.AUTHORITY",payload,evidence)
  return .AllJapanInsuranceResult~success(event)
::method claimPaidEvent
  expose authority
  use arg paymentIdArg,eventDateArg="",correlationRefArg="",counterpartyEntityIdArg="",evidenceArg=.nil
  numeric digits 50
  payment=authority~claimPayment(paymentIdArg)
  if payment==.nil then return .AllJapanInsuranceResult~failure("CLAIM_PAYMENT_NOT_FOUND",paymentIdArg)
  assessment=authority~assessment(payment~assessmentId)
  if assessment==.nil then return .AllJapanInsuranceResult~failure("CLAIM_ASSESSMENT_NOT_FOUND",payment~assessmentId)
  latest=authority~latestAssessmentForClaim(payment~claimId)
  if latest==.nil then return .AllJapanInsuranceResult~failure("CLAIM_PAYMENT_ASSESSMENT_NOT_CURRENT",payment~assessmentId)
  if latest~assessmentId\=assessment~assessmentId then return .AllJapanInsuranceResult~failure("CLAIM_PAYMENT_ASSESSMENT_NOT_CURRENT",payment~assessmentId)
  policy=authority~policy(payment~policyId)
  if policy==.nil then return .AllJapanInsuranceResult~failure("POLICY_NOT_FOUND",payment~policyId)
  quote=authority~quote(policy~quoteId)
  if quote==.nil then return .AllJapanInsuranceResult~failure("QUOTE_NOT_FOUND",policy~quoteId)
  if payment~currency\=quote~currency then return .AllJapanInsuranceResult~failure("CLAIM_PAYMENT_CURRENCY_MISMATCH",payment~currency)
  if payment~currency\=.AllJapanInsuranceAccountingBuild~FUNCTIONAL_CURRENCY then return .AllJapanInsuranceResult~failure("ACCOUNTING_FX_POLICY_REQUIRED",payment~currency)
  paidAfter=authority~claimPaidTotal(payment~claimId)
  paidBefore=paidAfter-payment~amountMinor
  reserveBefore=assessment~payableMinor-paidBefore
  reserveAfter=reserveBefore-payment~amountMinor
  if paidBefore<0 | reserveBefore<payment~amountMinor | reserveAfter<0 then return .AllJapanInsuranceResult~failure("CLAIM_PAYMENT_ACCOUNTING_POSITION_INVALID",payment~paymentId)
  if eventDateArg~string="" then eventDateArg=payment~paidAt~substr(1,10)
  payload=.directory~new
  payload["currency"]=payment~currency
  payload["amountMinor"]=payment~amountMinor
  payload["reserveBeforeMinor"]=reserveBefore
  payload["reserveAfterMinor"]=reserveAfter
  payload["paidToDateBeforeMinor"]=paidBefore
  payload["paidToDateAfterMinor"]=paidAfter
  payload["paymentId"]=payment~paymentId
  payload["paymentRef"]=payment~paymentRef
  payload["payeeRef"]=payment~payeeRef
  payload["policyId"]=policy~policyId
  payload["policyNumber"]=policy~policyNumber
  payload["claimId"]=payment~claimId
  payload["assessmentId"]=payment~assessmentId
  payload["productCode"]=policy~productCode
  evidence=.array~new
  if evidenceArg\==.nil then do item over evidenceArg; ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,item); end
  ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,"AJI:CLAIM_PAYMENT:" || payment~paymentId)
  ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,"AJI:CLAIM_ASSESSMENT:" || assessment~assessmentId)
  ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,payment~paymentRef)
  if payment~evidenceRef\="" then ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,payment~evidenceRef)
  if counterpartyEntityIdArg~string="" then counterpartyEntityIdArg=payment~payeeRef
  event=.AccountingEvent~new("AJI:CLAIM_PAID:" || payment~paymentId,.AllJapanInsuranceAccountingBuild~LEGAL_ENTITY_ID,.AllJapanInsuranceAccountingBuild~EVENT_CLAIM_PAID,eventDateArg,correlationRefArg,counterpartyEntityIdArg,"ALL_JAPAN.CLAIMS.PAYMENT_AUTHORITY",payload,evidence)
  return .AllJapanInsuranceResult~success(event)
::method premiumCollectionAttemptEvent
  expose authority transactionAuthority
  use arg attemptIdArg,eventDateArg="",correlationRefArg="",counterpartyEntityIdArg="",evidenceArg=.nil
  if transactionAuthority==.nil then return .AllJapanInsuranceResult~failure("TRANSACTION_AUTHORITY_REQUIRED")
  attempt=transactionAuthority~collectionAttempt(attemptIdArg)
  if attempt==.nil then return .AllJapanInsuranceResult~failure("PREMIUM_COLLECTION_ATTEMPT_NOT_FOUND",attemptIdArg)
  if attempt~outcome\=.AllJapanInsuranceTransactionBuild~COLLECTION_COLLECTED then return .AllJapanInsuranceResult~failure("PREMIUM_COLLECTION_NO_ACCOUNTING_EFFECT",attempt~outcome)
  policy=authority~policy(attempt~policyId)
  if policy==.nil then return .AllJapanInsuranceResult~failure("POLICY_NOT_FOUND",attempt~policyId)
  if attempt~currency\=.AllJapanInsuranceAccountingBuild~FUNCTIONAL_CURRENCY then return .AllJapanInsuranceResult~failure("ACCOUNTING_FX_POLICY_REQUIRED",attempt~currency)
  if eventDateArg~string="" then eventDateArg=attempt~attemptedAt~substr(1,10)
  payload=.directory~new
  payload["currency"]=attempt~currency
  payload["amountMinor"]=attempt~amountMinor
  payload["policyId"]=policy~policyId
  payload["policyNumber"]=policy~policyNumber
  payload["termNumber"]=policy~termNumber
  payload["productCode"]=policy~productCode
  payload["instalmentId"]=attempt~instalmentId
  payload["attemptId"]=attempt~attemptId
  payload["paymentRef"]=attempt~paymentRef
  payload["bankEvidenceRef"]=attempt~bankEvidenceRef
  evidence=.array~new
  if evidenceArg\==.nil then do item over evidenceArg; ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,item); end
  ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,"AJI:PREMIUM_COLLECTION_ATTEMPT:" || attempt~attemptId)
  ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,attempt~paymentRef)
  ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,attempt~bankEvidenceRef)
  event=.AccountingEvent~new("AJI:PREMIUM_COLLECTED:" || attempt~attemptId,.AllJapanInsuranceAccountingBuild~LEGAL_ENTITY_ID,.AllJapanInsuranceAccountingBuild~EVENT_PREMIUM_COLLECTED,eventDateArg,correlationRefArg,counterpartyEntityIdArg,"ALL_JAPAN.PREMIUM.BILLING_AUTHORITY",payload,evidence)
  return .AllJapanInsuranceResult~success(event)
::method premiumAdjustmentEvent
  expose authority transactionAuthority
  use arg adjustmentIdArg,eventDateArg="",correlationRefArg="",counterpartyEntityIdArg="",evidenceArg=.nil
  if transactionAuthority==.nil then return .AllJapanInsuranceResult~failure("TRANSACTION_AUTHORITY_REQUIRED")
  adj=transactionAuthority~premiumAdjustment(adjustmentIdArg)
  if adj==.nil then return .AllJapanInsuranceResult~failure("PREMIUM_ADJUSTMENT_NOT_FOUND",adjustmentIdArg)
  policy=authority~policy(adj~policyId)
  if policy==.nil then return .AllJapanInsuranceResult~failure("POLICY_NOT_FOUND",adj~policyId)
  if adj~currency\=.AllJapanInsuranceAccountingBuild~FUNCTIONAL_CURRENCY then return .AllJapanInsuranceResult~failure("ACCOUNTING_FX_POLICY_REQUIRED",adj~currency)
  if eventDateArg~string="" then eventDateArg=adj~effectiveDate
  payload=.directory~new
  payload["currency"]=adj~currency
  payload["riskDeltaMinor"]=adj~riskDeltaMinor
  payload["salesDeltaMinor"]=adj~salesDeltaMinor
  payload["taxDeltaMinor"]=adj~taxDeltaMinor
  payload["totalDeltaMinor"]=adj~totalDeltaMinor
  payload["salesCostTreatment"]=adj~salesCostTreatment
  payload["transactionType"]=adj~transactionType
  payload["calculationRef"]=adj~calculationRef
  if adj~transactionType=.AllJapanInsuranceTransactionBuild~ADJUSTMENT_ENDORSEMENT | adj~transactionType=.AllJapanInsuranceTransactionBuild~ADJUSTMENT_REINSTATEMENT then do
    calc=transactionAuthority~adjustmentCalculation(adj~calculationRef)
    if calc==.nil then return .AllJapanInsuranceResult~failure("PREMIUM_ADJUSTMENT_CALCULATION_NOT_FOUND",adj~calculationRef)
    payload["calculationFunctionRef"]=calc~ratingFunctionRef
  end
  else do
    calc=transactionAuthority~cancellationCalculation(adj~calculationRef)
    if calc==.nil then return .AllJapanInsuranceResult~failure("CANCELLATION_CALCULATION_NOT_FOUND",adj~calculationRef)
    payload["calculationFunctionRef"]=calc~functionRef
    payload["cancellationPlanRef"]=calc~planRef
  end
  commissionRecovery=transactionAuthority~commissionRecoveryForAdjustment(adj~adjustmentId)
  if commissionRecovery\==.nil then do
    payload["commissionRecoveryRef"]=commissionRecovery~recoveryId
    payload["commissionRecoveryMinor"]=commissionRecovery~amountMinor
    payload["producerRef"]=commissionRecovery~producerRef
  end
  taxRecovery=transactionAuthority~taxRecoveryForAdjustment(adj~adjustmentId)
  if taxRecovery\==.nil then do
    payload["taxRecoveryRef"]=taxRecovery~recoveryId
    payload["taxRecoveryMinor"]=taxRecovery~amountMinor
    payload["taxAuthorityRef"]=taxRecovery~taxAuthorityRef
  end
  payload["adjustmentId"]=adj~adjustmentId
  payload["policyId"]=policy~policyId
  payload["policyNumber"]=policy~policyNumber
  payload["termNumber"]=policy~termNumber
  payload["productCode"]=policy~productCode
  evidence=.array~new
  if evidenceArg\==.nil then do item over evidenceArg; ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,item); end
  ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,"AJI:PREMIUM_ADJUSTMENT:" || adj~adjustmentId)
  ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,"AJI:CALCULATION:" || adj~calculationRef)
  ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,payload["calculationFunctionRef"])
  if payload~hasIndex("cancellationPlanRef") then ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,payload["cancellationPlanRef"])
  ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,adj~evidenceRef)
  if commissionRecovery\==.nil then do
    ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,"AJI:COMMISSION_RECOVERY:" || commissionRecovery~recoveryId)
    ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,commissionRecovery~evidenceRef)
  end
  if taxRecovery\==.nil then do
    ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,"AJI:TAX_RECOVERY:" || taxRecovery~recoveryId)
    ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,taxRecovery~evidenceRef)
  end
  event=.AccountingEvent~new("AJI:PREMIUM_ADJUSTED:" || adj~adjustmentId,.AllJapanInsuranceAccountingBuild~LEGAL_ENTITY_ID,.AllJapanInsuranceAccountingBuild~EVENT_PREMIUM_ADJUSTED,eventDateArg,correlationRefArg,counterpartyEntityIdArg,"ALL_JAPAN.POLICY.TRANSACTION_AUTHORITY",payload,evidence)
  return .AllJapanInsuranceResult~success(event)
::method commissionPaidEvent
  expose authority transactionAuthority
  use arg settlementIdArg,eventDateArg="",correlationRefArg="",counterpartyEntityIdArg="",evidenceArg=.nil
  if transactionAuthority==.nil then return .AllJapanInsuranceResult~failure("TRANSACTION_AUTHORITY_REQUIRED")
  settlement=transactionAuthority~commissionSettlement(settlementIdArg)
  if settlement==.nil then return .AllJapanInsuranceResult~failure("COMMISSION_SETTLEMENT_NOT_FOUND",settlementIdArg)
  policy=authority~policy(settlement~policyId)
  if policy==.nil then return .AllJapanInsuranceResult~failure("POLICY_NOT_FOUND",settlement~policyId)
  if settlement~currency\=.AllJapanInsuranceAccountingBuild~FUNCTIONAL_CURRENCY then return .AllJapanInsuranceResult~failure("ACCOUNTING_FX_POLICY_REQUIRED",settlement~currency)
  if eventDateArg~string="" then eventDateArg=settlement~settledAt~substr(1,10)
  payload=.directory~new
  payload["currency"]=settlement~currency
  payload["amountMinor"]=settlement~amountMinor
  payload["settlementId"]=settlement~settlementId
  payload["producerRef"]=settlement~producerRef
  payload["paymentRef"]=settlement~paymentRef
  payload["bankEvidenceRef"]=settlement~bankEvidenceRef
  payload["policyId"]=policy~policyId
  payload["policyNumber"]=policy~policyNumber
  payload["termNumber"]=policy~termNumber
  payload["productCode"]=policy~productCode
  evidence=.array~new
  if evidenceArg\==.nil then do item over evidenceArg; ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,item); end
  ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,"AJI:COMMISSION_SETTLEMENT:" || settlement~settlementId)
  ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,settlement~paymentRef)
  ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,settlement~bankEvidenceRef)
  if counterpartyEntityIdArg~string="" then counterpartyEntityIdArg=settlement~producerRef
  event=.AccountingEvent~new("AJI:COMMISSION_PAID:" || settlement~settlementId,.AllJapanInsuranceAccountingBuild~LEGAL_ENTITY_ID,.AllJapanInsuranceAccountingBuild~EVENT_COMMISSION_PAID,eventDateArg,correlationRefArg,counterpartyEntityIdArg,"ALL_JAPAN.COMMISSION.SETTLEMENT_AUTHORITY",payload,evidence)
  return .AllJapanInsuranceResult~success(event)
::method policyholderRefundPaidEvent
  expose authority transactionAuthority
  use arg refundIdArg,eventDateArg="",correlationRefArg="",counterpartyEntityIdArg="",evidenceArg=.nil
  if transactionAuthority==.nil then return .AllJapanInsuranceResult~failure("TRANSACTION_AUTHORITY_REQUIRED")
  refund=transactionAuthority~policyholderRefund(refundIdArg)
  if refund==.nil then return .AllJapanInsuranceResult~failure("POLICYHOLDER_REFUND_NOT_FOUND",refundIdArg)
  policy=authority~policy(refund~policyId)
  if policy==.nil then return .AllJapanInsuranceResult~failure("POLICY_NOT_FOUND",refund~policyId)
  if refund~currency\=.AllJapanInsuranceAccountingBuild~FUNCTIONAL_CURRENCY then return .AllJapanInsuranceResult~failure("ACCOUNTING_FX_POLICY_REQUIRED",refund~currency)
  if eventDateArg~string="" then eventDateArg=refund~paidAt~substr(1,10)
  payload=.directory~new
  payload["currency"]=refund~currency
  payload["amountMinor"]=refund~amountMinor
  payload["refundId"]=refund~refundId
  payload["payeeRef"]=refund~payeeRef
  payload["paymentRef"]=refund~paymentRef
  payload["bankEvidenceRef"]=refund~bankEvidenceRef
  payload["policyId"]=policy~policyId
  payload["policyNumber"]=policy~policyNumber
  payload["termNumber"]=policy~termNumber
  payload["productCode"]=policy~productCode
  evidence=.array~new
  if evidenceArg\==.nil then do item over evidenceArg; ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,item); end
  ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,"AJI:POLICYHOLDER_REFUND:" || refund~refundId)
  ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,refund~paymentRef)
  ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,refund~bankEvidenceRef)
  if counterpartyEntityIdArg~string="" then counterpartyEntityIdArg=refund~payeeRef
  event=.AccountingEvent~new("AJI:POLICYHOLDER_REFUND_PAID:" || refund~refundId,.AllJapanInsuranceAccountingBuild~LEGAL_ENTITY_ID,.AllJapanInsuranceAccountingBuild~EVENT_POLICYHOLDER_REFUND_PAID,eventDateArg,correlationRefArg,counterpartyEntityIdArg,"ALL_JAPAN.PREMIUM.BILLING_AUTHORITY",payload,evidence)
  return .AllJapanInsuranceResult~success(event)
::method commissionRecoveryReceivedEvent
  expose authority transactionAuthority
  use arg receiptIdArg,eventDateArg="",correlationRefArg="",counterpartyEntityIdArg="",evidenceArg=.nil
  if transactionAuthority==.nil then return .AllJapanInsuranceResult~failure("TRANSACTION_AUTHORITY_REQUIRED")
  receipt=transactionAuthority~commissionRecoveryReceipt(receiptIdArg)
  if receipt==.nil then return .AllJapanInsuranceResult~failure("COMMISSION_RECOVERY_RECEIPT_NOT_FOUND",receiptIdArg)
  if receipt~currency\=.AllJapanInsuranceAccountingBuild~FUNCTIONAL_CURRENCY then return .AllJapanInsuranceResult~failure("ACCOUNTING_FX_POLICY_REQUIRED",receipt~currency)
  policy=authority~policy(receipt~policyId); if policy==.nil then return .AllJapanInsuranceResult~failure("POLICY_NOT_FOUND",receipt~policyId)
  if eventDateArg~string="" then eventDateArg=receipt~receivedAt~substr(1,10)
  payload=.directory~new; payload["currency"]=receipt~currency; payload["amountMinor"]=receipt~amountMinor; payload["receiptId"]=receipt~receiptId; payload["recoveryId"]=receipt~recoveryId; payload["producerRef"]=receipt~producerRef; payload["paymentRef"]=receipt~paymentRef; payload["bankEvidenceRef"]=receipt~bankEvidenceRef; payload["policyId"]=policy~policyId; payload["policyNumber"]=policy~policyNumber; payload["termNumber"]=policy~termNumber; payload["productCode"]=policy~productCode
  evidence=.array~new; if evidenceArg\==.nil then do item over evidenceArg; ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,item); end
  ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,"AJI:COMMISSION_RECOVERY_RECEIPT:" || receipt~receiptId); ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,receipt~paymentRef); ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,receipt~bankEvidenceRef)
  if counterpartyEntityIdArg~string="" then counterpartyEntityIdArg=receipt~producerRef
  event=.AccountingEvent~new("AJI:COMMISSION_RECOVERED:" || receipt~receiptId,.AllJapanInsuranceAccountingBuild~LEGAL_ENTITY_ID,.AllJapanInsuranceAccountingBuild~EVENT_COMMISSION_RECOVERED,eventDateArg,correlationRefArg,counterpartyEntityIdArg,"ALL_JAPAN.COMMISSION.SETTLEMENT_AUTHORITY",payload,evidence)
  return .AllJapanInsuranceResult~success(event)
::method taxRemittedEvent
  expose authority transactionAuthority
  use arg remittanceIdArg,eventDateArg="",correlationRefArg="",counterpartyEntityIdArg="",evidenceArg=.nil
  if transactionAuthority==.nil then return .AllJapanInsuranceResult~failure("TRANSACTION_AUTHORITY_REQUIRED")
  remittance=transactionAuthority~taxRemittance(remittanceIdArg)
  if remittance==.nil then return .AllJapanInsuranceResult~failure("TAX_REMITTANCE_NOT_FOUND",remittanceIdArg)
  if remittance~currency\=.AllJapanInsuranceAccountingBuild~FUNCTIONAL_CURRENCY then return .AllJapanInsuranceResult~failure("ACCOUNTING_FX_POLICY_REQUIRED",remittance~currency)
  policy=authority~policy(remittance~policyId); if policy==.nil then return .AllJapanInsuranceResult~failure("POLICY_NOT_FOUND",remittance~policyId)
  if eventDateArg~string="" then eventDateArg=remittance~remittedAt~substr(1,10)
  payload=.directory~new; payload["currency"]=remittance~currency; payload["amountMinor"]=remittance~amountMinor; payload["remittanceId"]=remittance~remittanceId; payload["taxAuthorityRef"]=remittance~taxAuthorityRef; payload["paymentRef"]=remittance~paymentRef; payload["bankEvidenceRef"]=remittance~bankEvidenceRef; payload["policyId"]=policy~policyId; payload["policyNumber"]=policy~policyNumber; payload["termNumber"]=policy~termNumber; payload["productCode"]=policy~productCode
  evidence=.array~new; if evidenceArg\==.nil then do item over evidenceArg; ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,item); end
  ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,"AJI:TAX_REMITTANCE:" || remittance~remittanceId); ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,remittance~paymentRef); ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,remittance~bankEvidenceRef)
  if counterpartyEntityIdArg~string="" then counterpartyEntityIdArg=remittance~taxAuthorityRef
  event=.AccountingEvent~new("AJI:TAX_REMITTED:" || remittance~remittanceId,.AllJapanInsuranceAccountingBuild~LEGAL_ENTITY_ID,.AllJapanInsuranceAccountingBuild~EVENT_TAX_REMITTED,eventDateArg,correlationRefArg,counterpartyEntityIdArg,"ALL_JAPAN.PREMIUM.TAX.SETTLEMENT_AUTHORITY",payload,evidence)
  return .AllJapanInsuranceResult~success(event)
::method taxRecoveryReceivedEvent
  expose authority transactionAuthority
  use arg receiptIdArg,eventDateArg="",correlationRefArg="",counterpartyEntityIdArg="",evidenceArg=.nil
  if transactionAuthority==.nil then return .AllJapanInsuranceResult~failure("TRANSACTION_AUTHORITY_REQUIRED")
  receipt=transactionAuthority~taxRecoveryReceipt(receiptIdArg)
  if receipt==.nil then return .AllJapanInsuranceResult~failure("TAX_RECOVERY_RECEIPT_NOT_FOUND",receiptIdArg)
  if receipt~currency\=.AllJapanInsuranceAccountingBuild~FUNCTIONAL_CURRENCY then return .AllJapanInsuranceResult~failure("ACCOUNTING_FX_POLICY_REQUIRED",receipt~currency)
  policy=authority~policy(receipt~policyId); if policy==.nil then return .AllJapanInsuranceResult~failure("POLICY_NOT_FOUND",receipt~policyId)
  if eventDateArg~string="" then eventDateArg=receipt~receivedAt~substr(1,10)
  payload=.directory~new; payload["currency"]=receipt~currency; payload["amountMinor"]=receipt~amountMinor; payload["receiptId"]=receipt~receiptId; payload["recoveryId"]=receipt~recoveryId; payload["taxAuthorityRef"]=receipt~taxAuthorityRef; payload["paymentRef"]=receipt~paymentRef; payload["bankEvidenceRef"]=receipt~bankEvidenceRef; payload["policyId"]=policy~policyId; payload["policyNumber"]=policy~policyNumber; payload["termNumber"]=policy~termNumber; payload["productCode"]=policy~productCode
  evidence=.array~new; if evidenceArg\==.nil then do item over evidenceArg; ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,item); end
  ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,"AJI:TAX_RECOVERY_RECEIPT:" || receipt~receiptId); ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,receipt~paymentRef); ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,receipt~bankEvidenceRef)
  if counterpartyEntityIdArg~string="" then counterpartyEntityIdArg=receipt~taxAuthorityRef
  event=.AccountingEvent~new("AJI:TAX_RECOVERED:" || receipt~receiptId,.AllJapanInsuranceAccountingBuild~LEGAL_ENTITY_ID,.AllJapanInsuranceAccountingBuild~EVENT_TAX_RECOVERED,eventDateArg,correlationRefArg,counterpartyEntityIdArg,"ALL_JAPAN.PREMIUM.TAX.SETTLEMENT_AUTHORITY",payload,evidence)
  return .AllJapanInsuranceResult~success(event)
::method billingReceiptEvent
  expose authority transactionAuthority
  use arg receiptIdArg,eventDateArg="",correlationRefArg="",counterpartyEntityIdArg="",evidenceArg=.nil
  if transactionAuthority==.nil then return .AllJapanInsuranceResult~failure("TRANSACTION_AUTHORITY_REQUIRED")
  receipt=transactionAuthority~billingReceipt(receiptIdArg)
  if receipt==.nil then return .AllJapanInsuranceResult~failure("BILLING_RECEIPT_NOT_FOUND",receiptIdArg)
  if receipt~currency\=.AllJapanInsuranceAccountingBuild~FUNCTIONAL_CURRENCY then return .AllJapanInsuranceResult~failure("ACCOUNTING_FX_POLICY_REQUIRED",receipt~currency)
  policy=authority~policy(receipt~policyId); if policy==.nil then return .AllJapanInsuranceResult~failure("POLICY_NOT_FOUND",receipt~policyId)
  applied=transactionAuthority~billingReceiptAppliedAtRecord(receipt~receiptId)
  if applied==.nil then return .AllJapanInsuranceResult~failure("BILLING_RECEIPT_ALLOCATION_SNAPSHOT_REQUIRED",receipt~receiptId)
  unapplied=receipt~amountMinor-applied
  if eventDateArg~string="" then eventDateArg=receipt~receivedAt~substr(1,10)
  payload=.directory~new
  payload["currency"]=receipt~currency
  payload["amountMinor"]=receipt~amountMinor
  payload["appliedAtReceiptMinor"]=applied
  payload["unappliedAtReceiptMinor"]=unapplied
  payload["billingReceiptId"]=receipt~receiptId
  payload["payerRef"]=receipt~payerRef
  payload["paymentRef"]=receipt~paymentRef
  payload["bankEvidenceRef"]=receipt~bankEvidenceRef
  payload["policyId"]=policy~policyId
  payload["policyNumber"]=policy~policyNumber
  payload["termNumber"]=policy~termNumber
  payload["productCode"]=policy~productCode
  evidence=.array~new
  if evidenceArg\==.nil then do item over evidenceArg; ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,item); end
  ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,"AJI:BILLING_RECEIPT:" || receipt~receiptId)
  ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,receipt~paymentRef)
  ignored=.AllJapanInsuranceAccountingUtil~appendEvidence(evidence,receipt~bankEvidenceRef)
  if counterpartyEntityIdArg~string="" then counterpartyEntityIdArg=receipt~payerRef
  event=.AccountingEvent~new("AJI:BILLING_CASH_RECEIVED:" || receipt~receiptId,.AllJapanInsuranceAccountingBuild~LEGAL_ENTITY_ID,.AllJapanInsuranceAccountingBuild~EVENT_BILLING_CASH_RECEIVED,eventDateArg,correlationRefArg,counterpartyEntityIdArg,"ALL_JAPAN.PREMIUM.BILLING_AUTHORITY",payload,evidence)
  return .AllJapanInsuranceResult~success(event)
::method premiumSplit private
  use arg rating
  numeric digits 50
  sales=0
  tax=0
  do cost over rating~costs
    if cost~currency\="" & cost~currency\=rating~currency then return .AllJapanInsuranceResult~failure("ACCOUNTING_COST_CURRENCY_MISMATCH",cost~code)
    if cost~code=.AllJapanInsuranceRatingBuild~COST_SALES then sales+=cost~amountMinor
    else if cost~code~length>=4 & cost~code~substr(1,4)="TAX_" then tax+=cost~amountMinor
  end
  risk=rating~totalPremiumMinor-sales-tax
  if risk<0 | risk+sales+tax\=rating~totalPremiumMinor then return .AllJapanInsuranceResult~failure("ACCOUNTING_PREMIUM_SPLIT_INVALID",rating~ratingId)
  parts=.directory~new
  parts["riskPremiumMinor"]=risk
  parts["salesCostMinor"]=sales
  parts["taxMinor"]=tax
  return .AllJapanInsuranceResult~success(parts)

::requires "AllJapanInsuranceTransactions.cls"
::requires "AllJapanInsuranceProductRating.cls"
::requires "AccountingEngine.cls"
::requires "AccountingPersistence.cls"
