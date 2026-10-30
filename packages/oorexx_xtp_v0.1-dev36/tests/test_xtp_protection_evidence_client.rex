/* dev36 ooRexx test, opening side: protection evidence before and after the open.
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
 * Arguments: xtpPeer keyFile (four keys: svc.evid, svc.evid2, svc.auth, svc.evid4) */
parse arg peer keyFile
failures = 0
keys = .XtpServiceKeys~new(.array~of(.XtpFileKeySource~new(keyFile)))
ignore = keys~refresh
/* the key file's lines, so the test can change one key at a time as a reload would */
lines = .array~new
do while lines(keyFile) > 0; lines~append(linein(keyFile)); end
call stream keyFile, 'c', 'close'
md = .directory~new; md['XTP_MODE'] = 'session'; md['XTP_SERVICE'] = 'svc.evid'
address = .SocketAddresses~xtp(peer, .false, 'evid.send', md)

/* 1. before the open: from the route table and the key table */
route = .XtpSocketBackend~routeEvidence(address)
failures = failures + check('route evidence before the open', route, ,
  'SCHEMA=xtp.protection.evidence/1 BOUND=route MODE=session ROUTE='peer 'LAYER=4 CARRIER=udp SERVICE=svc.evid PROFILE=encrypt PROTECTION=encrypt OPENABLE=1 REASON=- KEYID=00000000000e71d1 KEYPRINCIPAL=- KEYSUITE=aes256gcm KEYSOURCE=file KEYSTATE=active KEYNOTBEFOREMS=0 KEYNOTAFTERMS=0')

/* 2. the caller's metadata cannot lower it: a floor of none still answers encrypt */
low = .directory~new; low['XTP_SERVICE'] = 'svc.evid'; low['XTP_PROTECTION'] = 'none'
failures = failures + check('a floor of none does not lower the evidence (and MODE is message without XTP_MODE)', ,
  .XtpSocketBackend~routeEvidence(xtp(low)), 'MODE=message PROFILE=encrypt PROTECTION=encrypt OPENABLE=1')

/* 3. a floor raises it: encrypt over an authenticate profile, as open_session does */
up = .directory~new; up['XTP_SERVICE'] = 'svc.auth'; up['XTP_PROTECTION'] = 'encrypt'
failures = failures + check('a floor of encrypt over an authenticate profile', ,
  .XtpSocketBackend~routeEvidence(xtp(up)), 'PROFILE=authenticate PROTECTION=encrypt OPENABLE=1 KEYID=00000000000e71d3 KEYSUITE=chacha20poly1305')

/* 4. a service with no keys and a floor of authenticate: not openable */
none = .directory~new; none['XTP_SERVICE'] = 'svc.nokeys'; none['XTP_PROTECTION'] = 'authenticate'
failures = failures + check('a floor with no key is not openable', ,
  .XtpSocketBackend~routeEvidence(xtp(none)), 'PROFILE=none PROTECTION=authenticate OPENABLE=0 REASON=no_active_key KEYID=-')

/* 5. a service with no keys and no floor: openable in clear, and says so */
clear = .directory~new; clear['XTP_SERVICE'] = 'svc.clear'
failures = failures + check('a service without keys is reported clear', ,
  .XtpSocketBackend~routeEvidence(xtp(clear)), 'PROFILE=none PROTECTION=none OPENABLE=1 KEYID=- KEYSOURCE=- KEYSTATE=-')

/* 6. a client principal with no key of its own; then one with its own key */
client = .directory~new; client['XTP_SERVICE'] = 'svc.evid'; client['XTP_KEY_PRINCIPAL'] = 'service:svc.evid/client:alice'
failures = failures + check('a principal without its own key is not openable', ,
  .XtpSocketBackend~routeEvidence(xtp(client)), 'OPENABLE=0 REASON=no_active_key_for_principal KEYID=-')
call xtpNativeKeyInstall 'svc.evid', '00000000000b0b01', 'encrypt', 'chacha20poly1305', copies('a5', 32), 'service:svc.evid/client:bob'
bob = .directory~new; bob['XTP_SERVICE'] = 'svc.evid'; bob['XTP_KEY_PRINCIPAL'] = 'service:svc.evid/client:bob'
failures = failures + check('a client principal gets its own key', ,
  .XtpSocketBackend~routeEvidence(xtp(bob)), 'OPENABLE=1 KEYID=00000000000b0b01 KEYPRINCIPAL=service:svc.evid/client:bob KEYSUITE=chacha20poly1305 KEYSOURCE=api')
