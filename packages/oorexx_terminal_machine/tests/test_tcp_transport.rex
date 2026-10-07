failures = 0
parse arg port
transport = .TcpTerminalTransport~new("127.0.0.1", port)
call assertTrue transport~open~ok, "open loopback"
call assertTrue transport~sendBytes("5250-PING")~ok, "send bytes"
ready = transport~waitReadable(2)
call assertTrue ready~ok, "wait readable result"
if ready~ok then call assertTrue ready~value, "loopback becomes readable"
rx = transport~receiveBytesWait(64, 2)
call assertTrue rx~ok, "receive bytes"
call assertEq rx~value, "ACK:5250-PING", "exact loopback response"
call assertTrue transport~close~ok, "close"

if failures > 0 then do
  say "FAIL test_tcp_transport" failures
  exit 1
end
say "PASS test_tcp_transport"
exit 0

assertEq: procedure expose failures
  use arg actual, expected, label
  if actual == expected then return
  failures += 1
  say "ASSERT_EQ FAIL:" label "expected="expected "actual="actual
  return
assertTrue: procedure expose failures
  use arg condition, label
  if condition then return
  failures += 1
  say "ASSERT_TRUE FAIL:" label
  return

::requires "TerminalTransport.cls"
