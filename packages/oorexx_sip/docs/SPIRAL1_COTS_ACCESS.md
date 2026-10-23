# Spiral 1 COTS access — SIP

- RFC 3261 SIP access object: `SipProtocolAccess`.
- RFC 4566 SDP is the negotiated media-description interface.
- RFC 8760 digest support remains an authentication boundary.
- SIP signalling obtains UDP through SocketProvider; it does not own RxSock sockets.
- RTP is a sibling shared layer (`rtp/0.1`), not part of the SIP object.