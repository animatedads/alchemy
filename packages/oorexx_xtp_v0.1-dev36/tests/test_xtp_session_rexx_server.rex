/* dev31 ooRexx session test, server side.  Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
 * Admits only the service rexx.echo.  For each of two sessions: echoes every
 * message until the client closes its direction, then closes its own. */
parse arg peer
listener = .XtpSessionListener~new(peer, 'rexx.echo')
say 'READY'
total = 0
do sessionNumber = 1 to 2
  session = listener~accept(10000)
  if session = .nil then do; say 'FAIL server: session' sessionNumber 'not accepted'; exit 1; end
  count = 0
  do forever
    message = session~readMessage(10000)
    if message = .nil then leave
    session~writeMessage(message)
    count = count + 1
  end
  info = session~info
  if \session~close(5000) then do; say 'FAIL server: close of session' sessionNumber 'did not complete'; exit 1; end
  say 'PASS server: session' sessionNumber 'from' info['PEER'] 'echoed' count 'messages and closed'
  total = total + count
end
listener~close
exit 0
::requires 'XtpSession.cls'
