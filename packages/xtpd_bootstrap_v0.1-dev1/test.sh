#!/bin/sh
set -eu
cd "$(dirname "$0")"
: "${NEWSHELL_HOME:?Set NEWSHELL_HOME to installed kit with LoggingCore.cls and crypto.cls}"
export REXX_PATH="$PWD/src:$NEWSHELL_HOME/src${REXX_PATH:+:$REXX_PATH}"
f=$(mktemp -d)
trap 'rm -rf "$f"' EXIT HUP INT TERM
rexx tests/test.rex "$f/role"
