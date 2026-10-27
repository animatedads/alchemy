/* test_operational_socket_rexx.rex
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5), dev29.
 *
 * Proves the dev26 R-09 rule in ooRexx: XtpOperationalSocket~send refuses with
 * -7 when the planner decides THROTTLE at 0%, or THROTTLE with a missing or
 * non-numeric RATE_PERCENT, and never reaches the socket.  A positive THROTTLE
 * and an ALLOW decision still send.  Uses a fake socket and planner, so no
 * network or native call is made.
 */
sock = .FakeOperationalSocket~new
planner = .FakeOperationalPlanner~new
opsock = .XtpOperationalSocket~new(sock, planner, 'BULK.STORAGE.COPY', 'degraded', .false, .true)

planner~decision('throttle', '0')
answer = opsock~send('payload')
if answer \= -7 then call fail 'THROTTLE 0% returned' answer 'instead of -7'
if sock~sends \= 0 then call fail 'THROTTLE 0% reached the socket'

planner~decision('throttle', '')
answer = opsock~send('payload')
if answer \= -7 then call fail 'THROTTLE without RATE_PERCENT returned' answer 'instead of -7'

planner~decision('throttle', 'abc')
answer = opsock~send('payload')
if answer \= -7 then call fail 'THROTTLE with RATE_PERCENT abc returned' answer 'instead of -7'
if sock~sends \= 0 then call fail 'a refused THROTTLE reached the socket'

planner~decision('throttle', '40')
answer = opsock~send('payload')
if sock~sends \= 1 then call fail 'THROTTLE 40% did not reach the socket'

planner~decision('allow', '100')
answer = opsock~send('payload')
if sock~sends \= 2 then call fail 'ALLOW did not reach the socket'

say 'PASS ooRexx XtpOperationalSocket refuses THROTTLE 0% (and missing or bad RATE_PERCENT) with -7'
exit 0

fail:
  use arg reason
  say 'FAIL' reason
  exit 1

::requires 'XtpSocketProvider.cls'

::class FakeOperationalSocket public
::attribute sends get
::method init
  expose sends
  sends = 0
::method send
  expose sends
  use arg bytes
  sends = sends + 1
  return length(bytes)
::method priority
  return self

::class FakeOperationalPlanner public
::method init
  expose current
  current = .directory~new
::method decision
  expose current
  use arg action, ratePercent
  current = .directory~new
  current['ACTION'] = action
  current['TRANSMIT'] = '1'
  current['TRANSFORM'] = '0'
  current['FALLBACK'] = 'allow'
  current['PROTECTED_ONLY'] = '0'
  if ratePercent \= '' then current['RATE_PERCENT'] = ratePercent
  return self
::method decide
  expose current
  use arg className, operatingState
  return current
