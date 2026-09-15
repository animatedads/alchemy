/* Independent company books linked only by an economic correlation reference. */
flylo = .AccountingBook~new("FLYLO_AIR_LTD", "FLYLO-STAT")
flylo~chart~add(.AccountingAccount~new("6100", "Insurance expense", "EXPENSE"))
flylo~chart~add(.AccountingAccount~new("2000", "Trade payable", "LIABILITY"))
flylo~addPeriod(.AccountingPeriod~new("2026-08", "2026-08-01", "2026-08-31"))

d = .AccountingJournalDraft~new("FLYLO:INSURANCE:POLICY-77", "2026-08-28", "2026-08", "flylo.accounting.insurance/0.1", "Policy premium", "CHAIN-77")
d~addLine(.AccountingJournalLine~new("6100", "GBP", 4900, 0))
d~addLine(.AccountingJournalLine~new("2000", "GBP", 0, 4900))
r = flylo~post(d)
say r~status r~entry~entryId

::options digits 50

::requires "AccountingCore.cls"
