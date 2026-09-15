t = .AccountingTest~new

engine = makeEngine("FLYLO_AIR_LTD")
p1 = .DemoExpensePolicy~new("flylo.accounting.insurance/0.1", "impl:flylo:insurance:sha256:001", "FLYLO_AIR_LTD", "INSURANCE_PURCHASED", "2026-01-01", "2026-08-15")
p2 = .DemoExpensePolicy~new("flylo.accounting.insurance/0.2", "impl:flylo:insurance:sha256:002", "FLYLO_AIR_LTD", "INSURANCE_PURCHASED", "2026-08-16")
engine~registerPolicy(p1)
engine~registerPolicy(p2)

payload = .directory~new
payload["amountMinor"] = 10000
evidence = .array~of("FLYLO:BOOKING:ABC", "AJI:POLICY:1001")
event = .AccountingEvent~new("FLYLO:INSURANCE:1", "FLYLO_AIR_LTD", "INSURANCE_PURCHASED", "2026-08-28", "ECONOMIC-CHAIN-001", "ALL_JAPAN_INSURANCE_CO_LTD", "FLYLO.BOOKING.ENGINE", payload, evidence)
r = engine~transact(event)
t~assertTrue(r~ok, "event transaction succeeds")
t~assertEq("POSTED", r~status, "transaction posts")
t~assertEq(p2~policyRef, r~entry~policyRef, "event-date policy selected")
t~assertEq(p2~policyIdentity, r~entry~policyIdentity, "exact executable policy identity locked")
t~assertEq(event~fingerprint, r~entry~sourceEventFingerprint, "source event fingerprint locked")
t~assertEq("INSURANCE_PURCHASED", r~entry~eventType, "event type retained")
t~assertEq("ALL_JAPAN_INSURANCE_CO_LTD", r~entry~counterpartyEntityId, "counterparty retained")
t~assertEq(2, r~entry~evidenceRefs~items, "event evidence preserved")
t~assertEq(1, (engine~entriesByCorrelation("ECONOMIC-CHAIN-001"))~items, "correlation query finds own-company entry")
t~assertEq(1, p2~calls, "policy called once")

/* Exact replay is handled before policy dispatch. */
dup = engine~transact(event)
t~assertTrue(dup~ok, "exact replay accepted idempotently")
t~assertEq("DUPLICATE", dup~status, "exact replay returns original entry")
t~assertEq(r~entry~entryId, dup~entry~entryId, "exact replay returns immutable original")
t~assertEq(1, p2~calls, "exact replay does not re-evaluate policy")

/* Same source identity with changed operational evidence is a conflict before policy. */
changedPayload = .directory~new
changedPayload["amountMinor"] = 10001
changed = .AccountingEvent~new("FLYLO:INSURANCE:1", "FLYLO_AIR_LTD", "INSURANCE_PURCHASED", "2026-08-28", "ECONOMIC-CHAIN-001", "ALL_JAPAN_INSURANCE_CO_LTD", "FLYLO.BOOKING.ENGINE", changedPayload, evidence)
conflict = engine~transact(changed)
t~assertEq("SOURCE_EVENT_CONFLICT", conflict~errorCode, "changed replay rejected")
t~assertEq(1, p2~calls, "changed replay rejected before policy dispatch")

/* Historical event resolves the historical executable policy. */
historicalPayload = .directory~new
historicalPayload["amountMinor"] = 5000
historical = .AccountingEvent~new("FLYLO:INSURANCE:HIST", "FLYLO_AIR_LTD", "INSURANCE_PURCHASED", "2026-08-10", "ECONOMIC-CHAIN-HIST", "ALL_JAPAN_INSURANCE_CO_LTD", "FLYLO.BOOKING.ENGINE", historicalPayload)
hr = engine~transact(historical)
t~assertTrue(hr~ok, "historical event posts")
t~assertEq(p1~policyIdentity, hr~entry~policyIdentity, "historical policy identity retained")
t~assertEq(1, p1~calls, "historical policy called")

