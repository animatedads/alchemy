t = .AccountingTest~new
numeric digits 50

entity = "ANGLO_AUSTRALIAN_LAW_LLP"
engine = .AccountingEngine~new(entity, "FIRM-STAT", "ENTITY_GAAP")
book = engine~book
book~addAccount(.AccountingAccount~new("1000", "Operating cash", "ASSET", "AUTO", "MULTI"))
book~addAccount(.AccountingAccount~new("1100", "Client bank", "ASSET", "AUTO", "MULTI"))
book~addAccount(.AccountingAccount~new("2100", "Client money liability", "LIABILITY", "AUTO", "MULTI"))
book~addAccount(.AccountingAccount~new("2200", "Tax payable", "LIABILITY", "AUTO", "MULTI"))
book~addAccount(.AccountingAccount~new("4000", "Legal fees", "REVENUE", "AUTO", "MULTI"))
book~sealChart
book~addPeriod(.AccountingPeriod~new("2026", "2026-01-01", "2026-12-31"))

scopes = engine~scopes
london = .AccountingEstablishment~new("EST-LONDON", entity, "GB", "PLACE_OF_BUSINESS", "2026-01-01")
sydney = .AccountingEstablishment~new("EST-SYDNEY", entity, "AU", "PLACE_OF_BUSINESS", "2026-01-01")
scopes~registerEstablishment(london)
scopes~registerEstablishment(sydney)

gbVat = .AccountingTaxRegistration~new("TAX-GB-VAT", entity, "GB", "HMRC", "VAT", "GB123456789", "EST-LONDON", "NON_ESTABLISHED_OR_LOCAL_SUPPLY", "2026-01-01")
auGst = .AccountingTaxRegistration~new("TAX-AU-GST", entity, "AU", "ATO", "GST", "AU-GST-987654", "EST-SYDNEY", "TAXABLE_SUPPLIES", "2026-01-01")
scopes~registerTaxRegistration(gbVat)
scopes~registerTaxRegistration(auGst)

t~assertEq("GB", gbVat~jurisdiction, "tax jurisdiction is independent first-class state")
gbElection = .AccountingTaxElection~new("ELECT-GB-VAT-2026", "sha256:gb-vat-election-2026", entity, "TAX-GB-VAT", "uk.vat.rules/2026", "UK-VAT-RULES-SHA256-001", "HMRC-NEAREST-PENNY", "PER_LINE", "VAT_RETURN", "2026-01-01", "2026-12-31")
auElection = .AccountingTaxElection~new("ELECT-AU-GST-2026", "sha256:au-gst-election-2026", entity, "TAX-AU-GST", "au.gst.rules/2026", "AU-GST-RULES-SHA256-001", "ATO-GST-ROUNDING", "PER_TAX_TOTAL", "BAS", "2026-01-01")
scopes~registerTaxElection(gbElection)
scopes~registerTaxElection(auElection)
gbElection2027 = .AccountingTaxElection~new("ELECT-GB-VAT-2027", "sha256:gb-vat-election-2027", entity, "TAX-GB-VAT", "uk.vat.rules/2027", "UK-VAT-RULES-SHA256-002", "HMRC-TRUNCATE-6DP", "PER_TAX_TOTAL", "VAT_RETURN", "2027-01-01")
scopes~registerTaxElection(gbElection2027)
t~assertEq("HMRC-NEAREST-PENNY", gbElection~roundingAlgorithmRef, "VAT rounding election is effective-dated separately from registration")
t~assertEq("PER_LINE", gbElection~calculationGranularity, "tax calculation granularity is explicit")
t~assertEq("ELECT-GB-VAT-2026", scopes~resolveTaxElection("TAX-GB-VAT", "2026-08-28")~taxElectionId, "2026 transaction resolves 2026 tax election")
t~assertEq("ELECT-GB-VAT-2027", scopes~resolveTaxElection("TAX-GB-VAT", "2027-02-01")~taxElectionId, "prospective election change preserves registration identity")
t~assertTrue(.ScopeTestHelpers~overlapRejected(scopes, entity), "overlapping tax elections are rejected")

/* A foreign legal entity can hold a UK VAT registration without a UK company
 * or even a UK establishment object.  Nexus/registration is not domicile. */
foreignScopes = .AccountingScopeRegistry~new("US_DISTANCE_SELLER_INC")
foreignScopes~registerEstablishment(.AccountingEstablishment~new("EST-US-HQ", "US_DISTANCE_SELLER_INC", "US", "HEAD_OFFICE", "2026-01-01"))
foreignGbVat = .AccountingTaxRegistration~new("TAX-FOREIGN-GB-VAT", "US_DISTANCE_SELLER_INC", "GB", "HMRC", "VAT", "GB987654321", "", "NON_ESTABLISHED_TAXABLE_PERSON", "2026-01-01")
foreignScopes~registerTaxRegistration(foreignGbVat)
t~assertEq("GB", foreignScopes~taxRegistration("TAX-FOREIGN-GB-VAT")~jurisdiction, "foreign entity can have GB VAT jurisdiction")
t~assertEq("", foreignGbVat~establishmentRef, "foreign VAT registration does not require fictional UK establishment")

