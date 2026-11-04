/* XTP provisioning -> LDAP Identity principal binding regression.
 * Requires the normal LDAP Identity Crypto dependency through IdentityDirectory.cls.
 */
failed = 0
keyId = '000000000000a11c'

/* Happy path: one current MI key, explicit ACL and stable directory revision. */
directory = buildDirectory(keyId)
resolver = .XtpProvisionLdapResolver~new(directory)
verdict = resolver~resolveSession(sessionInfo(keyId))
call assertTrue verdict['OK'], 'exclusive MI key admitted'
call assertEqual 'mi:ed209a.mi1', verdict['PRINCIPAL'], 'MI principal derived from directory'
call assertEqual 'LDAP', verdict['AUTHORITY'], 'LDAP authority returned'
call assertTrue verdict['FENCED'], 'directory revision fence returned'
call assertTrue verdict['FENCE_REVISION'] > 0, 'nonzero directory fence revision'

/* Principal revocation must immediately deny the same established key id. */
ignore = directory~setEntityState('mi:ed209a.mi1', 'REVOKED')
verdict = resolver~resolveSession(sessionInfo(keyId))
call assertFalse verdict['OK'], 'revoked MI denied'
call assertEqual 'KEY_BINDING_DENIED', verdict['REASON'], 'revoked MI denial reason'

/* A shared service key can encrypt traffic, but it cannot identify an MI. */
directory = buildDirectory(keyId)
call addSharedServiceKey directory, keyId
resolver = .XtpProvisionLdapResolver~new(directory)
verdict = resolver~resolveSession(sessionInfo(keyId))
call assertFalse verdict['OK'], 'shared key collision denied'
call assertEqual 'KEY_NOT_EXCLUSIVE', verdict['REASON'], 'shared key collision is nonexclusive'

/* A second MI client using the same KEYID is an ambiguity, not a tie-break. */
directory = buildDirectory(keyId)
call addSecondMiKey directory, keyId
resolver = .XtpProvisionLdapResolver~new(directory)
verdict = resolver~resolveSession(sessionInfo(keyId))
call assertFalse verdict['OK'], 'duplicate MI key denied'
call assertEqual 'KEY_NOT_EXCLUSIVE', verdict['REASON'], 'duplicate MI key is nonexclusive'

/* ACL withdrawal denies admission while leaving the cryptographic key current. */
directory = buildDirectory(keyId)
ignore = directory~setEntityState('acl:mi1:xtp-provision', 'REVOKED')
resolver = .XtpProvisionLdapResolver~new(directory)
verdict = resolver~resolveSession(sessionInfo(keyId))
call assertFalse verdict['OK'], 'withdrawn XTP_PROVISION ACL denied'
call assertEqual 'KEY_BINDING_DENIED', verdict['REASON'], 'withdrawn ACL denial reason'

/* Key revocation denies admission independently of principal and ACL state. */
directory = buildDirectory(keyId)
ignore = directory~revokeKeyGeneration('keygen:xtp.provision:mi1:1', 'test revoke')
resolver = .XtpProvisionLdapResolver~new(directory)
verdict = resolver~resolveSession(sessionInfo(keyId))
call assertFalse verdict['OK'], 'revoked key generation denied'
call assertEqual 'KEY_UNBOUND', verdict['REASON'], 'revoked key no longer current binding'

if failed = 0 then do
  say 'XTP PROVISION LDAP RESOLVER: OK'
  exit 0
end
say 'XTP PROVISION LDAP RESOLVER: FAILED' failed
exit 1

buildDirectory: procedure
  use strict arg keyId
  d = .IdentityDirectory~new('test-peer')
  call requireOk d~createPrincipal('service:xtp.provision', 'oorexxEntityId=service:xtp.provision,ou=services,dc=example', 'SERVICE', 'XTP provision service'), 'service principal'
  call requireOk d~createPrincipal('service:xtp.provision/client:mi:ed209a.mi1', 'oorexxEntityId=client-mi1,oorexxEntityId=service:xtp.provision,ou=services,dc=example', 'NODE', 'XTP MI client'), 'client principal'
  call requireOk d~createPrincipal('mi:ed209a.mi1', 'oorexxEntityId=mi:ed209a.mi1,ou=nodes,dc=example', 'NODE', 'MI1'), 'MI principal'
  call requireOk d~createResource('resource:xtp.provision', 'oorexxEntityId=resource:xtp.provision,ou=resources,dc=example', 'SERVICE', 'xtp.provision', 'XTP provision admission'), 'resource'
  call requireOk d~createAclGrant('acl:mi1:xtp-provision', 'oorexxEntityId=acl:mi1:xtp-provision,ou=acl,dc=example', 'mi:ed209a.mi1', 'resource:xtp.provision', 'XTP_PROVISION', 'ALLOW'), 'ACL'
  call requireOk d~createKeySet('keyset:xtp.provision:mi1', 'oorexxEntityId=keyset-mi1,oorexxEntityId=client-mi1,oorexxEntityId=service:xtp.provision,ou=services,dc=example', 'service:xtp.provision/client:mi:ed209a.mi1', 'XTP_ENCRYPT'), 'key set'
  call requireOk d~stageKeyGeneration('keygen:xtp.provision:mi1:1', 'oorexxEntityId=keygen-mi1-1,oorexxEntityId=keyset-mi1,oorexxEntityId=client-mi1,oorexxEntityId=service:xtp.provision,ou=services,dc=example', 'keyset:xtp.provision:mi1', 1, 'AES256GCM', keyId, 'secret://xtp/xtp.provision/mi1/1'), 'key generation'
  call requireOk d~activateKeyGeneration('keyset:xtp.provision:mi1', 'keygen:xtp.provision:mi1:1'), 'key activation'
  return d

