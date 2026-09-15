/* Revenue line that can be accused — journals and period named. */
doc = .ReportDocument~new("pnl-2026-08", "FlyLo management accounts August 2026")
reg = .ReportTransformRegistry~new
ignore = .ReportJournalAdapter~registerInto(reg, .ReportJournalAdapter~transformId)
ignore = .ReportGlPostingAdapter~registerInto(reg, .ReportGlPostingAdapter~transformId)
ignore = .ReportPeriodAdapter~registerInto(reg, .ReportPeriodAdapter~transformId)
doc~transformRegistry = reg

per = .directory~new
per["book"] = "FLYLO"
per["period"] = "2026-08"
je = .directory~new
je["entryId"] = "JE-2026-0812"
je["digest"] = "sha256:je0812"
p1 = .directory~new
p1["postingId"] = "P-1"
p1["account"] = "4000"
p1["side"] = "CR"
p1["amount"] = "800.00"
p2 = .directory~new
p2["postingId"] = "P-2"
p2["account"] = "4000"
p2["side"] = "CR"
p2["amount"] = "400.00"

bPer = .ReportPeriodAdapter~bind("b-per", "SUPPORTING", per)
bJe  = .ReportJournalAdapter~bind("b-je", "PRIMARY", je)
bP1  = .ReportGlPostingAdapter~bind("b-p1", "SUPPORTING", p1)
bP2  = .ReportGlPostingAdapter~bind("b-p2", "SUPPORTING", p2)

agg = .ReportAggregate~new("rev-4000-2026-08")
ignore = agg~addMember("ACCT:GL:4000:P-1")
ignore = agg~addMember("ACCT:GL:4000:P-2")
say "member-set" agg~sealMembers

c = .ReportClaim~new("c-rev", "Account 4000 revenue for 2026-08 is 1,200.00.", "METRIC")
ignore = c~addBindingId("b-je")
ignore = c~addBindingId("b-p1")
ignore = c~addBindingId("b-p2")
ignore = c~addBindingId("b-per")
s = .ReportSection~new("pnl", "Profit and loss")
ignore = s~addClaimId("c-rev")
ignore = doc~addBinding(bPer)~addBinding(bJe)~addBinding(bP1)~addBinding(bP2)
ignore = doc~addClaim(c)~addSection(s)
say "sealed" doc~seal
say doc~humanForm
say
say doc~machineTrace
exit 0

::requires "../src/adapters/accounting/ReportJournalAdapter.cls"
