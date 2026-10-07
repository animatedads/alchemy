# dev10 carrier ownership

The independent SIP control/audio/RTP objects now share a SocketProvider authority.
Sharing that authority does not merge object lifecycles: SIP signalling, RTP endpoint,
RTP receiver, RTP sender, inbound audio and outbound audio remain independently
operable and separately logged.

# SIP call object model — dev9 shared RTP boundary

## Architectural rule

A SIP call is **not one object**. Correlation does not imply ownership.

Dev9 also removes the historical assumption that RTP belongs to SIP. RTP is a
shared protocol/media service in `rtp/0.1`.

```text
SipCall (correlation only)
  +-- SipCallControl
  +-- SipInboundAudio
  +-- SipOutboundAudio
  +-- RtpEndpoint          [shared RTP package]
  +-- RtpReceiver          [shared RTP package]
  +-- RtpSender            [shared RTP package]

Bindings:
  SipInboundAudio  -> RtpReceiver
  SipOutboundAudio -> RtpSender
  RtpReceiver      -> RtpEndpoint
  RtpSender        -> RtpEndpoint
```

`RtpEndpoint` owns the native datagram carrier lifetime. `RtpReceiver` and
`RtpSender` reference that endpoint but have their own lifecycle. This allows
one bidirectional RTP port to be used correctly without falsely turning send,
receive and application audio into one object.

## Signalling vs media

SIP owns:

* REGISTER/authentication;
* INVITE/ACK/BYE/CANCEL/OPTIONS;
* SIP transaction/dialog/control state;
* SDP offer/answer negotiation;
* correlation to a selected RTP graph.

RTP owns:

* RTP packet framing/parsing;
* sequence, timestamp, SSRC and marker metadata;
* payload codec boundary;
* the datagram endpoint used by RTP;
* independent RTP receiver/sender lifecycle.

Application audio owns:

* STT/TTS/microphone/speaker/recorder attachment;
* fan-out and producer selection;
* worker failure isolation.

## INVITE construction

The native SIP engine parses the remote SDP and returns an `invite-offer` event.
The ooRexx server then creates the shared RTP endpoint, receiver and sender,
obtains the endpoint's actual local port, and gives only that negotiated port
back to the SIP engine to construct the final 200 OK SDP answer.

This is important: SIP no longer allocates an RTP socket behind the application's
back.  The shared RTP object exists before SIP advertises the local media port.

## Shared socket/XTP alignment

The current XTP/socket architecture establishes `SocketSelector`,
`SocketEndpoint`, `SocketAddress` and `SocketCapabilities` as transport-level
shared concepts. RTP follows that shape rather than embedding carrier choices in
SIP. `RtpEndpoint` is currently backed by a native UDP provider because packet
timing and media conversion benefit from native execution. The carrier provider
can later bind to a datagram-capable `SocketSelector` without changing the
public RTP or SIP object contracts.

## Non-goals

Do not introduce:

* `SipCall~startEverything`;
* private SIP RTP sender/receiver classes;
* RTP packet parsing in STT/TTS workers;
* automatic call teardown because one media worker fails;
* a shared all-or-nothing lifecycle across control, endpoint, RX, TX, input or output.