sra = .AccountingRegulatoryRegistration~new("REG-SRA", entity, "GB", "SRA", "SRA-12345", "EST-LONDON", "sra.accounts.rules/2026", "SRA-RULES-SHA256-001", "2026-01-01")
nsw = .AccountingRegulatoryRegistration~new("REG-NSW", entity, "AU", "NSW-LAW-SOCIETY", "NSW-54321", "EST-SYDNEY", "nsw.trust.rules/2026", "NSW-RULES-SHA256-001", "2026-01-01")
scopes~registerRegulatoryRegistration(sra)
scopes~registerRegulatoryRegistration(nsw)

ukClient = .AccountingClientMoneyArrangement~new("CLIENT-GB-01", entity, "GB", "REG-SRA", "EST-LONDON", "BANK-CLIENT-GBP", "GBP", "2026-01-01")
auClient = .AccountingClientMoneyArrangement~new("CLIENT-AU-01", entity, "AU", "REG-NSW", "EST-SYDNEY", "BANK-TRUST-AUD", "AUD", "2026-01-01")
scopes~registerClientMoneyArrangement(ukClient)
scopes~registerClientMoneyArrangement(auClient)

/* UK client-money receipt. */
d1 = .AccountingJournalDraft~new("LAW:CLIENT:GB:1", "2026-08-28", "2026", "manual.client.money/0.1", "UK client money receipt")
dim1 = .directory~new
dim1[.AccountingDimensionKeys~ESTABLISHMENT_REF] = "EST-LONDON"
dim1[.AccountingDimensionKeys~REGULATORY_REGISTRATION_REF] = "REG-SRA"
dim1[.AccountingDimensionKeys~CLIENT_MONEY_ARRANGEMENT_REF] = "CLIENT-GB-01"
dim1[.AccountingDimensionKeys~MATTER_REF] = "MATTER-GB-1001"
dim1[.AccountingDimensionKeys~RELATIONSHIP_KIND] = "EXTERNAL"
d1~addLine(.AccountingJournalLine~new("1100", "GBP", "2500000", 0, "Client receipt", dim1))
d1~addLine(.AccountingJournalLine~new("2100", "GBP", 0, "2500000", "Client liability", dim1))
r1 = engine~post(d1)
t~assertTrue(r1~ok, "UK client money posting accepted")

/* Australian client-money receipt in the same legal entity and same book. */
d2 = .AccountingJournalDraft~new("LAW:CLIENT:AU:1", "2026-08-28", "2026", "manual.client.money/0.1", "AU trust money receipt")
dim2 = .directory~new
dim2[.AccountingDimensionKeys~ESTABLISHMENT_REF] = "EST-SYDNEY"
dim2[.AccountingDimensionKeys~REGULATORY_REGISTRATION_REF] = "REG-NSW"
dim2[.AccountingDimensionKeys~CLIENT_MONEY_ARRANGEMENT_REF] = "CLIENT-AU-01"
dim2[.AccountingDimensionKeys~MATTER_REF] = "MATTER-AU-2001"
dim2[.AccountingDimensionKeys~RELATIONSHIP_KIND] = "EXTERNAL"
d2~addLine(.AccountingJournalLine~new("1100", "AUD", "5000000", 0, "Trust receipt", dim2))
d2~addLine(.AccountingJournalLine~new("2100", "AUD", 0, "5000000", "Trust liability", dim2))
r2 = engine~post(d2)
t~assertTrue(r2~ok, "AU client money posting accepted into same legal-entity book")

/* UK tax invoice: tax registration is an orthogonal dimension, not a company. */
d3 = .AccountingJournalDraft~new("LAW:INV:GB:1", "2026-08-28", "2026", "manual.tax.invoice/0.1", "UK tax invoice")
dim3 = .directory~new
dim3[.AccountingDimensionKeys~ESTABLISHMENT_REF] = "EST-LONDON"
dim3[.AccountingDimensionKeys~TAX_REGISTRATION_REF] = "TAX-GB-VAT"
dim3[.AccountingDimensionKeys~TAX_ELECTION_REF] = "ELECT-GB-VAT-2026"
dim3[.AccountingDimensionKeys~TAX_ELECTION_IDENTITY] = "sha256:gb-vat-election-2026"
dim3[.AccountingDimensionKeys~MATTER_REF] = "MATTER-GB-3001"
d3~addLine(.AccountingJournalLine~new("1000", "GBP", "120000", 0, "Invoice receipt", dim3))
d3~addLine(.AccountingJournalLine~new("4000", "GBP", 0, "100000", "Fees", dim3))
d3~addLine(.AccountingJournalLine~new("2200", "GBP", 0, "20000", "VAT payable", dim3))
r3 = engine~post(d3)
t~assertTrue(r3~ok, "UK VAT-tagged invoice accepted")

