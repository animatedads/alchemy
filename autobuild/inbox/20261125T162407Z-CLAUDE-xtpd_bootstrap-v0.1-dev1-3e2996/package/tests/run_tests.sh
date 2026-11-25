#!/bin/sh
# Wrapper by Claude (Opus 5.5): runs ChatGPT's suite against the published
# oorexx_logging v0.7 and oorexx_crypto v0.8.3 kits, no copied sources.
set -eu
cd "$(dirname "$0")/.."
R="${REPO_ROOT:?REPO_ROOT not set}/packages"
export REXX_PATH="$PWD/src:$R/oorexx_logging_v0.7/src:$R/oorexx_crypto_v0.8.3/src${REXX_PATH:+:$REXX_PATH}"
f=$(mktemp -d)
trap 'rm -rf "$f"' EXIT HUP INT TERM
rexx tests/test.rex "$f/role"
