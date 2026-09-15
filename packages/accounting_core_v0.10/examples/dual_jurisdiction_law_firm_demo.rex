numeric digits 50
entity = "ANGLO_AUSTRALIAN_LAW_LLP"
engine = .AccountingEngine~new(entity, "FIRM-STAT", "ENTITY_GAAP")
book = engine~book
book~addAccount(.AccountingAccount~new("1100", "Client bank", "ASSET", "AUTO", "MULTI"))
book~addAccount(.AccountingAccount~new("2100", "Client money liability", "LIABILITY", "AUTO", "MULTI"))
book~sealChart
book~addPeriod(.AccountingPeriod~new("2026", "2026-01-01", "2026-12-31"))

scopes = engine~scopes
scopes~registerEstablishment(.AccountingEstablishment~new("EST-LONDON", entity, "GB", "PLACE_OF_BUSINESS", "2026-01-01"))
scopes~registerEstablishment(.AccountingEstablishment~new("EST-SYDNEY", entity, "AU", "PLACE_OF_BUSINESS", "2026-01-01"))
scopes~registerRegulatoryRegistration(.AccountingRegulatoryRegistration~new("REG-SRA", entity, "GB", "SRA", "SRA-12345", "EST-LONDON", "sra.accounts.rules/2026", "SRA-RULES-ID", "2026-01-01"))
scopes~registerRegulatoryRegistration(.AccountingRegulatoryRegistration~new("REG-NSW", entity, "AU", "NSW-LAW-SOCIETY", "NSW-54321", "EST-SYDNEY", "nsw.trust.rules/2026", "NSW-RULES-ID", "2026-01-01"))
scopes~registerClientMoneyArrangement(.AccountingClientMoneyArrangement~new("CLIENT-GB-01", entity, "GB", "REG-SRA", "EST-LONDON", "BANK-CLIENT-GBP", "GBP", "2026-01-01"))
scopes~registerClientMoneyArrangement(.AccountingClientMoneyArrangement~new("CLIENT-AU-01", entity, "AU", "REG-NSW", "EST-SYDNEY", "BANK-TRUST-AUD", "AUD", "2026-01-01"))

call postClientMoney engine, "GB", "EST-LONDON", "REG-SRA", "CLIENT-GB-01", "MATTER-1001", "GBP", "2500000"
call postClientMoney engine, "AU", "EST-SYDNEY", "REG-NSW", "CLIENT-AU-01", "MATTER-2001", "AUD", "5000000"

selectors = .directory~new
selectors[.AccountingDimensionKeys~CLIENT_MONEY_ARRANGEMENT_REF] = .array~of("CLIENT-GB-01", "CLIENT-AU-01")
boundary = .AccountingReportingBoundary~new("WHOLE-FIRM-CLIENT-MONEY", "PROFESSIONAL-REGULATOR", "CLIENT_ACCOUNT_POSITION", "2026-01-01", "", .array~of(entity), .array~of("FIRM-STAT"), selectors, "firm.client.money.reporting/0.1", "REPORT-POLICY-ID-001")
view = engine~reportingView(boundary)

say "legal entity=" entity
say "native accounting entries=" book~entryCount
say "client-money reporting lines=" view~lineCount
say "boundary fingerprint=" view~boundaryFingerprint
results = view~totals
do currency over results
  say currency "debits=" results[currency]["debit_minor"] "credits=" results[currency]["credit_minor"]
end
exit 0

postClientMoney:
  use arg engine, jurisdiction, establishmentRef, regulatorRef, arrangementRef, matterRef, currency, amount
  d = .directory~new
  d[.AccountingDimensionKeys~ESTABLISHMENT_REF] = establishmentRef
  d[.AccountingDimensionKeys~REGULATORY_REGISTRATION_REF] = regulatorRef
  d[.AccountingDimensionKeys~CLIENT_MONEY_ARRANGEMENT_REF] = arrangementRef
  d[.AccountingDimensionKeys~MATTER_REF] = matterRef
  draft = .AccountingJournalDraft~new("CLIENT:" || jurisdiction || ":" || matterRef, "2026-08-28", "2026", "demo.client.money/0.1", jurisdiction || " client money")
  draft~addLine(.AccountingJournalLine~new("1100", currency, amount, 0, "Client receipt", d))
  draft~addLine(.AccountingJournalLine~new("2100", currency, 0, amount, "Client liability", d))
  result = engine~post(draft)
  if \result~ok then do
    say "posting failed:" result~errorCode result~message
    exit 1
  end
  return

::options digits 50
::requires "AccountingEngine.cls"
