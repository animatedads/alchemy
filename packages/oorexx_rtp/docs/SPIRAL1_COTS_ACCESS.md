# Spiral 1 COTS access — RTP

RTP is a shared protocol layer, not a SIP-owned media object.

- RFC 3550 access object: `RtpProtocolAccess`.
- RTP/AVP profile witness: RFC 3551.
- Carrier acquisition: `socket.provider/0.1`.
- Multicast membership: `socket.multicast.membership/0.1`; RTP does not implement IGMP.
- `RtpReceiver` and `RtpSender` remain independently startable objects.