t = .AccountingTest~new
numeric digits 50

storePath = "./tests/tmp_accounting_scope_store_v05.jsonl"
store = .AccountingFileStore~new(storePath)
book = store~createBook("US_DISTANCE_SELLER_INC", "STAT", "ENTITY_GAAP")
book~addAccount(.AccountingAccount~new("1000", "Cash", "ASSET", "AUTO", "SINGLE", .true, "GBP"))
book~addAccount(.AccountingAccount~new("2200", "VAT payable", "LIABILITY", "AUTO", "SINGLE", .true, "GBP"))
book~sealChart
book~addPeriod(.AccountingPeriod~new("2026", "2026-01-01", "2026-12-31"))
engine = .AccountingEngine~new(book~legalEntityId, book~bookId, book~reportingBasis, book)
engine~scopes~registerTaxRegistration(.AccountingTaxRegistration~new("TAX-GB-VAT", book~legalEntityId, "GB", "HMRC", "VAT", "GB001234567", "", "NON_ESTABLISHED_TAXABLE_PERSON", "2026-01-01"))
engine~scopes~registerTaxElection(.AccountingTaxElection~new("ELECT-GB-VAT-2026", "sha256:gb-vat-election-2026", book~legalEntityId, "TAX-GB-VAT", "uk.vat.rules/2026", "UK-RULES-ID", "HMRC-NEAREST-PENNY", "PER_LINE", "VAT_RETURN", "2026-01-01"))

dims = .directory~new
dims[.AccountingDimensionKeys~TAX_REGISTRATION_REF] = "TAX-GB-VAT"
dims[.AccountingDimensionKeys~TAX_ELECTION_REF] = "ELECT-GB-VAT-2026"
dims[.AccountingDimensionKeys~TAX_ELECTION_IDENTITY] = "sha256:gb-vat-election-2026"
dims[.AccountingDimensionKeys~MATTER_REF] = "000123"
draft = .AccountingJournalDraft~new("SALE:GB:001", "2026-08-28", "2026", "manual/0.1", "Foreign seller UK VAT")
draft~addLine(.AccountingJournalLine~new("1000", "GBP", "2000", 0, "Cash", dims))
draft~addLine(.AccountingJournalLine~new("2200", "GBP", 0, "2000", "VAT", dims))
posted = engine~post(draft)
t~assertTrue(posted~ok, "scope-tagged journal persists")

recovered = store~recoverBook
t~assertEq("1", recovered~entryCount, "scope-tagged journal recovered")
line = recovered~entries[1]~lines[1]
rd = line~dimensions
t~assertEq("TAX-GB-VAT", rd[.AccountingDimensionKeys~TAX_REGISTRATION_REF], "tax registration identity survives restart")
t~assertEq("ELECT-GB-VAT-2026", rd[.AccountingDimensionKeys~TAX_ELECTION_REF], "tax election reference survives restart")
t~assertEq("sha256:gb-vat-election-2026", rd[.AccountingDimensionKeys~TAX_ELECTION_IDENTITY], "exact tax election identity survives restart")
t~assertEq("000123", rd[.AccountingDimensionKeys~MATTER_REF], "leading-zero matter identity survives restart")

selectors = .directory~new
selectors[.AccountingDimensionKeys~TAX_REGISTRATION_REF] = .array~of("TAX-GB-VAT")
boundary = .AccountingReportingBoundary~new("GB-VAT-RECOVERED", "HMRC", "VAT_RETURN", "2026-01-01", "", .array~of(book~legalEntityId), .array~of(book~bookId), selectors, "uk.vat.reporting/2026", "UK-VAT-REPORT-ID")
view = .AccountingReportingService~buildView(boundary, .array~of(recovered))
t~assertEq("2", view~lineCount, "reporting boundary selects persisted tax dimensions after restart")
totals = view~totals
t~assertEq("2000", totals["GBP"]["debit_minor"], "recovered report exact debit")
t~assertEq("2000", totals["GBP"]["credit_minor"], "recovered report exact credit")

say "scope persistence assertions=" t~assertions "failures=" t~failures
if t~failures > 0 then exit 1
exit 0

::options digits 50
::requires "AccountingPersistence.cls"
::requires "AccountingEngine.cls"
::requires "TestSupport.cls"
