#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$HERE"
./run_all.sh
REXX_PATH="../src:../src/adapters${REXX_PATH:+:$REXX_PATH}" rexx adapters/test_imap_adapter.rex
REXX_PATH="../src:../src/adapters${REXX_PATH:+:$REXX_PATH}" rexx adapters/test_storage_adapter.rex
