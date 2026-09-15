/* Two assessments may disagree; neither is promoted to FACT by the report. */
doc = .ReportDocument~new("sass-1", "Style assessments")
b = .ReportBinding~new("b-utt", "PRIMARY", "INTERACTION_EVENT",,
      "INTERACTION_EVENT:utt-9", "", "", "", "", "INTERNAL")
a1 = .ReportClaim~new("a-sass", "Agent tone scored high SASS.", "ASSESSMENT")
a2 = .ReportClaim~new("a-calm", "Agent tone scored low SASS.", "ASSESSMENT")
ignore = a1~addBindingId("b-utt")
ignore = a2~addBindingId("b-utt")
ignore = doc~addBinding(b)
ignore = doc~addClaim(a1)
ignore = doc~addClaim(a2)
ignore = doc~groundAll
if a1~kind \= "ASSESSMENT" | a2~kind \= "ASSESSMENT" then do
  say "FAIL kinds mutated"
  exit 1
end
if a1~status \= "GROUNDED" | a2~status \= "GROUNDED" then do
  say "FAIL both assessments should ground to the same event"
  exit 1
end
say "PASS test_assessments_not_facts"
exit 0

::requires "../src/AlchemyReport.cls"
