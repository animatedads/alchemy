# ooRexx SIP/RTP Gopher Sphere v0.1

Continuity sphere for the ooRexx SIP server/client and shared RTP stack.

Current source baseline:
- SIP `0.1-dev16` in `packages/oorexx_sip`
- RTP `0.1-dev7` in `packages/oorexx_rtp`
- SIP archive SHA-256 `d70e3c53a7b4c5aef70fcd095c94952fdc3430d2d38ac1861cab1073ef18e3e2`
- RTP archive SHA-256 `0eb69d0c09192a731c6c52c3fe8504030bdd846daf52ec9d89715896bdd77bda`

The governing rule is that a SIP call is not one object. Signalling/control, inbound audio, outbound audio, RTP receive, RTP send, socket carrier, STT, TTS, logging and instrumentation are correlated participants with independent identity, lifecycle and failure domains.

This sphere is documentation/continuity authority, not runtime protocol authority.
