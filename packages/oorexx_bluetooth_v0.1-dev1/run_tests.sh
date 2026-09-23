#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$HERE/tests"
rexx test_core.rex
rexx test_profile_map.rex
rexx test_rfcomm_codec.rex
