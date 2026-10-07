# ooRexx SIP v0.1-dev10

## dev10: shared SocketProvider transport boundary

SIP no longer acquires UDP sockets directly with RxSock. Both SIP signalling and
the shared RTP layer acquire their UDP carrier through `SocketProvider`. The
protocols still own their wire formats, state machines and logging; SocketProvider
owns carrier selection/acquisition.

The default local profile registers `RxSockUdpBinding`, while callers may inject
an already configured `SocketProvider`/`SocketSelector`. This keeps SIP aligned
with the same shared socket boundary now used by XTP and NORM without merging
those protocols into one object model.

# ooRexx SIP v0.1-dev9

SIP registrar/UAS and user-agent client for ooRexx 5.3.

## dev9: RTP moves to the shared transport/media layer

RTP is no longer implemented as a private SIP transport.  SIP now performs SIP
signalling, dialog/control work and SDP negotiation only.  Once an INVITE offer
has been accepted, it binds the negotiated media parameters to the external
`rtp/0.1` package:

```text
SIP / SDP                         shared RTP
--------                          ----------
INVITE offer                      RtpEndpoint
codec/port negotiation       ->   RtpReceiver
200 OK + local RTP port           RtpSender

SipCall (correlation only)
  +-- SipCallControl
  +-- SipInboundAudio  -> RtpReceiver
  +-- SipOutboundAudio -> RtpSender
  +-- RtpEndpoint
  +-- RtpReceiver
  +-- RtpSender
```

`RtpEndpoint`, `RtpReceiver` and `RtpSender` are shared objects from
`oorexx_rtp_v0.1-dev1`; they are not SIP classes.  The same RTP package can be
used by RTSP, media tools, gateways or other protocols without importing SIP.

The shared RTP endpoint is deliberately aligned with the current SocketProvider
/XTP direction: transport acquisition is a provider boundary, not application
logic.  dev1 of the RTP package has a native UDP endpoint provider for the audio
hot path.  Its public object contract is carrier-independent so a later
`SocketSelector` datagram endpoint can replace that provider without changing
SIP, STT, TTS or recorder objects.

## SIP signalling

SIP UDP signalling remains ooRexx + RxSock. `SipUdpTransport` owns the ordinary
SIP datagram socket and preserves peer addresses for `rport`/`received` handling.
The native `oorexx_sip` package now contains SIP parsing, response construction,
Digest primitives and SDP negotiation; it contains no RTP packet send/receive
API in its public package table.

## Call object rule

A call is not one object. Correlation does not imply ownership. Call control,
inbound application audio, outbound application audio, RTP endpoint, RTP receive
and RTP send all retain separate identity, lifecycle and failure state.

Inbound audio supports named consumers (STT, recorder, monitor, speaker, etc.).
Outbound audio supports named producers with one explicit active selection
(TTS, microphone, file, generator, etc.). Stopping a consumer/producer or RTP
receiver/sender does not implicitly tear down the others.

## Registrar / authentication

* REGISTER and OPTIONS run through RxSock.
* Digest authentication supports MD5, SHA-256 and SHA-512-256, with SHA-256 as
  the default.
* Contact-level `;expires=` is honoured ahead of the general `Expires` header.
* RFC 3581-style `rport`/`received` response information is filled from the
  actual datagram source.
* Successful registrations are represented by queryable
  `SipRegistrationBinding` objects.
* Auth rejection evidence includes a machine-readable reason.

## Observability

SIP and shared RTP objects emit independent structured events into the same
`recordEvent(Directory)` sink boundary.  The production adapter remains the
shared ooRexx Logging Framework v0.7.  Shared logging correlates the graph; it
does not turn it back into one object.

## Build

Build shared RTP first:

```sh
cd ../oorexx_rtp_v0.1-dev1
make OOREXX_ROOT=/path/to/extracted/usr/local
```

Then SIP:

```sh
make OOREXX_ROOT=/path/to/extracted/usr/local
```

Runtime:

```sh
export LD_LIBRARY_PATH="/path/to/oorexx_rtp/build:$PWD/build:/path/to/oorexx/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export REXX_PATH="/path/to/oorexx_rtp/src:$PWD/src${REXX_PATH:+:$REXX_PATH}"
rexx examples/registrar_audio_sink.rex
```

The code and qualification target the user-supplied ooRexx 5.3.0 r13196 Ubuntu
x86-64 runtime.