/* Policy can reject without producing a journal. */
rejectEngine = makeEngine("VECTOR_MERIDIAN_MARKETS_LTD")
rejectPolicy = .RejectPolicy~new("vmm.accounting.otc/0.1", "impl:vmm:reject:1", "VECTOR_MERIDIAN_MARKETS_LTD", "OTC_TRADE", "2026-01-01")
rejectEngine~registerPolicy(rejectPolicy)
re = .AccountingEvent~new("VMM:OTC:BAD", "VECTOR_MERIDIAN_MARKETS_LTD", "OTC_TRADE", "2026-08-28")
rr = rejectEngine~transact(re)
t~assertTrue(\rr~ok, "policy rejection does not post")
t~assertEq("OTC_ACCOUNTING_EVIDENCE_INCOMPLETE", rr~errorCode, "policy rejection code preserved")
t~assertEq(0, rejectEngine~book~entryCount, "rejected policy creates no journal")

/* A policy cannot detach its proposal from the source event/policy identity. */
badEngine = makeEngine("ALL_JAPAN_INSURANCE_CO_LTD")
badPolicy = .BadBindingPolicy~new("aji.accounting.premium/0.1", "impl:aji:premium:1", "ALL_JAPAN_INSURANCE_CO_LTD", "POLICY_BOUND", "2026-01-01")
badEngine~registerPolicy(badPolicy)
be = .AccountingEvent~new("AJI:POLICY:1", "ALL_JAPAN_INSURANCE_CO_LTD", "POLICY_BOUND", "2026-08-28")
br = badEngine~transact(be)
t~assertTrue(\br~ok, "unbound policy draft rejected")
t~assertEq("POLICY_DRAFT_BINDING_INVALID", br~errorCode, "policy/source binding enforced")
t~assertEq(0, badEngine~book~entryCount, "invalid binding creates no journal")

/* Legal entity and missing policy boundaries. */
wrongEntity = .AccountingEvent~new("X:1", "OTHER_CO", "INSURANCE_PURCHASED", "2026-08-28")
t~assertEq("LEGAL_ENTITY_MISMATCH", engine~transact(wrongEntity)~errorCode, "cross-company event rejected")
unknownType = .AccountingEvent~new("FLYLO:UNKNOWN:1", "FLYLO_AIR_LTD", "UNKNOWN_EVENT", "2026-08-28")
t~assertEq("POLICY_NOT_FOUND", engine~transact(unknownType)~errorCode, "unknown accounting treatment rejected")



/* Wire/Queue-friendly event projection round-trips exactly. */
projection = .AccountingEventCodec~toProjection(event)
roundTrip = .AccountingEventCodec~fromProjection(projection)
t~assertEq(event~fingerprint, roundTrip~fingerprint, "event projection round-trip preserves identity")
projectionEventPayload = .directory~new; projectionEventPayload["amountMinor"] = 700
projectionEvent = .AccountingEvent~new("FLYLO:INSURANCE:PROJECTION:1", "FLYLO_AIR_LTD", "INSURANCE_PURCHASED", "2026-08-28", "ECONOMIC-PROJECTION-1", "ALL_JAPAN_INSURANCE_CO_LTD", "FLYLO.BOOKING.ENGINE", projectionEventPayload)
projectionResult = engine~transactProjection(.AccountingEventCodec~toProjection(projectionEvent))
t~assertTrue(projectionResult~ok, "normalized event projection can transact")
t~assertEq("POSTED", projectionResult~status, "projected event posts")
badProjection = .AccountingEventCodec~toProjection(.AccountingEvent~new("BAD:1", "FLYLO_AIR_LTD", "UNKNOWN_EVENT", "2026-08-28"))
badProjection["contract_generation"] = "accounting.event/999"
t~assertEq("EVENT_PROJECTION_INVALID", engine~transactProjection(badProjection)~errorCode, "unsupported event projection generation rejected")

