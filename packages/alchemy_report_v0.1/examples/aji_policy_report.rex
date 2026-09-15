/* All Japan Insurance — legal + civic + host. No aviation adapter. */
doc = .ReportDocument~new("aji-claim-1", "Policy schedule extract")
reg = .ReportTransformRegistry~new
ignore = .ReportLegalTraceAdapter~registerInto(reg, .ReportLegalTraceAdapter~transformId)
ignore = .ReportCivicAdapter~registerInto(reg, .ReportCivicAdapter~transformId)
doc~transformRegistry = reg

host = .directory~new
host["recordPoint"] = "HOST:POLICY:7781.STATUS"
host["transformId"] = ""
law = .directory~new
law["traceId"] = "aji-cover-7781"
civ = .directory~new
civ["documentId"] = "schedule-7781"
civ["privacyClass"] = "CUSTOMER"

b1 = .ReportHostRecordAdapter~bind("b-host", "PRIMARY", host)
b2 = .ReportLegalTraceAdapter~bind("b-law", "SUPPORTING", law)
b3 = .ReportCivicAdapter~bind("b-civ", "SUPPORTING", civ)
c = .ReportClaim~new("c1", "Policy 7781 is in force.", "FACT")
ignore = c~addBindingId("b-host")
ignore = c~addBindingId("b-law")
s = .ReportSection~new("cover", "Cover")
ignore = s~addClaimId("c1")
ignore = doc~addBinding(b1)~addBinding(b2)~addBinding(b3)
ignore = doc~addClaim(c)~addSection(s)
say "sealed" doc~seal
say doc~humanForm
exit 0

::requires "../src/adapters/host/ReportHostRecordAdapter.cls"
::requires "../src/adapters/legal/ReportLegalTraceAdapter.cls"
::requires "../src/adapters/civic/ReportCivicAdapter.cls"
