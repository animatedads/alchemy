#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"
sha256sum -c qualification/MANIFEST.sha256 >/dev/null
: "${GOPHER:?set GOPHER to LLM Gopher v0.21+}"
"$GOPHER" --profile oorexx-speech context oorexx-speech --full > /tmp/oorexx-speech-context.$$
grep -q 'arch.oorexx-speech.runtime' /tmp/oorexx-speech-context.$$
grep -q 'arch.oorexx-speech.rpc-https' /tmp/oorexx-speech-context.$$
for q in Macrospace streaming SIP RTP HTTPS LDAP JSON-RPC material; do
  "$GOPHER" --profile oorexx-speech search "$q" --sphere oorexx-speech > /tmp/oorexx-speech-search.$$
  grep -q '"class": "FOUND"' /tmp/oorexx-speech-search.$$
done
rm -f /tmp/oorexx-speech-context.$$ /tmp/oorexx-speech-search.$$
echo 'PASS OOREXX SPEECH SPHERE v0.1'
