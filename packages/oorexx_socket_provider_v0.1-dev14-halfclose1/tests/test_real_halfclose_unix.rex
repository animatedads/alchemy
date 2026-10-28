/* test_real_halfclose_unix.rex - live AF_UNIX half-close in /tmp.
 * Needs ooRexx Unix Socket v0.6 and Foreign Runtime on REXX_PATH.
 * Architecture: Tom Dyer. Coding: Claude (Opus 5.5). */
ap=.RegisteredSocketAddressProvider~new
ap~register("loop",.SocketAddresses~unix("/tmp/oorexx-halfclose-"||random(10000,99999)||".sock"))
p=.SocketProvider~new(ap)
p~registerBinding("UNIX",.RexxUnixSocketBinding~new)
exit .HalfCloseRoundTrip~run("UNIX",p)
::requires "SocketProvider.cls"
::requires "UnixSocketBinding.cls"
::requires "HalfCloseRoundTrip.cls"
