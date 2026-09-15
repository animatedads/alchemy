assertions = 0
call assertEqual "127.0.0.1", .QueueSocketIpv4~canonical("127.0.0.1"), "loopback canonical"
call assertEqual "10.12.34.56", .QueueSocketIpv4~canonical("10.12.34.56"), "private address canonical"
call assertEqual "192.168.1.9", .QueueSocketIpv4~canonical(" 192.168.1.9 "), "outer whitespace stripped"
call assertInvalid ""
call assertInvalid "localhost"
call assertInvalid "10.0.0.0/24"
call assertInvalid "010.0.0.1"
call assertInvalid "10.0.0.256"
call assertInvalid "::1"
call assertInvalid "0.0.0.0"
call assertInvalid "10.0..1"
say "OBJECT QUEUE FABRIC V0.9-dev5 EXACT IPV4 SOURCE POLICY: OK assertions=" || assertions
exit 0

assertEqual: procedure expose assertions
  use arg expected, actual, label
  assertions += 1
  if expected \= actual then do
    say "ASSERT FAILED:" label "expected="expected "actual="actual
    exit 1
  end
  return

assertInvalid: procedure expose assertions
  use arg value
  assertions += 1
  if .QueueSocketIpv4~canonicalOrEmpty(value) \= "" then do
    say "ASSERT FAILED: invalid IP accepted:" value
    exit 1
  end
  return

::requires "ObjectQueueSocketTransport.cls"
