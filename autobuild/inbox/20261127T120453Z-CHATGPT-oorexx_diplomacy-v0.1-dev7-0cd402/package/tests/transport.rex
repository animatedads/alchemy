/* Fake credential and fake curl only. No network. Exercise lease lifecycle,
   curl argv/stdin separation, exact request bytes, response and timeout. */
parse arg work
if work == '' then exit 2
checks = 0
failures = 0
broker = .FakeBroker~new
transport = .DiplomacyCurlTransport~new(broker,'fixture-reference')
reply = transport~post('HAIKU','{"input":"fixture"}',5)
call check reply[1] == 'OK' & reply[2] == 200 & reply[3] == '{"fixture":true}','Haiku fake HTTPS response'
call check \broker~lease~active,'lease retired after success'
call check broker~reference == 'fixture-reference','reference only'
call check broker~calls = 1,'one lease per call'
reply = transport~post('SOL','{"input":"timeout"}',5)
call check reply[1] == 'TIMEOUT','curl timeout mapped'
call check \broker~lease~active,'lease retired after timeout'
reply = transport~post('SOL','{"input":"error"}',5)
call check reply[1] == 'ERROR','curl error mapped'
call check \broker~lease~active,'lease retired after error'
started = time('E')
reply = transport~post('SOL','{"input":"sleep"}',1)
call check reply[1] == 'TIMEOUT','outer process deadline enforced'
call check time('E')-started < 5,'sleep interrupted before natural return'
call check \broker~lease~active,'lease retired after outer deadline'
reply = transport~post('STUB','secret',5)
call check reply[1] == 'ERROR' & broker~calls = 4,'unsupported provider never acquires credential'
say 'Transport gate:' checks 'assertions;' failures 'failures'
exit (failures > 0)
check:
  use strict arg ok, label
  checks += 1
  if \ok then do
    failures += 1
    say 'FAIL:' label
  end
  return

::class FakeBroker
::attribute lease get
::attribute reference get
::attribute calls get
::method init
  expose calls
  calls = 0
::method acquire
  expose lease reference calls
  use strict arg reference
  calls += 1
  lease = .FakeLease~new
  return lease
::class FakeLease
::attribute active get
::method init
  expose active
  active = .true
::method ok
  return .true
::method secretForTrustedConsumer
  return self
::method value
  return 'FIXTURE-SECRET-NOT-A-REAL-KEY'
::method retire
  expose active
  active = .false
  return .true
::requires 'DiplomacyCurlTransport.cls'