/* v0.3.1 sibling-branch repair regression:
 * exact institutional-scale minor units must be validated under NUMERIC DIGITS 50
 * before DATATYPE(..., "W").  Retained explicitly even though the v0.4 precision
 * suite exercises much larger 40-digit JPY values. */
largePayload = .directory~new
largePayload["amountMinor"] = 12000000000
largeEvent = .AccountingEvent~new("FLYLO:INSURANCE:LARGE:1", "FLYLO_AIR_LTD", "INSURANCE_PURCHASED", "2026-08-28", "ECONOMIC-LARGE-1", "ALL_JAPAN_INSURANCE_CO_LTD", "FLYLO.BOOKING.ENGINE", largePayload)
largeResult = engine~transact(largeEvent)
t~assertTrue(largeResult~ok, "v0.3.1 regression: 12bn exact minor-unit event transacts")
t~assertEq("12000000000", largeResult~entry~lines[1]~debitMinor, "v0.3.1 regression: 12bn exact minor units retained")

/* Nested event payload is detached from caller mutation. */
nested = .directory~new
structure = .directory~new
structure["trustRef"] = "TRUST-A"
nested["structure"] = structure
immutableEvent = .AccountingEvent~new("FLYLO:IMMUTABLE:1", "FLYLO_AIR_LTD", "UNKNOWN_EVENT", "2026-08-28", "", "", "SOURCE", nested)
immutableFingerprint = immutableEvent~fingerprint
structure["trustRef"] = "TRUST-MUTATED"
t~assertEq(immutableFingerprint, immutableEvent~fingerprint, "caller nested mutation cannot change event identity")
copyPayload = immutableEvent~payload
copyPayload["structure"]["trustRef"] = "TRUST-COPY-MUTATED"
t~assertEq("TRUST-A", immutableEvent~payload["structure"]["trustRef"], "payload getter returns detached nested structure")

/* Closed periods reject at posting mechanics rather than crashing policy execution. */
closedEngine = makeEngine("CLOSED_CO")
closedPolicy = .DemoExpensePolicy~new("closed.accounting/0.1", "impl:closed:1", "CLOSED_CO", "INSURANCE_PURCHASED", "2026-01-01")
closedEngine~registerPolicy(closedPolicy)
closedEngine~book~period("2026-08")~close
cp = .directory~new; cp["amountMinor"] = 1
closedEvent = .AccountingEvent~new("CLOSED:1", "CLOSED_CO", "INSURANCE_PURCHASED", "2026-08-28", "", "", "SOURCE", cp)
closedResult = closedEngine~transact(closedEvent)
t~assertEq("PERIOD_NOT_OPEN", closedResult~errorCode, "closed period returns posting rejection")

/* Policy exceptions become bounded transaction failures. */
noPeriod = .AccountingEngine~new("NO_PERIOD_CO", "NP")
noPeriod~book~chart~add(.AccountingAccount~new("2000", "Payable", "LIABILITY"))
noPeriod~book~chart~add(.AccountingAccount~new("6100", "Expense", "EXPENSE"))
noPeriod~book~chart~seal
npPolicy = .DemoExpensePolicy~new("np.accounting/0.1", "impl:np:1", "NO_PERIOD_CO", "INSURANCE_PURCHASED", "2026-01-01")
noPeriod~registerPolicy(npPolicy)
npPayload = .directory~new; npPayload["amountMinor"] = 1
npEvent = .AccountingEvent~new("NP:1", "NO_PERIOD_CO", "INSURANCE_PURCHASED", "2026-08-28", "", "", "SOURCE", npPayload)
npResult = noPeriod~transact(npEvent)
t~assertTrue(\npResult~ok, "policy execution failure is bounded")
t~assertEq("POLICY_EXECUTION_FAILED", npResult~errorCode, "missing period is reported as policy execution failure")

