parse arg port certPath
failures = 0

oldTerminalCa = value("OOREXX_TERMINAL_CA_FILE",, "ENVIRONMENT")
ignore = value("OOREXX_TERMINAL_CA_FILE", certPath, "ENVIRONMENT")
transport = .SocatTlsTerminalTransport~new("localhost", port, .true)
opened = transport~open
call assertTrue opened~ok, "TLS helper lifecycle transport opens"
if opened~ok then do
  pid = transport~helperPid
  call assertTrue pid~datatype("W"), "helper PID is numeric"
  if pid~datatype("W") then do
    call assertTrue processActive(pid), "helper active before forced stop"
    address command "kill -STOP " || pid || " >/dev/null 2>&1"
    call assertTrue rc = 0, "helper can be stopped for regression fixture"
    address command "sleep 0.05"
    call assertTrue processActive(pid), "stopped helper is still a live process"
    closed = transport~close
    call assertTrue closed~ok, "close escalates and confirms stubborn helper shutdown"
    call assertTrue \processActive(pid), "stubborn helper is no longer active after close"
    call assertEq transport~state, .TerminalTransportState~CLOSED, "transport closes after escalation"
  end
end
ignore = value("OOREXX_TERMINAL_CA_FILE", oldTerminalCa, "ENVIRONMENT")

if failures > 0 then do
  say "FAIL test_tls_helper_lifecycle" failures
  exit 1
end
say "PASS test_tls_helper_lifecycle"
exit 0

processActive: procedure
  use arg pid
  if \pid~datatype("W") then return .false
  address command "ps -p " || pid || " -o stat= 2>/dev/null | grep -Eq '^[[:space:]]*[^Z]'"
  return rc = 0

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