failures = failures + check('the service itself still gets the service key', .XtpSocketBackend~routeEvidence(address), 'KEYID=00000000000e71d1 KEYPRINCIPAL=-')

/* 7. no route for the peer: no_route, even when there is no key either (open fails on the route first) */
failures = failures + check('a peer with no route is not openable', ,
  .XtpSession~serviceEvidence('NOROUTE', 'svc.evid'), 'ROUTE=NOROUTE LAYER=- OPENABLE=0 REASON=no_route')
failures = failures + check('no route and no key: the route is the reason', ,
  .XtpSession~serviceEvidence('NOROUTE', 'svc.nokeys', '', 'encrypt'), 'OPENABLE=0 REASON=no_route')

/* 8. key sources: a program call is always api; ldap and file belong to the key sources */
call xtpNativeKeyInstall 'svc.api', '00000000000a0a01', 'authenticate', 'aes256gcm', copies('5a', 32)
failures = failures + check('a key installed by a call is labelled api', ,
  .XtpSession~serviceEvidence(peer, 'svc.api'), 'PROFILE=authenticate PROTECTION=authenticate KEYID=00000000000a0a01 KEYSOURCE=api KEYSTATE=active')
failures = failures + raises('a call cannot label its key ldap', 'call xtpNativeKeyInstall "svc.api", "00000000000a0a02", "authenticate", "aes256gcm", copies("5a", 32), , , , , "ldap"')
failures = failures + raises('a replace with an unknown source name is refused', 'call xtpNativeKeyReplaceSource "evil", ""')

/* 9. values are given exactly: '=' in a service or principal is kept, so two names never look alike */
call xtpNativeKeyInstall 'svc.a=b', '00000000000a0a03', 'encrypt', 'aes256gcm', copies('3c', 32), 'p=q'
call xtpNativeKeyInstall 'svc.a_b', '00000000000a0a04', 'encrypt', 'aes256gcm', copies('3d', 32), 'p_q'
failures = failures + check('a service and principal containing =', .XtpSession~serviceEvidence(peer, 'svc.a=b', 'p=q'), 'SERVICE=svc.a=b KEYPRINCIPAL=p=q KEYID=00000000000a0a03')
failures = failures + check('the look-alike stays distinct', .XtpSession~serviceEvidence(peer, 'svc.a_b', 'p_q'), 'SERVICE=svc.a_b KEYPRINCIPAL=p_q KEYID=00000000000a0a04')
failures = failures + raises('an invalid service name raises', 'ignore = .XtpSession~serviceEvidence(peer, "bad name")')

/* 10. after the open: four sessions, bound to each, on both ends */
s1 = open('svc.evid'); s2 = open('svc.evid2'); s3 = open('svc.auth', 'encrypt'); s4 = open('svc.evid4')
failures = failures + check('session evidence at the opener', s1~evidence, ,
  'BOUND=session ROLE=opener SERVICE=svc.evid OPEN=1 PROTECTION=encrypt SUITE=aes256gcm KEYID='route['KEYID'] 'KEYPRINCIPAL=- PROFILE=encrypt KEYSOURCE=file KEYSTATE=active')
failures = failures + check('session above its profile: PROFILE is the service''s, PROTECTION the session''s', s3~evidence, ,
  'SERVICE=svc.auth PROTECTION=encrypt PROFILE=authenticate SUITE=chacha20poly1305 KEYSTATE=active')
do s over .array~of(s1, s2, s3, s4)
  e = s~evidence; seen = ''
  do while length(seen) < 16
    if \s~pump(5000) then leave
    chunk = s~recv(16 - length(seen))
    if chunk == .nil | chunk == '' then leave
    seen = seen || chunk
  end
  if seen \== e['KEYID'] then do; say 'FAIL client: the acceptor of' e['SERVICE'] 'reports key' seen; failures = failures + 1; end
end
say 'PASS client: each acceptor reports the same key as its opener'

/* 11. a key marked retiring (same secret): KEYSTATE retiring, the session stays; the route cannot open */
lines[1] = lines[1] '- 0 0 retiring'
call reload
failures = failures + check('retiring key, session kept', s1~evidence, 'KEYID=00000000000e71d1 KEYSTATE=retiring OPEN=1')
failures = failures + check('retiring key, route not openable', .XtpSocketBackend~routeEvidence(address), 'OPENABLE=0 REASON=no_active_key')