/* Overlapping executable policy ranges are forbidden. */
overlap = .DemoExpensePolicy~new("flylo.accounting.insurance/evil", "impl:flylo:overlap", "FLYLO_AIR_LTD", "INSURANCE_PURCHASED", "2026-08-01", "2026-08-31")
t~assertTrue(registerFails(engine~policies, overlap), "overlapping policy registration rejected")

/* Accounting policy source packages must compile with NUMERIC DIGITS 50. */
lowDigitsPolicy = .LowDigitsPolicy~new("low.accounting/0.1", "impl:low:digits9", "LOW_DIGITS_CO", "INSURANCE_PURCHASED", "2026-01-01")
t~assertEq(9, lowDigitsPolicy~class~package~digits, "negative fixture is compiled at default numeric digits")
t~assertTrue(registerFails(.AccountingPolicyCatalog~new, lowDigitsPolicy), "policy package below digits 50 is rejected")

say "transaction assertions=" t~assertions "failures=" t~failures
if t~failures > 0 then exit 1
exit 0

::routine makeEngine
  use arg entity
  e = .AccountingEngine~new(entity, entity || "-STAT")
  e~book~chart~add(.AccountingAccount~new("1000", "Cash / receivable", "ASSET"))
  e~book~chart~add(.AccountingAccount~new("2000", "Payable", "LIABILITY"))
  e~book~chart~add(.AccountingAccount~new("6100", "Expense", "EXPENSE"))
  e~book~chart~seal
  e~book~addPeriod(.AccountingPeriod~new("2026-08", "2026-08-01", "2026-08-31"))
  return e

::routine registerFails
  use arg catalog, policy
  signal on syntax name caught
  ignore = catalog~register(policy)
  return .false
caught:
  return .true

::class DemoExpensePolicy subclass AccountingPolicy
::attribute calls get
::method init
  expose calls
  use arg refArg, identityArg, entityArg, typeArg, fromArg, toArg = ""
  calls = 0
  self~init:super(refArg, identityArg, entityArg, typeArg, fromArg, toArg)
::method propose
  expose calls
  use arg event, book
  calls += 1
  amount = .AccountingUtil~requireWholeNonNegative(event~value("amountMinor"), "amountMinor")
  if amount = 0 then return .AccountingPolicyDecision~reject("ZERO_NOT_ACCOUNTABLE", event~sourceEventRef)
  draft = self~newDraft(event, book, event~eventDate, "Insurance accounting consequence")
  draft~addLine(.AccountingJournalLine~new("6100", "GBP", amount, 0, "Insurance expense"))
  draft~addLine(.AccountingJournalLine~new("2000", "GBP", 0, amount, "Insurance payable"))
  return .AccountingPolicyDecision~accept(draft, "Entity policy maps authoritative insurance event")

::class RejectPolicy subclass AccountingPolicy
::method init
  use arg refArg, identityArg, entityArg, typeArg, fromArg, toArg = ""
  self~init:super(refArg, identityArg, entityArg, typeArg, fromArg, toArg)
::method propose
  use arg event, book
  return .AccountingPolicyDecision~reject("OTC_ACCOUNTING_EVIDENCE_INCOMPLETE", event~sourceEventRef)

::class BadBindingPolicy subclass AccountingPolicy
::method init
  use arg refArg, identityArg, entityArg, typeArg, fromArg, toArg = ""
  self~init:super(refArg, identityArg, entityArg, typeArg, fromArg, toArg)
::method propose
  use arg event, book
  period = book~periodForDate(event~eventDate)
  draft = .AccountingJournalDraft~new(event~sourceEventRef, event~eventDate, period~periodId, self~policyRef)
  draft~addLine(.AccountingJournalLine~new("1000", "GBP", 1, 0))
  draft~addLine(.AccountingJournalLine~new("2000", "GBP", 0, 1))
  return .AccountingPolicyDecision~accept(draft)

::options digits 50

::requires "AccountingEngine.cls"
::requires "LowDigitsPolicy.cls"
::requires "TestSupport.cls"
