profiles=.QuicSecurityProfileRegistry~new
p=.QuicSecurityProfile~new("P","example.test","oorexx-quic/0.1")
profiles~register(p)
a=.QuicSocketAddress~new("192.0.2.10",443,"P","TEST")
if a~transport<>"QUIC" then exit 10
if a~scheme<>"quic" then exit 11
if a~addressFamily<>"QUIC_INET" then exit 12
if \a~family~capabilities~secure then exit 13
if \a~family~capabilities~stream then exit 14
if a~multicast then exit 15
if pos("securityProfile=P",a~canonical)=0 then exit 16
say "CONTRACT_OK"
::requires "QuicSocketProvider.cls"
