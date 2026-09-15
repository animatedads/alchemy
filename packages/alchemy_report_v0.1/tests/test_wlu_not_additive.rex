r = .ReportWluHierarchyRule~reflectedWork(6000000, 4)
if r["accountedMicroWlu"] \= 6000000 then do
  say "FAIL accounted"
  exit 1
end
if r["additiveWrong"] \= 24000000 then do
  say "FAIL additive illustration"
  exit 1
end
if r["accountedMicroWlu"] = r["additiveWrong"] then do
  say "FAIL accounted equals additive"
  exit 1
end
say "PASS test_wlu_not_additive"
exit 0

::requires "../src/adapters/wlu/ReportWluAdapter.cls"
