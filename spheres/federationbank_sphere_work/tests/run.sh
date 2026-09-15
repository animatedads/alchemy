#!/bin/sh
set -eu
: "${GOPHER:?set GOPHER to LLM Gopher v0.19-dev1+}"

TMP="${TMPDIR:-/tmp}/federationbank-sphere.$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

"$GOPHER" --profile federationbank context federationbank --full > "$TMP/context.json"
grep -q 'architecture.federationbank.authority-map' "$TMP/context.json"
grep -q 'ledger.federationbank.monetary-truth' "$TMP/context.json"
grep -q 'merchant.federationbank.arm-length-boundary' "$TMP/context.json"

"$GOPHER" --profile federationbank search "physical cash" --sphere federationbank > "$TMP/cash.json"
grep -q '"class": "FOUND"' "$TMP/cash.json"
grep -q 'cash.federationbank.physical-vs-monetary' "$TMP/cash.json"

"$GOPHER" --profile federationbank search "Merchant collateral" --sphere federationbank > "$TMP/merchant.json"
grep -q '"class": "FOUND"' "$TMP/merchant.json"
grep -q 'merchant.federationbank.collateral-two-effects' "$TMP/merchant.json"

"$GOPHER" --profile federationbank lookup topic=replay --sphere federationbank > "$TMP/replay.json"
grep -q '"class": "FOUND"' "$TMP/replay.json"
grep -q 'replay.federationbank.durable-idempotency' "$TMP/replay.json"

"$GOPHER" --profile federationbank open ledger.federationbank.monetary-truth > "$TMP/ledger.json"
grep -q 'SERIALIZABLE' "$TMP/ledger.json"
grep -q 'federationbank_engine_v0.9.2.zip' "$TMP/ledger.json"

echo "PASS FEDERATIONBANK GOPHER SPHERE v0.2"
