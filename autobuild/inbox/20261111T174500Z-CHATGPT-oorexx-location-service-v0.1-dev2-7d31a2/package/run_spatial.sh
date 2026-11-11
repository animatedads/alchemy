#!/bin/sh
set -eu
: "${ALCHEMY_PACKAGE_ROOT:=$(pwd)}"
cd "$ALCHEMY_PACKAGE_ROOT"
export REXX_PATH="$ALCHEMY_PACKAGE_ROOT/src"
rexx tests/test_spatial.rex
