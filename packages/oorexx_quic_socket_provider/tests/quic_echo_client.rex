parse arg port ca
payload="QUIC_SOCKET_PROVIDER_LIVE_ROUNDTRIP"||d2c(0)||"BINARY"
profiles=.QuicSecurityProfileRegistry~new
profiles~register(.QuicSecurityProfile~new("CLIENT","localhost","oorexx-quic/0.1",ca,"","",.true))
addr=.QuicSocketAddress~new("127.0.0.1",port,"CLIENT","QUIC_ECHO")
backend=.QuicSocketBackend~new(profiles)
binding=.RexxQuicSocketBinding~new(backend)
addresses=.RegisteredSocketAddressProvider~new
addresses~register("QUIC_ECHO",addr,.SocketRole~SENDER)
provider=.SocketProvider~new(addresses)
provider~registerBinding("QUIC",binding)
if provider~capabilities("QUIC_ECHO",.SocketRole~SENDER)~secure \= .true then exit 29
sock=provider~sender("QUIC_ECHO")
if sock~address \== addr then exit 30
if sock~descriptor<0 then exit 31
stream=sock~asStream
if stream~socketAddress \== addr then exit 32
if \stream~pump(0) then exit 33
if \stream~write(payload) then exit 34
reply=stream~read(65536)
if reply \== payload then do
  say "mismatch expected" length(payload) "got" length(reply)
  exit 35
end
stream~close
say "CLIENT_OK" length(reply)
::requires "QuicSocketProvider.cls"
