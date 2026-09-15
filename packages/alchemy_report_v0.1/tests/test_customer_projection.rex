doc = .ReportDocument~new("proj-1", "Mixed privacy")
bOk = .ReportBinding~new("bok", "PRIMARY", "HOST_RECORD", "AS400:STATUS",,
      "sha256:x", "", "", "", "OPERATIONAL")
bHid = .ReportBinding~new("bhid", "PRIMARY", "CIVIC_DOCUMENT", "CIVIC:name")
cOk = .ReportClaim~new("c-ok", "Flight is DIVERT.", "FACT")
cHid = .ReportClaim~new("c-hid", "Passenger is SMITH.", "FACT")
ignore = cOk~addBindingId("bok")
ignore = cHid~addBindingId("bhid")
s = .ReportSection~new("all", "All")
ignore = s~addClaimId("c-ok")
ignore = s~addClaimId("c-hid")
ignore = doc~addBinding(bOk)
ignore = doc~addBinding(bHid)
ignore = doc~addClaim(cOk)
ignore = doc~addClaim(cHid)
ignore = doc~addSection(s)
ignore = doc~groundAll
h = doc~customerHumanForm
if h~pos("SMITH") > 0 then do
  say "FAIL customer form leaked UNKNOWN claim"
  exit 1
end
if h~pos("DIVERT") = 0 then do
  say "FAIL customer form dropped operational claim"
  exit 1
end
if doc~humanForm~pos("SMITH") = 0 then do
  say "FAIL internal form lost SMITH"
  exit 1
end
say "PASS test_customer_projection"
exit 0

::requires "../src/AlchemyReport.cls"
