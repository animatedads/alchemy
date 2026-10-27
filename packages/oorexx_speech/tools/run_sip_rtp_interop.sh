#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$HERE/.." && pwd)
: "${SIP_ROOT:?Set SIP_ROOT to packages/oorexx_sip}"
: "${RTP_ROOT:?Set RTP_ROOT to packages/oorexx_rtp}"
: "${SOCKET_PROVIDER_ROOT:?Set SOCKET_PROVIDER_ROOT to the current SocketProvider package root}"

RTP_LIB=${RTP_LIB:-$RTP_ROOT/lib}
PATHS="$ROOT/src:$SIP_ROOT/src:$RTP_ROOT/src:$SOCKET_PROVIDER_ROOT/src"
export REXX_PATH="$PATHS${REXX_PATH:+:$REXX_PATH}"
export LD_LIBRARY_PATH="$RTP_LIB${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "${REXX:-rexx}" "$ROOT/tests/test_sip_rtp_interop.rex"
