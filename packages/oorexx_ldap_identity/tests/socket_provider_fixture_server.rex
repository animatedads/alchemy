parse arg port readyFile
if port="" then port=1399
dir=.IdentityDirectory~new("socket-provider-fixture")
ignore=dir~createPrincipal("principal:alice","uid=alice,ou=people,dc=example,dc=org","PERSON","Alice","alice")
ignore=dir~createResource("resource:directory","cn=directory,ou=resources,dc=example,dc=org","DIRECTORY","identity://example","Identity Directory")
provider=.TestSecretProvider~new
broker=.SecretBroker~new(provider)
authn=.SecretBrokerSimpleBindAuthenticator~new(dir,broker)
authority=.DirectoryAclLdapAuthority~new(dir)
service=.LdapConversationService~new(dir,.NativeLdapPersonality~new,authn,authority,"resource:directory")
addresses=.RegisteredSocketAddressProvider~new
addresses~register("ldap.public",.SocketAddresses~tcp("127.0.0.1",port))
sockets=.SocketSelector~new(addresses)
sockets~registerBinding("TCP",.RxSockTcpBinding~new)
server=.LdapWireServer~new(service,"127.0.0.1",port,"dc=example,dc=org",.nil,.nil,.false,0.05,15,.nil,sockets,"ldap.public")
served=server~serve(1,readyFile)
say "LDAP SOCKET PROVIDER SERVER: OK connections="||served
::requires "RxSockSocketBinding.cls"
::requires "src/LdapWireServer.cls"
