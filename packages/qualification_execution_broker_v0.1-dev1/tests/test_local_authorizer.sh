#!/usr/bin/env bash
set -euo pipefail
: "${REXX_BIN:?}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/tests"
rm -f local_challenge.json local_grant.json local_seed.hex no_such_private_key.hex
"$REXX_BIN" make_local_challenge.rex local_challenge.json
# Declining must succeed even though the private-key path does not exist, proving it was not opened.
printf 'NO\n' | "$REXX_BIN" "$ROOT/tools/qual_authorize.rex" local_challenge.json architect-ed25519 no_such_private_key.hex local_grant.json > local_decline.txt
if [[ -e local_grant.json ]]; then echo 'FAIL decline wrote grant'; exit 1; fi
grep -q 'private key was not opened' local_decline.txt
printf '%s\n' '9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60' > local_seed.hex
chmod 600 local_seed.hex
printf 'YES\n' | "$REXX_BIN" "$ROOT/tools/qual_authorize.rex" local_challenge.json architect-ed25519 local_seed.hex local_grant.json > local_approve.txt
"$REXX_BIN" verify_local_grant.rex local_challenge.json local_grant.json
rm -f local_challenge.json local_grant.json local_seed.hex local_decline.txt local_approve.txt
echo 'PASS test_local_authorizer'