/* AU GST invoice under the other registration. */
d4 = .AccountingJournalDraft~new("LAW:INV:AU:1", "2026-08-28", "2026", "manual.tax.invoice/0.1", "AU tax invoice")
dim4 = .directory~new
dim4[.AccountingDimensionKeys~ESTABLISHMENT_REF] = "EST-SYDNEY"
dim4[.AccountingDimensionKeys~TAX_REGISTRATION_REF] = "TAX-AU-GST"
dim4[.AccountingDimensionKeys~TAX_ELECTION_REF] = "ELECT-AU-GST-2026"
dim4[.AccountingDimensionKeys~TAX_ELECTION_IDENTITY] = "sha256:au-gst-election-2026"
dim4[.AccountingDimensionKeys~MATTER_REF] = "MATTER-AU-3001"
d4~addLine(.AccountingJournalLine~new("1000", "AUD", "110000", 0, "Invoice receipt", dim4))
d4~addLine(.AccountingJournalLine~new("4000", "AUD", 0, "100000", "Fees", dim4))
d4~addLine(.AccountingJournalLine~new("2200", "AUD", 0, "10000", "GST payable", dim4))
r4 = engine~post(d4)
t~assertTrue(r4~ok, "AU GST-tagged invoice accepted")
t~assertEq("4", book~entryCount, "one book contains both countries' tax and client-money activity")

/* A registration cannot be silently used for the wrong establishment. */
bad = .AccountingJournalDraft~new("LAW:BAD:1", "2026-08-28", "2026", "manual/0.1", "bad tax scope")
badDim = .directory~new
badDim[.AccountingDimensionKeys~ESTABLISHMENT_REF] = "EST-SYDNEY"
badDim[.AccountingDimensionKeys~TAX_REGISTRATION_REF] = "TAX-GB-VAT"
badDim[.AccountingDimensionKeys~TAX_ELECTION_REF] = "ELECT-GB-VAT-2026"
badDim[.AccountingDimensionKeys~TAX_ELECTION_IDENTITY] = "sha256:gb-vat-election-2026"
bad~addLine(.AccountingJournalLine~new("1000", "GBP", 1, 0, "bad", badDim))
bad~addLine(.AccountingJournalLine~new("4000", "GBP", 0, 1, "bad", badDim))
badResult = engine~post(bad)
t~assertTrue(\badResult~ok, "tax/establishment mismatch rejected")
t~assertEq("TAX_ESTABLISHMENT_MISMATCH", badResult~errorCode, "tax/establishment mismatch is explicit")

/* Once an election exists for a registration, tax-tagged accounting must
 * retain the exact election identity used. */
missingElection = .AccountingJournalDraft~new("LAW:BAD:ELECTION:1", "2026-08-28", "2026", "manual/0.1", "missing election")
meDim = .directory~new
meDim[.AccountingDimensionKeys~ESTABLISHMENT_REF] = "EST-LONDON"
meDim[.AccountingDimensionKeys~TAX_REGISTRATION_REF] = "TAX-GB-VAT"
missingElection~addLine(.AccountingJournalLine~new("1000", "GBP", 1, 0, "bad", meDim))
missingElection~addLine(.AccountingJournalLine~new("4000", "GBP", 0, 1, "bad", meDim))
meResult = engine~post(missingElection)
t~assertEq("TAX_ELECTION_REQUIRED", meResult~errorCode, "tax-tagged posting requires current election identity")

/* Establishment-specific registrations must retain their establishment on the
 * journal; historical reporting must not depend on a mutable lookup alone. */
noEstDim = .directory~new
noEstDim[.AccountingDimensionKeys~TAX_REGISTRATION_REF] = "TAX-GB-VAT"
noEstDim[.AccountingDimensionKeys~TAX_ELECTION_REF] = "ELECT-GB-VAT-2026"
noEstDim[.AccountingDimensionKeys~TAX_ELECTION_IDENTITY] = "sha256:gb-vat-election-2026"
noEstCheck = scopes~validateLine(.AccountingJournalLine~new("1000", "GBP", 1, 0, "missing establishment", noEstDim), "2026-08-28")
t~assertEq("TAX_ESTABLISHMENT_REQUIRED", noEstCheck~errorCode, "establishment-specific tax posting must retain establishment ref")

