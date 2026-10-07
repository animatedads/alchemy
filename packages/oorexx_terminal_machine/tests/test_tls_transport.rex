parse arg port certPath
failures = 0

bad = .SocatTlsTerminalTransport~new("localhost", port, .true, certPath || ".missing")
b = bad~open
call assertTrue \b~ok, "missing CA fails closed"
call assertEq b~code, "TLS_CA_NOT_FOUND", "missing CA code"

oldTerminalCa = value("OOREXX_TERMINAL_CA_FILE",, "ENVIRONMENT")
ignore = value("OOREXX_TERMINAL_CA_FILE", certPath, "ENVIRONMENT")
resolved = .TerminalTlsTrustStore~resolve
call assertTrue resolved~ok, "environment CA discovery succeeds"
if resolved~ok then do
  call assertEq resolved~value~mode, "FILE", "environment CA selection mode"
  call assertEq resolved~value~path, certPath, "environment CA selection path"
  call assertEq resolved~value~source, "ENV:OOREXX_TERMINAL_CA_FILE", "environment CA selection source"
end

transport = .SocatTlsTerminalTransport~new("localhost", port, .true)
opened = transport~open
helperPid = ""
call assertTrue opened~ok, "verified TLS tunnel opens through discovered trust"
if opened~ok then do
  helperPid = transport~helperPid
  call assertTrue helperPid~datatype("W"), "TLS helper PID captured"
  if helperPid~datatype("W") then call assertTrue processActive(helperPid), "TLS helper active while transport open"
  call assertEq transport~trustSource, "ENV:OOREXX_TERMINAL_CA_FILE", "transport reports trust source"
  sent = transport~sendBytes("TLS-5250-PING")
  call assertTrue sent~ok, "TLS binary send"
  ready = transport~waitReadable(2)
  call assertTrue ready~ok, "TLS wait readable result"
  if ready~ok then call assertTrue ready~value, "TLS tunnel becomes readable"
  received = transport~receiveBytesWait(1024, 2)
  call assertTrue received~ok, "TLS binary receive"
  if received~ok then call assertEq received~value, "TLS-5250-PING", "TLS exact echo"
end
closed = transport~close
call assertTrue closed~ok, "TLS close confirms helper shutdown"
if helperPid \= "" then call assertTrue \processActive(helperPid), "TLS helper not active after close"
ignore = value("OOREXX_TERMINAL_CA_FILE", oldTerminalCa, "ENVIRONMENT")
call assertEq transport~state, .TerminalTransportState~CLOSED, "TLS transport closed"

invalidPort = .SocatTlsTerminalTransport~new("localhost", "992;echo BAD", .false)
invalidOpen = invalidPort~open
call assertTrue \invalidOpen~ok, "unsafe/non-numeric TLS port fails closed"
call assertEq invalidOpen~code, "TLS_PORT_INVALID", "invalid TLS port code"

if failures > 0 then do
  say "FAIL test_tls_transport" failures
  exit 1
end
say "PASS test_tls_transport"
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
