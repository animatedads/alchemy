/* Aviation + legal adapters — core does not define these classes. */
d = .directory~new
d["traceId"] = "uk261-divert-022"
d["digest"] = "sha256:le1"
b = .ReportLegalTraceAdapter~bind("b-law", "SUPPORTING", d)
if b~sourcePoint \= "LEGAL:trace:uk261-divert-022" then do
  say "FAIL point" b~sourcePoint
  exit 1
end
n = .directory~new
n["notamId"] = "A1324/26"
b2 = .ReportNotamAdapter~bind("b-n", "PRIMARY", n)
if b2~sourcePoint \= "NOTAM:A1324/26" then do
  say "FAIL notam point"
  exit 1
end
bad = .directory~new
signal on syntax name missing
ignore = .ReportCivicAdapter~bind("b-c", "PRIMARY", bad)
say "FAIL missing documentId accepted"
exit 1
missing:
  say "PASS test_evidence_adapter"
  exit 0

::requires "../src/adapters/legal/ReportLegalTraceAdapter.cls"
::requires "../src/adapters/aviation/ReportNotamAdapter.cls"
::requires "../src/adapters/civic/ReportCivicAdapter.cls"
