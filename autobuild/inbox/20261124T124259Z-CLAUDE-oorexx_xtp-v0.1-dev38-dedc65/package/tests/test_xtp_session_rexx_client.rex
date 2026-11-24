/* dev31 ooRexx session test, client side.  Architecture: Tom Dyer.  Coding: Claude (Opus 5.5). */
parse arg peer
failures = 0
/* 1. a service the server does not admit is refused with the reason */
signal on syntax name refused
ignore = .XtpSession~open(peer, 'not.admitted', 2000)
say 'FAIL client: a refused service was opened'
failures = failures + 1
signal afterRefused
refused:
  reason = condition('O')['ADDITIONAL']~makeString
  if pos('SERVICE_NOT_ADMITTED', reason) > 0 then say 'PASS client: refused service raised' reason
  else do; say 'FAIL client: refusal reason was' reason; failures = failures + 1; end
afterRefused:
signal off syntax
/* 2. two messages echoed, one short and one of 76800 bytes holding every byte value */
session = .XtpSession~open(peer, 'rexx.echo', 3000)
short = 'hello from ooRexx'
session~writeMessage(short)
echo = session~readMessage(5000)
if echo == short then say 'PASS client: short message echoed'
else do; say 'FAIL client: short echo was' echo; failures = failures + 1; end
long = xrange('00'x, 'FF'x)~copies(300)
session~writeMessage(long)
echo = session~readMessage(5000)
if echo == long then say 'PASS client: 76800-byte binary message echoed intact'
else do; say 'FAIL client: long echo length' length(echo); failures = failures + 1; end
/* 3. half-close: we close our direction; the server closes its own; both complete */
session~shutdown
rest = session~readAll(5000)
if rest == '' & session~lastFlag = 'END' then say 'PASS client: the server closed its direction after ours'
else do; say 'FAIL client: expected END, got' session~lastFlag; failures = failures + 1; end
if session~close(5000) then say 'PASS client: close completed in both directions'
else do; say 'FAIL client: close did not complete'; failures = failures + 1; end
/* 4. one thread reads while another writes the same session object */
duplex = .XtpSession~open(peer, 'rexx.echo', 3000)
reader = .DuplexReader~new
reader~start(duplex)
expected = ''
do i = 1 to 200
  message = 'message' i copies('x', i * 37)
  duplex~writeMessage(message)
  expected = expected || message || '|'
end
duplex~shutdown
got = reader~collected(20)
if got == expected then say 'PASS client: 200 messages written on one thread and read on another, all in order'
else do; say 'FAIL client: duplex read' length(got) 'of' length(expected) 'bytes'; failures = failures + 1; end
if duplex~close(5000) then nop
else do; say 'FAIL client: duplex close did not complete'; failures = failures + 1; end
if failures = 0 then exit 0
exit 1

/* Reads every message on its own thread until the peer closes. */
::class DuplexReader
::method start
  expose text done
  use strict arg session
  text = ''
  done = .false
  reply
  do forever
    message = session~readMessage(10000)
    if message = .nil then leave
    text = text || message || '|'
  end
  done = .true
::method collected
  expose text done
  use strict arg seconds
  guard off
  do seconds * 10
    guard on
    if done then return text
    guard off
    call SysSleep 0.1
  end
  return text
::requires 'XtpSession.cls'
