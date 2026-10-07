dir = .IdentityDirectory~new("peer-a")
ignore = .LdapIdentityTest~assert(dir~createPrincipal("principal:alice", "uid=alice,ou=people,dc=example,dc=org", "PERSON", "Alice", "alice")~ok, "alice")
ignore = .LdapIdentityTest~assert(dir~createCredential("credential:alice:ldap", "cn=ldap-bind,uid=alice,ou=people,dc=example,dc=org", "principal:alice", "LDAP_SIMPLE_BIND_SECRET", "secret://identity/alice/ldap", .nil, .nil, "ACTIVE")~ok, "credential")
provider = .TestSecretProvider~new
provider~put("secret://identity/alice/ldap", "correct-horse-battery-staple")
broker = .SecretBroker~new(provider)
authn = .SecretBrokerSimpleBindAuthenticator~new(dir, broker)
r = authn~bind("uid=alice,ou=people,dc=example,dc=org", "correct-horse-battery-staple")
ignore = .LdapIdentityTest~assert(r~ok, "correct secret")
ignore = .LdapIdentityTest~equal("principal:alice", r~principalId, "principal attribution")
ignore = .LdapIdentityTest~equal(0, broker~activeLeaseCount, "lease retired")
r = authn~bind("uid=alice,ou=people,dc=example,dc=org", "wrong")
ignore = .LdapIdentityTest~assert(\r~ok, "wrong secret denied")
ignore = .LdapIdentityTest~equal(0, broker~activeLeaseCount, "failed lease retired")

/* Bind-name resolution follows ldap.matching/0.1.  The stored DN contains two
 * internal spaces; caseIgnoreMatch makes the one-space bind form equivalent. */
ignore = .LdapIdentityTest~assert(dir~createPrincipal("principal:spaced", "cn=Alice  Smith,ou=people,dc=example,dc=org", "PERSON", "Alice Smith", "alice-spaced")~ok, "spaced principal")
ignore = .LdapIdentityTest~assert(dir~createCredential("credential:spaced:ldap", "cn=ldap-bind,cn=Alice  Smith,ou=people,dc=example,dc=org", "principal:spaced", "LDAP_SIMPLE_BIND_SECRET", "secret://identity/spaced/ldap", .nil, .nil, "ACTIVE")~ok, "spaced credential")
provider~put("secret://identity/spaced/ldap", "space-secret")
r = authn~bind("cn=alice smith,ou=people,dc=example,dc=org", "space-secret")
ignore = .LdapIdentityTest~assert(r~ok, "schema matching bind-name resolution")
ignore = .LdapIdentityTest~equal("principal:spaced", r~principalId, "schema matched principal attribution")
ignore = .LdapIdentityTest~equal(0, broker~activeLeaseCount, "schema-matched bind lease retired")

/* ACTIVE is not enough: credential lifetime is DateTime-governed semantic state. */
ignore = .LdapIdentityTest~assert(dir~createPrincipal("principal:expired", "uid=expired,ou=people,dc=example,dc=org", "PERSON", "Expired", "expired")~ok, "expired principal")
expiredAt = .DateTime~fromUtcIsoDate("2000-01-01T00:00:00.000000Z")
ignore = .LdapIdentityTest~assert(dir~createCredential("credential:expired:ldap", "cn=ldap-bind,uid=expired,ou=people,dc=example,dc=org", "principal:expired", "LDAP_SIMPLE_BIND_SECRET", "secret://identity/expired/ldap", .nil, expiredAt, "ACTIVE")~ok, "expired credential")
provider~put("secret://identity/expired/ldap", "old-secret")
r = authn~bind("uid=expired,ou=people,dc=example,dc=org", "old-secret")
ignore = .LdapIdentityTest~assert(\r~ok, "expired credential denied")
ignore = .LdapIdentityTest~equal(0, broker~activeLeaseCount, "expired credential not leased")

entry = .NativeLdapPersonality~new~project(dir~entryById("credential:alice:ldap"), dir)
ignore = .LdapIdentityTest~assert(\entry~attributes~has("userPassword"), "directory projection never exposes raw secret")
ignore = .LdapIdentityTest~equal("secret://identity/alice/ldap", entry~attributes~first("oorexxSecretRef"), "directory exposes only reference")
say "SECRET BROKER BIND: OK"
::requires "tests/TestSupport.cls"
::requires "src/LdapSecretBrokerAdapter.cls"
