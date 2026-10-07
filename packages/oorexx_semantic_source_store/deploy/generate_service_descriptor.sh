#!/usr/bin/env bash
set -euo pipefail

: "${SSC_EXAMINER_WEBSOCKET_URL:?set SSC_EXAMINER_WEBSOCKET_URL, normally wss://HOST/wire-ui}"
: "${SSC_EXAMINER_OUTBOUND_QUEUE:?set SSC_EXAMINER_OUTBOUND_QUEUE to the WireUIServer-authorised IN queue}"

case "$SSC_EXAMINER_WEBSOCKET_URL" in
  wss://*) ;;
  *) echo "refusing non-TLS websocket URL: $SSC_EXAMINER_WEBSOCKET_URL" >&2; exit 2 ;;
esac

out="${1:-service-descriptor}"
umask 077
cat > "$out" <<JSON
{
  "schema": "semantic-source.code-examiner.service/1",
  "applicationId": "SSC-CODE-EXAMINER",
  "accessPointId": "WEB",
  "source": "SSC.CODE.EXAMINER.WEB",
  "websocketUrl": "${SSC_EXAMINER_WEBSOCKET_URL}",
  "outboundQueue": "${SSC_EXAMINER_OUTBOUND_QUEUE}",
  "authenticationRequired": true,
  "authentication": {
    "scheme": "SSC-SIGNED-CHALLENGE-1",
    "session": "opaque-bearer",
    "principalSource": "verified-session",
    "privilegedStepUp": [
      "WORK.ACCEPT",
      "WORK.REFUSE",
      "BRANCH.CLASSIFY",
      "BRANCH.PROTECT",
      "BRANCH.CONFLICT.RESOLVE"
    ]
  }
}
JSON
chmod 0644 "$out"
printf '%s\n' "$out"
