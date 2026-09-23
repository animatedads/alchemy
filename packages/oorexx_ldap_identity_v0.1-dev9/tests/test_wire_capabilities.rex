dir = .IdentityDirectory~new("capability-test")
service = .LdapConversationService~new(dir, .NativeLdapPersonality~new, .nil, .nil, "resource:directory")
server = .LdapWireServer~new(service)
caps = server~compatibilitySnapshot
ignore = .LdapIdentityTest~assert(caps["rfc4533RefreshOnly"], "refreshOnly advertised")
ignore = .LdapIdentityTest~assert(caps["rfc4533RefreshAndPersistNotifications"], "persistent notifications advertised")
ignore = .LdapIdentityTest~assert(caps["rfc4533RefreshAndPersist"], "refreshAndPersist advertised")
ignore = .LdapIdentityTest~assert(caps["rfc2696PagedResults"], "RFC 2696 paged results advertised")
ignore = .LdapIdentityTest~assert(caps["pagedResultsAssociationLocal"], "paged state is association-local")
ignore = .LdapIdentityTest~assert(caps["pagedResultsRotatingCookies"], "paged cookies rotate")
ignore = .LdapIdentityTest~equal(64,caps["pagedResultsMaxActivePerAssociation"],"paged result sets are bounded")
ignore = .LdapIdentityTest~assert(caps["rfc3909Cancel"], "RFC 3909 Cancel advertised")
ignore = .LdapIdentityTest~assert(caps["rfc4533Cancel"], "Sync cancellation advertised")
ignore = .LdapIdentityTest~assert(caps["messageIdDemultiplexing"], "message-id demultiplexing advertised")
ignore = .LdapIdentityTest~assert(caps["persistentOperationDispatch"], "persistent operation dispatch advertised")
ignore = .LdapIdentityTest~assert(caps["asyncAccept"], "async association acceptance advertised")
ignore = .LdapIdentityTest~assert(\caps["concurrentDispatch"], "general concurrent dispatch still not overclaimed")
ignore = .LdapIdentityTest~assert(\caps["ldaps"], "plain endpoint does not claim LDAPS")

tls = .CapabilityTlsProvider~new
ldaps = .LdapWireServer~new(service, "127.0.0.1", 1636, "dc=example,dc=org", tls, .nil, .true)
lcaps = ldaps~compatibilitySnapshot
ignore = .LdapIdentityTest~assert(lcaps["ldaps"], "implicit TLS endpoint advertises LDAPS")
ignore = .LdapIdentityTest~assert(lcaps["tls"], "implicit TLS endpoint advertises TLS")
ignore = .LdapIdentityTest~assert(\lcaps["startTls"], "implicit TLS endpoint does not claim StartTLS mode")
say "LDAP WIRE CAPABILITIES: OK"

::class CapabilityTlsProvider
::method available
  return .true

::requires "tests/TestSupport.cls"
::requires "src/LdapWireServer.cls"
