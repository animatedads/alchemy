agg = .ReportAggregate~new("avg-delay")
ignore = agg~addMember("HOST:FLT:022.delay")
ignore = agg~addMember("HOST:FLT:023.delay")
d = agg~sealMembers
if d = "" then do
  say "FAIL empty member digest"
  exit 1
end
if agg~memberPoints~items \= 2 then do
  say "FAIL member count"
  exit 1
end
say "PASS test_aggregate" d
exit 0

::requires "../src/AlchemyReport.cls"
