/* FlyLo loads aviation + host + legal. Insurance would not load NOTAM. */
doc = .ReportDocument~new("flylo-022-adapt", "FlyLo 022 — adapter report")
reg = .ReportTransformRegistry~new
ignore = .ReportNotamAdapter~registerInto(reg, .ReportNotamAdapter~transformId)
ignore = .ReportLegalTraceAdapter~registerInto(reg, .ReportLegalTraceAdapter~transformId)
ignore = reg~register("pnr.status/1")
doc~transformRegistry = reg

notam = .directory~new
notam["notamId"] = "A1324/26"
notam["digest"] = "sha256:aixm1"
pnr = .directory~new
pnr["recordPoint"] = "AS400:PNR:ABC123.STATUS"
pnr["transformId"] = "pnr.status/1"
law = .directory~new
law["traceId"] = "uk261-divert-022"

b1 = .ReportNotamAdapter~bind("b-aixm", "SUPPORTING", notam)
b2 = .ReportHostRecordAdapter~bind("b-pnr", "PRIMARY", pnr)
b3 = .ReportLegalTraceAdapter~bind("b-uk261", "SUPPORTING", law)
c1 = .ReportClaim~new("c-fact", "EWR is unavailable in the FlyLo 022 arrival window.", "FACT")
c2 = .ReportClaim~new("c-ops", "Flight 022 is marked DIVERT on the reservation host.", "FACT")
c3 = .ReportClaim~new("c-law", "UK261 assistance may apply; trace is CONDITIONAL.", "OBLIGATION")
ignore = c1~addBindingId("b-aixm")
ignore = c2~addBindingId("b-pnr")
ignore = c3~addBindingId("b-uk261")
ignore = c3~addBindingId("b-pnr")
s1 = .ReportSection~new("facts", "What we know")
ignore = s1~addClaimId("c-fact")
ignore = s1~addClaimId("c-ops")
s2 = .ReportSection~new("rights", "What we may tell the passenger")
ignore = s2~addClaimId("c-law")
ignore = doc~addBinding(b1)~addBinding(b2)~addBinding(b3)
ignore = doc~addClaim(c1)~addClaim(c2)~addClaim(c3)
ignore = doc~addSection(s1)~addSection(s2)
say "sealed" doc~seal
say doc~customerHumanForm
exit 0

::requires "../src/adapters/aviation/ReportNotamAdapter.cls"
::requires "../src/adapters/host/ReportHostRecordAdapter.cls"
::requires "../src/adapters/legal/ReportLegalTraceAdapter.cls"
