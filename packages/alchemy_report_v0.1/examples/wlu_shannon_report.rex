/* Shannon chat work — 10 reserved, 6 settled. Money is derived only. */
doc = .ReportDocument~new("wlu-shannon-1", "Shannon chat WLU — August window")
reg = .ReportTransformRegistry~new
ignore = .ReportWluReservationAdapter~registerInto(reg, .ReportWluReservationAdapter~transformId)
ignore = .ReportWluSettlementAdapter~registerInto(reg, .ReportWluSettlementAdapter~transformId)
ignore = .ReportWluNodeAdapter~registerInto(reg, .ReportWluNodeAdapter~transformId)
ignore = .ReportWluPriceBookAdapter~registerInto(reg, .ReportWluPriceBookAdapter~transformId)
doc~transformRegistry = reg

res = .directory~new
res["reservationId"] = "res-chat-77"
res["expectedMicroWlu"] = "10000000"
setl = .directory~new
setl["settlementId"] = "set-chat-77"
setl["actualMicroWlu"] = "6000000"
node = .directory~new
node["nodePath"] = "ENTERPRISE/FLYLO/SHANNON/CHAT"
node["ceilingMicroWlu"] = "20000000"
pb = .directory~new
pb["priceBookId"] = "flylo-std"
pb["version"] = "3"
pb["currency"] = "GBP"
pb["microCurrency"] = "12"

bR = .ReportWluReservationAdapter~bind("b-r", "SUPPORTING", res)
bS = .ReportWluSettlementAdapter~bind("b-s", "PRIMARY", setl)
bN = .ReportWluNodeAdapter~bind("b-n", "SUPPORTING", node)
bP = .ReportWluPriceBookAdapter~bind("b-p", "DERIVED", pb)

c1 = .ReportClaim~new("c-work", "Shannon chat settled 6 WLU of 10 reserved.", "METRIC")
c2 = .ReportClaim~new("c-env", "Charge counted once under ENTERPRISE/FLYLO/SHANNON/CHAT.", "FACT")
c3 = .ReportClaim~new("c-£", "Indicative GBP from price book flylo-std v3 — not WLU.", "NARRATIVE")
ignore = c1~addBindingId("b-s")
ignore = c1~addBindingId("b-r")
ignore = c2~addBindingId("b-n")
ignore = c2~addBindingId("b-s")
ignore = c3~addBindingId("b-p")
ignore = c3~addBindingId("b-s")

s1 = .ReportSection~new("work", "Work")
s2 = .ReportSection~new("note", "Chargeback translation")
ignore = s1~addClaimId("c-work")
ignore = s1~addClaimId("c-env")
ignore = s2~addClaimId("c-£")
ignore = doc~addBinding(bR)~addBinding(bS)~addBinding(bN)~addBinding(bP)
ignore = doc~addClaim(c1)~addClaim(c2)~addClaim(c3)
ignore = doc~addSection(s1)~addSection(s2)
say "sealed" doc~seal
say doc~humanForm
exit 0

::requires "../src/adapters/wlu/ReportWluAdapter.cls"
