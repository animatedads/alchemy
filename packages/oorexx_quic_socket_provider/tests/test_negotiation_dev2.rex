profiles=.QuicSecurityProfileRegistry~new
profiles~register(.QuicSecurityProfile~new("P","example.test","oorexx-quic/0.1"))
addr=.QuicSocketAddress~new("192.0.2.44",443,"P","DEBUG_REMOTE")
offers=.QuicSocketOfferProvider~new
offers~register("debug.remote","quic-1",addr,40,"REMOTE",.true,"QUIC dev2 qualified")
neg=.SocketNegotiator~new
neg~registerOfferProvider(offers)
req=.SocketNegotiationRequest~new("debug.remote",.SocketRole~SENDER,.true,.true,.false,.false)
sel=neg~negotiate(req)
if \sel~selected then exit 10
if sel~address \== addr then exit 11
if \sel~offer~capabilities~secure then exit 12
if \sel~offer~capabilities~stream then exit 13
if sel~offer~capabilities~multicast then exit 14
say "NEGOTIATION_DEV2_OK"
::requires "QuicSocketProvider.cls"
