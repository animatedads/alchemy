parse arg port caFile bridgeDirectory
if port = "" then raise syntax 88.900 array("port required")
config = .LdapClientTlsConfig~new
config~bridgeDirectory = bridgeDirectory
config~caFile = caFile
config~verifyPeer = .true
config~readTimeout = 10
config~writeTimeout = 10
provider = .OpenSslLdapClientTlsProvider~new(config)
client = .LdapWireClient~new("localhost", port)
r = client~connectTls(provider)
ignore = .LdapIdentityTest~assert(r~ok, "direct TLS connect")
ignore = .LdapIdentityTest~assert(client~tlsActive, "LDAPS marks TLS active")
session = r~value
ignore = .LdapIdentityTest~assert(session~protocol = "TLSv1.2" | session~protocol = "TLSv1.3", "LDAPS TLS 1.2+")
creds = '00'x || "uid=alice,ou=people,dc=example,dc=org" || '00'x || "wire-secret"
ignore = .LdapIdentityTest~assert(client~bindSasl("PLAIN", creds)~ok, "LDAPS SASL PLAIN")
r = client~search("dc=example,dc=org", "SUB", "(uid=alice)", .array~of("uid","cn","entryUUID","oorexxEntityId"))
ignore = .LdapIdentityTest~assert(r~ok, "LDAPS search")
ignore = .LdapIdentityTest~equal(1, r~value~items, "LDAPS one entry")
ignore = .LdapIdentityTest~equal("Alice LDAPS", r~value[1]~attributes~first("cn"), "LDAPS content")
client~unbind
provider~close
say "LDAP LDAPS OOREXX CLIENT: OK"
::requires "tests/TestSupport.cls"
::requires "src/LdapWireClient.cls"
::requires "src/LdapOpenSslClientTls.cls"
