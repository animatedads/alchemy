p = .array~new
d1 = .directory~new
d1["side"] = "DR"
d1["amount"] = "1200.00"
d2 = .directory~new
d2["side"] = "CR"
d2["amount"] = "800.00"
d3 = .directory~new
d3["side"] = "CR"
d3["amount"] = "400.00"
p~append(d1)
p~append(d2)
p~append(d3)
r = .ReportJournalBalance~check(p)
if r["balanced"] \= .true then do
  say "FAIL expected balanced" r["difference"]
  exit 1
end
d3["amount"] = "399.00"
r2 = .ReportJournalBalance~check(p)
if r2["balanced"] = .true then do
  say "FAIL expected imbalance"
  exit 1
end
say "PASS test_journal_balance" r["debit"] r["credit"]
exit 0

::requires "../src/adapters/accounting/ReportJournalAdapter.cls"
