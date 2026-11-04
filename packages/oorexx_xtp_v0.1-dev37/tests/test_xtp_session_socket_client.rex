/* dev35 ooRexx test, opening side: an XTP session as a SocketProvider stream.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
 * Arguments: xtpPeer keyFile */
parse arg peer keyFile
failures = 0
keys = .XtpServiceKeys~new(.array~of(.XtpFileKeySource~new(keyFile)))
ignore = keys~refresh
md = .directory~new; md['XTP_MODE'] = 'session'; md['XTP_SERVICE'] = 'svc.stream'
addresses = .RegisteredSocketAddressProvider~new
addresses~register('stream.send', .SocketAddresses~xtp(peer, .false, 'stream.send', md))
provider = .SocketProvider~new(addresses)
provider~registerBinding('XTP', .RexxXtpSocketBinding~new(.XtpSocketBackend~new))
stream = provider~streamSender('stream.send')
if stream == .nil then do; say 'FAIL client: no stream'; exit 1; end
/* a bounded pump with nothing to read returns .false after about its timeout */
t0 = time('E')
ready = stream~pump(300)
waited = time('E') - t0
if \ready & waited >= 0.25 & waited < 2 then say 'PASS client: pump(300) with nothing to read returned .false after' format(waited,,2) 's'
else do; say 'FAIL client: pump(300) gave' ready 'after' waited 's'; failures = failures + 1; end
/* 200,000 bytes in 7 writes of uneven size */
data = ''
do i = 1 to 200; data = data || d2c(i // 256) || copies(xrange('00'x, 'ff'x), 3) || 'x'; end
data = data~left(200000, 'z')
sent = 0; pos = 1
do size over .array~of(1, 999, 40000, 9, 50000, 60000, 48991)
  if stream~write(data~substr(pos, size)) then sent = sent + size
  pos = pos + size
end
ignore = stream~endpoint~shutdown
answer = ''
do forever
  if \stream~pump(5000) then do; say 'FAIL client: no answer within 5 s'; failures = failures + 1; leave; end
  chunk = stream~read(65536)
  if chunk == .nil | chunk == '' then leave
  answer = answer || chunk
end
info = stream~endpoint~info
if sent = 200000 & answer == data~reverse & info['PROTECTION'] = 'encrypt' then say 'PASS client: 200,000 bytes written as a stream, answered reversed and byte-exact, protection='info['PROTECTION']
else do; say 'FAIL client: sent' sent 'answer' length(answer) 'protection' info['PROTECTION']; failures = failures + 1; end
ignore = stream~close
if failures = 0 then exit 0
exit 1
::requires 'XtpSocketProvider.cls'
::requires 'XtpServiceKeys.cls'
::requires 'SocketProvider.cls'
