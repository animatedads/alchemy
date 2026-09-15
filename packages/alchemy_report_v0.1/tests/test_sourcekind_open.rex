/* Core accepts any token kind; punctuation is refused. */
b = .ReportBinding~new("b1", "PRIMARY", "POLICY_SCHEDULE", "AJI:POL:9")
if b~sourceKind \= "POLICY_SCHEDULE" then do
  say "FAIL insurance kind rejected"
  exit 1
end
b2 = .ReportBinding~new("b2", "PRIMARY", "NOTAM_AIXM", "NOTAM:A1324/26")
if b2~sourceKind \= "NOTAM_AIXM" then do
  say "FAIL aviation kind rejected"
  exit 1
end
signal on syntax name good
ignore = .ReportBinding~new("b3", "PRIMARY", "NOTAM/AIXM", "x")
say "FAIL slash kind accepted"
exit 1
good:
  say "PASS test_sourcekind_open"
  exit 0

::requires "../src/AlchemyReport.cls"
