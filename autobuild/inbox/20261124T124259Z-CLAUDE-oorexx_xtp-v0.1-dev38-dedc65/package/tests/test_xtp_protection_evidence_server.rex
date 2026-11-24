/* dev36 ooRexx test, listening side: protection evidence of accepted sessions.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
 * Arguments: xtpPeer keyFile.  Accepts four streams (svc.evid, svc.evid2,
 * svc.auth, svc.evid4), checks each one's evidence, sends back the key id it
 * sees, then reads every stream to its end. */
parse arg peer keyFile
keys = .XtpServiceKeys~new(.array~of(.XtpFileKeySource~new(keyFile)))
ignore = keys~refresh
md = .directory~new; md['XTP_MODE'] = 'session'; md['XTP_SERVICE'] = 'svc.evid,svc.evid2,svc.auth,svc.evid4'
addresses = .RegisteredSocketAddressProvider~new
addresses~register('evid.listen', .SocketAddresses~xtp(peer, .false, 'evid.listen', md))
provider = .SocketProvider~new(addresses)
provider~registerBinding('XTP', .RexxXtpSocketBinding~new(.XtpSocketBackend~new))
listener = provider~listener('evid.listen')
say 'READY'
expected = .directory~new
expected['svc.evid']  = 'PROTECTION=encrypt PROFILE=encrypt SUITE=aes256gcm KEYID=00000000000e71d1'
expected['svc.evid2'] = 'PROTECTION=encrypt PROFILE=encrypt SUITE=aes256gcm KEYID=00000000000e71d2'
/* the opener asked for encrypt over an authenticate profile */
expected['svc.auth']  = 'PROTECTION=encrypt PROFILE=authenticate SUITE=chacha20poly1305 KEYID=00000000000e71d3'
expected['svc.evid4'] = 'PROTECTION=encrypt PROFILE=encrypt SUITE=aes256gcm KEYID=00000000000e71d4'
sockets = .array~new; failures = 0
do 4
  if \listener~waitReady(15000) then do; say 'FAIL server: a stream did not arrive within 15 s'; exit 1; end
  socket = listener~tryAccept
  e = socket~evidence
  want = 'BOUND=session ROLE=acceptor OPEN=1 KEYSTATE=active KEYSOURCE=file KEYPRINCIPAL=-' expected[e['SERVICE']]
  ok = expected~hasIndex(e['SERVICE'])
  do pair over want~makeArray(' ')
    parse var pair name '=' value
    if e[name] \== value then ok = .false
  end
  if ok then say 'PASS server: acceptor evidence:' e['LINE']
  else do; say 'FAIL server: acceptor evidence:' e['LINE'] '(expected' want')'; failures = failures + 1; end
  n = socket~send(e['KEYID'])
  ignore = socket~shutdown
  sockets~append(socket)
end
do socket over sockets
  do forever
    if \socket~pump(8000) then leave
    chunk = socket~recv(65536)
    if chunk == .nil | chunk == '' then leave
  end
  ignore = socket~close
end
ignore = listener~close
if failures = 0 then exit 0
exit 1
::requires 'XtpSocketProvider.cls'
::requires 'XtpServiceKeys.cls'
::requires 'SocketProvider.cls'
