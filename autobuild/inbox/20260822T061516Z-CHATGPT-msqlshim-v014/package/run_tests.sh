#!/bin/sh
set -eu
cd "$(dirname "$0")/prepared/msqlshim_v0.14"
sh run_tests.sh
