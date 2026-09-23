dir = .IdentityDirectory~new("peer-a")
ignore = .LdapIdentityTest~assert(dir~createPrincipal("service:signer", "uid=signer,ou=services,dc=example,dc=org", "SERVICE", "Signer", "signer")~ok, "principal")
ignore = .LdapIdentityTest~assert(dir~createKeySet("keyset:signer", "cn=signer,ou=keysets,dc=example,dc=org", "service:signer", "SIGNING")~ok, "keyset")
ignore = .LdapIdentityTest~assert(dir~stageKeyGeneration("key:signer:1", "cn=1,cn=signer,ou=keysets,dc=example,dc=org", "keyset:signer", 1, "ED25519", "pub-one", "secret://keys/signer/1")~ok, "stage 1")
ignore = .LdapIdentityTest~assert(dir~activateKeyGeneration("keyset:signer", "key:signer:1")~ok, "activate 1")
ignore = .LdapIdentityTest~equal("ACTIVE", dir~entryById("key:signer:1")~state, "gen1 active")
ignore = .LdapIdentityTest~assert(dir~stageKeyGeneration("key:signer:2", "cn=2,cn=signer,ou=keysets,dc=example,dc=org", "keyset:signer", 2, "ED25519", "pub-two", "secret://keys/signer/2")~ok, "stage 2")
ignore = .LdapIdentityTest~assert(dir~activateKeyGeneration("keyset:signer", "key:signer:2")~ok, "activate 2")
ignore = .LdapIdentityTest~equal("RETIRING", dir~entryById("key:signer:1")~state, "gen1 retiring")
ignore = .LdapIdentityTest~equal("ACTIVE", dir~entryById("key:signer:2")~state, "gen2 active")
ignore = .LdapIdentityTest~equal("key:signer:2", dir~entryById("keyset:signer")~activeGenerationId, "active pointer")
ignore = .LdapIdentityTest~assert(dir~retireKeyGeneration("key:signer:1")~ok, "retire old")
ignore = .LdapIdentityTest~assert(dir~revokeKeyGeneration("key:signer:2", "operator revoke")~ok, "revoke active")
ignore = .LdapIdentityTest~equal("", dir~entryById("keyset:signer")~activeGenerationId, "revoked active pointer cleared")
say "KEY LIFECYCLE: OK"
::requires "tests/TestSupport.cls"
::requires "src/IdentityDirectory.cls"
