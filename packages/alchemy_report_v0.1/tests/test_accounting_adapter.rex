j = .directory~new
j["entryId"] = "JE-2026-0812"
bJ = .ReportJournalAdapter~bind("b-je", "PRIMARY", j)
if bJ~sourcePoint \= "ACCT:JOURNAL:JE-2026-0812" then do
  say "FAIL journal point"
  exit 1
end

g = .directory~new
g["postingId"] = "P-1"
g["account"] = "4000"
g["side"] = "CR"
g["amount"] = "1200.00"
bG = .ReportGlPostingAdapter~bind("b-gl", "SUPPORTING", g)
if bG~sourcePoint \= "ACCT:GL:4000:P-1" then do
  say "FAIL gl point" bG~sourcePoint
  exit 1
end
if bG~span~pos("CR") = 0 then do
  say "FAIL span side"
  exit 1
end

p = .directory~new
p["book"] = "FLYLO"
p["period"] = "2026-08"
bP = .ReportPeriodAdapter~bind("b-per", "SUPPORTING", p)
if bP~sourceKind \= "ACCOUNTING_PERIOD" then do
  say "FAIL period kind"
  exit 1
end

bad = .directory~new
signal on syntax name missing
ignore = .ReportGlPostingAdapter~bind("b-x", "PRIMARY", bad)
say "FAIL posting without account accepted"
exit 1
missing:
  say "PASS test_accounting_adapter"
  exit 0

::requires "../src/adapters/accounting/ReportJournalAdapter.cls"
