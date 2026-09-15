/* Generic tax determination demo: one legal entity, UK VAT + AU GST. */
entity = "GLOBAL_SERVICES_LLP"
engine = .AccountingEngine~new(entity, "STAT")
engine~book~addAccount(.AccountingAccount~new("1000", "Receivable", "ASSET"))
engine~book~addAccount(.AccountingAccount~new("2200", "Tax payable", "LIABILITY"))
engine~book~addAccount(.AccountingAccount~new("4000", "Revenue", "REVENUE"))
engine~book~sealChart
engine~book~addPeriod(.AccountingPeriod~new("2026", "2026-01-01", "2026-12-31"))

engine~scopes~registerTaxRegistration(.AccountingTaxRegistration~new("TAX-GB-VAT", entity, "GB", "HMRC", "VAT", "GB123456789", "", "VAT_REGISTERED", "2026-01-01"))
engine~scopes~registerTaxElection(.AccountingTaxElection~new("ELECT-GB-VAT-2026", "sha256:demo-gb-election", entity, "TAX-GB-VAT", "uk.vat.demo/2026", "DEMO-UK-VAT-RULESET", "HMRC-NEAREST-PENNY", "PER_LINE", "VAT_RETURN", "2026-01-01"))
engine~scopes~registerTaxRegistration(.AccountingTaxRegistration~new("TAX-AU-GST", entity, "AU", "ATO", "GST", "ABN-GST-DEMO", "", "GST_REGISTERED", "2026-01-01"))
engine~scopes~registerTaxElection(.AccountingTaxElection~new("ELECT-AU-GST-2026", "sha256:demo-au-election", entity, "TAX-AU-GST", "au.gst.demo/2026", "DEMO-AU-GST-RULESET", "ATO-NEAREST-CENT", "PER_LINE", "BAS", "2026-01-01"))

engine~registerTaxPolicy(.DemoUKVATTaxPolicy~new("demo.uk.vat/0.1", "sha256:demo-uk-code", "uk.vat.demo/2026", "DEMO-UK-VAT-RULESET"))
engine~registerTaxPolicy(.DemoAUGSTTaxPolicy~new("demo.au.gst/0.1", "sha256:demo-au-code", "au.gst.demo/2026", "DEMO-AU-GST-RULESET"))
engine~registerPolicy(.DemoTaxPostingPolicy~new("demo.accounting.tax/0.1", "sha256:demo-accounting-tax", entity, "TAX_DETERMINED", "2026-01-01"))

uk = .AccountingTaxRequest~new("GB-INVOICE-1-LINE-1", entity, "2026-08-28", "GBP", 2, "999", "TAX-GB-VAT", "PER_LINE", "GB-INVOICE-1")
ukResult = engine~transactTax(uk)
say "UK tax minor:" ukResult~determination~taxMinor "journal:" ukResult~entry~entryId

au = .AccountingTaxRequest~new("AU-INVOICE-1-LINE-1", entity, "2026-08-28", "AUD", 2, "95", "TAX-AU-GST", "PER_LINE", "AU-INVOICE-1")
auResult = engine~transactTax(au)
say "AU tax minor:" auResult~determination~taxMinor "journal:" auResult~entry~entryId

say "One legal entity; two sovereign tax registrations; one accounting book."
exit 0

::class DemoUKVATTaxPolicy subclass AccountingTaxPolicy
::method determine
  use arg request, registration, election
  raw = .AccountingTaxExactAmount~fromBasisRate(request~taxableBasisMinor, 20, 100)
  return .AccountingTaxPolicyDecision~accept(self~newDetermination(request, registration, election, raw~toMinorUnits("HALF_UP"), "GB-VAT-STANDARD", "DEMO_EXCLUSIVE_20_PERCENT", raw))

::class DemoAUGSTTaxPolicy subclass AccountingTaxPolicy
::method determine
  use arg request, registration, election
  raw = .AccountingTaxExactAmount~fromBasisRate(request~taxableBasisMinor, 10, 100)
  return .AccountingTaxPolicyDecision~accept(self~newDetermination(request, registration, election, raw~toMinorUnits("HALF_UP"), "AU-GST-TAXABLE", "DEMO_EXCLUSIVE_10_PERCENT", raw))

::class DemoTaxPostingPolicy subclass AccountingPolicy
::method propose
  use arg event, book
  basis = .AccountingUtil~requireWholeNonNegative(event~value("taxableBasisMinor"), "basis")
  tax = .AccountingUtil~requireWholeNonNegative(event~value("taxMinor"), "tax")
  gross = basis + tax
  dims = event~value("accountingDimensions")
  draft = self~newDraft(event, book, event~eventDate, "Tax determination")
  draft~addLine(.AccountingJournalLine~new("1000", event~value("currency"), gross, 0, "Receivable", dims))
  draft~addLine(.AccountingJournalLine~new("4000", event~value("currency"), 0, basis, "Revenue", dims))
  draft~addLine(.AccountingJournalLine~new("2200", event~value("currency"), 0, tax, "Tax payable", dims))
  return .AccountingPolicyDecision~accept(draft)

::options digits 50
::requires "AccountingEngine.cls"
