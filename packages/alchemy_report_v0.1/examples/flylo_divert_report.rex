/* Person + machine form of a FlyLo disruption claim with a NOTAM trail. */
doc = .ReportDocument~new("flylo-022-divert", "FlyLo 022 — disruption report")
bLegal = .ReportBinding~new("b-uk261", "SUPPORTING", "LEGAL_TRACE",,
          "LEGAL:trace:uk261-divert-022", "", "", "2026-08-24T16:10Z",,
          "legal.effect/0.14", "LEGAL")
bPnr = .ReportBinding~new("b-pnr", "PRIMARY", "HOST_RECORD",,
          "AS400:PNR:ABC123.STATUS", "sha256:pnr1", "PNRH.STATUS", "2026-08-24T16:05Z",,
          "pnr.status/1", "OPERATIONAL")
bNotam = .ReportBinding~new("b-aixm", "SUPPORTING", "NOTAM_AIXM",,
          "NOTAM:A1324/26", "sha256:aixm1",,
          "/AIXMBasicMessage/hasMember[1]/Event", "2026-08-24T15:54Z",,
          "notam.projection/0.3", "OPERATIONAL")

c1 = .ReportClaim~new("c-fact", "EWR is unavailable in the FlyLo 022 arrival window.", "FACT")
c2 = .ReportClaim~new("c-ops", "Flight 022 is marked DIVERT on the reservation host.", "FACT")
c3 = .ReportClaim~new("c-law", "UK261 assistance may apply; trace is CONDITIONAL.", "OBLIGATION")
ignore = c1~addBindingId("b-aixm")
ignore = c2~addBindingId("b-pnr")
ignore = c3~addBindingId("b-uk261")
ignore = c3~addBindingId("b-pnr")

s1 = .ReportSection~new("facts", "What we know")
s2 = .ReportSection~new("rights", "What we may tell the passenger")
ignore = s1~addClaimId("c-fact")
ignore = s1~addClaimId("c-ops")
ignore = s2~addClaimId("c-law")

ignore = doc~addBinding(bLegal)
ignore = doc~addBinding(bPnr)
ignore = doc~addBinding(bNotam)
ignore = doc~addClaim(c1)
ignore = doc~addClaim(c2)
ignore = doc~addClaim(c3)
ignore = doc~addSection(s1)
ignore = doc~addSection(s2)
ignore = doc~seal

say doc~humanForm
say
say "--- machine ---"
say doc~machineForm
say
say "trail c-law:"
say doc~trail("c-law")~machineForm
exit 0

::requires "../src/AlchemyReport.cls"
