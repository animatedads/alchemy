/* test_real_halfclose_tcp.rex - live TCP half-close on 127.0.0.1.
 * Needs RxSock socket.cls on REXX_PATH. Architecture: Tom Dyer.
 * Coding: Claude (Opus 5.5). */
ap=.RegisteredSocketAddressProvider~new
ap~register("loop",.SocketAddresses~tcp("127.0.0.1",39192))
p=.SocketProvider~new(ap)
p~registerBinding("TCP",.RxSockTcpBinding~new)
exit .HalfCloseRoundTrip~run("TCP",p)
::requires "SocketProvider.cls"
::requires "RxSockSocketBinding.cls"
::requires "HalfCloseRoundTrip.cls"
