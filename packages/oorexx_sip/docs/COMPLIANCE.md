# SIP compliance target — v0.1-dev2

This is an executable interoperability development baseline, not a claim of complete SIP RFC conformance or certification.

## Implemented/qualified slice

* SIP/2.0 UDP signalling using ooRexx `rxsock` rather than native signalling sockets.
* RFC 3261-shaped REGISTER, INVITE, ACK, BYE, CANCEL and OPTIONS request/response framing for the exercised paths.
* Via/From/To/Call-ID/CSeq preservation in UAS responses and To-tag generation.
* Registrar Contact/Expires capture for a single current binding per user in this increment.
* Digest challenge/verification with SHA-256 default, SHA-512/256 support, and MD5 only as an explicit interoperability algorithm.
* SDP audio offer parsing and answer generation for RTP/AVP static payload types 0 (PCMU) and 8 (PCMA).
* RTP v2 packet receive and G.711 decode to 16-bit PCM.

## Runtime evidence for dev2

Using the supplied ooRexx 5.3.0 r13196 runtime:

* RxSock client -> RxSock registrar REGISTER returned 200.
* Credentialed REGISTER produced 401 challenge followed by authenticated 200 using SHA-256.
* INVITE -> 100/200 SDP negotiation allocated a native RTP port.
* A 160-sample PCMU RTP packet was accepted and surfaced to ooRexx as 320 PCM bytes.

## Not yet claimed

The following remain explicit future compliance work:

* RFC 3261 transaction state machines and retransmission timers (A/B/D/E/F/K/G/H/I/J), merged-request handling and full branch matching.
* TCP and TLS/SIPS transport.
* DNS NAPTR/SRV routing and outbound proxy route sets.
* Multiple registrar bindings, q-values, wildcard Contact deregistration and persistent location service.
* Proxy/B2BUA behaviour, Record-Route/Route processing and forking.
* NAT traversal (`rport` response handling, STUN, TURN, ICE), symmetric RTP policy.
* PRACK/100rel, UPDATE, REFER, SUBSCRIBE/NOTIFY and session timers.
* SRTP/DTLS-SRTP.
* RTCP, jitter buffer, loss concealment and clock-drift handling.
* Wideband codecs and dynamic RTP payload mapping.
* IPv6.
* SIP torture-suite and broad third-party interoperability matrix.

The package must not be described as fully RFC 3261 compliant until those protocol-state and interoperability requirements are qualified.

## Twinkle 1.10.3 interoperability fixture (dev3)

A captured Twinkle 1.10.3 REGISTER exposed two registrar interoperability requirements now covered by executable fixtures:

* a Contact-level `expires` parameter takes precedence over the general `Expires` header/default;
* a request with an empty `rport` Via parameter is answered with the actual source port, and the observed source address is returned as `received`.

`tests/twinkle_register_fixture.rex` reproduces the captured REGISTER shape and asserts a 300-second binding, `rport=5071`, and `received=127.0.0.1`.
`tests/twinkle_options_fixture.rex` exercises the UAS OPTIONS response shape used by softphone keepalive/capability probing.

## dev9 shared RTP claim boundary

RTP packet transport is no longer claimed as an implementation inside SIP. SIP
claims SDP negotiation and binding of the negotiated media endpoint to the
external `rtp/0.1` package. The shared RTP package currently qualifies RTP/AVP
payload type 0 (PCMU) and 8 (PCMA) over IPv4 UDP and exposes normalized 8 kHz
mono S16LE frames.

The environment qualification proves that SIP advertises the local port owned
by `RtpEndpoint`, receives a real RTP packet through `RtpReceiver`, and sends
frames through an independently-operable `RtpSender`. It does not yet claim
jitter-buffer quality, RTCP, SRTP, ICE, NAT traversal, Opus, IPv6 or full RFC
3550/3551 conformance.