/* 12. a new secret under the same id (a reload with the key changed): replaced at once, then closed */
parse value lines[1] with svc id prot suite secret rest
lines[1] = svc id prot suite secret~reverse
call reload
failures = failures + check('secret replaced under the same id', s1~evidence, 'KEYID=00000000000e71d1 KEYSTATE=replaced KEYSOURCE=-')
failures = failures + closesWithin(s1, 'after its secret was replaced')
failures = failures + check('replaced: the route opens under the new secret', .XtpSocketBackend~routeEvidence(address), 'OPENABLE=1 KEYID=00000000000e71d1 KEYSTATE=active')

/* 13. not yet valid (same secret, not_before in the future) */
lines[2] = lines[2] '- 4102444800000 0 active'
call reload
failures = failures + check('key not yet valid', s2~evidence, 'KEYID=00000000000e71d2 KEYSTATE=notyet KEYNOTBEFOREMS=4102444800000')
failures = failures + closesWithin(s2, 'once its key was not yet valid')

/* 14. expired (same secret, not_after in the past) */
lines[3] = lines[3] '- 0 1 active'
call reload
failures = failures + check('key expired', s3~evidence, 'KEYID=00000000000e71d3 KEYSTATE=expired KEYNOTAFTERMS=1')
failures = failures + closesWithin(s3, 'after its key expired')

/* 15. revoked: absent at once; libxtp ends the session within about a second */
call xtpNativeKeyRevoke '00000000000e71d4'
failures = failures + check('revoked key shown at once', s4~evidence, 'KEYID=00000000000e71d4 KEYSTATE=absent KEYSOURCE=-')
failures = failures + closesWithin(s4, 'after its key was revoked')

/* 16. after close: the record kept as the session was released, OPEN 0 */
ignore = s4~close
failures = failures + check('evidence after close', s4~evidence, 'BOUND=session ROLE=opener SERVICE=svc.evid4 OPEN=0 KEYID=00000000000e71d4')
do s over .array~of(s1, s2, s3); ignore = s~close; end
if failures = 0 then exit 0
exit 1

reload:
  ignore = xtpNativeKeyReplaceSource('file', lines~makeString('L', '0a'x))
  return

xtp: procedure expose peer
  use arg metadata
  return .SocketAddresses~xtp(peer, .false, 'evid.x', metadata)

open: procedure expose peer
  use arg service, floor = 'auto'
  m = .directory~new; m['XTP_MODE'] = 'session'; m['XTP_SERVICE'] = service; m['XTP_PROTECTION'] = floor
  addresses = .RegisteredSocketAddressProvider~new
  addresses~register('evid.send', .SocketAddresses~xtp(peer, .false, 'evid.send', m))
  provider = .SocketProvider~new(addresses)
  provider~registerBinding('XTP', .RexxXtpSocketBinding~new(.XtpSocketBackend~new))
  return provider~streamSender('evid.send')~endpoint

closesWithin: procedure
  use arg socket, label
  t0 = time('E')
  do while socket~evidence['OPEN'] = 1 & time('E') - t0 < 5
    call SysSleep 0.05
  end
  if socket~evidence['OPEN'] = 0 then do
    say 'PASS client: the session closed' format(time('E') - t0,,2) 's' label
    return 0
  end
  say 'FAIL client: the session is still open 5 s' label
  return 1

raises: procedure expose peer
  use arg label, statement
  signal on syntax name raised
  interpret statement
  say 'FAIL client:' label': no error'
  return 1
raised:
  say 'PASS client:' label':' condition('O')['ADDITIONAL']~makeString~strip~left(80)
  return 0

/* expected: 'NAME=value ...' (each word split at its first '='); every one must match */
check: procedure
  use arg label, evidence, expected
  do pair over expected~makeArray(' ')
    if pair = '' then iterate
    parse var pair name '=' value
    if evidence[name] \== value then do
      say 'FAIL client:' label': 'name'='evidence[name] '(expected' value') in:' evidence['LINE']
      return 1
    end
  end
  say 'PASS client:' label': 'evidence['LINE']
  return 0

::requires 'XtpSocketProvider.cls'
::requires 'XtpServiceKeys.cls'
::requires 'SocketProvider.cls'
