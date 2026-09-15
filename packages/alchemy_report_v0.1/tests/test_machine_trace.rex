doc = .ReportDocument~new("t1", "Trace")
b = .ReportBinding~new("b1", "PRIMARY", "HOST_RECORD", "HOST:X")
c = .ReportClaim~new("c1", "X is set.", "FACT")
ignore = c~addBindingId("b1")
s = .ReportSection~new("s1", "S")
ignore = s~addClaimId("c1")
ignore = doc~addBinding(b)~addClaim(c)~addSection(s)
ignore = doc~seal
tr = doc~machineTrace
if tr~pos("REPORT:t1") = 0 then do
  say "FAIL missing report point"
  exit 1
end
if tr~pos("REPORT:t1:CLAIM:c1") = 0 then do
  say "FAIL missing claim point"
  exit 1
end
if tr~pos("REPORT_BINDING:b1") = 0 then do
  say "FAIL missing binding point"
  exit 1
end
say "PASS test_machine_trace"
exit 0

::requires "../src/AlchemyReport.cls"
