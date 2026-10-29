/* dev32 ooRexx test, XTP side that listens.  Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
 * Arguments: xtpPeer ldapPort secretHex.  Keys come from LDAP.  Accepts up to
 * two sessions of svc.ldap, echoes one message on each, then closes. */
parse arg peer ldapPort secretHex
keys = .XtpServiceKeys~new(.array~of(ldapSource(ldapPort, secretHex)))
outcome = keys~refresh
if outcome['SOURCE'] <> 'ldap' then do; say 'FAIL server: keys did not come from LDAP:' outcome['ERRORS']~makeString('L', '; '); exit 1; end
say 'PASS server: keys from LDAP, count='outcome['COUNT'] 'profile of svc.ldap='keys~protectionOf('svc.ldap')
listener = .XtpSessionListener~new(peer, 'svc.ldap')
say 'READY'
served = 0
do 2
  session = listener~accept(15000)
  if session = .nil then leave
  message = session~readMessage(5000)
  session~writeMessage(message)
  info = session~info
  rest = session~readAll(5000)
  closed = session~close(5000)
  served = served + 1
  say 'PASS server: session' served 'protection='info['PROTECTION'] 'keyId='info['KEYID'] 'closed='closed
end
listener~close
exit 0

ldapSource: procedure
  use arg ldapPort, secretHex
  provider = .TestSecretProvider~new
  ignore = provider~put('secret://identity/mu-07/ldap', 'mu-07-bind-secret')
  ignore = provider~put('secret://xtp/svc.ldap/1', secretHex~reverse)
  ignore = provider~put('secret://xtp/svc.ldap/2', secretHex)
  addresses = .RegisteredSocketAddressProvider~new
  addresses~register('xtp.keys.ldap', .SocketAddresses~tcp('127.0.0.1', ldapPort))
  sockets = .SocketSelector~new(addresses)
  sockets~registerBinding('TCP', .RxSockTcpBinding~new)
  return .XtpLdapKeySource~new(sockets, 'xtp.keys.ldap', 'uid=mu-07,ou=nodes,dc=example,dc=org', 'secret://identity/mu-07/ldap', 'dc=example,dc=org', .SecretBroker~new(provider))

::requires 'RxSockSocketBinding.cls'
::requires 'SecretBroker.cls'
::requires 'XtpSession.cls'
::requires 'XtpLdapKeySource.cls'
