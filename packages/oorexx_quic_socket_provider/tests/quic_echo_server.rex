parse arg port cert key
profiles=.QuicSecurityProfileRegistry~new
profiles~register(.QuicSecurityProfile~new("SERVER","localhost","oorexx-quic/0.1","",cert,key,.false))
addr=.QuicSocketAddress~new("127.0.0.1",port,"SERVER","QUIC_ECHO")
backend=.QuicSocketBackend~new(profiles)
binding=.RexxQuicSocketBinding~new(backend)
addresses=.RegisteredSocketAddressProvider~new
addresses~register("QUIC_ECHO",addr,.SocketRole~LISTENER)
provider=.SocketProvider~new(addresses)
provider~registerBinding("QUIC",binding)
listener=provider~listener("QUIC_ECHO",8)
if listener=.nil then exit 10
if listener~descriptor<0 then exit 11
sock=.nil
do i=1 to 200 while sock=.nil
  ignore=listener~waitReady(50)
  sock=listener~tryAccept
end
if sock=.nil then exit 12
/* Common provider must retain the peer address supplied by QuicSocketListener. */
if sock~address \== sock~raw~address then exit 13
if sock~address == addr then exit 14
bytes=sock~recv(65536)
if bytes=.nil then exit 20
n=sock~sendAll(bytes)
if n<>length(bytes) then exit 21
ignore=sock~waitDrained(100)
sock~close
listener~close
say "SERVER_OK" length(bytes)
::requires "QuicSocketProvider.cls"
