parse arg port ca
profiles=.QuicSecurityProfileRegistry~new
profiles~register(.QuicSecurityProfile~new("CLIENT","localhost","oorexx-quic/0.1",ca,"","",.true))
addr=.QuicSocketAddress~new("127.0.0.1",port,"CLIENT","QUIC_MUX")
backend=.QuicSocketBackend~new(profiles)
binding=.RexxQuicSocketBinding~new(backend)
addresses=.RegisteredSocketAddressProvider~new
addresses~register("QUIC_MUX",addr,.SocketRole~SENDER)
provider=.SocketProvider~new(addresses)
provider~registerBinding("QUIC",binding)
sock=provider~sender("QUIC_MUX")
if sock=.nil then exit 10
s1=sock~openStream
s2=sock~openStream
if s1=.nil | s2=.nil then exit 11
if s1~streamId=s2~streamId then exit 12
p1="MUX_STREAM_ONE"||d2c(0)||"A"
p2="MUX_STREAM_TWO"||d2c(0)||"B"
a1=s1~asStream
if a1~socketAddress \== addr then exit 13
if \a1~write(p1) then exit 20
if s2~sendAll(p2)<>length(p2) then exit 21
r1=a1~read(65536)
r2=s2~recv(65536)
if r1 \== p1 then exit 30
if r2 \== p2 then exit 31
id1=s1~streamId; id2=s2~streamId
s1~close; s2~close; sock~close
say "CLIENT_MUX_OK" id1 id2
::requires "QuicSocketProvider.cls"
