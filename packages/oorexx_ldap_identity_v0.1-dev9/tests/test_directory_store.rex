say 'DIRECTORY STORE START'

store = .MemoryDirectoryStore~new
dir = .IdentityDirectory~new('peer-store', store)

nb = .DateTime~fromUtcIsoDate('2026-09-22T12:00:00.000000Z')
na = .DateTime~fromUtcIsoDate('2027-09-22T12:00:00.000000Z')

r = dir~createPrincipal('principal:001', 'uid=001,ou=people,dc=example,dc=org', 'PERSON', '001', '001')
ignore = .LdapIdentityTest~assert(r~ok, 'principal stored')
r = dir~createCredential('credential:001', 'cn=password,uid=001,ou=people,dc=example,dc=org', 'principal:001', 'PASSWORD', 'secret://principal/001', nb, na, 'ACTIVE')
ignore = .LdapIdentityTest~assert(r~ok, 'credential stored')
revision = dir~revision

recovered = .IdentityDirectory~new('peer-store', store)
ignore = .LdapIdentityTest~equal(revision, recovered~revision, 'revision recovered')
ignore = .LdapIdentityTest~equal('001', recovered~entryById('principal:001')~displayName, 'numeric-looking text preserved as string')
cred = recovered~entryById('credential:001')
ignore = .LdapIdentityTest~assert(cred~notBefore~isA(.DateTime), 'notBefore recovered as DateTime')
ignore = .LdapIdentityTest~equal(nb~utcIsoDate, cred~notBefore~utcIsoDate, 'notBefore instant recovered')
ignore = .LdapIdentityTest~equal('secret://principal/001', cred~secretRef, 'secret reference recovered')


-- Replicated changes are also durable, but do not consume the target peer's
-- local origin sequence. The next local write must therefore be target:1.
source = .IdentityDirectory~new('source')
r = source~createPrincipal('principal:remote', 'uid=remote,dc=example,dc=org')
ignore = .LdapIdentityTest~assert(r~ok, 'source change created')
remoteChange = source~changesSince(0)[1]
targetStore = .MemoryDirectoryStore~new
target = .IdentityDirectory~new('target', targetStore)
r = target~applyReplicatedChange(remoteChange)
ignore = .LdapIdentityTest~assert(r~ok, 'replicated change persisted')
targetRecovered = .IdentityDirectory~new('target', targetStore)
ignore = .LdapIdentityTest~assert(targetRecovered~entryById('principal:remote') <> .nil, 'replicated entity recovered')
r = targetRecovered~createPrincipal('principal:local', 'uid=local,dc=example,dc=org')
ignore = .LdapIdentityTest~assert(r~ok, 'local write after remote recovery')
ignore = .LdapIdentityTest~equal('target:1', r~detail, 'remote changes do not consume local origin sequence')

-- A failed durable append must not advance or mutate authoritative memory state.
failing = .FailingDirectoryStore~new
blocked = .IdentityDirectory~new('peer-fail', failing)
r = blocked~createPrincipal('principal:fail', 'uid=fail,dc=example,dc=org')
ignore = .LdapIdentityTest~assert(\r~ok, 'failing store blocks mutation')
ignore = .LdapIdentityTest~equal(0, blocked~revision, 'failed append does not advance revision')
ignore = .LdapIdentityTest~assert(blocked~entryById('principal:fail') == .nil, 'failed append does not mutate directory')

say 'DIRECTORY STORE: OK'

::class FailingDirectoryStore subclass DirectoryStore
::method bindDirectory
  use strict arg peerId
  return .DirectoryResult~success(.true)
::method appendChange
  use strict arg change
  return .DirectoryResult~failure('TEST_STORE_FAILURE', change~changeId)
::method loadChanges
  return .DirectoryResult~success(.array~new)

::requires 'src/DirectoryStore.cls'
::requires 'tests/TestSupport.cls'
