doc = .ReportDocument~new("fin-1", "Books")
ignore = doc~hide("FINANCIAL")
b = .ReportBinding~new("b1", "PRIMARY", "JOURNAL_ENTRY", "ACCT:JOURNAL:1",,
      "", "", "", "", "FINANCIAL")
c = .ReportClaim~new("c1", "Revenue is 1200.", "METRIC")
ignore = c~addBindingId("b1")
s = .ReportSection~new("pnl", "P&L")
ignore = s~addClaimId("c1")
ignore = doc~addBinding(b)~addClaim(c)~addSection(s)
ignore = doc~groundAll
if doc~customerHumanForm~pos("1200") > 0 then do
  say "FAIL FINANCIAL leaked to customer form"
  exit 1
end
if doc~humanForm~pos("1200") = 0 then do
  say "FAIL internal form lost metric"
  exit 1
end
say "PASS test_hide_financial"
exit 0

::requires "../src/AlchemyReport.cls"
