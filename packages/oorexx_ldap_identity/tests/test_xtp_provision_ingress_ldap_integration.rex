/* Contract smoke: actual XtpProvisionIngress consumes the LDAP-owned resolver. */
failed = 0
keyId = '000000000000a11c'
directory = buildDirectory(keyId)
resolver = .XtpProvisionLdapResolver~new(directory)
ingress = .XtpProvisionIngress~new(resolver, 64, 4, 100)

session = .IntegrationSession~new(keyId, 'ALLOCATE')
verdict = ingress~receive(session)
call assertTrue verdict['OK'], 'ingress accepts directory-authorised MI session'
call assertEqual 'mi:ed209a.mi1', verdict['PRINCIPAL'], 'ingress receives LDAP-derived MI principal'
call assertEqual 'ALLOCATE', verdict['PAYLOAD'], 'ingress preserves opaque payload'

ignore = directory~setEntityState('mi:ed209a.mi1', 'REVOKED')
session = .IntegrationSession~new(keyId, 'ALLOCATE')
verdict = ingress~receive(session)
call assertFalse verdict['OK'], 'ingress denies revoked MI'
call assertEqual 'IDENTITY_DENIED', verdict['REASON'], 'ingress fails at identity boundary'
call assertEqual 1, session~abortCount, 'denied session is aborted'

if failed = 0 then do
  say 'XTP PROVISION INGRESS + LDAP RESOLVER: OK'
  exit 0
end
say 'XTP PROVISION INGRESS + LDAP RESOLVER: FAILED' failed
exit 1

buildDirectory: procedure
  use strict arg keyId
  d = .IdentityDirectory~new('integration-peer')
  call requireOk d~createPrincipal('service:xtp.provision', 'oorexxEntityId=service:xtp.provision,ou=services,dc=example', 'SERVICE'), 'service principal'
  call requireOk d~createPrincipal('service:xtp.provision/client:mi:ed209a.mi1', 'oorexxEntityId=client-mi1,oorexxEntityId=service:xtp.provision,ou=services,dc=example', 'NODE'), 'client principal'
  call requireOk d~createPrincipal('mi:ed209a.mi1', 'oorexxEntityId=mi:ed209a.mi1,ou=nodes,dc=example', 'NODE'), 'MI principal'
  call requireOk d~createResource('resource:xtp.provision', 'oorexxEntityId=resource:xtp.provision,ou=resources,dc=example', 'SERVICE', 'xtp.provision'), 'resource'
  call requireOk d~createAclGrant('acl:mi1:xtp-provision', 'oorexxEntityId=acl:mi1:xtp-provision,ou=acl,dc=example', 'mi:ed209a.mi1', 'resource:xtp.provision', 'XTP_PROVISION', 'ALLOW'), 'ACL'
  call requireOk d~createKeySet('keyset:xtp.provision:mi1', 'oorexxEntityId=keyset-mi1,oorexxEntityId=client-mi1,oorexxEntityId=service:xtp.provision,ou=services,dc=example', 'service:xtp.provision/client:mi:ed209a.mi1', 'XTP_ENCRYPT'), 'key set'
  call requireOk d~stageKeyGeneration('keygen:xtp.provision:mi1:1', 'oorexxEntityId=keygen-mi1-1,oorexxEntityId=keyset-mi1,oorexxEntityId=client-mi1,oorexxEntityId=service:xtp.provision,ou=services,dc=example', 'keyset:xtp.provision:mi1', 1, 'AES256GCM', keyId, 'secret://xtp/xtp.provision/mi1/1'), 'key generation'
  call requireOk d~activateKeyGeneration('keyset:xtp.provision:mi1', 'keygen:xtp.provision:mi1:1'), 'key activation'
  return d

requireOk: procedure
  use strict arg result, label
  if \result~ok then raise syntax 93.900 array(label result~code result~detail)
  return

assertTrue: procedure expose failed
  use strict arg actual, label
  if \actual then do; say 'ASSERT TRUE FAILED:' label; failed += 1; end
  return

assertFalse: procedure expose failed
  use strict arg actual, label
  if actual then do; say 'ASSERT FALSE FAILED:' label; failed += 1; end
  return

assertEqual: procedure expose failed
  use strict arg expected, actual, label
  if expected \== actual then do; say 'ASSERT EQUAL FAILED:' label 'expected='expected 'actual='actual; failed += 1; end
  return

::class IntegrationSession public
::attribute abortCount
::attribute lastFlag
::method init
  expose key payload abortCount lastFlag consumed
  use strict arg key, payload
  abortCount = 0
  lastFlag = ''
  consumed = .false
::method info
  expose key
  info = .directory~new
  info['SERVICE'] = 'xtp.provision'
  info['OPEN'] = '1'
  info['PROTECTION'] = 'encrypt'
  info['KEYID'] = key
  return info
::method read
  expose payload lastFlag consumed
  use strict arg maxBytes, timeoutMs
  if consumed then do
    lastFlag = 'TIMEOUT'
    return ''
  end
  consumed = .true
  lastFlag = 'EOM'
  return payload
::method abort
  expose abortCount
  abortCount += 1
  return 0

::requires '../src/XtpProvisionLdapResolver.cls'
::requires 'XtpProvisionIngress.cls'
