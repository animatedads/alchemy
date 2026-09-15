t = .AccountingTest~new

flylo = makeBook("FLYLO_AIR_LTD", "FLYLO-STAT")
vmm = makeBook("VECTOR_MERIDIAN_MARKETS_LTD", "VMM-STAT")

/* Same economic correlation can exist independently in two legal-entity books. */
fd = .AccountingJournalDraft~new("FLYLO:POLICY:AJI-1001", "2026-08-28", "2026-08", "flylo.accounting.insurance/0.1", "Insurance premium", "ECONOMIC-CHAIN-001")
fd~addLine(.AccountingJournalLine~new("6100", "GBP", 10000, 0, "Insurance expense"))
fd~addLine(.AccountingJournalLine~new("2000", "GBP", 0, 10000, "Payable"))
fr = flylo~post(fd)
t~assertTrue(fr~ok, "FlyLo posting succeeds")
t~assertEq("POSTED", fr~status, "FlyLo posting status")

dims = .directory~new
dims["trustOrVehicleRef"] = "CAYMAN_PREMIUM_RECEIVABLES_TRUST_NO_3"
dims["legalOwner"] = "AJI_RECEIVABLES_TRUSTEE_LTD"
dims["beneficialOwner"] = "ALL_JAPAN_INSURANCE_CO_LTD"
dims["economicRiskBearer"] = "ALL_JAPAN_INSURANCE_CO_LTD"
dims["encumbranceRef"] = "REHYPOTHECATION-FACILITY-77"
vd = .AccountingJournalDraft~new("VMM:OTC:SHORT:9001", "2026-08-28", "2026-08", "vmm.accounting.derivatives/0.1", "OTC short fair value profit", "ECONOMIC-CHAIN-001")
vd~addLine(.AccountingJournalLine~new("1300", "GBP", 1000000, 0, "Derivative asset", dims))
vd~addLine(.AccountingJournalLine~new("4100", "GBP", 0, 1000000, "Trading P&L", dims))
vr = vmm~post(vd)
t~assertTrue(vr~ok, "VMM posting succeeds")
t~assertEq(1, flylo~entryCount, "FlyLo has its own entry")
t~assertEq(1, vmm~entryCount, "VMM has its own entry")
t~assertEq("CAYMAN_PREMIUM_RECEIVABLES_TRUST_NO_3", vr~entry~lines[1]~dimensions["trustOrVehicleRef"], "unusual legal dimension preserved")

/* Same source ref is idempotent inside one book. */
dup = vmm~post(vd)
t~assertEq("DUPLICATE", dup~status, "duplicate source is idempotent")

/* Same source ref with changed economic content is a conflict. */
changed = .AccountingJournalDraft~new("VMM:OTC:SHORT:9001", "2026-08-28", "2026-08", "vmm.accounting.derivatives/0.1", "Changed", "ECONOMIC-CHAIN-001")
changed~addLine(.AccountingJournalLine~new("1300", "GBP", 999999, 0))
changed~addLine(.AccountingJournalLine~new("4100", "GBP", 0, 999999))
cr = vmm~post(changed)
t~assertEq("SOURCE_EVENT_CONFLICT", cr~errorCode, "changed duplicate rejected")

/* Each currency balances independently. */
fx = .AccountingJournalDraft~new("VMM:FX:1", "2026-08-28", "2026-08", "vmm.accounting.fx/0.1")
fx~addLine(.AccountingJournalLine~new("1000", "USD", 50000, 0))
fx~addLine(.AccountingJournalLine~new("2000", "USD", 0, 50000))
fx~addLine(.AccountingJournalLine~new("1000", "GBP", 40000, 0))
fx~addLine(.AccountingJournalLine~new("2000", "GBP", 0, 40000))
t~assertTrue(vmm~post(fx)~ok, "multi-currency entry balances by currency")

badfx = .AccountingJournalDraft~new("VMM:FX:BAD", "2026-08-28", "2026-08", "vmm.accounting.fx/0.1")
badfx~addLine(.AccountingJournalLine~new("1000", "USD", 50000, 0))
badfx~addLine(.AccountingJournalLine~new("2000", "GBP", 0, 50000))
br = vmm~post(badfx)
t~assertEq("UNBALANCED_CURRENCY", br~errorCode, "cross-currency false balance rejected")

/* Reversal is a new immutable journal. */
rr = vmm~reverse(vr~entry~entryId, "VMM:OTC:SHORT:9001:REV", "2026-08-28", "2026-08", "vmm.accounting.derivatives/0.1")
t~assertTrue(rr~ok, "reversal succeeds")
t~assertEq(vr~entry~entryId, rr~entry~reversalOf, "reversal linkage retained")

/* Closed period prevents posting. */
vmm~period("2026-08")~close
closed = .AccountingJournalDraft~new("VMM:CLOSED:1", "2026-08-28", "2026-08", "x/0.1")
closed~addLine(.AccountingJournalLine~new("1000", "GBP", 1, 0))
closed~addLine(.AccountingJournalLine~new("2000", "GBP", 0, 1))
t~assertEq("PERIOD_NOT_OPEN", vmm~post(closed)~errorCode, "closed period rejects posting")


/* SINGLE currency accounts enforce their declared currency. */
single = .AccountingBook~new("SINGLE_CCY_CO", "SINGLE", "ENTITY_GAAP")
single~chart~add(.AccountingAccount~new("1000", "GBP cash", "ASSET", "AUTO", "SINGLE", .true, "GBP"))
single~chart~add(.AccountingAccount~new("2000", "Payable", "LIABILITY"))
single~chart~seal
single~addPeriod(.AccountingPeriod~new("2026-08", "2026-08-01", "2026-08-31"))
sd = .AccountingJournalDraft~new("SINGLE:USD:1", "2026-08-28", "2026-08", "single.test/0.1")
sd~addLine(.AccountingJournalLine~new("1000", "USD", 100, 0))
sd~addLine(.AccountingJournalLine~new("2000", "USD", 0, 100))
sr = single~post(sd)
t~assertEq("ACCOUNT_CURRENCY_MISMATCH", sr~errorCode, "single-currency account rejects wrong currency")

say "core assertions=" t~assertions "failures=" t~failures
if t~failures > 0 then exit 1
exit 0

::routine makeBook
  use arg entity, bookId
  b = .AccountingBook~new(entity, bookId, "ENTITY_GAAP")
  b~chart~add(.AccountingAccount~new("1000", "Cash", "ASSET"))
  b~chart~add(.AccountingAccount~new("1300", "Derivative asset", "ASSET"))
  b~chart~add(.AccountingAccount~new("2000", "Payables", "LIABILITY"))
  b~chart~add(.AccountingAccount~new("4100", "Trading revenue", "REVENUE"))
  b~chart~add(.AccountingAccount~new("6100", "Insurance expense", "EXPENSE"))
  b~chart~seal
  b~addPeriod(.AccountingPeriod~new("2026-08", "2026-08-01", "2026-08-31"))
  return b

::options digits 50

::requires "AccountingCore.cls"
::requires "TestSupport.cls"
