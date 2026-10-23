parse arg port cert key
profiles=.QuicSecurityProfileRegistry~new
profiles~register(.QuicSecurityProfile~new("SERVER","localhost","oorexx-quic/0.1","",cert,key,.false))
addr=.QuicSocketAddress~new("127.0.0.1",port,"SERVER","QUIC_MUX")
backend=.QuicSocketBackend~new(profiles)
binding=.RexxQuicSocketBinding~new(backend)
addresses=.RegisteredSocketAddressProvider~new
addresses~register("QUIC_MUX",addr,.SocketRole~LISTENER)
provider=.SocketProvider~new(addresses)
provider~registerBinding("QUIC",binding)
listener=provider~listener("QUIC_MUX",8)
if listener=.nil then exit 10
sock=.nil
do i=1 to 200 while sock=.nil
  ignore=listener~waitReady(50)
  sock=listener~tryAccept
end
if sock=.nil then exit 11
streams=.array~new
say "SERVER_CONNECTION_READY"
do while streams~items<2
  st=sock~tryAcceptStream
  if st=.nil then do
    ignore=sock~pump(50)
    iterate
  end
  streams~append(st)
end
id1=streams[1]~streamId; id2=streams[2]~streamId
if id1=id2 then exit 12
do i=1 to 2
  st=streams[i]
  bytes=st~recv(65536)
  if bytes=.nil then exit 20+i
  if st~sendAll(bytes)<>length(bytes) then exit 30+i
end
do i=1 to 2
  streams[i]~close
end
sock~close
listener~close
say "SERVER_MUX_OK" id1 id2
::requires "QuicSocketProvider.cls"
