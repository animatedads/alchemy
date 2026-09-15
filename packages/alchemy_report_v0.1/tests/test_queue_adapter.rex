q = .directory~new
q["manager"] = "QF1"
q["queue"] = "FLYLO.STATUS"
q["ready"] = 3
q["inflight"] = 1
b = .ReportQueueAdapter~bind("b-q", "PRIMARY", q)
if b~sourcePoint \= "QUEUE:QF1/FLYLO.STATUS" then do
  say "FAIL queue point" b~sourcePoint
  exit 1
end
if b~span~pos("ready=3") = 0 then do
  say "FAIL depth span"
  exit 1
end

w = .directory~new
w["correlationId"] = "corr-22"
w["deliverySequence"] = "9"
b2 = .ReportQueueWorkAdapter~bind("b-w", "PRIMARY", w)
if b2~sourcePoint \= "QUEUEWORK:corr-22" then do
  say "FAIL work"
  exit 1
end

d = .directory~new
d["disposition"] = "ACK"
d["correlationId"] = "corr-22"
b3 = .ReportQueueDispositionAdapter~bind("b-d", "SUPPORTING", d)
if b3~sourcePoint \= "QUEUEDISP:ACK:corr-22" then do
  say "FAIL disp" b3~sourcePoint
  exit 1
end

u = .directory~new
u["uowId"] = "uow-1"
u["result"] = "UOWCOMMIT"
b4 = .ReportQueueUowAdapter~bind("b-u", "SUPPORTING", u)
if b4~sourceKind \= "QUEUE_UOW" then do
  say "FAIL uow"
  exit 1
end
say "PASS test_queue_adapter"
exit 0

::requires "../src/adapters/queue/ReportQueueAdapter.cls"
