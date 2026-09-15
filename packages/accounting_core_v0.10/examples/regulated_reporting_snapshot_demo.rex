numeric digits 50
entity = "ANGLO_AUSTRALIAN_LAW_LLP"
book = .AccountingBook~new(entity, "FIRM-STAT", "ENTITY_GAAP")
book~addAccount(.AccountingAccount~new("1100", "Client bank", "ASSET", "AUTO", "SINGLE", .true, "GBP"))
book~addAccount(.AccountingAccount~new("2100", "Client liability", "LIABILITY", "AUTO", "SINGLE", .true, "GBP"))
book~sealChart
book~addPeriod(.AccountingPeriod~new("2026", "2026-01-01", "2026-12-31"))

dims = .directory~new
dims[.AccountingDimensionKeys~CLIENT_MONEY_ARRANGEMENT_REF] = "CLIENT-GB-01"
dims[.AccountingDimensionKeys~MATTER_REF] = "000123"
draft = .AccountingJournalDraft~new("CLIENT:RECEIPT:1", "2026-08-28", "2026", "demo/0.1", "client money receipt")
draft~addLine(.AccountingJournalLine~new("1100", "GBP", "2500000", 0, "client bank", dims))
draft~addLine(.AccountingJournalLine~new("2100", "GBP", 0, "2500000", "client liability", dims))
book~post(draft)

selectors = .directory~new
selectors[.AccountingDimensionKeys~CLIENT_MONEY_ARRANGEMENT_REF] = .array~of("CLIENT-GB-01")
boundary = .AccountingReportingBoundary~new("BOUNDARY-CLIENT-2026", "PROFESSIONAL-REGULATOR", "CLIENT_ACCOUNT_POSITION", "2026-01-01", "2026-12-31", .array~of(entity), .array~of("FIRM-STAT"), selectors, "client.report/0.2", "sha256:demo-report-policy")
snapshot = .AccountingReportingService~sealSnapshot("SNAP-CLIENT-2026", boundary, .array~of(book), "2026-01-01", "2026-12-31", "REPORT-SEAL-DEMO")

say "snapshot=" snapshot~snapshotId
say "lines=" snapshot~lineCount
say "fingerprint length=" snapshot~fingerprint~length
verify = .AccountingReportingService~verifySnapshot(snapshot, boundary, .array~of(book))
say "verification=" verify~status
exit 0

::options digits 50
::requires "AccountingEngine.cls"
