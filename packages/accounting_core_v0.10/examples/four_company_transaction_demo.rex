/*
 * One economic chain; four legal entities; four independent accounting truths.
 * Values are illustrative accounting mechanics, not accounting advice.
 */
correlation = "ECONOMIC-CHAIN-FLYLO-FED-AJI-VMM-001"

flylo = makeEngine("FLYLO_AIR_LTD", "FLYLO", "6100", "2000")
federation = makeEngine("FEDERATION_DISTRIBUTION_LTD", "FED", "1100", "4100")
aji = makeEngine("ALL_JAPAN_INSURANCE_CO_LTD", "AJI", "1100", "2200")
vmm = makeEngine("VECTOR_MERIDIAN_MARKETS_LTD", "VMM", "1300", "4100")

flylo~registerPolicy(.TwoLineAmountPolicy~new("flylo.accounting.insurance-purchase/0.1", "artifact:flylo:insurance-accounting:001", "FLYLO_AIR_LTD", "INSURANCE_PURCHASED", "2026-01-01", "", "6100", "2000", "Insurance purchase"))
federation~registerPolicy(.TwoLineAmountPolicy~new("federation.accounting.distribution-commission/0.1", "artifact:federation:commission-accounting:001", "FEDERATION_DISTRIBUTION_LTD", "DISTRIBUTION_COMMISSION_EARNED", "2026-01-01", "", "1100", "4100", "Distribution commission"))
aji~registerPolicy(.TwoLineAmountPolicy~new("aji.accounting.policy-bound/0.1", "artifact:aji:policy-accounting:001", "ALL_JAPAN_INSURANCE_CO_LTD", "POLICY_BOUND", "2026-01-01", "", "1100", "2200", "Premium initial recognition"))
vmm~registerPolicy(.TwoLineAmountPolicy~new("vmm.accounting.otc-fair-value/0.1", "artifact:vmm:otc-accounting:001", "VECTOR_MERIDIAN_MARKETS_LTD", "OTC_FAIR_VALUE_GAIN", "2026-01-01", "", "1300", "4100", "OTC fair-value gain"))

flyloPayload = amountPayload(10000)
flyloPayload["insurerRef"] = "ALL_JAPAN_INSURANCE_CO_LTD"
flyloEvent = .AccountingEvent~new("FLYLO:INSURANCE:001", "FLYLO_AIR_LTD", "INSURANCE_PURCHASED", "2026-08-28", correlation, "FEDERATION_DISTRIBUTION_LTD", "FLYLO.BOOKING", flyloPayload, .array~of("FLYLO:BOOKING:ABC", "AJI:QUOTE:Q1"))

fedPayload = amountPayload(1000)
fedPayload["providerRef"] = "ALL_JAPAN_INSURANCE_CO_LTD"
fedEvent = .AccountingEvent~new("FED:DISTRIBUTION:COMMISSION:001", "FEDERATION_DISTRIBUTION_LTD", "DISTRIBUTION_COMMISSION_EARNED", "2026-08-28", correlation, "ALL_JAPAN_INSURANCE_CO_LTD", "FEDERATION.DISTRIBUTION", fedPayload, .array~of("RID:CASE:001"))

ajiPayload = amountPayload(10000)
ajiPayload["policyRef"] = "AJI-POLICY-001"
ajiEvent = .AccountingEvent~new("AJI:POLICY:BOUND:001", "ALL_JAPAN_INSURANCE_CO_LTD", "POLICY_BOUND", "2026-08-28", correlation, "FLYLO_AIR_LTD", "ALL_JAPAN.POLICY.ADMIN", ajiPayload, .array~of("AJI:POLICY:001"))

vmmPayload = amountPayload(1000000)
structure = .directory~new
structure["trustOrVehicleRef"] = "CAYMAN_PREMIUM_RECEIVABLES_TRUST_NO_3"
structure["legalOwner"] = "AJI_RECEIVABLES_TRUSTEE_LTD"
structure["beneficialOwner"] = "ALL_JAPAN_INSURANCE_CO_LTD"
structure["encumbranceRef"] = "REHYPOTHECATION-FACILITY-77"
vmmPayload["dimensions"] = structure
vmmEvent = .AccountingEvent~new("VMM:OTC:FV:001", "VECTOR_MERIDIAN_MARKETS_LTD", "OTC_FAIR_VALUE_GAIN", "2026-08-28", correlation, "OTC_COUNTERPARTY_001", "VMM.SMART.EXECUTION", vmmPayload, .array~of("VMM:OTC:CONTRACT:001", "VMM:VALUATION:001"))

call postAndShow flylo, flyloEvent
call postAndShow federation, fedEvent
call postAndShow aji, ajiEvent
call postAndShow vmm, vmmEvent

say ""
say "Correlation" correlation
say "  FlyLo entries:     " (flylo~entriesByCorrelation(correlation))~items
say "  Federation entries:" (federation~entriesByCorrelation(correlation))~items
say "  All Japan entries: " (aji~entriesByCorrelation(correlation))~items
say "  VMM entries:       " (vmm~entriesByCorrelation(correlation))~items

exit 0

::routine amountPayload
  use arg amount
  d = .directory~new
  d["amountMinor"] = amount
  return d

::routine makeEngine
  use arg entity, bookPrefix, debitAccount, creditAccount
  e = .AccountingEngine~new(entity, bookPrefix || "-STAT")
  e~book~chart~add(.AccountingAccount~new(debitAccount, "Debit side", "ASSET"))
  if debitAccount = "6100" then do
    /* replace the demonstration classification with expense */
    e = .AccountingEngine~new(entity, bookPrefix || "-STAT")
    e~book~chart~add(.AccountingAccount~new(debitAccount, "Expense", "EXPENSE"))
  end
  if creditAccount = "2000" | creditAccount = "2200" then e~book~chart~add(.AccountingAccount~new(creditAccount, "Liability", "LIABILITY"))
  else e~book~chart~add(.AccountingAccount~new(creditAccount, "Revenue / gain", "REVENUE"))
  e~book~chart~seal
  e~book~addPeriod(.AccountingPeriod~new("2026-08", "2026-08-01", "2026-08-31"))
  return e

::routine postAndShow
  use arg engine, event
  r = engine~transact(event)
  if \r~ok then do
    say event~legalEntityId "REJECTED" r~errorCode r~message
    return
  end
  say event~legalEntityId "->" r~entry~entryId "policy=" || r~entry~policyRef "impl=" || r~entry~policyIdentity

::class TwoLineAmountPolicy subclass AccountingPolicy
::method init
  expose debitAccount creditAccount narrative
  use arg refArg, identityArg, entityArg, typeArg, fromArg, toArg = "", debitArg, creditArg, narrativeArg = "Accounting event"
  self~init:super(refArg, identityArg, entityArg, typeArg, fromArg, toArg)
  debitAccount = debitArg
  creditAccount = creditArg
  narrative = narrativeArg
::method propose
  expose debitAccount creditAccount narrative
  use arg event, book
  amount = .AccountingUtil~requireWholeNonNegative(event~value("amountMinor"), "amountMinor")
  draft = self~newDraft(event, book, event~eventDate, narrative)
  dimensions = event~value("dimensions", .directory~new)
  draft~addLine(.AccountingJournalLine~new(debitAccount, "GBP", amount, 0, narrative || " debit", dimensions))
  draft~addLine(.AccountingJournalLine~new(creditAccount, "GBP", 0, amount, narrative || " credit", dimensions))
  return .AccountingPolicyDecision~accept(draft)

::options digits 50

::requires "AccountingEngine.cls"
