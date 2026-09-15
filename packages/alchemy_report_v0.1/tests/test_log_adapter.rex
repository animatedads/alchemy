d = .directory~new
d["eventId"] = "log-1"
d["level"] = "ERROR"
d["logger"] = "queue.fabric"
b = .ReportLogAdapter~bind("b-l", "PRIMARY", d)
if b~sourcePoint \= "LOG:log-1" then do
  say "FAIL point"
  exit 1
end
say "PASS test_log_adapter"
exit 0

::requires "../src/adapters/logging/ReportLogAdapter.cls"
