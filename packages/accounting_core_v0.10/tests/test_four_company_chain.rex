t = .AccountingTest~new
correlation = "CHAIN-001"

entities = .array~of("FLYLO_AIR_LTD", "FEDERATION_DISTRIBUTION_LTD", "ALL_JAPAN_INSURANCE_CO_LTD", "VECTOR_MERIDIAN_MARKETS_LTD")
types = .array~of("INSURANCE_PURCHASED", "COMMISSION_EARNED", "POLICY_BOUND", "OTC_GAIN")
amounts = .array~of(10000, 1000, 10000, 1000000)
engines = .array~new

idx = 0
do entity over entities
  idx += 1
  e = makeEngine(entity, "B" || idx)
  p = .ChainPolicy~new("policy/" || idx, "impl/" || idx, entity, types[idx], "2026-01-01")
  e~registerPolicy(p)
  payload = .directory~new
  payload["amountMinor"] = amounts[idx]
  if entity = "VECTOR_MERIDIAN_MARKETS_LTD" then do
    dims = .directory~new
    dims["trustOrVehicleRef"] = "CAYMAN_PREMIUM_RECEIVABLES_TRUST_NO_3"
    dims["encumbranceRef"] = "REHYPOTHECATION-FACILITY-77"
    payload["dimensions"] = dims
  end
  ev = .AccountingEvent~new("SHARED-SOURCE-REF", entity, types[idx], "2026-08-28", correlation, "COUNTERPARTY-" || idx, entity || ".OPERATIONAL", payload)
  r = e~transact(ev)
  t~assertTrue(r~ok, entity || " posts its own side")
  t~assertEq(1, e~book~entryCount, entity || " has one independent entry")
  t~assertEq(1, (e~entriesByCorrelation(correlation))~items, entity || " correlation is local to its book")
  engines~append(e)
end

/* Same sourceEventRef is not global authority; source indexes are per legal-entity book. */
t~assertEq("SHARED-SOURCE-REF", engines[1]~book~entries[1]~sourceEventRef, "FlyLo source reference retained")
t~assertEq("SHARED-SOURCE-REF", engines[4]~book~entries[1]~sourceEventRef, "VMM may independently use same source token")
t~assertEq("CAYMAN_PREMIUM_RECEIVABLES_TRUST_NO_3", engines[4]~book~entries[1]~lines[1]~dimensions["trustOrVehicleRef"], "VMM legal structure dimension retained without affecting other books")
t~assertEq(0, engines[1]~book~entries[1]~lines[1]~dimensions~items, "FlyLo entry did not inherit VMM dimensions")

say "four-company chain assertions=" t~assertions "failures=" t~failures
if t~failures > 0 then exit 1
exit 0

::routine makeEngine
  use arg entity, bookId
  e = .AccountingEngine~new(entity, bookId)
  e~book~chart~add(.AccountingAccount~new("1000", "Debit", "ASSET"))
  e~book~chart~add(.AccountingAccount~new("4000", "Credit", "REVENUE"))
  e~book~chart~seal
  e~book~addPeriod(.AccountingPeriod~new("2026-08", "2026-08-01", "2026-08-31"))
  return e

::class ChainPolicy subclass AccountingPolicy
::method init
  use arg refArg, identityArg, entityArg, typeArg, fromArg, toArg = ""
  self~init:super(refArg, identityArg, entityArg, typeArg, fromArg, toArg)
::method propose
  use arg event, book
  amount = .AccountingUtil~requireWholeNonNegative(event~value("amountMinor"), "amountMinor")
  dims = event~value("dimensions", .directory~new)
  d = self~newDraft(event, book, event~eventDate, "chain")
  d~addLine(.AccountingJournalLine~new("1000", "GBP", amount, 0, "debit", dims))
  d~addLine(.AccountingJournalLine~new("4000", "GBP", 0, amount, "credit", dims))
  return .AccountingPolicyDecision~accept(d)

::options digits 50

::requires "AccountingEngine.cls"
::requires "TestSupport.cls"
