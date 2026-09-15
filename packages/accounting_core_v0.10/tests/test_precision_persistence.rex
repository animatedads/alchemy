t = .AccountingTest~new
numeric digits 50

t~assertEq("accounting.integer-minor-unit.numeric-digits-50/0.1", .AccountingBuild~ARITHMETIC_PROFILE, "arithmetic profile advertised")
t~assertEq(50, .AccountingBuild~NUMERIC_DIGITS, "numeric digits contract is 50")

storePath = "./tests/tmp_accounting_store_v04.jsonl"
store = .AccountingFileStore~new(storePath)
book = store~createBook("TOKYO_DEMO_CO_LTD", "TOKYO-STAT", "ENTITY_GAAP")

/* Use the legacy/direct chart surface deliberately: owner hooks must make it durable. */
book~chart~add(.AccountingAccount~new("1000", "JPY cash", "ASSET", "AUTO", "SINGLE", .true, "JPY"))
book~chart~add(.AccountingAccount~new("4000", "JPY revenue", "REVENUE", "AUTO", "SINGLE", .true, "JPY"))
book~chart~seal
book~addPeriod(.AccountingPeriod~new("2026-08", "2026-08-01", "2026-08-31"))

huge = "1234567890123456789012345678901234567890"
expectedTwice = "2469135780246913578024691357802469135780"

dims = .directory~new
dims["externalCompanyNumber"] = "00123456"
evidence = .array~of("000123")
d1 = .AccountingJournalDraft~new("JPY:SALE:1", "2026-08-28", "2026-08", "tokyo.revenue/0.1", "large yen sale", "", evidence)
d1~addLine(.AccountingJournalLine~new("1000", "JPY", huge, 0, "", dims))
d1~addLine(.AccountingJournalLine~new("4000", "JPY", 0, huge))
r1 = book~post(d1)
t~assertTrue(r1~ok, "first large JPY posting succeeds")
t~assertEq(huge, book~balance("1000", "JPY")~debitMinor, "40-digit JPY amount retained exactly")

d2 = .AccountingJournalDraft~new("JPY:SALE:2", "2026-08-28", "2026-08", "tokyo.revenue/0.1", "second large yen sale")
d2~addLine(.AccountingJournalLine~new("1000", "JPY", huge, 0))
d2~addLine(.AccountingJournalLine~new("4000", "JPY", 0, huge))
t~assertTrue(book~post(d2)~ok, "second large JPY posting succeeds")
t~assertEq(expectedTwice, book~balance("1000", "JPY")~debitMinor, "JPY aggregation uses numeric digits 50")

/* Store money as JSON strings, not JSON numeric tokens. */
ss = .stream~new(storePath)
ss~open("read")
storeText = ss~charin(1, ss~chars)
ss~close
t~assertTrue(pos('"debit_minor":"S:I:' || huge || '"', storeText) > 0, "persistence stores monetary values as protected prefixed strings")
t~assertTrue(pos('"numeric_digits":"S:50"', storeText) > 0, "persistence records numeric digits profile as exact text")
t~assertTrue(pos('"amount_representation":"S:PREFIXED_INTEGER_MINOR_UNIT_STRING"', storeText) > 0, "persistence records exact amount encoding")

/* Recover and prove balances/source idempotency survive restart. */
recovered = store~recoverBook
t~assertEq(expectedTwice, recovered~balance("1000", "JPY")~debitMinor, "large JPY balance survives recovery exactly")
t~assertEq(2, recovered~entryCount, "journal count survives recovery")
t~assertEq("00123456", recovered~entry("TOKYO-STAT-J0000000001")~lines[1]~dimensions["externalCompanyNumber"], "leading-zero dimension survives JSON persistence")
t~assertEq("000123", recovered~entry("TOKYO-STAT-J0000000001")~evidenceRefs[1], "leading-zero evidence reference survives JSON persistence")
dup = recovered~post(d1)
t~assertEq("DUPLICATE", dup~status, "direct posting idempotency survives recovery")
changed = .AccountingJournalDraft~new("JPY:SALE:1", "2026-08-28", "2026-08", "tokyo.revenue/0.1", "changed")
changed~addLine(.AccountingJournalLine~new("1000", "JPY", 1, 0))
changed~addLine(.AccountingJournalLine~new("4000", "JPY", 0, 1))
t~assertEq("SOURCE_EVENT_CONFLICT", recovered~post(changed)~errorCode, "changed replay conflicts after recovery")

/* Period lifecycle is durable and carries evidence. */
ev = .array~of("BOARD-CLOSE-MINUTES-2026-08")
recovered~period("2026-08")~close("ACCOUNTANT-01", "month-end close", ev, "2026-09-02T09:00:00+09:00")
t~assertEq("CLOSED", recovered~period("2026-08")~state, "period closes")
t~assertEq(1, recovered~periodTransitions~items, "period transition retained")
t~assertEq("BOARD-CLOSE-MINUTES-2026-08", recovered~periodTransitions[1]~evidenceRefs[1], "period close evidence retained")

recovered2 = store~recoverBook
t~assertEq("CLOSED", recovered2~period("2026-08")~state, "closed period state survives second restart")
t~assertEq(1, recovered2~periodTransitions~items, "period transition history survives restart")
t~assertEq("ACCOUNTANT-01", recovered2~periodTransitions[1]~actorRef, "period actor survives restart")
t~assertEq(expectedTwice, recovered2~balance("1000", "JPY")~debitMinor, "balance still exact after lifecycle replay")

/* Locked is terminal and durable. */
recovered2~period("2026-08")~lock("CONTROLLER-01", "statutory lock", .array~of("LOCK-EVIDENCE-1"), "2026-09-05T12:00:00+09:00")
recovered3 = store~recoverBook
t~assertEq("LOCKED", recovered3~period("2026-08")~state, "locked period survives restart")
t~assertTrue(periodOpenFails(recovered3~period("2026-08")), "locked period cannot be reopened")

/* Arithmetic-profile tampering is rejected during recovery. */
original = .stream~new(storePath)
original~open("read")
tamperText = original~charin(1, original~chars)
original~close
tamperText = tamperText~changestr('"numeric_digits":"S:50"', '"numeric_digits":"S:49"')
tamperPath = "./tests/tmp_accounting_store_v04_tampered.jsonl"
ts = .stream~new(tamperPath)
ts~open("write replace")
ts~charout(tamperText)
ts~close
t~assertTrue(recoverFails(tamperPath), "recovery rejects changed numeric-digits profile")

/* A 51-significant-digit minor-unit amount is rejected rather than rounded. */
tooWide = "123456789012345678901234567890123456789012345678901"
precisionRejected = .false
signal on syntax name precisionFailure
x = .AccountingJournalLine~new("1000", "JPY", tooWide, 0)
signal off syntax
signal skipPrecisionFailure
precisionFailure:
  signal off syntax
  precisionRejected = .true
skipPrecisionFailure:
t~assertTrue(precisionRejected, "amounts wider than numeric digits 50 are rejected rather than rounded")

say "precision/persistence assertions=" t~assertions "failures=" t~failures
if t~failures > 0 then exit 1
exit 0

::routine periodOpenFails
  use arg period
  signal on syntax name caught
  ignore = period~open
  return .false
caught:
  return .true

::routine recoverFails
  use arg path
  signal on syntax name caught
  ignore = .AccountingFileStore~new(path)~recoverBook
  return .false
caught:
  return .true

::options digits 50

::requires "AccountingPersistence.cls"
::requires "TestSupport.cls"
