/* Human claim trails to retained NOTAM identity + span. */
doc = .ReportDocument~new("flylo-notam-1", "Kahului navaid")
b1 = .ReportBinding~new("b-proj", "DERIVED", "NOTAM_AIXM",,
      "NOTAM:A1324/26", "sha256:aabb", "/EventTimeSlice", "2026-08-24T15:54Z",,
      "notam.projection/0.3", "OPERATIONAL")
b2 = .ReportBinding~new("b-xml", "PRIMARY", "NOTAM_AIXM",,
      "NOTAM:A1324/26#xml", "sha256:aabb",,
      "/AIXM:AIXMBasicMessage/hasMember[1]", "2026-08-24T15:54Z",,
      "", "OPERATIONAL")
c = .ReportClaim~new("c-upp", "UPP VORTAC is out of service.", "FACT")
ignore = c~addBindingId("b-proj")
ignore = c~addBindingId("b-xml")
ignore = doc~addBinding(b1)
ignore = doc~addBinding(b2)
ignore = doc~addClaim(c)
tr = doc~trail("c-upp")
if tr~steps~items \= 2 then do
  say "FAIL step count" tr~steps~items
  exit 1
end
if tr~terminal \= "LEAF" then do
  say "FAIL terminal" tr~terminal
  exit 1
end
if tr~steps[2]~sourcePoint \= "NOTAM:A1324/26#xml" then do
  say "FAIL leaf point"
  exit 1
end
if tr~steps[2]~span~pos("AIXM") = 0 then do
  say "FAIL span missing"
  exit 1
end
say "PASS test_trail_notam" tr~string
exit 0

::requires "../src/AlchemyReport.cls"