/* The tax return is one view over the common book. */
selectors = .directory~new
selectors[.AccountingDimensionKeys~TAX_REGISTRATION_REF] = .array~of("TAX-GB-VAT")
ukVatBoundary = .AccountingReportingBoundary~new("BOUNDARY-GB-VAT-Q3", "HMRC", "VAT_RETURN", "2026-01-01", "", .array~of(entity), .array~of("FIRM-STAT"), selectors, "uk.vat.reporting/2026", "UK-VAT-REPORTING-SHA256-001")
ukVatView = engine~reportingView(ukVatBoundary, "2026-07-01", "2026-09-30")
t~assertEq("3", ukVatView~lineCount, "UK VAT boundary selects only UK VAT invoice lines")
ukTotals = ukVatView~totals
 t~assertEq("120000", ukTotals["GBP"]["debit_minor"], "UK VAT view debit total")
 t~assertEq("120000", ukTotals["GBP"]["credit_minor"], "UK VAT view credit total")

/* A holistic professional-regulator client-account boundary can include both
 * jurisdictions without inventing two legal entities. */
clientSelectors = .directory~new
clientSelectors[.AccountingDimensionKeys~CLIENT_MONEY_ARRANGEMENT_REF] = .array~of("CLIENT-GB-01", "CLIENT-AU-01")
wholeClientBoundary = .AccountingReportingBoundary~new("BOUNDARY-FIRM-CLIENT-MONEY", "FIRM-REGULATORY-REPORT", "CLIENT_ACCOUNT_POSITION", "2026-01-01", "", .array~of(entity), .array~of("FIRM-STAT"), clientSelectors, "firm.client.money.report/0.1", "CLIENT-REPORT-SHA256-001")
clientView = engine~reportingView(wholeClientBoundary)
t~assertEq("4", clientView~lineCount, "holistic client-money boundary includes UK and AU client-account lines")
clientTotals = clientView~totals
t~assertEq("2500000", clientTotals["GBP"]["debit_minor"], "holistic report retains GBP client money")
t~assertEq("5000000", clientTotals["AUD"]["debit_minor"], "holistic report retains AUD client money")
t~assertTrue(clientView~boundaryFingerprint \= "", "report view freezes exact boundary identity")

/* Whole-firm view has no jurisdiction selector and therefore sees all native
 * journal lines, while remaining grouped by exact currency. */
wholeFirmBoundary = .AccountingReportingBoundary~new("BOUNDARY-MANAGEMENT", "BOARD", "MANAGEMENT_ACCOUNTS", "2026-01-01", "", .array~of(entity), .array~of("FIRM-STAT"))
wholeFirm = engine~reportingView(wholeFirmBoundary)
t~assertEq("10", wholeFirm~lineCount, "whole-firm boundary sees every accepted line")
wholeTotals = wholeFirm~totals
t~assertEq("2620000", wholeTotals["GBP"]["debit_minor"], "whole-firm GBP total")
t~assertEq("2620000", wholeTotals["GBP"]["credit_minor"], "whole-firm GBP balances")
t~assertEq("5110000", wholeTotals["AUD"]["debit_minor"], "whole-firm AUD total")
t~assertEq("5110000", wholeTotals["AUD"]["credit_minor"], "whole-firm AUD balances")

/* Inter-establishment is a relationship classification, not intercompany. */
relDim = .directory~new
relDim[.AccountingDimensionKeys~ESTABLISHMENT_REF] = "EST-LONDON"
relDim[.AccountingDimensionKeys~RELATIONSHIP_KIND] = "INTER_ESTABLISHMENT"
relCheck = scopes~validateLine(.AccountingJournalLine~new("1000", "GBP", 1, 0, "allocation", relDim), "2026-08-28")
t~assertTrue(relCheck~ok, "INTER_ESTABLISHMENT is a valid distinct relationship kind")

say "scope/reporting assertions=" t~assertions "failures=" t~failures
if t~failures > 0 then exit 1
exit 0

::class ScopeTestHelpers
::method overlapRejected class
  use arg scopes, entity
  signal on syntax name caught
  scopes~registerTaxElection(.AccountingTaxElection~new("ELECT-GB-VAT-OVERLAP", "sha256:gb-vat-election-overlap", entity, "TAX-GB-VAT", "uk.vat.rules/overlap", "OVERLAP-ID", "SOME-ROUNDING", "PER_LINE", "VAT_RETURN", "2026-06-01", "2026-06-30"))
  signal off syntax
  return .false
caught:
  signal off syntax
  return .true

::options digits 50
::requires "AccountingEngine.cls"
::requires "TestSupport.cls"
