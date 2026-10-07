parse arg port caFile bridgeDirectory
if port = "" then raise syntax 88.900 array("port required")
if caFile = "" then raise syntax 88.900 array("CA file required")
if bridgeDirectory = "" then bridgeDirectory = "bridge"

config = .LdapClientTlsConfig~new
config~bridgeDirectory = bridgeDirectory
config~caFile = caFile
config~verifyPeer = .true
config~readTimeout = 10
config~writeTimeout = 10
provider = .OpenSslLdapClientTlsProvider~new(config)

client = .LdapWireClient~new("localhost", port)
r = client~connect
ignore = .LdapIdentityTest~assert(r~ok, "connect before StartTLS")
r = client~startTls(provider)
ignore = .LdapIdentityTest~assert(r~ok, "StartTLS upgrade")
ignore = .LdapIdentityTest~assert(client~tlsActive, "client marks TLS active")
session = r~value
ignore = .LdapIdentityTest~assert(session~protocol = "TLSv1.2" | session~protocol = "TLSv1.3", "TLS 1.2+ negotiated")

creds = '00'x || "uid=alice,ou=people,dc=example,dc=org" || '00'x || "wire-secret"
r = client~bindSasl("PLAIN", creds)
ignore = .LdapIdentityTest~assert(r~ok, "SASL PLAIN after StartTLS")
r = client~search("dc=example,dc=org", "SUB", "(uid=alice)", .array~of("uid","cn","entryUUID","oorexxEntityId"))
ignore = .LdapIdentityTest~assert(r~ok, "TLS LDAP search")
ignore = .LdapIdentityTest~equal(1, r~value~items, "one TLS LDAP entry")
entry = r~value[1]
ignore = .LdapIdentityTest~equal("Alice TLS", entry~attributes~first("cn"), "TLS entry content")
ignore = .LdapIdentityTest~equal("principal:alice", entry~attributes~first("oorexxEntityId"), "semantic identity survives TLS")
ignore = .LdapIdentityTest~equal(36, entry~attributes~first("entryUUID")~length, "entryUUID survives TLS")
client~unbind
provider~close
say "LDAP STARTTLS + SASL PLAIN OOREXX CLIENT: OK"

::requires "tests/TestSupport.cls"
::requires "src/LdapWireClient.cls"
::requires "src/LdapOpenSslClientTls.cls"
