# dev12 qualification

Scope: cross-package compatibility of ooRexx Speech with the published SIP dev15
speech adapter and RTP dev7 decoded-PCM object model.

## Added

- `tests/test_sip_rtp_interop.rex`
- `tools/run_sip_rtp_interop.sh`
- `SIP_RTP_INTEROP_DEV12.md`

The regression uses the actual external `sip_speech.cls` and `rtp.cls`; it does
not copy their classes into Speech.

## Local execution status

The current build container has the Speech dev11/dev12 source but no ooRexx
interpreter or materializable r13196 runtime. The cross-package Rexx regression
is therefore **NOT_RUN locally**. It is intended for independent native
qualification through Rasen Falcon with exact SIP/RTP/SocketProvider roots.

Static package checks and the ooRexx standards enforcer are recorded on the
sealed dev12 archive separately.

The launcher defaults `RTP_LIB` to `$RTP_ROOT/build`, matching the current RTP Makefile output `build/liboorexx_rtp.so`.
