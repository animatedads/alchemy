parse arg port
if port="" then port=1399
addresses=.RegisteredSocketAddressProvider~new
addresses~register("ldap.public",.SocketAddresses~tcp("127.0.0.1",port))
sockets=.SocketSelector~new(addresses)
sockets~registerBinding("TCP",.RxSockTcpBinding~new)
client=.LdapWireClient~new("127.0.0.1",port,sockets,"ldap.public")
r=client~connect
ignore=.LdapIdentityTest~assert(r~ok,"SocketProvider DUA connect")
r=client~search("","BASE","(objectClass=*)",.array~of("supportedLDAPVersion","namingContexts"))
ignore=.LdapIdentityTest~assert(r~ok,"SocketProvider Root DSE")
ignore=.LdapIdentityTest~equal("3",r~value[1]~attributes~first("supportedLDAPVersion"),"LDAPv3 via provider")
client~unbind
say "LDAP SOCKET PROVIDER CLIENT: OK"
::requires "tests/TestSupport.cls"
::requires "RxSockSocketBinding.cls"
::requires "src/LdapWireClient.cls"
