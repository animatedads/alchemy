# ooRexx SIP v0.1-dev16

## dev16 — outbound user-agent call origination

Dev16 adds an outbound SIP client dialog without collapsing call control or media into one object. `SipClient~invite()` sends INVITE+SDP, receives a successful final response, sends ACK, then returns the ordinary independent `SipCall` graph. The returned call has a separate `SipClientDialog` for BYE/dialog signalling, `SipCallControl`, AudioIn, AudioOut, RTP endpoint, RTP receiver and RTP sender.

The client dialog does not own the application control or media lifecycles. `dialog~bye()` signals remote call termination; resource release remains explicit through the call graph. The current slice offers PCMU/PT0 or PCMA/PT8 narrowband RTP and consumes the remote `m=audio` port/payload from SDP.

# ooRexx SIP v0.1-dev16

Dev15 adds an optional Speech PCM integration seam without turning a SIP call into one object. `SipSpeechRecognitionConsumer` adapts decoded `SipInboundAudio` frames into a caller-owned Speech STT stream; `SipSpeechSynthesisProducer` adapts a caller-owned Speech TTS stream into RTP-sized 8 kHz S16LE frames for `SipOutboundAudio`. Neither adapter owns SIP control, RTP transport, STT/TTS stream lifetime, or pacing.

Dev15 also consumes Instrumentation Mesh dev8 additive correlation context. SIP and RTP events continue to use the explicit call correlation ID, while each retains its own source authority and object context. Causation is carried only when explicitly supplied; it is never inferred from timestamps or co-location.

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

## dev12 — Instrumentation Mesh

`src/sip_instrumentation.cls` integrates SIP and shared RTP with
`instrumentation.mesh/0.1`. It projects the existing structured event stream into
bounded operational counters/gauges without replacing Alchemy Log and without
creating another transport. `SipEventFanoutSink` allows forensic logging and
operational instrumentation to consume the same events independently.


## dev14 — socket isolation telemetry joins SIP/RTP instrumentation

SIP can now build its shared SocketProvider through `SipSocketFactory~observedProvider(observer)`. The UDP binding is decorated by `socket.telemetry/0.1` before either SIP signalling or the shared RTP endpoint acquires it. The same provider therefore observes both signalling and media carrier activity without merging SIP, RTP, audio or socket lifecycle.

The socket observer is intentionally a separate authority from `SipInstrumentationSink` and `RtpInstrumentationSink`. A caller may use `SocketInstrumentationObserver` to project carrier acquisition/I/O gauges into Instrumentation Mesh while Alchemy Log retains forensic protocol events. Payload and peer identity remain excluded by the Socket Telemetry default policy.