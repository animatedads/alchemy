t = .AccountingTest~new
numeric digits 50

storePath = "./tests/tmp_accounting_tx_store_v04.jsonl"
store = .AccountingFileStore~new(storePath)
book = store~createBook("ALL_JAPAN_INSURANCE_CO_LTD", "AJI-STAT", "ENTITY_GAAP")
book~chart~add(.AccountingAccount~new("1000", "JPY cash", "ASSET", "AUTO", "SINGLE", .true, "JPY"))
book~chart~add(.AccountingAccount~new("4000", "Premium revenue", "REVENUE", "AUTO", "SINGLE", .true, "JPY"))
book~chart~seal
book~addPeriod(.AccountingPeriod~new("2026-08", "2026-08-01", "2026-08-31"))

engine = .AccountingEngine~new(book~legalEntityId, book~bookId, book~reportingBasis, book)
policy = .LargeYenPremiumPolicy~new("aji.accounting.premium/0.4", "AJI.PREMIUM.ACCOUNTING/2026-08-28", book~legalEntityId, "PREMIUM_RECEIVED", "2026-01-01")
engine~registerPolicy(policy)

payload = .directory~new
payload["amountMinor"] = "9876543210987654321098765432109876543210"
event = .AccountingEvent~new("AJI:PREMIUM:JPY:9001", book~legalEntityId, "PREMIUM_RECEIVED", "2026-08-28", "ECONOMIC-AJI-JPY-9001", "FLYLO_AIR_LTD", "AJI.POLICY.SYSTEM", payload)
first = engine~transact(event)
t~assertTrue(first~ok, "durable policy transaction posts")
t~assertEq("POSTED", first~status, "durable policy transaction status")
t~assertEq("AJI.PREMIUM.ACCOUNTING/2026-08-28", first~entry~policyIdentity, "policy identity persisted in entry")

recoveredBook = store~recoverBook
recoveredEngine = .AccountingEngine~new(recoveredBook~legalEntityId, recoveredBook~bookId, recoveredBook~reportingBasis, recoveredBook)

/* Deliberately register no policy: replay identity must be resolved before policy dispatch. */
replay = recoveredEngine~transact(event)
t~assertTrue(replay~ok, "recovered event replay succeeds without policy redispatch")
t~assertEq("DUPLICATE", replay~status, "recovered event is duplicate")
t~assertEq("AJI.PREMIUM.ACCOUNTING/2026-08-28", replay~policyIdentity, "original executable policy identity survives restart")

changedPayload = .directory~new
changedPayload["amountMinor"] = "9876543210987654321098765432109876543211"
changedEvent = .AccountingEvent~new("AJI:PREMIUM:JPY:9001", book~legalEntityId, "PREMIUM_RECEIVED", "2026-08-28", "ECONOMIC-AJI-JPY-9001", "FLYLO_AIR_LTD", "AJI.POLICY.SYSTEM", changedPayload)
conflict = recoveredEngine~transact(changedEvent)
t~assertEq("SOURCE_EVENT_CONFLICT", conflict~errorCode, "changed durable event conflicts before policy dispatch")

newPayload = .directory~new
newPayload["amountMinor"] = "1"
newEvent = .AccountingEvent~new("AJI:PREMIUM:JPY:9002", book~legalEntityId, "PREMIUM_RECEIVED", "2026-08-28", "", "", "AJI.POLICY.SYSTEM", newPayload)
missing = recoveredEngine~transact(newEvent)
t~assertEq("POLICY_NOT_FOUND", missing~errorCode, "new event still requires an executable policy after restart")

t~assertEq("9876543210987654321098765432109876543210", recoveredBook~balance("1000", "JPY")~debitMinor, "durable transaction retains exact 40-digit JPY balance")

say "durable transaction assertions=" t~assertions "failures=" t~failures
if t~failures > 0 then exit 1
exit 0

::class LargeYenPremiumPolicy subclass AccountingPolicy
::method init
  use arg refArg, identityArg, entityArg, typeArg, fromArg, toArg = ""
  self~init:super(refArg, identityArg, entityArg, typeArg, fromArg, toArg)

::method propose
  use arg event, book
  numeric digits 50
  amount = .AccountingUtil~requireWholeNonNegative(event~value("amountMinor"), "amountMinor")
  draft = self~newDraft(event, book, event~eventDate, "JPY premium accounting")
  draft~addLine(.AccountingJournalLine~new("1000", "JPY", amount, 0, "Cash received"))
  draft~addLine(.AccountingJournalLine~new("4000", "JPY", 0, amount, "Premium revenue"))
  return .AccountingPolicyDecision~accept(draft, "AJI entity policy")

::options digits 50

::requires "AccountingPersistence.cls"
::requires "AccountingEngine.cls"
::requires "TestSupport.cls"
