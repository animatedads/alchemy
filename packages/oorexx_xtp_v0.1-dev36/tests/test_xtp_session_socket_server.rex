/* dev35 ooRexx test, listening side: an XTP session through SocketProvider.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
 * Arguments: xtpPeer keyFile.  Accepts one stream on svc.stream, reads it to
 * its end with bounded pumps, answers with the bytes reversed, then closes. */
parse arg peer keyFile
keys = .XtpServiceKeys~new(.array~of(.XtpFileKeySource~new(keyFile)))
ignore = keys~refresh
md = .directory~new; md['XTP_MODE'] = 'session'; md['XTP_SERVICE'] = 'svc.stream'
addresses = .RegisteredSocketAddressProvider~new
addresses~register('stream.listen', .SocketAddresses~xtp(peer, .false, 'stream.listen', md))
provider = .SocketProvider~new(addresses)
provider~registerBinding('XTP', .RexxXtpSocketBinding~new(.XtpSocketBackend~new))
listener = provider~listener('stream.listen')
say 'READY'
if \listener~waitReady(15000) then do; say 'FAIL server: no stream within 15 s'; exit 1; end
socket = listener~tryAccept
data = ''; pumps = 0
do forever
  if \socket~pump(2000) then do; pumps = pumps + 1; if pumps > 10 then leave; iterate; end
  chunk = socket~recv(65536)
  if chunk == .nil then do; say 'FAIL server: session failed:' socket~error; exit 1; end
  if chunk == '' then leave
  data = data || chunk
end
info = socket~info
say 'PASS server: read' length(data) 'bytes to the end of the stream, protection='info['PROTECTION'] 'keyId='info['KEYID']
n = socket~send(data~reverse)
ignore = socket~shutdown
ignore = socket~close
ignore = listener~close
if n = length(data) & info['PROTECTION'] = 'encrypt' then exit 0
exit 1
::requires 'XtpSocketProvider.cls'
::requires 'XtpServiceKeys.cls'
::requires 'SocketProvider.cls'
