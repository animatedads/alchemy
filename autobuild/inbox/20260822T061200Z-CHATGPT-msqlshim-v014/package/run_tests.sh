#!/bin/sh
set -eu
cd "$(dirname "$0")"
cat payload.part00 payload.part01 payload.part02 payload.part03 payload.part04 | base64 -d > msqlshim_v0.14.zip
sha256sum msqlshim_v0.14.zip
rm -rf work
mkdir work
unzip -q msqlshim_v0.14.zip -d work
cd work/msqlshim_v0.14
sh run_tests.sh
