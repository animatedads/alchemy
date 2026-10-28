/* dev33 ooRexx test: hostile directory entries (second dev32 review, F1 and F2).
 * Architecture: Tom Dyer.  Coding: Claude (Opus 5.5).
 * Arguments: ldapPort secretHex mode (tenant | inject | placement) */
parse arg port secretHex mode
ignore = xtpNativeKeyClearSource('ldap')
keys = .XtpServiceKeys~new(.array~of(src(port, secretHex)))
o = keys~refresh
held = ''
do k over keys~list; held = held k['KEYID']'='k['STATE']; end
warnings = o['WARNINGS']~makeString('L', '; ')~changeStr('0a'x, ' ')
say '  ' mode': source='o['SOURCE'] 'count='o['COUNT'] 'keys:'held
say '  ' mode': warnings:' warnings~left(240)
select
  when mode = 'tenant' then ok = o['SOURCE'] = 'ldap' & held~pos('00000000000a11c2=active') > 0 & held~pos('00000000000a11c1') = 0 & warnings~pos('key:xtp:evil:1') > 0
  when mode = 'inject' then ok = o['SOURCE'] = 'ldap' & held~pos('98bb') = 0 & held~pos('98cc') = 0 & held~pos('98aa') = 0 & warnings~pos('not by a service:<valid name>') > 0 & held~pos('00000000000a11c1=active') > 0
  when mode = 'placement' then ok = o['SOURCE'] = 'ldap' & held~pos('98dd') = 0 & warnings~pos('is not under its key set') > 0
  otherwise ok = .false
end
if ok then do; say 'PASS' mode; exit 0; end
say 'FAIL' mode
exit 1
src: procedure
  use arg port, secretHex
  provider = .TestSecretProvider~new
  ignore = provider~put('secret://identity/mu-07/ldap', 'mu-07-bind-secret')
  ignore = provider~put('secret://xtp/svc.ldap/1', secretHex~reverse)
  ignore = provider~put('secret://xtp/svc.ldap/2', secretHex)
  ignore = provider~put('secret://xtp/svc.ldap/3', copies('3', 64))
  ignore = provider~put('secret://xtp/svc.ldap/9', copies('9', 64))
  ignore = provider~put('secret://xtp/evil/1', copies('e', 64))
  crafted = 'evil/x 00000000000098aa authenticate aes256gcm' copies('1', 64) || '0a'x || 'svc.ldap 00000000000098bb encrypt aes256gcm' copies('7', 64) || '0a'x || '#'
  ignore = provider~put('secret://xtp/' || crafted || '/1', copies('c', 64))
  addresses = .RegisteredSocketAddressProvider~new
  addresses~register('xtp.keys.ldap', .SocketAddresses~tcp('127.0.0.1', port))
  sockets = .SocketSelector~new(addresses)
  sockets~registerBinding('TCP', .RxSockTcpBinding~new)
  return .XtpLdapKeySource~new(sockets, 'xtp.keys.ldap', 'uid=mu-07,ou=nodes,dc=example,dc=org', 'secret://identity/mu-07/ldap', 'dc=example,dc=org', .SecretBroker~new(provider))
::requires 'RxSockSocketBinding.cls'
::requires 'SecretBroker.cls'
::requires 'XtpServiceKeys.cls'
::requires 'XtpLdapKeySource.cls'
