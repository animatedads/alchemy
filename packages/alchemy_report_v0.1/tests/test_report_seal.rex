/* Seal + grounding invariants */
doc = .ReportDocument~new("flylo-divert-1", "FlyLo 022 disruption")
b = .ReportBinding~new("b-notam", "PRIMARY", "NOTAM_AIXM",,
      "NOTAM:A1324/26", "sha256:deadbeef", "/AIXM/message[1]", "2026-08-24T15:54Z",,
      "notam.projection/0.3", "OPERATIONAL")
c = .ReportClaim~new("c-ewr", "EWR unavailable during FlyLo 022 arrival window.", "FACT")
ignore = c~addBindingId("b-notam")
sec = .ReportSection~new("ops", "Operations")
ignore = sec~addClaimId("c-ewr")
ignore = doc~addBinding(b)
ignore = doc~addClaim(c)
ignore = doc~addSection(sec)

st = doc~groundClaim("c-ewr")
if st \= "GROUNDED" then do
  say "FAIL expected GROUNDED got" st
  exit 1
end
d1 = doc~seal
if doc~sealed \= .true then do
  say "FAIL not sealed"
  exit 1
end
d2 = .ReportSealDigest~of(doc~machineForm)
if d1 \= d2 then do
  say "FAIL digest mismatch"
  exit 1
end
say "PASS test_report_seal" d1
exit 0

::requires "../src/AlchemyReport.cls"