addSharedServiceKey: procedure
  use strict arg d, keyId
  call requireOk d~createKeySet('keyset:xtp.provision:shared', 'oorexxEntityId=keyset-shared,oorexxEntityId=service:xtp.provision,ou=services,dc=example', 'service:xtp.provision', 'XTP_ENCRYPT'), 'shared key set'
  call requireOk d~stageKeyGeneration('keygen:xtp.provision:shared:1', 'oorexxEntityId=keygen-shared-1,oorexxEntityId=keyset-shared,oorexxEntityId=service:xtp.provision,ou=services,dc=example', 'keyset:xtp.provision:shared', 1, 'AES256GCM', keyId, 'secret://xtp/xtp.provision/shared/1'), 'shared key generation'
  call requireOk d~activateKeyGeneration('keyset:xtp.provision:shared', 'keygen:xtp.provision:shared:1'), 'shared key activation'
  return

addSecondMiKey: procedure
  use strict arg d, keyId
  call requireOk d~createPrincipal('service:xtp.provision/client:mi:ed209a.mi2', 'oorexxEntityId=client-mi2,oorexxEntityId=service:xtp.provision,ou=services,dc=example', 'NODE', 'XTP MI2 client'), 'second client principal'
  call requireOk d~createPrincipal('mi:ed209a.mi2', 'oorexxEntityId=mi:ed209a.mi2,ou=nodes,dc=example', 'NODE', 'MI2'), 'second MI principal'
  call requireOk d~createAclGrant('acl:mi2:xtp-provision', 'oorexxEntityId=acl:mi2:xtp-provision,ou=acl,dc=example', 'mi:ed209a.mi2', 'resource:xtp.provision', 'XTP_PROVISION', 'ALLOW'), 'second ACL'
  call requireOk d~createKeySet('keyset:xtp.provision:mi2', 'oorexxEntityId=keyset-mi2,oorexxEntityId=client-mi2,oorexxEntityId=service:xtp.provision,ou=services,dc=example', 'service:xtp.provision/client:mi:ed209a.mi2', 'XTP_ENCRYPT'), 'second key set'
  call requireOk d~stageKeyGeneration('keygen:xtp.provision:mi2:1', 'oorexxEntityId=keygen-mi2-1,oorexxEntityId=keyset-mi2,oorexxEntityId=client-mi2,oorexxEntityId=service:xtp.provision,ou=services,dc=example', 'keyset:xtp.provision:mi2', 1, 'AES256GCM', keyId, 'secret://xtp/xtp.provision/mi2/1'), 'second key generation'
  call requireOk d~activateKeyGeneration('keyset:xtp.provision:mi2', 'keygen:xtp.provision:mi2:1'), 'second key activation'
  return

sessionInfo: procedure
  use strict arg keyId
  info = .directory~new
  info['SERVICE'] = 'xtp.provision'
  info['OPEN'] = '1'
  info['PROTECTION'] = 'encrypt'
  info['KEYID'] = keyId
  return info

requireOk: procedure
  use strict arg result, label
  if \result~ok then raise syntax 93.900 array(label result~code result~detail)
  return

assertTrue: procedure expose failed
  use strict arg actual, label
  if \actual then do
    say 'ASSERT TRUE FAILED:' label
    failed += 1
  end
  return

assertFalse: procedure expose failed
  use strict arg actual, label
  if actual then do
    say 'ASSERT FALSE FAILED:' label
    failed += 1
  end
  return

assertEqual: procedure expose failed
  use strict arg expected, actual, label
  if expected \== actual then do
    say 'ASSERT EQUAL FAILED:' label 'expected='expected 'actual='actual
    failed += 1
  end
  return

::requires '../src/XtpProvisionLdapResolver.cls'
