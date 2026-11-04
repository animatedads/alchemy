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
before=sock~availableBidirectionalStreams
if before<2 then exit 9
s1=sock~tryOpenStream
s2=sock~tryOpenStream
if s1=.nil | s2=.nil then exit 11
if \s1~setBlockingMode(.false) then exit 14
if \s2~setBlockingMode(.false) then exit 15
if s1~streamId=s2~streamId then exit 12
p1="MUX_STREAM_ONE"||d2c(0)||"A"
p2="MUX_STREAM_TWO"||d2c(0)||"B"
a1=s1~asStream
if a1~socketAddress \== addr then exit 13
r=s1~trySend(p1)
do n=1 to 100 while r~retryable
  r=s1~trySend(p1)
end
if \r~ok | r~count<>length(p1) then exit 20
r=s2~trySend(p2)
do n=1 to 100 while r~retryable
  r=s2~trySend(p2)
end
if \r~ok | r~count<>length(p2) then exit 21
rr=s1~tryRecv(65536)
do n=1 to 100 while rr~retryable
  rr=s1~tryRecv(65536)
end
if \rr~ok then exit 30
r1=rr~bytes
rr=s2~tryRecv(65536)
do n=1 to 100 while rr~retryable
  rr=s2~tryRecv(65536)
end
if \rr~ok then exit 31
r2=rr~bytes
if r1 \== p1 then exit 32
if r2 \== p2 then exit 33
id1=s1~streamId; id2=s2~streamId
s1~close; s2~close; sock~close
say "CLIENT_MUX_OK" id1 id2 "BIDI_AVAIL_BEFORE" before "AFTER" sock~availableBidirectionalStreams
::requires "QuicSocketProvider.cls"
