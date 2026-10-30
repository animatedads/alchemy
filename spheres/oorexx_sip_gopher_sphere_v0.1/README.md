# ooRexx SIP/RTP Gopher Sphere v0.1

Continuity sphere for the ooRexx SIP server/client and shared RTP stack.

Current source baseline:
- SIP `0.1-dev17` in `packages/oorexx_sip`
- RTP `0.1-dev7` in `packages/oorexx_rtp`
- SIP archive SHA-256 `3fd4edc6b7fddbbd1aef4490a5168cf8092cb7665d9004f6a57bd4942a0be3a6`
- RTP archive SHA-256 `0eb69d0c09192a731c6c52c3fe8504030bdd846daf52ec9d89715896bdd77bda`

The governing rule is that a SIP call is not one object. Signalling/control, inbound audio, outbound audio, RTP receive, RTP send, socket carrier, STT, TTS, logging and instrumentation are correlated participants with independent identity, lifecycle and failure domains.

This sphere is documentation/continuity authority, not runtime protocol authority.


v0.1-dev17 adds an optional LDAP Identity v0.1-dev22 / Secret Broker credential-provider boundary for SIP Digest authentication. LDAP remains identity authority; SIP remains protocol authority; call and RTP/media objects remain independent.
