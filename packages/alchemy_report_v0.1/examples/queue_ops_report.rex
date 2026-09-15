/* Infra: status queue drained under a committed UOW. */
doc = .ReportDocument~new("qf-ops-1", "Queue Fabric — FLYLO.STATUS window")
reg = .ReportTransformRegistry~new
ignore = .ReportQueueAdapter~registerInto(reg, .ReportQueueAdapter~transformId)
ignore = .ReportQueueWorkAdapter~registerInto(reg, .ReportQueueWorkAdapter~transformId)
ignore = .ReportQueueDispositionAdapter~registerInto(reg, .ReportQueueDispositionAdapter~transformId)
ignore = .ReportQueueUowAdapter~registerInto(reg, .ReportQueueUowAdapter~transformId)
doc~transformRegistry = reg

q = .directory~new
q["manager"] = "QF1"
q["queue"] = "FLYLO.STATUS"
q["ready"] = 0
q["inflight"] = 0
q["total"] = 0
w = .directory~new
w["correlationId"] = "corr-22"
w["deliverySequence"] = "9"
disp = .directory~new
disp["disposition"] = "ACK"
disp["correlationId"] = "corr-22"
uow = .directory~new
uow["uowId"] = "uow-88"
uow["result"] = "UOWCOMMIT"

bQ = .ReportQueueAdapter~bind("b-q", "SUPPORTING", q)
bW = .ReportQueueWorkAdapter~bind("b-w", "PRIMARY", w)
bD = .ReportQueueDispositionAdapter~bind("b-d", "SUPPORTING", disp)
bU = .ReportQueueUowAdapter~bind("b-u", "SUPPORTING", uow)

c = .ReportClaim~new("c1", "FLYLO.STATUS package corr-22 was ACK under UOWCOMMIT uow-88.", "FACT")
ignore = c~addBindingId("b-w")
ignore = c~addBindingId("b-d")
ignore = c~addBindingId("b-u")
ignore = c~addBindingId("b-q")
s = .ReportSection~new("ops", "Operations")
ignore = s~addClaimId("c1")
ignore = doc~addBinding(bQ)~addBinding(bW)~addBinding(bD)~addBinding(bU)
ignore = doc~addClaim(c)~addSection(s)
say "sealed" doc~seal
say doc~humanForm
say
say doc~machineTrace
exit 0

::requires "../src/adapters/queue/ReportQueueAdapter.cls"
