numeric digits 50

store = .AccountingFileStore~new("./durable_jpy_demo.jsonl")
book = store~createBook("TOKYO_DEMO_CO_LTD", "TOKYO-STAT", "ENTITY_GAAP")
book~chart~add(.AccountingAccount~new("1000", "JPY cash", "ASSET", "AUTO", "SINGLE", .true, "JPY"))
book~chart~add(.AccountingAccount~new("4000", "JPY revenue", "REVENUE", "AUTO", "SINGLE", .true, "JPY"))
book~chart~seal
book~addPeriod(.AccountingPeriod~new("2026-08", "2026-08-01", "2026-08-31"))

amount = "1234567890123456789012345678901234567890"
draft = .AccountingJournalDraft~new("TOKYO:SALE:1", "2026-08-28", "2026-08", "tokyo.revenue/0.1", "large JPY transaction")
draft~addLine(.AccountingJournalLine~new("1000", "JPY", amount, 0))
draft~addLine(.AccountingJournalLine~new("4000", "JPY", 0, amount))
result = book~post(draft)
say result~status result~entry~entryId
say "before restart:" book~balance("1000", "JPY")~debitMinor "JPY"

recovered = store~recoverBook
say "after restart: " recovered~balance("1000", "JPY")~debitMinor "JPY"

::options digits 50

::requires "AccountingPersistence.cls"
