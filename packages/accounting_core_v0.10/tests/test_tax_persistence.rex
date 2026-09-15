t = .AccountingTest~new
numeric digits 50

path = "./tests/tmp_accounting_tax_store_v06.jsonl"
store = .AccountingFileStore~new(path)
book = store~createBook("FOREIGN_DISTANCE_SELLER_INC", "STAT", "ENTITY_GAAP")
book~addAccount(.AccountingAccount~new("1000", "Receivable", "ASSET", "AUTO", "SINGLE", .true, "GBP"))
book~addAccount(.AccountingAccount~new("2200", "VAT payable", "LIABILITY", "AUTO", "SINGLE", .true, "GBP"))
book~addAccount(.AccountingAccount~new("4000", "Revenue", "REVENUE", "AUTO", "SINGLE", .true, "GBP"))
book~sealChart
book~addPeriod(.AccountingPeriod~new("2026", "2026-01-01", "2026-12-31"))
engine = .AccountingEngine~new(book~legalEntityId, book~bookId, book~reportingBasis, book)
engine~scopes~registerTaxRegistration(.AccountingTaxRegistration~new("TAX-GB-VAT", book~legalEntityId, "GB", "HMRC", "VAT", "GB001234567", "", "NON_ESTABLISHED_TAXABLE_PERSON", "2026-01-01"))
engine~scopes~registerTaxElection(.AccountingTaxElection~new("ELECT-GB-VAT-2026", "sha256:gb-election-persist", book~legalEntityId, "TAX-GB-VAT", "uk.vat.rules/2026", "UK-VAT-PERSIST-RULESET", "HMRC-NEAREST-PENNY", "PER_LINE", "VAT_RETURN", "2026-01-01"))
engine~registerTaxPolicy(.PersistUKVATPolicy~new("uk.vat.tax/persist", "sha256:uk-policy-persist", "uk.vat.rules/2026", "UK-VAT-PERSIST-RULESET"))
engine~registerPolicy(.PersistTaxAccountingPolicy~new("seller.accounting.tax/0.6", "sha256:seller-tax-accounting", book~legalEntityId, "TAX_DETERMINED", "2026-01-01"))

dims = .directory~new
dims[.AccountingDimensionKeys~MATTER_REF] = "000123"
request = .AccountingTaxRequest~new("WEBSALE:000001:LINE:01", book~legalEntityId, "2026-08-28", "GBP", 2, "12345", "TAX-GB-VAT", "PER_LINE", "ORDER:000001", "GB-CONSUMER", "ECOMMERCE.CHECKOUT", .array~of("CHECKOUT:000001"), dims)
first = engine~transactTax(request)
t~assertTrue(first~ok, "durable tax determination posts")
t~assertEq("POSTED", first~status, "durable tax posting status")
t~assertEq("2469", first~determination~taxMinor, "durable UK VAT determination exact")
entryMeta = first~entry~metadata
t~assertEq(request~fingerprint, entryMeta["accounting.taxRequestFingerprint"], "tax request fingerprint is persisted in journal metadata")
lineDims = first~entry~lines[3]~dimensions
t~assertEq("TAX-GB-VAT", lineDims[.AccountingDimensionKeys~TAX_REGISTRATION_REF], "tax registration retained on durable tax line")
t~assertEq("ELECT-GB-VAT-2026", lineDims[.AccountingDimensionKeys~TAX_ELECTION_REF], "tax election retained on durable tax line")
t~assertEq("sha256:gb-election-persist", lineDims[.AccountingDimensionKeys~TAX_ELECTION_IDENTITY], "tax election identity retained on durable tax line")
t~assertEq("000123", lineDims[.AccountingDimensionKeys~MATTER_REF], "opaque matter identity retained on durable tax line")

recoveredBook = store~recoverBook
recoveredEngine = .AccountingEngine~new(recoveredBook~legalEntityId, recoveredBook~bookId, recoveredBook~reportingBasis, recoveredBook)
/* Deliberately do not restore scopes, tax policy or accounting policy.  An
 * already-accounted tax request must be recognized before either dispatch. */
replay = recoveredEngine~transactTax(request)
t~assertTrue(replay~ok, "durable tax replay succeeds without policy/scopes")
t~assertEq("DUPLICATE", replay~status, "durable tax replay returns original entry")
t~assertEq(first~entry~entryId, replay~entry~entryId, "durable tax replay returns immutable original")

changed = .AccountingTaxRequest~new("WEBSALE:000001:LINE:01", book~legalEntityId, "2026-08-28", "GBP", 2, "12346", "TAX-GB-VAT", "PER_LINE", "ORDER:000001", "GB-CONSUMER", "ECOMMERCE.CHECKOUT", .array~of("CHECKOUT:000001"), dims)
conflict = recoveredEngine~transactTax(changed)
t~assertEq("SOURCE_TAX_EVENT_CONFLICT", conflict~errorCode, "changed durable tax request conflicts before policy/scopes")

t~assertEq("14814", recoveredBook~balance("1000", "GBP")~debitMinor, "gross durable receivable recovered exactly")
t~assertEq("12345", recoveredBook~balance("4000", "GBP")~creditMinor, "net durable revenue recovered exactly")
t~assertEq("2469", recoveredBook~balance("2200", "GBP")~creditMinor, "durable VAT payable recovered exactly")

say "tax persistence assertions=" t~assertions "failures=" t~failures
if t~failures > 0 then exit 1
exit 0

::class PersistUKVATPolicy subclass AccountingTaxPolicy
::method determine
  use arg request, registration, election
  raw = .AccountingTaxExactAmount~fromBasisRate(request~taxableBasisMinor, 20, 100)
  return .AccountingTaxPolicyDecision~accept(self~newDetermination(request, registration, election, raw~toMinorUnits("HALF_UP"), "GB-VAT-STANDARD", "EXCLUSIVE_RATE_20_PERCENT", raw))

::class PersistTaxAccountingPolicy subclass AccountingPolicy
::method propose
  use arg event, book
  basis = .AccountingUtil~requireWholeNonNegative(event~value("taxableBasisMinor"), "basis")
  tax = .AccountingUtil~requireWholeNonNegative(event~value("taxMinor"), "tax")
  gross = basis + tax
  currency = event~value("currency")
  dims = event~value("accountingDimensions")
  draft = self~newDraft(event, book, event~eventDate, "Durable VAT accounting")
  draft~addLine(.AccountingJournalLine~new("1000", currency, gross, 0, "Gross receivable", dims))
  draft~addLine(.AccountingJournalLine~new("4000", currency, 0, basis, "Revenue", dims))
  draft~addLine(.AccountingJournalLine~new("2200", currency, 0, tax, "VAT payable", dims))
  return .AccountingPolicyDecision~accept(draft)

::options digits 50
::requires "AccountingPersistence.cls"
::requires "AccountingEngine.cls"
::requires "TestSupport.cls"
