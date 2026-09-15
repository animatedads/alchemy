/* FlyLo captured-payment accounting policy implementation.
 *
 * This class is the executable entity-accounting treatment used through
 * Accounting Core v0.7's AccountingEngine~transact() path.  Operational
 * FlyLo code emits AccountingEvent evidence; it does not construct journals.
 */

::options digits 50

::class FlyLoCapturedPaymentAccountingPolicy subclass AccountingPolicy public
::method init
  use arg refArg, identityArg, eventTypeArg, fromArg="2026-01-01", toArg=""
  self~init:super(refArg, identityArg, "FLYLO_AIR_LTD", eventTypeArg, fromArg, toArg)

::method propose
  use arg event, book
  status=event~value("status", "")~string~upper
  if status<>"CAPTURED" then return .AccountingPolicyDecision~reject("PAYMENT_CAPTURE_REQUIRED", "payment authorisation alone is not posting evidence")

  amount=event~value("amountMinor", .nil)
  if amount==.nil then return .AccountingPolicyDecision~reject("FLYLO_ACCOUNTING_AMOUNT_INVALID", amount)
  signal on syntax name invalidAmount
  amount=.AccountingUtil~requireWholeNonNegative(amount,"FlyLo captured payment amountMinor")
  signal off syntax
  if amount="0" then return .AccountingPolicyDecision~reject("FLYLO_ACCOUNTING_AMOUNT_INVALID", amount)
  ccy=event~value("currency", "")~string~upper~strip
  if ccy="" then return .AccountingPolicyDecision~reject("FLYLO_ACCOUNTING_CURRENCY_REQUIRED", event~sourceEventRef)
  captureId=event~value("captureId", "")~string~strip
  authId=event~value("paymentAuthorizationId", "")~string~strip
  if captureId="" | authId="" then return .AccountingPolicyDecision~reject("FLYLO_ACCOUNTING_PAYMENT_EVIDENCE_INCOMPLETE", event~sourceEventRef)

  dims=.directory~new
  dims["eventType"]=event~eventType
  dims["captureId"]=captureId
  dims["paymentAuthorizationId"]=authId
  dims["revenueRecognition"]="DEFERRED_UNTIL_PERFORMANCE"
  do field over .array~of("bookingRef","saleId","serviceId","serviceType")
    value=event~value(field, "")
    if value<>.nil then if value~string<>"" then dims[field]=value
  end

  metadata=.directory~new
  metadata["accountingTreatment"]="CAPTURE_TO_PASSENGER_CONTRACT_LIABILITY"
  metadata["revenueRecognition"]="DEFERRED_UNTIL_PERFORMANCE"
  metadata["paymentSource"]=event~value("paymentSource", "")
  draft=self~newDraft(event, book, event~eventDate, "Captured passenger payment - deferred until service performance", .nil, metadata)
  draft~addLine(.AccountingJournalLine~new("1100",ccy,amount,0,"Captured payment receivable",dims))
  draft~addLine(.AccountingJournalLine~new("2100",ccy,0,amount,"Passenger service obligation",dims))
  return .AccountingPolicyDecision~accept(draft,"FlyLo policy recognizes captured consideration as receivable plus passenger-service contract liability; no revenue before performance")

invalidAmount:
  signal off syntax
  return .AccountingPolicyDecision~reject("FLYLO_ACCOUNTING_AMOUNT_INVALID",condition("D"))

::requires "AccountingEngine.cls"
