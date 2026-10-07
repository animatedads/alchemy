# Source provenance — ooRexx SIP v0.1-dev10

## dev10 shared socket inputs

- `oorexx_socket_provider_v0.1-dev8.zip` from Library was the authority baseline
  for `SocketProvider`, `SocketSelector`, `SocketAddress` and provider ownership.
- `oorexx_xtp_v0.1-dev11.zip` was reviewed for the current XTP shared socket
  contract and multipath/provider boundary.
- `oorexx_norm_v0.1-dev1.zip` was reviewed for the first-class NORM family and
  the rule that protocol/session mechanics remain below the provider binding.
- `oorexx_rtp_v0.1-dev1.zip` and `oorexx_sip_v0.1-dev9.zip` are the direct source
  baselines for this increment.

# Source provenance — ooRexx SIP v0.1-dev9

* ooRexx target/runtime: user-supplied `oorexx-5.3.0-13196.ubuntu1604debug.x86_64` package.
* SIP signalling: `rxsock` from that exact ooRexx package.
* Digest/OpenSSL conventions: Library Crypto v0.8.3; SIP links libcrypto for digest/random primitives.
* Native ABI/loading conventions: Library Foreign Runtime v0.22.6.
* Audio integration direction: current Library Audio V9 work; application-facing audio remains normalized frames rather than device ownership inside SIP.
* Logging: shared ooRexx Logging Framework v0.7 through the existing `recordEvent(Directory)` adapter boundary.
* Review gate: Library `oorexx_standards_enforcer.py`.

## dev9 shared transport inputs

The refactor was explicitly aligned to the Library transport work current on
2026-10-07:

* `oorexx_socket_provider_v0.1-dev2.zip`
  SHA-256 `a93f77ba001840e5fda32e4a71637975239b42b2f0b16faa406c166a7d64c7a7`
* `oorexx_xtp_v0.1-dev7.zip`
  SHA-256 `2d27f3f930a48f4072b4490821fa679f97a0a6e9a2364669057e510a879fedd4`

Those packages establish the shared selector/endpoint/capability direction and
the rule that application code does not own carrier-specific APIs.

RTP is now an external/shared dependency: `oorexx_rtp_v0.1-dev1`. SIP performs
SDP negotiation and supplies the chosen address/port/payload parameters to the
RTP objects. No third-party SIP or RTP stack source is vendored.
