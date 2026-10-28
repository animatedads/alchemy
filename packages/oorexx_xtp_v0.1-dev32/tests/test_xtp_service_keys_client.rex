/* dev32 ooRexx test, XTP side that opens.  Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
 * Arguments: xtpPeer ldapPort deadLdapPort secretHex goodKeyFile wrongKeyFile */
parse arg peer ldapPort deadPort secretHex goodFile wrongFile
failures = 0
/* 1. LDAP works: keys from LDAP, an encrypted session under the active key */
keys = .XtpServiceKeys~new(.array~of(ldapSource(ldapPort, secretHex), .XtpFileKeySource~new(goodFile)))
outcome = keys~refresh
listing = keys~list
states = ''
do key over listing; states = states key['KEYID']'='key['STATE']'/'key['SOURCE']; end
if outcome['SOURCE'] = 'ldap' & outcome['COUNT'] = 2 then say 'PASS client: keys from LDAP:'states
else do; say 'FAIL client: LDAP refresh gave' outcome['SOURCE'] outcome['COUNT'] outcome['ERRORS']~makeString('L', '; '); failures = failures + 1; end
failures = failures + echo(peer, 'over LDAP keys', '00000000000a11c1')
/* 2. LDAP unreachable: the key file is the fallback */
ignore = xtpNativeKeyClearSource('ldap')
keys = .XtpServiceKeys~new(.array~of(ldapSource(deadPort, secretHex), .XtpFileKeySource~new(goodFile)))
outcome = keys~refresh
if outcome['SOURCE'] = 'file' then say 'PASS client: LDAP unreachable, keys from the key file ('outcome['ERRORS'][1]')'
else do; say 'FAIL client: fallback gave' outcome['SOURCE']; failures = failures + 1; end
failures = failures + echo(peer, 'over key-file keys', '00000000000a11c1')
/* 2b (review H3). LDAP answers but finds no XTP keys (a base DN the reader can
 * see but that holds no key sets): that is a failure, the file keys stay */
keys = .XtpServiceKeys~new(.array~of(ldapSource(ldapPort, secretHex, 'uid=mu-07,ou=nodes,dc=example,dc=org'), .XtpFileKeySource~new(goodFile)))
outcome = keys~refresh
errors = outcome['ERRORS']~makeString('L', '; ')
if outcome['SOURCE'] = 'file' & errors~pos('no XTP keys') > 0 & keys~protectionOf('svc.ldap') = 'encrypt' then say 'PASS client: LDAP with no keys is a failure; the key file is used ('errors~left(90)')'
else do; say 'FAIL client: LDAP with no keys gave' outcome['SOURCE'] errors; failures = failures + 1; end
/* 2c (review ML1). a generation whose secret reference is outside secret://xtp/<service>/ fails the whole LDAP fetch */
keys = .XtpServiceKeys~new(.array~of(ldapSource(ldapPort, secretHex, 'dc=example,dc=org', 'secret://other/'), .XtpFileKeySource~new(goodFile)))
outcome = keys~refresh
errors = outcome['ERRORS']~makeString('L', '; ')
if outcome['SOURCE'] = 'file' & errors~pos('outside secret://other/svc.ldap/') > 0 then say 'PASS client: a secret reference outside the service prefix is refused ('errors~left(90)')'
else do; say 'FAIL client: secret prefix check gave' outcome['SOURCE'] errors; failures = failures + 1; end
/* 2d (review H3). a source that raises an error is a failed source; the next one is tried */
keys = .XtpServiceKeys~new(.array~of(.RaisingKeySource~new, .XtpFileKeySource~new(goodFile)))
outcome = keys~refresh
if outcome['SOURCE'] = 'file' then say 'PASS client: a source that raises falls through to the key file ('outcome['ERRORS'][1]~left(60)')'
else do; say 'FAIL client: raising source gave' outcome['SOURCE']; failures = failures + 1; end
/* 3. a key file with the wrong secret for the same key id cannot open */
keys = .XtpServiceKeys~new(.array~of(.XtpFileKeySource~new(wrongFile)))
outcome = keys~refresh
signal on syntax name refused
ignore = .XtpSession~open(peer, 'svc.ldap', 1500)
say 'FAIL client: a session opened with the wrong secret'
failures = failures + 1
signal done
refused:
  say 'PASS client: wrong secret cannot open:' condition('O')['ADDITIONAL']~makeString~left(120)
done:
signal off syntax
/* 4 (review H1). with every key gone the profile stays: opens fail, never fall back to clear */
ignore = xtpNativeKeyClearSource('file')
ignore = xtpNativeKeyClearSource('ldap')
profile = keys~protectionOf('svc.ldap')
signal on syntax name refused2
ignore = .XtpSession~open(peer, 'svc.ldap', 1500, 'none')
say 'FAIL client: a session opened with no keys left'
failures = failures + 1
signal done2
refused2:
  if profile = 'encrypt' then say 'PASS client: no keys left, profile still' profile', open refused:' condition('O')['ADDITIONAL']~makeString~left(80)
  else do; say 'FAIL client: profile fell to' profile; failures = failures + 1; end
done2:
signal off syntax
if failures = 0 then exit 0
exit 1

echo: procedure
  use arg peer, label, expectedKey
  session = .XtpSession~open(peer, 'svc.ldap', 3000)
  info = session~info
  message = 'encrypted hello' label
  session~writeMessage(message)
  answer = session~readMessage(5000)
  session~shutdown
  ignore = session~readAll(5000)
  closed = session~close(5000)
  if answer == message & info['PROTECTION'] = 'encrypt' & info['KEYID'] = expectedKey & closed then do
    say 'PASS client: encrypted session' label 'keyId='info['KEYID']
    return 0
  end
  say 'FAIL client: session' label 'answer='answer 'protection='info['PROTECTION'] 'keyId='info['KEYID'] 'closed='closed
  return 1

ldapSource: procedure
  use arg ldapPort, secretHex, baseDn = 'dc=example,dc=org', prefix = 'secret://xtp/'
  provider = .TestSecretProvider~new
  ignore = provider~put('secret://identity/mu-07/ldap', 'mu-07-bind-secret')
  ignore = provider~put('secret://xtp/svc.ldap/1', secretHex~reverse)
  ignore = provider~put('secret://xtp/svc.ldap/2', secretHex)
  addresses = .RegisteredSocketAddressProvider~new
  addresses~register('xtp.keys.ldap', .SocketAddresses~tcp('127.0.0.1', ldapPort))
  sockets = .SocketSelector~new(addresses)
  sockets~registerBinding('TCP', .RxSockTcpBinding~new)
  return .XtpLdapKeySource~new(sockets, 'xtp.keys.ldap', 'uid=mu-07,ou=nodes,dc=example,dc=org', 'secret://identity/mu-07/ldap', baseDn, .SecretBroker~new(provider), prefix)

::class RaisingKeySource
::method name
  return 'raising'
::method apply
  raise syntax 93.900 array('this key source always fails')

::requires 'RxSockSocketBinding.cls'
::requires 'SecretBroker.cls'
::requires 'XtpSession.cls'
::requires 'XtpLdapKeySource.cls'
