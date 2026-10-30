#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
REXX=${REXX:-rexx}
: "${XTP_PROVISION_ROOT:?set XTP_PROVISION_ROOT to xtp_route_publication_v0.1-dev2 or newer}"
: "${OOREXX_CRYPTO_ROOT:?set OOREXX_CRYPTO_ROOT to the qualified ooRexx Crypto root}"
[ -f "$XTP_PROVISION_ROOT/src/XtpProvisionIngress.cls" ] || { echo "missing XtpProvisionIngress.cls" >&2; exit 2; }
[ -f "$OOREXX_CRYPTO_ROOT/src/crypto.cls" ] || { echo "missing crypto.cls" >&2; exit 2; }
command -v "$REXX" >/dev/null 2>&1 || { echo "ooRexx executable unavailable: $REXX" >&2; exit 2; }
export REXX_PATH="$ROOT:$XTP_PROVISION_ROOT/src:$OOREXX_CRYPTO_ROOT/src${REXX_PATH:+:$REXX_PATH}"
cd "$ROOT"
"$REXX" tests/test_xtp_provision_ingress_ldap_integration.rex
